#!/usr/bin/env python3
import csv
import statistics
import argparse
import sys
import os
from pathlib import Path

try:
    import matplotlib.pyplot as plt
except ImportError:
    print("[!] Cannot continue, matplotlib not found. Install with: pip install matplotlib")
    sys.exit(1)

REQUIRED_COLS = {'timestamp_ms', 'cpu_usage_usec', 'cpu_percent', 'mem_bytes'}

def analyse_file(file_path: Path, output_dir: Path):
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

            # ---- LOAD VALUES ----
            try:
                start_time = float(data[0]['timestamp_ms'])
                times = [(float(r['timestamp_ms']) - start_time) / 1000.0 for r in data]
                cpus = [float(r['cpu_percent']) for r in data]
                mems = [int(r['mem_bytes']) / 1048576 for r in data]  # MB
                cpu_usage = [int(r['cpu_usage_usec']) for r in data]
            except ValueError:
                print(f"[!] {file_path.name}: Data conversion error.")
                return

            # ====== BASE CPU METRICS (all samples) ======
            cpu_avg  = statistics.mean(cpus)
            cpu_med  = statistics.median(cpus)
            cpu_min  = min(cpus)
            cpu_max  = max(cpus)
            cpu_std  = statistics.pstdev(cpus)

            # ====== ACTIVE CPU (cpu_percent > 0) ======
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


            # ====== CPU REAL AVG (cumulative counters) ======
            try:
                t0 = float(data[0]['timestamp_ms'])
                t1 = float(data[-1]['timestamp_ms'])
                cpu0 = cpu_usage[0]
                cpu1 = cpu_usage[-1]
                wall_sec = (t1 - t0) / 1000
                cpu_sec  = (cpu1 - cpu0) / 1_000_000
                nproc = os.cpu_count() or 1
                cpu_avg_real = (cpu_sec / wall_sec) * 100 / nproc
            except Exception:
                cpu_avg_real = 0.0

            # ====== RAM ======
            mem_avg = statistics.mean(mems)
            mem_med = statistics.median(mems)
            mem_min = min(mems)
            mem_max = max(mems)

            # --- REPORT ---
            print(f"\n=== {file_path.name} ===")
            print(f"CPU (all samples):  Avg {cpu_avg:6.3f} | Med {cpu_med:6.3f} | Min {cpu_min:6.3f} | Max {cpu_max:6.3f} | Std {cpu_std:6.3f}")
            print(f"CPU (active >0%) :  Avg {cpu_avg_active:6.3f} | Med {cpu_med_active:6.3f} | Min {cpu_min_active:6.3f} | Max {cpu_max_active:6.3f} | Std {cpu_std_active:6.3f} | p95 {cpu_p95:6.3f} | p99 {cpu_p99:6.3f}")
            print(f"CPU (real avg)   :  {cpu_avg_real:6.3f} %   (from cumulative counters)")
            print(f"MEM (MB)         :  Avg {mem_avg:6.3f} | Med {mem_med:6.3f} | Min {mem_min:6.3f} | Max {mem_max:6.3f}")


            # --- GRAPH SAVING ----
            base_name = file_path.stem
            cpu_out = output_dir / f"{base_name}_cpu.png"
            mem_out = output_dir / f"{base_name}_memory.png"

            # CPU BOXPLOT
            plt.figure(figsize=(6, 6))
            plt.boxplot(cpus, patch_artist=True,
                        boxprops=dict(facecolor='lightblue', color='blue'),
                        medianprops=dict(color='red'))
            plt.title(f"CPU distribution\n{file_path.name}")
            plt.ylabel("CPU usage [%]")
            plt.grid(True, linestyle="--", alpha=0.6)
            plt.xticks([1], ['CPU'])
            plt.tight_layout()
            plt.savefig(cpu_out)
            plt.close()

            # MEMORY LINE
            plt.figure(figsize=(10, 6))
            plt.plot(times, mems, linewidth=1.5, color='tab:orange')
            plt.title(f"Memory usage over time\n{file_path.name}")
            plt.xlabel("Time [s]")
            plt.ylabel("Memory [MB]")
            plt.grid(True, linestyle="--", alpha=0.6)
            plt.tight_layout()
            plt.savefig(mem_out)
            plt.close()

            print(f"> Graphs saved to {output_dir}")

    except Exception as e:
        print(f"[!] {file_path.name}: Unknown error: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Analyses CSV files to extract metrics and generate plots (CPU Boxplot, Mem Line).",
    )
    parser.add_argument('files', metavar='FILE', type=Path, nargs='+', help='Paths of CSV files to analyze')
    parser.add_argument('--out-dir', type=Path, default=Path("test_results/server_metrics/plots"), help="Output directory for plots")

    args = parser.parse_args()

    if not args.out_dir.exists():
        try:
            args.out_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"[!] Error creating output directory: {e}")
            sys.exit(1)

    for file_path in args.files:
        if not file_path.exists():
            print(f"[!] File not found: {file_path}")
            continue
        analyse_file(file_path, args.out_dir)

if __name__ == "__main__":
    main()