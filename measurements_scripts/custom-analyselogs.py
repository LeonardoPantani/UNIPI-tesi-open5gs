#!/usr/bin/env python3
import os
import re
import sys
import statistics
import argparse
from glob import glob

def analyse_logs(log_dir):
    re_encaps = re.compile(r"\[TLS-KEM\]\s+Encaps time \(server\):\s+([\d.]+)\s+ms")
    re_decaps = re.compile(r"\[TLS-KEM\]\s+Decaps time \(client\):\s+([\d.]+)\s+ms")
    re_handshake = re.compile(r"\[TLS\]\s+Handshake time \(server side\):\s+([\d.]+)\s+ms")

    encaps_values = []
    decaps_values = []
    handshake_values = []

    log_files = sorted(glob(os.path.join(log_dir, "*.log")))
    
    if not log_files:
        print(f"[!] No .log files found in {log_dir}")
        return

    print(f"> Analysing {len(log_files)} files in '{log_dir}'...")

    for path in log_files:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if "[TLS" not in line: 
                        continue
                        
                    if m := re_encaps.search(line):
                        encaps_values.append(float(m.group(1)))
                    elif m := re_decaps.search(line):
                        decaps_values.append(float(m.group(1)))
                    elif m := re_handshake.search(line):
                        handshake_values.append(float(m.group(1)))
        except Exception as e:
            print(f"[!] Error while reading {path}: {e}")

    def print_stat(name, values):
        if values:
            avg = statistics.mean(values)
            med = statistics.median(values)
            n = len(values)
            print(f"> {name:<20} | Avg: {avg:6.3f} ms | Med: {med:6.3f} ms | n={n}")
            return med
        else:
            print(f"> {name:<20} | No data")
            return 0.0

    print("-" * 60)
    med_enc = print_stat("Encaps (server)", encaps_values)
    med_dec = print_stat("Decaps (client)", decaps_values)
    med_hs  = print_stat("Handshake (server)", handshake_values)
    print("-" * 60)
    print(f"CSV_DATA: {med_enc:.3f},{med_dec:.3f},{med_hs:.3f}")

def main():
    parser = argparse.ArgumentParser(
        description="Analyses .log files produced by Open5GS NFs to extract encaps/decaps/handshake timings."
    )
    parser.add_argument(
        "log_dir",
        nargs="?",
        default="install/var/log/open5gs",
        help="Directory containing logs"
    )
    args = parser.parse_args()

    if not os.path.exists(args.log_dir):
        print(f"[!] Directory not found: {args.log_dir}")
        sys.exit(1)

    analyse_logs(args.log_dir)

if __name__ == "__main__":
    main()