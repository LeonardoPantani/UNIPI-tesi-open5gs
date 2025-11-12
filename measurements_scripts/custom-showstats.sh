#!/usr/bin/env bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <csv_file(s)> [seconds]"
    exit 1
fi

CORES=$(nproc)

if [[ "$2" =~ ^[0-9]+$ ]]; then
    SECONDS_LIMIT=$2
else
    SECONDS_LIMIT=0
fi

for FILE in "$@"; do
    if [[ "$FILE" =~ ^[0-9]+$ ]]; then
        continue
    fi

    if [ ! -f "$FILE" ]; then
        echo "Skipping $FILE (not a file)"
        continue
    fi

    NAME=$(basename "$FILE")
    NAME=${NAME#open5gs_usage_}

    awk -v cores=$CORES -v name="$NAME" -v limit="$SECONDS_LIMIT" -F, '
    NR==2 {
        prev_ts=$1; prev_cpu=$2;
        min_cpu=1000; max_cpu=0; sum_cpu=0; count=0;
        min_mem=$3; max_mem=$3; sum_mem=0;
        next
    }
    NR>2 {
        if (limit > 0 && count >= limit) exit;

        dcpu=($2-prev_cpu)/1000000;
        dt=($1-prev_ts)/1000;
        cpu_pct=(dcpu/dt)*100/cores;

        if (cpu_pct < min_cpu) min_cpu=cpu_pct;
        if (cpu_pct > max_cpu) max_cpu=cpu_pct;
        sum_cpu+=cpu_pct;

        if ($3 < min_mem) min_mem=$3;
        if ($3 > max_mem) max_mem=$3;
        sum_mem+=$3;

        prev_ts=$1; prev_cpu=$2;
        count++;
    }
    END {
        if (count > 0) {
            print "==== Report for " name " ===="
            printf "CPU usage (%%): avg = %.2f, min = %.2f, max = %.2f\n", sum_cpu/count, min_cpu, max_cpu
            printf "Memory usage (MB): avg = %.2f, min = %.2f, max = %.2f\n", (sum_mem/count)/1024/1024, min_mem/1024/1024, max_mem/1024/1024
            if (limit > 0)
                print "Seconds considered: " limit
            else
                print "Seconds considered: all"
        } else {
            print "No samples found in " name
        }
    }' "$FILE"

done