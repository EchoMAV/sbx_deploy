#!/bin/bash

SUDO=$(test ${EUID} -ne 0 && which sudo)
SYSCFG=/etc/systemd
UDEV_RULESD=/etc/udev/rules.d

DEFAULTS=false
DRY_RUN=false
while (($#)) ; do    
	if [ "$1" == "--dry-run" ] && ! $DRY_RUN ; then DRY_RUN=true ; set -x ;
	elif [ "$1" == "--defaults" ] ; 
        then            
            DEFAULTS=true ;
	fi
	shift
done

function contains {
	local result=no
	#if [[ " $2 " =~ " $1 " ]] ; then result=yes ; fi
	if [[ $2 == *"$1"* ]] ; then result=yes ; fi
	echo $result
}

function interactive {
	local result
	read -p "${2}? ($1) " result
	if [ -z "$result" ] ; then result=$1 ; elif [ "$result" == "*" ] ; then result="" ; fi
	echo $result
}

APN="Broadband";  #default value
if ! $DEFAULTS ; then
	APN=$(interactive "$APN" "APN for cellular serice")			
fi	


if [ ! -z "$APN" ] ; then
	echo "Removing existing network manager profile for cellular..."
	$SUDO nmcli con delete 'cellular'
	echo "Adding network manager profile for cellular..."
	$SUDO nmcli connection add type gsm ifname ttyUSB0 con-name "cellular" apn "$APN" connection.autoconnect yes	
	echo "Waiting for conneciton to come up..."
	sleep 5
	$SUDO nmcli con show
else
	echo "APN cannot be blank, doing nothing!"
fi


