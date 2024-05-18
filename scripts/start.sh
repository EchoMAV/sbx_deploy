#!/bin/bash
# 
#
# This starts mavnetProxy

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local

echo "Starting MavnetProxy"

cd ${LOCAL}/echopilot/mavnetProxy/ && ./mavnetProxy start
