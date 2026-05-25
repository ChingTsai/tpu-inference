# Autoresearch: Debugging DP Scheduler Prefix Cache Imbalance

## Goal
Debug the scheduling bug in `tpu_inference/core/sched/dp_scheduler.py` inside the `_find_best_rank_for_request` function.
Currently, if there is a prefix cache hit, requests might not be assigned evenly among DP groups, resulting in load imbalance.

## Verification Plan

To verify the issue and your fixes, follow these steps:

1.  **Start the Server**:
    Run the server using the provided script:
    ```bash
    sh run.sh
    ```
    *Note: This will start the server and stream logs to a file named `vllm_output_YYYYMMDD_HHMMSS.log`.*

2.  **Run Warmup**:
    Run the benchmark command once for warmup:
    ```bash
    vllm bench serve --model Qwen/Qwen3-32B   --dataset-name prefix_repetition   --num-prompts 512   --prefix-repetition-num-prefixes 128   --prefix-repetition-prefix-len 2048   --prefix-repetition-suffix-len 0   --prefix-repetition-output-len 1024   --max-concurrency 128 --seed 41
    ```

3.  **Run Benchmark**:
    Run the benchmark command again for the actual measurement:
    ```bash
    vllm bench serve --model Qwen/Qwen3-32B   --dataset-name prefix_repetition   --num-prompts 512   --prefix-repetition-num-prefixes 128   --prefix-repetition-prefix-len 2048   --prefix-repetition-suffix-len 0   --prefix-repetition-output-len 1024   --max-concurrency 128 --seed 41
    ```

4.  **Check Concurrency**:
    After the actual benchmark starts, run the following command to check the running request number:
    ```bash
    sh eval.sh 120
    ```
    This command will check if the concurrency exceeds 120.

5.  **Teardown**:
    Teardown the server after the benchmark by running `sh teardown.sh`. Restart it if you have code changes.

## Target Function
The target function is `_find_best_rank_for_request` in `tpu_inference/core/sched/dp_scheduler.py`.
The current logic favors the rank with the most cache hits, which can lead to imbalance.

```python
    def _find_best_rank_for_request(self, request: Request) -> int:
        # ...
        if best_cache_tokens > 0:
            return best_cache_rank
        # ...
```

## The Experiment Loop

The experiment runs on a dedicated branch (e.g. `autoresearch/debug-dp-sched-may25`).

LOOP FOREVER:

1.  **Look at the git state**: Check the current branch/commit you are on.
2.  **Tune the code**: Modify `tpu_inference/core/sched/dp_scheduler.py` (specifically `_find_best_rank_for_request`) with an experimental idea to improve load balancing.
3.  **Git commit**: Commit your changes to track them.
4.  **Run the verification plan**:
    - Start the server: `sh run.sh`
    - Run warmup: (vllm bench command)
    - Run benchmark: (vllm bench command)
    - Check concurrency: `sh eval.sh 120` (run this during the benchmark)
    - Teardown the server: `sh teardown.sh`
5.  **Evaluate results**: Check the output of `sh eval.sh 120`.
    - If it succeeds (exit code 0), it means the average running requests reached the target, indicating better balance and utilization.
    - If it fails (exit code 1), the change did not achieve the target.
6.  **Record results**: Log the result (success/failure, description of change).
7.  **Iterate**:
    - If the experiment succeeded, keep the change and continue iterating on top of it.
    - If the experiment failed, revert the change (`git reset --hard`) and try a new idea.

**Simplicity criterion**: All else being equal, simpler fixes are better. Avoid overly complex logic if a simple heuristic works.

The idea is that you are a completely autonomous researcher trying things out. If they work, keep. If they don't, discard. And you're advancing the branch so that you can iterate. If you feel like you're getting stuck in some way, you can rewind but you should probably do this very very sparingly (if ever).

**Timeout**: Each experiment should take ~5 minutes total (+ a few seconds for startup and eval overhead). If a run exceeds 10 minutes, kill it and treat it as a failure (discard and revert).

**Crashes**: If a run crashes (OOM, or a bug, or etc.), use your judgment: If it's something dumb and easy to fix (e.g. a typo, a missing import), fix it and re-run. If the idea itself is fundamentally broken, just skip it, log "crash" as the status in the tsv, and move on.

**NEVER STOP**: Once the experiment loop has begun (after the initial setup), do NOT pause to ask the human if you should continue. Do NOT ask "should I keep going?" or "is this a good stopping point?". The human might be asleep, or gone from a computer and expects you to continue working *indefinitely* until you are manually stopped. You are autonomous. If you run out of ideas, think harder — read papers referenced in the code, re-read the in-scope files for new angles, try combining previous near-misses, try more radical architectural changes. The loop runs until the human interrupts you, period.

As an example use case, a user might leave you running while they sleep. If each experiment takes you ~5 minutes then you can run approx 12/hour, for a total of about 100 over the duration of the average human sleep. The user then wakes up to experimental results, all completed by you while they slept!