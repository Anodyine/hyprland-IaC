#!/bin/bash

# Target file for the dispatcher script
DISPATCHER_SCRIPT="/etc/NetworkManager/dispatcher.d/99-force-wol.sh"

# 1. Define the Dispatcher Script Content
SCRIPT_CONTENT='#!/bin/sh
interface=$1
status=$2

if [ "$status" = "up" ]; then
    # Check if ethtool is available and the interface supports Magic Packet (g)
    # We use grep -v "Supports" here too just to be safe, though less critical inside the dispatcher
    if /usr/bin/ethtool "$interface" | grep -v "Supports" | grep -q "Wake-on: .*g"; then
        # Already good? No, this check is "Does it SUPPORT g". 
        # Actually, for the dispatcher, we want: IF supports G, THEN enable G.
        # So we check the SUPPORTS line.
        if /usr/bin/ethtool "$interface" | grep "Supports Wake-on" | grep -q "g"; then
            /usr/bin/ethtool -s "$interface" wol g
        fi
    fi
fi'

# CORRECTION FOR DISPATCHER CONTENT:
# The inner logic above was slightly messy. Let's simplify the dispatcher content to be robust.
SIMPLE_SCRIPT_CONTENT='#!/bin/sh
interface=$1
status=$2

if [ "$status" = "up" ]; then
    # If the interface advertises "g" support in the "Supports Wake-on" line...
    if /usr/bin/ethtool "$interface" | grep "Supports Wake-on" | grep -q "g"; then
        # ...force it to be enabled.
        /usr/bin/ethtool -s "$interface" wol g
    fi
fi'

# 2. Install the Dispatcher Script
if [ ! -f "$DISPATCHER_SCRIPT" ] || ! echo "$SIMPLE_SCRIPT_CONTENT" | diff -q - "$DISPATCHER_SCRIPT" > /dev/null; then
    echo "🔧 Installing NetworkManager Dispatcher script for WOL..."
    echo "$SIMPLE_SCRIPT_CONTENT" | sudo tee "$DISPATCHER_SCRIPT" > /dev/null
    sudo chmod +x "$DISPATCHER_SCRIPT"
    sudo chown root:root "$DISPATCHER_SCRIPT"
    echo "✅ Dispatcher script installed."
else
    echo "✅ WOL Dispatcher script is already up to date."
fi

# 3. Trigger the "Up" Event (The Fix)
ACTIVE_CON=$(nmcli -t -f NAME,TYPE connection show --active | grep ':802-3-ethernet' | head -n1 | cut -d: -f1)

if [ -n "$ACTIVE_CON" ]; then
    DEVICE=$(nmcli -t -f DEVICE,NAME connection show --active | grep ":$ACTIVE_CON" | cut -d: -f1)
    
    # THE FIX IS HERE:
    # We pipe to grep -v "Supports" to ignore the capabilities line.
    # We look for "Wake-on: g" specifically in the remaining output.
    if ! sudo ethtool "$DEVICE" 2>/dev/null | grep -v "Supports" | grep -q "Wake-on: g"; then
        echo "🔄 WOL is NOT active on $DEVICE. Cycling connection '$ACTIVE_CON'..."
        sudo nmcli connection down "$ACTIVE_CON"
        sudo nmcli connection up "$ACTIVE_CON"
        echo "✅ Connection cycled."
    else
        echo "✅ WOL is already active (g) on $ACTIVE_CON. No restart needed."
    fi
else
    echo "⚠️ No active Ethernet connection found. The script will run automatically next time you connect."
fi
