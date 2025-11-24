#!/usr/bin/env python3
import csv
import statistics
import argparse
import sys
import os
from pathlib import Path

REQUIRED_COLS = {'timestamp_ms', 'cpu_usage_usec', 'cpu_percent', 'mem_bytes'}

def analyse_file(file_path: Path):
    try:
        with file_path.open('r', encoding='utf-8') as f:
            reader = csv.DictReader(f)

            if not reader.fieldnames or not REQUIRED_COLS.issubset(reader.fieldnames):
                print(f"[!] Skipping {file_path.name}: missing columns {REQUIRED_COLS}")
                return

            data = list(reader)
            if not data:
                print(f"[!] {file_path.name}: empty or no data file.")
                return

            try:
                start_time = float(data[0]['timestamp_ms'])
                times = [(float(r['timestamp_ms']) - start_time) / 1000.0 for r in data]
                cpus = [float(r['cpu_percent']) for r in data]
                mems = [int(r['mem_bytes']) / 1048576 for r in data]
                cpu_usage = [int(r['cpu_usage_usec']) for r in data]
            except ValueError:
                print(f"[!] {file_path.name}: Data conversion error.")
                return

            cpu_avg = statistics.mean(cpus)
            cpu_med = statistics.median(cpus)
            cpu_min = min(cpus)
            cpu_max = max(cpus)
            cpu_std = statistics.pstdev(cpus)

            active = [x for x in cpus if x > 0]

            if active:
                cpu_avg_active = statistics.mean(active)
                cpu_med_active = statistics.median(active)
                cpu_min_active = min(active)
                cpu_max_active = max(active)
                cpu_std_active = statistics.pstdev(active)

                s_active = sorted(active)
                cpu_p95 = s_active[int(0.95 * (len(s_active) - 1))]
                cpu_p99 = s_active[int(0.99 * (len(s_active) - 1))]
            else:
                cpu_avg_active = cpu_med_active = cpu_min_active = cpu_max_active = cpu_std_active = 0.0
                cpu_p95 = cpu_p99 = 0.0

            try:
                t0 = float(data[0]['timestamp_ms'])
                t1 = float(data[-1]['timestamp_ms'])
                cpu0 = cpu_usage[0]
                cpu1 = cpu_usage[-1]
                wall_sec = (t1 - t0) / 1000
                cpu_sec = (cpu1 - cpu0) / 1_000_000
                nproc = os.cpu_count() or 1
                cpu_avg_real = (cpu_sec / wall_sec) * 100 / nproc
            except Exception:
                cpu_avg_real = 0.0

            mem_avg = statistics.mean(mems)
            mem_med = statistics.median(mems)
            mem_min = min(mems)
            mem_max = max(mems)

            print(f"\n=== {file_path.name} ===")
            print(f"CPU (all samples):  Avg {cpu_avg:6.3f} | Med {cpu_med:6.3f} | Min {cpu_min:6.3f} | Max {cpu_max:6.3f} | Std {cpu_std:6.3f}")
            print(f"CPU (active >0%) :  Avg {cpu_avg_active:6.3f} | Med {cpu_med_active:6.3f} | Min {cpu_min_active:6.3f} | Max {cpu_max_active:6.3f} | Std {cpu_std_active:6.3f} | p95 {cpu_p95:6.3f} | p99 {cpu_p99:6.3f}")
            print(f"CPU (real avg %) : {cpu_avg_real:6.3f}")
            print(f"MEM (MB)         :  Avg {mem_avg:6.3f} | Med {mem_med:6.3f} | Min {mem_min:6.3f} | Max {mem_max:6.3f}")
            print(f"\n{cpu_avg_real:.3f},{mem_med:6.3f}")

    except Exception as e:
        print(f"[!] {file_path.name}: Unknown error: {e}")

def main():
    parser = argparse.ArgumentParser(description="Analyse CSV files to extract CPU and memory metrics.")
    parser.add_argument('files', metavar='FILE', type=Path, nargs='+', help='Paths of CSV files to analyze')
    args = parser.parse_args()

    for file_path in args.files:
        if not file_path.exists():
            print(f"[!] File not found: {file_path}")
            continue
        analyse_file(file_path)

if __name__ == "__main__":
    main()
