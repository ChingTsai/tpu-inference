#!/bin/bash

# Create a timestamp (Format: YYYYMMDD_HHMMSS)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Define log file and a PID file to track the process
LOG_FILE="vllm_output_${TIMESTAMP}.log"
PID_FILE="vllm_server.pid"

echo "🚀 Starting vLLM server in the background..."
echo "📝 All output will be saved to: ${LOG_FILE}"

# 1. Environment Variables
export NEW_MODEL_DESIGN=True
export USE_BATCHED_RPA_KERNEL=1
export VLLM_SERVER_DEV_MODE=1
export MODEL_IMPL_TYPE="vllm"
export PYTHONUNBUFFERED=1 

# 2. Server Launch Command (Backgrounded)
# Added 'nohup' at the start and '> file 2>&1 &' at the end
nohup python -m vllm.entrypoints.cli.main serve Qwen/Qwen3-32B \
    --max-model-len=5120 \
    --max-num-batched-tokens=4096 \
    --max-num-seqs=32 \
    --enable-prefix-caching \
    --gpu-memory-utilization=0.7 \
    --tensor-parallel-size=8 \
    --async-scheduling \
    --additional-config '{"sharding": {"sharding_strategy": {"dp_attn_parallelism": 4, "enable_dp_attention": true}}}' \
    > "${LOG_FILE}" 2>&1 &