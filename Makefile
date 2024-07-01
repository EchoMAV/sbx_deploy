# MK1 Deploy Makefile
# EchoMAV, LLC
# bstinson@echomav.com
# Standard install is make install (requires internet)
# Run make installed while the device has internet. At the end of the configuration, an interactive session will let you set up at static IP address

SHELL := /bin/bash
SN := $(shell hostname)
SUDO := $(shell test $${EUID} -ne 0 && echo "sudo")
.EXPORT_ALL_VARIABLES:

SERIAL ?= $(shell python3 serial_number.py)
LOCAL=/usr/local
LOCAL_SCRIPTS=scripts/start.sh scripts/cockpitScript.sh scripts/temperature.sh scripts/start-video.sh scripts/stop-video.sh scripts/serial_number.py scripts/snap.sh scripts/start-edge.sh
CONFIG ?= /var/local
LIBSYSTEMD=/lib/systemd/system
PKGDEPS ?= v4l-utils build-essential nano nload picocom curl htop modemmanager
#SERVICES=mavnetProxy.service temperature.service video.service edge.service
# leaving out mavnetProxy.service for the herelink build as it does it's own telemetry routing via s.bus in/out
SERVICES=temperature.service video.service edge.service
SYSCFG=/usr/local/echopilot/mavnetProxy
DRY_RUN=false
PLATFORM ?= $(shell python serial_number.py | cut -c1-4)
SW_LOCATION=sw_driver
N2N_REPO=https://github.com/ntop/n2n.git
N2N_REV=3.1.1

.PHONY = clean dependencies cockpit cellular network enable install provision see uninstall n2n

default:
	@echo "Please choose an action:"
	@echo ""
	@echo "  install: installs programs and system scripts (requires internet)"
	@echo "  dependencies: ensure all needed software is installed (requires internet)"
	@echo "  cockpit: installs and updates only cockpit (requires internet)"
	@echo "  cellular: installs and updates only cellular"
	@echo "  network: sets up only the network"
	@echo "  see: shows the provisioning information for this system"
	@echo "  uninstall: disables and removes services and files"
	@echo ""
	@echo ""

clean:
	@if [ -d src ] ; then cd src && make clean ; fi

dependencies:	
	@if [ ! -z "$(PKGDEPS)" ] ; then $(SUDO) apt-get install -y $(PKGDEPS) ; fi
	@curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | $(SUDO) bash
	@$(SUDO) apt-get install speedtest

cellular:
# run script which sets up nmcli "cellular" connection. Remove --defaults if you want it to be interactive, otherwise it'll use the default ATT APN: Broadband
	@$(SUDO) ./ensure-cellular.sh

network:
# start an interactive session to configure the network
	@$(SUDO) ./static-network.sh

n2n:
# clone and build n2n
	@if [ -d src ]; then $(SUDO) rm -rf src; else mkdir -p src; fi
	@git clone $(N2N_REPO) -b $(N2N_REV) src
	@( cd ./src && ./autogen.sh && ./configure && make && $(SUDO) make install )
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done
	
cockpit:
	@$(SUDO) ./ensure-cockpit.sh
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done

# set up cockpit files
	@echo "Copying cockpit files..."
	@$(SUDO) rm -rf /usr/share/cockpit/telemetry/ /usr/share/cockpit/mavnet-server/ /usr/share/cockpit/video/ /usr/share/cockpit/cellular
	@$(SUDO) mkdir /usr/share/cockpit/telemetry/
	@$(SUDO) cp -rf ui/telemetry/* /usr/share/cockpit/telemetry/
	@$(SUDO) mkdir /usr/share/cockpit/video/
	@$(SUDO) cp -rf ui/video/* /usr/share/cockpit/video/
	@$(SUDO) mkdir /usr/share/cockpit/cellular
	@$(SUDO) cp -rf ui/cellular/* /usr/share/cockpit/cellular/		
	@$(SUDO) cp -rf ui/branding/debian/* /usr/share/cockpit/branding/debian/
	@$(SUDO) cp -rf ui/static/* /usr/share/cockpit/static/	
	@$(SUDO) cp -rf ui/base1/* /usr/share/cockpit/base1/
	@$(SUDO) install -Dm755 version.txt $(LOCAL)/echopilot/.	

disable:
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(SERVICES) ; done ; true )
	@$(SUDO) nmcli con down cellular ; $(SUDO) nmcli con delete "cellular"

enable:
	@echo "Installing service files..."
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(SERVICES) ; done ; true )	
	@( for s in $(SERVICES) ; do $(SUDO) install -Dm644 $${s%.*}.service $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	@echo "Enabling services files..."
	@( for s in $(SERVICES) ; do $(SUDO) systemctl enable $${s%.*} ; done ; true )
	@echo ""
	@echo "Video Service is installed. To run now use sudo systemctl start video or reboot"
	@echo "Inspect output with sudo journalctl -fu video"

install: dependencies	

# install video prequisites
	$(SUDO) apt update
	@PLATFORM=$(PLATFORM) ./ensure-gst.sh $(DRY_RUN)
	@PLATFORM=$(PLATFORM) ./ensure-gstd.sh $(DRY_RUN)	

# build and install n2n
	@echo "Starting interactive session to set up N2N..."
	@$(MAKE) --no-print-directory n2n

# install cockpit
	@$(MAKE) --no-print-directory cockpit

# set up folders used by mavnetProxy
	@echo "Setting up mavnetProxy folders..."
	@[ -d /mnt/data/mission ] || $(SUDO) mkdir -p /mnt/data/mission
	@[ -d /mnt/container ] || $(SUDO) mkdir -p /mnt/container
	@[ -d /mnt/data/tmp_images ] || $(SUDO) mkdir -p /mnt/data/tmp_images
	@[ -d /mnt/container/image ] || $(SUDO) mkdir -p /container/image
	@[ -d /mnt/data/mission/processed_images ] || $(SUDO) mkdir -p /mnt/data/mission/processed_images
	@[ -d $(LOCAL)/echopilot ] || $(SUDO) mkdir -p $(LOCAL)/echopilot

# install any UDEV RULES
	@echo "Installing UDEV rules..."
	@for s in $(RULES) ; do $(SUDO) install -Dm644 $${s%.*}.rules $(UDEVRULES)/$${s%.*}.rules ; done
	@if [ ! -z "$(RULES)" ] ; then $(SUDO) udevadm control --reload-rules && udevadm trigger ; fi

# install LOCAL_SCRIPTS
	@echo "Installing local scripts..."
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done

# stop and disable services
	@echo "Disabling running services..."
	-@for c in stop disable ; do $(SUDO) systemctl $${c} $(SERVICES) ; done ; true

# install mavnetProxy files
	@echo "Installing mavnetProxy files..."
	@[ -d $(LOCAL)/echopilot/mavnetProxy ] || $(SUDO) mkdir $(LOCAL)/echopilot/mavnetProxy
	@$(SUDO) cp -a bin/. $(LOCAL)/echopilot/mavnetProxy/  
# The baseline configuration files are including in this folder including video.conf
# not using mavnetProxy for this install, so don't chmod it
# @$(SUDO) chmod +x $(LOCAL)/echopilot/mavnetProxy/mavnetProxy

# install services and enable them
	@$(MAKE) --no-print-directory enable

# install cellular
	@echo "Setting up cellular connection..."
	@$(MAKE) --no-print-directory cellular

# provision the network
	@echo "Starting interactive session to set up the network..."
	@$(MAKE) --no-print-directory network

# provision n2n
	@$(SUDO) python3 n2nConfigure.py --interactive --start

# cleanup and final settings
	@echo "Final cleanup..."
	@$(SUDO) chown -R echopilot /usr/local/echopilot
	@$(SUDO) systemctl stop nvgetty &>/dev/null || true
	@$(SUDO) systemctl disable nvgetty &>/dev/null || true
	@$(SUDO) usermod -aG dialout echopilot
	@$(SUDO) usermod -aG tty echopilot
	@echo "Please access the web UI to change settings..."
	@echo "Please reboot now to complete the installation..."

see:
#	$(SUDO) cat $(SYSCFG)/mavnetProxy.conf
#   mavnet conf not applicable yet
#	$(SUDO) cat $(SYSCFG)/mavnet.conf
	$(SUDO) cat $(SYSCFG)/video.conf
	$(SUDO) cat $(SYSCFG)/edge.conf
	@echo -n "Cellular APN is: "
	@$(SUDO) nmcli con show cellular | grep gsm.apn | cut -d ":" -f2 | xargs


uninstall:
	@$(MAKE) --no-print-directory disable
	@( for s in $(SERVICES) ; do $(SUDO) rm $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	$(SUDO) rm -f $(SYSCFG)


