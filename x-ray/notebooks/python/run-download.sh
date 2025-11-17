#!/bin/bash
# NIH Chest X-ray dataset download script with nohup

cd "$(dirname "$0")"
nohup python3 get-all-data.py > download.log 2>&1 &

echo "Download started in background (PID: $!)"
echo "Monitor progress with: tail -f download.log"
echo "Check if still running: ps aux | grep get-all-data.py"
