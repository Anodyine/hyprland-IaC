#!/bin/bash
set -e # Exit immediately if a command fails

echo ">> Starting Arch Snapper & GRUB Setup..."

# ---------------------------------------------------------
# 1. Install Packages (Idempotent)
# ---------------------------------------------------------
echo ">> Ensuring packages..."
sudo pacman -S --needed --noconfirm snapper snap-pac grub-btrfs inotify-tools

# ---------------------------------------------------------
# 2. Configure Snapper
# ---------------------------------------------------------
echo ">> Configuring Snapper root layout..."
if mountpoint -q /.snapshots; then
    sudo umount /.snapshots
fi

# Remove directory if exists (to allow snapper to create config)
if [ -d "/.snapshots" ]; then
    sudo rm -rf /.snapshots
fi

# Create config (only if it doesn't exist)
if [ ! -f "/etc/snapper/configs/root" ]; then
    sudo snapper -c root create-config /
fi

# Restore the mountpoint
sudo rm -rf /.snapshots
sudo mkdir -p /.snapshots
sudo mount -a # Remounts from fstab

# ---------------------------------------------------------
# 3. Configure Retention & Permissions
# ---------------------------------------------------------
echo ">> Applying retention policy..."
CONF="/etc/snapper/configs/root"
USER=$(logname)

# Set permissions so the user can actually browse snapshots
sudo chmod a+rx /.snapshots
sudo chown :$USER /.snapshots
sudo sed -i "s/^ALLOW_USERS=\"\"/ALLOW_USERS=\"$USER\"/" $CONF

# Set limits (5 hourly/daily, 0 others)
sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=".*"/TIMELINE_LIMIT_HOURLY="5"/' $CONF
sudo sed -i 's/^TIMELINE_LIMIT_DAILY=".*"/TIMELINE_LIMIT_DAILY="5"/' $CONF
sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=".*"/TIMELINE_LIMIT_WEEKLY="0"/' $CONF
sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=".*"/TIMELINE_LIMIT_MONTHLY="0"/' $CONF
sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=".*"/TIMELINE_LIMIT_YEARLY="0"/' $CONF
sudo sed -i 's/^NUMBER_LIMIT=".*"/NUMBER_LIMIT="10"/' $CONF

# ---------------------------------------------------------
# 4. Enable OverlayFS for Read-Only Snapshots (CRITICAL)
# ---------------------------------------------------------
echo ">> Configuring mkinitcpio for writable snapshot booting..."
MKINIT="/etc/mkinitcpio.conf"

# Check if hook is already present
if grep -q "grub-btrfs-overlayfs" "$MKINIT"; then
    echo "   Overlay hook already present."
else
    # Check for systemd hook (warning based on docs)
    if grep -q "HOOKS=.*systemd" "$MKINIT"; then
        echo "WARNING: Systemd initramfs detected. grub-btrfs-overlayfs may not work."
        echo "Please switch to busybox hooks (base udev...) or consult documentation."
    fi

    # Append the hook to the end of the HOOKS list
    # Replaces the closing parenthesis ')' with ' grub-btrfs-overlayfs)'
    echo "   Adding grub-btrfs-overlayfs to HOOKS..."
    sudo sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1 grub-btrfs-overlayfs)/' "$MKINIT"
    
    echo "   Regenerating initramfs..."
    sudo mkinitcpio -P
fi

# ---------------------------------------------------------
# 5. Enable Services
# ---------------------------------------------------------
echo ">> Enabling services..."
# Fix the executable permission bug common in Arch
sudo chmod +x /etc/grub.d/41_snapshots-btrfs
sudo systemctl enable --now grub-btrfsd

# ---------------------------------------------------------
# 6. The Redirect Fix (Bootloader Installation and Stub Config)
# ---------------------------------------------------------
echo ">> Installing Bootloader with Btrfs modules..."

# Force GRUB to look in /boot/efi/grub for its config/modules
# This aligns the binary search path with our stub file location
sudo grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=GRUB \
  --modules="btrfs part_gpt part_msdos" \
  --recheck

ROOT_UUID=$(findmnt -n -o UUID /)

if [ -z "$ROOT_UUID" ]; then
    echo "ERROR: Could not detect Root UUID. Aborting stub generation."
    exit 1
fi
echo ">> Detected Root UUID: $ROOT_UUID"

# We target /boot/efi/grub/grub.cfg as requested
STUB_DIR="/boot/efi/grub"
STUB_FILE="$STUB_DIR/grub.cfg"

echo ">> Creating Stub Config at $STUB_FILE..."

if [ ! -d "$STUB_DIR" ]; then
    sudo mkdir -p "$STUB_DIR"
fi

# Backup existing if it's not already a backup
if [ -f "$STUB_FILE" ]; then
    sudo cp "$STUB_FILE" "${STUB_FILE}.bak"
fi

# Write the Stub
sudo tee "$STUB_FILE" > /dev/null <<EOF
search --no-floppy --fs-uuid --set=root $ROOT_UUID
set prefix=(\$root)/@/boot/grub
configfile /@/boot/grub/grub.cfg
EOF

# ---------------------------------------------------------
# 7. Generate the Real Config
# ---------------------------------------------------------
echo ">> Generating the main GRUB config inside Btrfs..."
# This generates the file at /boot/grub/grub.cfg (which is actually /@/boot/grub/grub.cfg)
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "=========================================="
echo "Setup Complete. Reboot to test."
echo "=========================================="