#!/usr/bin/env python3
import csv
import statistics
import argparse
import os
from pathlib import Path

REQUIRED_COLS = {"timestamp_ms", "cpu_usage_usec", "cpu_percent", "mem_bytes"}


def _compute_stats(values):
    s = sorted(values)
    return {
        "avg": statistics.mean(values),
        "med": statistics.median(values),
        "min": min(values),
        "max": max(values),
        "std": statistics.pstdev(values),
        "p95": s[int(0.95 * (len(s) - 1))],
        "p99": s[int(0.99 * (len(s) - 1))],
    }


def analyse_file(file_path: Path):
    try:
        with file_path.open("r", encoding="utf-8") as f:
            reader = csv.DictReader(f)

            if not reader.fieldnames or not REQUIRED_COLS.issubset(reader.fieldnames):
                print(f"[!] Skipping {file_path.name}: missing columns {REQUIRED_COLS}")
                return

            data = list(reader)
            if not data:
                print(f"[!] {file_path.name}: empty or no data file.")
                return

            try:
                cpus = [float(r["cpu_percent"]) for r in data]
                mems = [int(r["mem_bytes"]) / 1048576 for r in data]
                cpu_usage = [int(r["cpu_usage_usec"]) for r in data]

                cpu_active = [x for x in cpus if x > 0]
            except ValueError:
                print(f"[!] {file_path.name}: Data conversion error.")
                return

            # calculate cpu avg real
            try:
                t0 = float(data[0]["timestamp_ms"])
                t1 = float(data[-1]["timestamp_ms"])
                cpu0 = cpu_usage[0]
                cpu1 = cpu_usage[-1]
                wall_sec = (t1 - t0) / 1000
                cpu_sec = (cpu1 - cpu0) / 1_000_000
                nproc = os.cpu_count() or 1
                cpu_avg_real = (cpu_sec / wall_sec) * 100 / nproc
            except Exception:
                cpu_avg_real = 0.0

            cpu_active_stats = _compute_stats(cpu_active)
            cpu_stats = _compute_stats(cpus)
            mem_stats = _compute_stats(mems)

            print(f"\n=== {file_path.name} ===")
            print(f"CPU (real)       :  Avg {cpu_avg_real:7.3f}")
            print(
                f"CPU (active >0%) :  Avg {cpu_active_stats['avg']:7.3f} | "
                f"Med {cpu_active_stats['med']:7.3f} | Min {cpu_active_stats['min']:7.3f} | "
                f"Max {cpu_active_stats['max']:7.3f} | Std {cpu_active_stats['std']:7.3f} | "
                f"p95 {cpu_active_stats['p95']:7.3f} | p99 {cpu_active_stats['p99']:7.3f}"
            )
            print(
                f"CPU (all samples):  Avg {cpu_stats['avg']:7.3f} | "
                f"Med {cpu_stats['med']:7.3f} | Min {cpu_stats['min']:7.3f} | "
                f"Max {cpu_stats['max']:7.3f} | Std {cpu_stats['std']:7.3f} | "
                f"p95 {cpu_stats['p95']:7.3f} | p99 {cpu_stats['p99']:7.3f}"
            )
            print(
                f"MEM (MB)         :  Avg {mem_stats['avg']:7.3f} | "
                f"Med {mem_stats['med']:7.3f} | Min {mem_stats['min']:7.3f} | "
                f"Max {mem_stats['max']:7.3f} | Std {mem_stats['std']:7.3f} | "
                f"p95 {mem_stats['p95']:7.3f} | p99 {mem_stats['p99']:7.3f}"
            )

    except Exception as e:
        print(f"[!] {file_path.name}: Unknown error: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Analyse CSV files to extract CPU and memory metrics."
    )
    parser.add_argument(
        "files",
        metavar="FILE",
        type=Path,
        nargs="+",
        help="Paths of CSV files to analyze",
    )
    args = parser.parse_args()

    for file_path in args.files:
        if not file_path.exists():
            print(f"[!] File not found: {file_path}")
            continue
        analyse_file(file_path)


if __name__ == "__main__":
    main()
