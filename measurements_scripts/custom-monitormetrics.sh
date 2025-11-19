#!/usr/bin/env bash
export LC_NUMERIC=C

if [ $# -ne 3 ]; then
    echo "Usage: $0 <nosr|sr> <ALG_TYPE> <SIG_TYPE>"
    exit 1
fi

MODE=$1
ALG_TYPE=$2
SIG_TYPE=$3
FILE_OUT="test_results/server_metrics/servermetrics_${MODE}_usage_${ALG_TYPE}_${SIG_TYPE}.csv"

CGROUP_DIR="/sys/fs/cgroup/open5gs"

if [ -d "$CGROUP_DIR" ]; then
    sudo rmdir "$CGROUP_DIR" 2>/dev/null
fi
sudo mkdir -p "$CGROUP_DIR"

pids=$(pgrep -f "open5gs-")
if [ -z "$pids" ]; then
    echo "[!] No Open5GS process found."
    exit 1
fi

for pid in $pids; do
    echo "$pid" | sudo tee "$CGROUP_DIR/cgroup.procs" > /dev/null
done

echo "Monitoring metrics for mode=$MODE, alg=$ALG_TYPE, sig=$SIG_TYPE"
echo "timestamp_ms,cpu_usage_usec,cpu_percent,mem_bytes" > "$FILE_OUT"

cpu_prev=$(awk '/usage_usec/{print $2}' "$CGROUP_DIR/cpu.stat")
t_prev_ns=$(date +%s%N)
nproc=$(nproc)

for _ in $(seq 1800); do # 1800 secs = half an hour
    sleep 1
    ts=$(date +%s%3N)
    cpu_now=$(awk '/usage_usec/{print $2}' "$CGROUP_DIR/cpu.stat")
    mem=$(cat "$CGROUP_DIR/memory.current")

    delta_cpu=$((cpu_now - cpu_prev))
    cpu_prev=$cpu_now
    
    # calculating cpu percent
    t_now_ns=$(date +%s%N)
    elapsed_s=$(awk -v a="$t_prev_ns" -v b="$t_now_ns" 'BEGIN { printf "%.6f", (b - a)/1e9 }')
    t_prev_ns=$t_now_ns

    cpu_percent=$(awk -v d="$delta_cpu" -v e="$elapsed_s" -v n="$nproc" \
    'BEGIN { printf "%.2f", ((d / 1e6) / e / n) * 100 }')

    echo "$ts,$cpu_now,$cpu_percent,$mem" >> "$FILE_OUT"
    echo -ne "\r[$(date +%T)] CPU=${cpu_now} usec (${cpu_percent}%)  MEM=${mem} bytes   "
done


echo -e "\n> Measurement completed and saved to $FILE_OUT"
