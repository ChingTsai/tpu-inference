#!/bin/bash

echo "🛑 Scanning for processes holding TPU devices..."

# Loop continuously until no TPU PIDs are found
while true; do
    # 1. Grab PIDs, remove spaces, and filter out empty lines AND the word "None"
    TPU_PIDS=$(tpu-info | awk -F'│' '/\/dev\/vfio/ {print $5}' | tr -d ' ' | sort -u | grep -E -v '^$|^None$')

    # 2. If the string is empty (meaning no valid numbers were found), we are done!
    if [ -z "$TPU_PIDS" ]; then
        echo "✅ All TPUs are completely free and released."
        break
    fi

    # 3. If we found actual numeric PIDs, iterate through them and kill them
    echo "⚠️ Found active TPU process(es): ${TPU_PIDS}"
    for PID in $TPU_PIDS; do
        echo "   -> Terminating PID: $PID..."
        kill -9 "$PID" 2>/dev/null
    done

    # Wait 2 seconds to give the OS time to cleanly release the hardware locks
    sleep 2
done