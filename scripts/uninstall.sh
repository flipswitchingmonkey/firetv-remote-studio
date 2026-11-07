#!/bin/sh
# Removes the Fire TV Remote Studio components. Run as root. Keeps user settings unless --purge.
DST="/Library/Audio/Plug-Ins/HAL/FireTVRemoteMicrophone.driver"
rm -rf "$DST"
rm -rf /Users/Shared/FireTVRemoteStudio
killall coreaudiod 2>/dev/null || true
launchctl bootout system/com.uaaa.firetv-remote-bridge.helper 2>/dev/null || true
if [ "$1" = "--purge" ]; then rm -rf "/Applications/Fire TV Remote Studio.app" "/Applications/FireTVRemoteBridge.app"; fi
echo "uninstalled driver, shared ring and helper registration"
