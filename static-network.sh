#!/bin/bash
# EchoMAV, LLC
# This script sets up a static network on the EchoPilot SBX using NetworkManager (nmcli)
# It will prompt the user for the IP info since we don't really have a way to predict what the desired IP will be on the SBX
# usage: static-network.sh
# An alias is also added to the interface with the value of BACKDOOR_ADDR

IP_PREFIX="10.223"
BACKDOOR_ADDR="172.20.154.0/24"
PROMPTINPUT=false
sigterm_handler() { 
  echo "Shutdown signal received."
  exit 1
}

function interactive {
	local result
	read -p "${2}? ($1) " result
	if [ -z "$result" ] ; then result=$1 ; elif [ "$result" == "*" ] ; then result="" ; fi
	echo $result
}


## Setup signal trap
trap 'trap " " SIGINT SIGTERM SIGHUP; kill 0; wait; sigterm_handler' SIGINT SIGTERM SIGHUP

SUDO=$(test ${EUID} -ne 0 && which sudo)

echo "Enter the network provisioning information below...";
echo "Note for Herelink radios, use 192.168.144.4/24, but 192.168.144.10 and 192.168.144.11 cannot be used";

IFACE="eth0"
IP_INPUT=$(interactive "172.20.1.4/24" "IPv4 Address with Netmask")
# GATEWAY=$(interactive "172.20.100.100" "IPv4 Gateway")
# no gateway for now, as we want the cellular to provide gateway 
GATEWAY=""

# validate ip address
if [[ ! $IP_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,3}$ ]]; then
    echo "ERROR! Invalid IP Address, should be x.x.x.x/y where y is the subnet mask" >&2; exit 1
fi
HOST=$(echo ${IP_INPUT} | cut -d/ -f 1);
NETMASK=$(echo ${IP_INPUT} | cut -d/ -f 2);

echo "Configuring ${IFACE} with the provided static IP address ${HOST}/${NETMASK}";
   
# check if there is a connection called Wired connection 1", if so take it down and delete

state=$(nmcli -f GENERAL.STATE c show "Wired connection 1" 2>/dev/null)
if [[ "$state" == *activated* ]] ; then         # take the interface down
        $SUDO nmcli c down "Wired connection 1"
fi
exist=$(nmcli c show "Wired connection 1" 2>/dev/null)
if [ ! -z "$exist" ] ; then     # delete the interface if it exists
        echo "Removing Wired connection 1..."
        $SUDO nmcli c delete "Wired connection 1"
fi

# check if there is already an interface called static-$IFACE, if so take down and delete
state=$(nmcli -f GENERAL.STATE c show "static-$IFACE" 2>/dev/null)
if [[ "$state" == *activated* ]] ; then         # take the interface down
        $SUDO nmcli c down "static-$IFACE"
fi
exist=$(nmcli c show "static-$IFACE" 2>/dev/null)
if [ ! -z "$exist" ] ; then     # delete the interface if it exists
        $SUDO nmcli c delete "static-$IFACE"
fi

echo "Creating new connection static-$IFACE..."
$SUDO nmcli c add con-name "static-$IFACE" ifname $IFACE type ethernet ip4 $HOST/$NETMASK

# if gateway was provided, add that info to the connection
if [[ "$GATEWAY" == *.* ]]
then
    echo "Defining gateway ${GATEWAY}...";
    $SUDO nmcli c mod "static-$IFACE" ifname $IFACE gw4 $GATEWAY 
fi

# add backdoor ip address
$SUDO nmcli c mod "static-$IFACE" +ipv4.addresses "$BACKDOOR_ADDR"

# disable ipv6
$SUDO nmcli c mod "static-$IFACE" ipv6.method "disabled"

# bring up the interface
$SUDO nmcli c up "static-$IFACE"

# Set mcast routes
$SUDO nmcli con mod "static-$IFACE" +ipv4.routes "224.0.0.0/8"
$SUDO nmcli con mod "static-$IFACE" +ipv4.routes "239.0.0.0/8"

# change hostname
echo "Setting hostname to EchoMAV-SBX...";
echo "EchoMAV-SBX" > /tmp/$$.hostname
$SUDO install -Dm644 /tmp/$$.hostname /etc/hostname
$SUDO hostname "EchoMAV-SBX"

echo "";
echo "Static Ethernet Configuration Successful! Interface $IFACE is set to $HOST/$NETMASK"
echo ""
