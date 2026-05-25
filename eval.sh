#!/bin/bash

# 檢查是否有輸入參數 (預期平均值)
if [ -z "$1" ]; then
    echo "⚠️ 請輸入預期的平均 Running 數量！"
    echo "用法範例: sh $0 100"
    exit 1
fi

expected_avg="$1"
loops=6

echo "🎯 目標平均 Running 數量: $expected_avg"
echo "⏳ 準備就緒，先等待 15 秒..."
sleep 15

echo "▶️ 開始監控 vLLM metrics (共 1 分鐘，每 10 秒抓取一次)..."
echo "--------------------------------------------------------"

# 建立暫存檔
tmp_file=$(mktemp)

# 使用通用寫法確保 bash / sh 都能正確執行
for i in 1 2 3 4 5 6; do
    # 抓取當下 metrics
    metrics=$(curl -s http://localhost:8000/metrics)
    
    # 1. 顯示當下所有詳細狀態
    echo "$metrics" | awk -v step="$i" '
        /^vllm:num_requests_running/ {r=$2} 
        /^vllm:num_requests_waiting{/ {w=$2} 
        /^vllm:kv_cache_usage_perc/ {kv=$2*100} 
        /^vllm:prefix_cache_queries_total/ {q=$2} 
        /^vllm:prefix_cache_hits_total/ {h=$2} 
        END {
            printf "[%d/6] Running: %.0f | Waiting: %.0f | KV Cache: %.2f%% | Prefix Cache Hit Rate: %.2f%%\n", step, r, w, kv, (q>0?(h/q)*100:0)
        }'
    
    # 2. 單獨將 running request 寫入暫存檔
    echo "$metrics" | awk '/^vllm:num_requests_running/ {print $2+0}' >> "$tmp_file"
    
    # 等待 10 秒 (最後一次不等待)
    if [ "$i" -lt "$loops" ]; then
        sleep 10
    fi
done

echo "--------------------------------------------------------"

# 3. 計算實際平均值
avg_running=$(awk '{sum+=$1} END {if (NR>0) printf "%.2f", sum/NR}' "$tmp_file")

# 清理暫存檔
rm -f "$tmp_file"

echo "👉 1 分鐘內的實際平均 Running requests: $avg_running"

# 4. 判斷是否達標 (利用 awk 進行浮點數比大小)
# 如果 avg_running >= expected_avg，awk 印出 1 (代表 true)，否則印出 0 (代表 false)
is_reached=$(awk -v actual="$avg_running" -v expected="$expected_avg" 'BEGIN { if (actual >= expected) print 1; else print 0 }')

echo "--------------------------------------------------------"
if [ "$is_reached" -eq 1 ]; then
    echo "✅ 成功：實際平均 ($avg_running) 已達標 (>= $expected_avg)！"
    exit 0
else
    echo "❌ 失敗：實際平均 ($avg_running) 未達標 (< $expected_avg)。"
    exit 1
fi