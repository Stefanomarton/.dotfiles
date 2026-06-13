#!/usr/bin/env bash

# clipboard history
wl-paste --watch cliphist store &
disown

# nextcloud
nextcloud &
disown

# Check VM
## Define the name of the VM
vm_name="work"

### Check if the VM is running
if ! virsh dominfo "$vm_name" | grep -q "State:\s*running"; then

    ### Start VM using virsh
    virsh start "$vm_name"

    killall looking-glass-client

    sleep 10
    hyprctl dispatch exec "[workspace name:w11 silent; noanim] looking-glass-client -F"

else

    ### Command to start Looking Glass
    killall looking-glass-client
    hyprctl dispatch exec "[workspace name:w11 silent; noanim] looking-glass-client -F"

fi

# Kmonad

## Start kmonad if hostname is laptop
if [ "$(hostnamectl hostname)" = "laptop" ]; then
    sleep 1 && kmonad .config/kmonad/laptop.kbd
fi

if [ "$(hostnamectl hostname)" = "desktop" ] &&
    ! pgrep -f "^go-hass-agent-amd64 run" >/dev/null; then
    go-hass-agent run &
fi

# quickshell widgets
qs -p ~/personal/projects/quickshell/workspaces/ &
disown

qs -p ~/personal/projects/quickshell/corner/ &
disown
