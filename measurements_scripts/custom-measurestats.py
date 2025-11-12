#!/usr/bin/env python3
import glob
import os
import sys
import re
import pandas as pd
import matplotlib.pyplot as plt

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <file(s)>")
    sys.exit(1)

input_args = sys.argv[1:]
files = []
for arg in input_args:
    expanded = glob.glob(arg)
    if expanded:
        files.extend(expanded)
    elif os.path.isfile(arg):
        files.append(arg)

files = sorted(set(files))
if not files:
    print("No file found.")
    sys.exit(0)

cpu_data = {}
mem_data = {}

summary_rows = []

for f in files:
    try:
        df = pd.read_csv(f)
    except Exception as e:
        print(f"Error reading {f}: {e}")
        continue

    if not {'timestamp_ms', 'cpu_usage_usec', 'mem_bytes'}.issubset(df.columns):
        print(f"{f}: columns not found, skipping.")
        continue

    base = os.path.basename(f)

    # Regex per catturare sr/nosr, KEX e SIG
    m = re.search(r'servermetrics_(sr|nosr)_usage_([^_]+)_([^_]+).csv', base)
    if m:
        mode = m.group(1)
        kex_alg = m.group(2)
        sig_alg = m.group(3)
        label = f"{mode.upper()} | {kex_alg} | {sig_alg}"
    else:
        mode = kex_alg = sig_alg = "unknown"
        label = base

    df['time_s'] = (df['timestamp_ms'] - df['timestamp_ms'].iloc[0]) / 1000.0
    cpu_data[label] = df['cpu_percent']
    mem_data[label] = df['mem_bytes'] / (1024*1024)  # MB

    # Calcolo statistiche
    cpu_median = df['cpu_percent'].median()
    cpu_mean = df['cpu_percent'].mean()
    mem_median = df['mem_bytes'].median() / (1024*1024)
    mem_mean = df['mem_bytes'].mean() / (1024*1024)

    summary_rows.append({
        'File name': base,
        'Mode': mode,
        'Key Ex. Alg.': kex_alg,
        'Signat. Alg.': sig_alg,
        'CPU_mean_%': cpu_mean,
        'CPU_median_%': cpu_median,
        'Mem_mean_MB': mem_mean,
        'Mem_median_MB': mem_median
    })

# ===== Summary Table =====
summary_df = pd.DataFrame(summary_rows)
print(summary_df.to_string(index=False, float_format="%.2f"))

# ===== CPU boxplot =====
cpu_df = pd.DataFrame(dict([(k, pd.Series(v)) for k, v in cpu_data.items()]))
plt.figure(figsize=(10,6))
cpu_df.boxplot()
plt.title("CPU Utilization per Configuration (Open5GS)")
plt.ylabel("CPU usage [%]")
plt.grid(True, linestyle="--", alpha=0.6)
plt.tight_layout()
plt.show()

# ===== Memory usage over time =====
plt.figure(figsize=(10,6))
for f in files:
    df = pd.read_csv(f)
    if not {'timestamp_ms', 'mem_bytes'}.issubset(df.columns):
        continue
    base = os.path.basename(f)
    m = re.search(r'servermetrics_(sr|nosr)_usage_([^_]+)_([^_]+)', base)
    if m:
        mode = m.group(1)
        kex_alg = m.group(2)
        sig_alg = m.group(3)
        label = f"{mode.upper()} | {kex_alg} | {sig_alg}"
    else:
        label = base
    df['time_s'] = (df['timestamp_ms'] - df['timestamp_ms'].iloc[0]) / 1000.0
    plt.plot(df['time_s'], df['mem_bytes'] / (1024*1024), linewidth=1.3, label=label)

plt.title("Memory usage over time (Open5GS)")
plt.xlabel("Time [s]")
plt.ylabel("Memory [MB]")
plt.grid(True, linestyle="--", alpha=0.6)
plt.legend(title="Mode | KEX | SIG", fontsize=9)
plt.tight_layout()
plt.show()
