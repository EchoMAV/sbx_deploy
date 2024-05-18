# Echomav Deployment for the EchoLite
## Using Herelink Radio and MIPI IMX477 camera

Note that in this configuration, mavnetProxy is not used to handle telemetry, rather telemetry is handled natively by the Herelink radios. So the mavnetProxy service is not enabled.

## Dependencies

Requires git-lfs
```sudo apt-get install git-lfs -y```

Other dependencies will be installed automatically by during a `make install` assuming you have an internet connection  

## Installation

To perform an initial install, establish an internet connection and clone the repository.
You will issue the following commands:
```
sudo apt-get install git-lfs -y
cd $HOME
git clone https://github.com/echomav/echolite_deploy.git
make -C $HOME/echolite_deploy install
```

To configure your system, edit the following files in `/usr/local/echopilot/mavnetProxy/`  
- mavnet.conf - mavnet key, serial number    
- video.conf - video server information  
- appsettings.json - app related configuration, sensors onboard, gimbal ip address, gcs_passthru variable, default param values, etc.  

## Supported Platforms
These platforms are supported/tested:


 * Raspberry PI
   - [x] [Raspbian Bookworm 64 bit)](https://www.raspberrypi.org/downloads/raspbian/)
 * Jetson Nano
   - [ ] [Jetpack 5.x]

