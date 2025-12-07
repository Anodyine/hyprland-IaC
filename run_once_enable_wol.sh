#!/bin/bash

# Define the target file
WOL_CONF="/etc/NetworkManager/conf.d/wake-on-lan.conf"

# Define the configuration content
CONFIG_CONTENT="[connection]
ethernet.wake-on-lan=magic"

# Check if the file exists and has the correct content
if [ ! -f "$WOL_CONF" ] || ! grep -Fq "ethernet.wake-on-lan=magic" "$WOL_CONF"; then
    echo "🔧 Enabling Wake-on-LAN globally for NetworkManager..."

    # Use sudo to write the file (since it's in /etc)
    echo "$CONFIG_CONTENT" | sudo tee "$WOL_CONF" > /dev/null

    # Reload NetworkManager to apply changes immediately
    echo "🔄 Reloading NetworkManager..."
    sudo systemctl reload NetworkManager
else
    echo "✅ Wake-on-LAN is already enabled globally."
fi