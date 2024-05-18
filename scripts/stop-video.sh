#!/bin/bash
# script to stop the SBX video service

gst-client pipeline_stop h264src
gst-client pipeline_stop los
#gst-client pipeline_stop server
#gst-client pipeline_stop snapshot

gst-client pipeline_delete h264src
gst-client pipeline_delete los
#gst-client pipeline_delete server
#gst-client pipeline_delete snapshot

set +e
gstd -f /var/run -l /dev/null -d /dev/null -k
set -e
