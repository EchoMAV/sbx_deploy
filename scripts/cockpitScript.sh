#!/bin/bash

# Only used by cockpit to get/set some information from the filesystem

function ApnChange
{
    echo "Removing existing network manager profile for cellular..."
    sudo nmcli con delete 'cellular'
    echo "Adding network manager profile for cellular..."
    sudo nmcli connection add type gsm ifname ttyUSB0 con-name "cellular" apn "$1" connection.autoconnect yes	
}

while [[ $# -gt 0 ]]; do 
    key="$1"
    shift  

    case $key in
        -a)
            ApnChange $1
            exit 0
            ;;
        -d)
            ls /dev/ | grep video
            exit 0
            ;;
        -s)
            ls /dev/ | grep ttyS | sed -e "s/.*/\/dev\/&/"
            exit 0
            ;;
        -i)
            basename -a /sys/class/net/*
            exit 0
            ;;
        -c)
            nmcli con show cellular | grep gsm.apn | cut -d ":" -f2 | xargs
            exit 0
            ;;
        -v)
            cat /usr/local/echopilot/version.txt
            exit 0
            ;;
        -u)
            hostname -I | awk '{print $1}' | cut -d'.' -f1,2
            exit 0
            ;;
        -z)
            hostname -I | cut -d' ' -f1 | xargs
            exit 0
            ;;
        -g)
            gst-client list_pipelines
            exit 0
            ;;
	    -t)
            journalctl --no-pager -q -r -u mavnetProxy --output=short | grep -Po '(^|[ ,])FMU Connected=\K[^,]*' -m1 | sed 's/.$//'
	        exit 0
            ;;
    esac
    exit 0
done
