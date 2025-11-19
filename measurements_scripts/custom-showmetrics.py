#!/usr/bin/env python3
import csv
import statistics
import argparse
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
except ImportError:
    print("[!] Cannot continue, matplotlib not found. Install with: pip install matplotlib")
    sys.exit(1)

REQUIRED_COLS = {'timestamp_ms', 'cpu_percent', 'mem_bytes'}

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

            try:
                start_time = float(data[0]['timestamp_ms'])
                times = [(float(r['timestamp_ms']) - start_time) / 1000.0 for r in data]
                cpus = [float(r['cpu_percent']) for r in data]
                mems = [int(r['mem_bytes']) / 1048576 for r in data] # MB
            except ValueError:
                print(f"[!] {file_path.name}: Data conversion error.")
                return

            # --- TEXT REPORT ---
            print(f"\n=== {file_path.name} ===") 
            print(f"CPU (%) : Avg {statistics.mean(cpus):5.2f} | Med {statistics.median(cpus):5.2f} | Min {min(cpus):5.2f} | Max {max(cpus):5.2f}")
            print(f"MEM (MB): Avg {statistics.mean(mems):5.2f} | Med {statistics.median(mems):5.2f} | Min {min(mems):5.2f} | Max {max(mems):5.2f}")

            # --- GRAPH SAVING
            base_name = file_path.stem
            cpu_out = output_dir / f"{base_name}_cpu.png"
            mem_out = output_dir / f"{base_name}_memory.png"

            # 1. CPU: BOXPLOT
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

            # 2. MEMORY: LINE PLOT
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