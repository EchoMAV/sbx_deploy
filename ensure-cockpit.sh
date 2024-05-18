#!/bin/bash
# usage:
#   ensure-cockpit.sh
#
# This script ensures that cockpit it installed and setup
# As recommended by cockpit, it enableds the backport repo and uses it to get the latest version

DRY_RUN=false
LOCAL=/usr/local
SUDO=$(test ${EUID} -ne 0 && which sudo)

$SUDO echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list
$SUDO apt update

$SUDO apt install -y -t bookworm-backports cockpit

# Change the port to 443/80 and restart

$SUDO sed -i 's/9090/443/g' /lib/systemd/system/cockpit.socket
$SUDO sed -i '/ListenStream=80/d' /lib/systemd/system/cockpit.socket
$SUDO sed -i '/ListenStream=443/a ListenStream=80' /lib/systemd/system/cockpit.socket 
$SUDO systemctl daemon-reload
$SUDO systemctl restart cockpit.socket



