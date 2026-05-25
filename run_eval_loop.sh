#!/bin/bash
set -e

# Cleanup first
pkill -f "python -m vllm.entrypoints.cli.main" || true
sh teardown.sh > /dev/null 2>&1 || true

echo "Starting server..." >&2
sh run.sh >&2

echo "Waiting for server to start..." >&2
timeout=600
start_time=$(date +%s)
while ! curl -f -s http://localhost:8000/health > /dev/null; do
    sleep 5
    curr_time=$(date +%s)
    if [ $((curr_time - start_time)) -gt $timeout ]; then
        echo "Server failed to start within timeout." >&2
        sh teardown.sh >&2
        exit 2
    fi
done

echo "Server is up. Running warmup..." >&2
vllm bench serve --model Qwen/Qwen3-32B --dataset-name prefix_repetition --num-prompts 512 --prefix-repetition-num-prefixes 128 --prefix-repetition-prefix-len 2048 --prefix-repetition-suffix-len 0 --prefix-repetition-output-len 1024 --max-concurrency 128 --seed 41 > /dev/null 2>&1

echo "Running benchmark..." >&2
vllm bench serve --model Qwen/Qwen3-32B --dataset-name prefix_repetition --num-prompts 512 --prefix-repetition-num-prefixes 128 --prefix-repetition-prefix-len 2048 --prefix-repetition-suffix-len 0 --prefix-repetition-output-len 1024 --max-concurrency 128 --seed 41 > benchmark_output.log 2>&1 &
BENCH_PID=$!

echo "Running eval..." >&2
# Run eval and capture its output
sh eval.sh 120 > eval_output.txt 2>&1
EVAL_EXIT_CODE=$?
EVAL_OUT=$(cat eval_output.txt)
echo "$EVAL_OUT" >&2

sh teardown.sh >&2
wait $BENCH_PID 2>/dev/null || true

# Extract metric
METRIC=$(echo "$EVAL_OUT" | grep "👉 1 分鐘內的實際平均 Running requests:" | awk '{print $NF}')
if [ -z "$METRIC" ]; then
    METRIC="0"
fi
echo "$METRIC"

exit $EVAL_EXIT_CODE
