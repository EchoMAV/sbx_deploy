#!/bin/bash
# EchoMAV, LLC
# This script helps set up the EchoPilot SBX using NetworkManager (nmcli)
# usage: setup-network.sh -i {interface} -a {ip_addres|auto|dhcp} -g {gateway(optional)}
# If auto is used, the static IP address will be set to 10.223.x.y where x and y are the last two octects of the network interface mac address
# The first two octets cab be changed per IP_PREFIX
# An alias is also added to the interface with the value of BACKDOOR_ADDR
#
# This is a helper script only, it is not used during installation

IP_PREFIX="10.223"
BACKDOOR_ADDR="172.20.154.0/24"
sigterm_handler() { 
  echo "Shutdown signal received."
  exit 1
}

## Setup signal trap
trap 'trap " " SIGINT SIGTERM SIGHUP; kill 0; wait; sigterm_handler' SIGINT SIGTERM SIGHUP

SUDO=$(test ${EUID} -ne 0 && which sudo)

function print_help { echo "Usage: ./setup-network.sh -i interface_name -a ip_addres|auto|dhcp -g gateway_address(optional)" >&2 ; }

# process args
while getopts :i:a:g:h: flag;
do
    case "${flag}" in
        h)  print_help
            exit 1
            ;;
        i) IFACE=${OPTARG};;
        a) IP_INPUT=${OPTARG};;
        g) GATEWAY=${OPTARG};;
        *) print_help
           exit 1
           ;;
    esac
done

# check mandatory arguments

if [ -z $IP_INPUT ]; then
        echo 'Missing mandatory -a argument' >&2
        print_help
        exit 1
fi

if [ -z $IFACE ]; then
        echo 'Missing mandatory -i argument' >&2
        print_help
        exit 1
fi

if [ $IP_INPUT = "auto" ]; then    
    ifconfig ${IFACE} &> /dev/null
    if [ $? -ne 0 ] 
    then 
        echo "ERROR: Failed to get information for interface ${IFACE}, does it really exist?"
        echo ""
        echo "Here is output of ip link show:"
        ip link show
        exit 1 
    fi

    echo "Determining the auto static IP address for interface ${IFACE}...";
    # Get the mac address
    MAC_ADDRESS=$(ifconfig ${IFACE} | awk '/ether/ {print $2}')

    OCT1DEC=$((0x`ifconfig ${IFACE} | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[5]}'`))
    OCT2DEC=$((0x`ifconfig ${IFACE} | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[6]}'`))
    
    echo "MAC address for ${IFACE} is $MAC_ADDRESS";

    if ! [[ $OCT1DEC =~ ^[0-9]{1,3} && $OCT2DEC =~ ^[0-9]{1,3} ]] ; then
        echo "Error: Failure calculating the target IP address" >&2; exit 1
    fi
    
    HOST="$IP_PREFIX.$OCT1DEC.$OCT2DEC";
    NETMASK=16;
    echo "Auto-calculated IP is $HOST/$NETMASK";

elif [ $IP_INPUT = "dhcp" ]; then 
  #if static-iface exists, then mod to dhcp
  exist=$(nmcli c show "static-$IFACE" 2>/dev/null)  
  if [ ! -z "$exist" ] ; then     # delete the interface if it exists
        $SUDO nmcli con mod "static-$IFACE" ipv4.method auto
        $SUDO nmcli con mod "static-$IFACE" ipv4.gateway ""
        $SUDO nmcli con mod "static-$IFACE" ipv4.addresses ""
        $SUDO nmcli con down "static-$IFACE"
        $SUDO nmcli con up "static-$IFACE"
  else
    echo "Error: connection static-$IFACE is not found. This script is only designed to convert an existing static-$IFACE to DHCP"; 
  fi
  echo "Connection static-$IFACE is now set to DHCP";
  exit

else
    # validate ip address
    if [[ ! $IP_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,3}$ ]]; then
        echo "ERROR! Invalid IP Address, should be x.x.x.x/y where y is the subnet mask" >&2; exit 1
    fi
    HOST=$(echo ${IP_INPUT} | cut -d/ -f 1);
    NETMASK=$(echo ${IP_INPUT} | cut -d/ -f 2);

    echo "Configuring ${IFACE} with the provided static IP address ${HOST}/${NETMASK}";
   
fi

# check if there is a connection called Wired connection 1", if so take it down and delete\

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

# bring up the interface
$SUDO nmcli c up "static-$IFACE"

echo "";
echo "Static Ethernet Configuration Successful! Interface $IFACE is set to $HOST/$NETMASK"
echo ""

