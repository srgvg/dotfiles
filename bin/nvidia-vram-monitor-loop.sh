#!/usr/bin/env bash
while true; do
    /home/serge/bin/nvidia-vram-monitor.sh
    echo "$(date): nvidia-vram-monitor exited (status=$?), restarting in 5s"
    sleep 5
done
