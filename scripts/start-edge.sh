#!/bin/bash
SUDO=$(test ${EUID} -ne 0 && which sudo)

/usr/sbin/edge /usr/local/echopilot/edge.conf


