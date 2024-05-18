#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "No arguments supplied, usage ./snap.sh path/to/filename.jpg"
    exit
fi
# This script sets the snapshot filename, then executes the pipeline waiting until eos is reached, then stops the pipeline
gst-client element_set snapshot filename location $1
gstd-client bus_filter snapshot eos
gstd-client bus_timeout snapshot 1000000000
gstd-client pipeline_play snapshot
# wait eos
gstd-client bus_read snapshot
gstd-client pipeline_stop snapshot
