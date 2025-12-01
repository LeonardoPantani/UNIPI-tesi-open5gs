#!/usr/bin/env python3
import os
import re
import sys
import statistics
import argparse
from glob import glob


def _percentile(values, p):
    if not values:
        return 0.0
    k = (len(values) - 1) * (p / 100)
    f = int(k)
    c = min(f + 1, len(values) - 1)
    return values[f] + (values[c] - values[f]) * (k - f)


def _analyse_logs(log_dir):
    re_genkey = re.compile(r"^genkey,([\d.]+),ms")
    re_encap = re.compile(r"^encap,([\d.]+),ms")
    re_decap = re.compile(r"^decap,([\d.]+),ms")
    re_hshake = re.compile(r"^hshake,([\d.]+),ms")
    re_ch_snd_sh_rcv = re.compile(r"^ch_snd-sh_rcv,([\d.]+),ms")
    re_ch_rcv_sh_snd = re.compile(r"^ch_rcv-sh_snd,([\d.]+),ms")
    re_sign = re.compile(r"^sign,([\d.]+),ms")
    re_verify = re.compile(r"^verify,([\d.]+),ms")

    genkey_values = []
    encaps_values = []
    decaps_values = []
    handshake_values = []
    ch_snd_sh_rcv_values = []
    ch_rcv_sh_snd_values = []
    sign_values = []
    verify_values = []

    log_files = sorted(glob(os.path.join(log_dir, "*.log")))

    if not log_files:
        print(f"[!] No .log files found in {log_dir}")
        return

    print(f"> Analysing {len(log_files)} files in '{log_dir}'...")

    def add_if_nonzero(lst, match):
        v = float(match.group(1))
        if v != 0.0:
            lst.append(v)

    for path in log_files:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()

                    if m := re_genkey.match(line):
                        add_if_nonzero(genkey_values, m)
                        continue

                    if m := re_encap.match(line):
                        add_if_nonzero(encaps_values, m)
                        continue

                    if m := re_decap.match(line):
                        add_if_nonzero(decaps_values, m)
                        continue

                    if m := re_hshake.match(line):
                        add_if_nonzero(handshake_values, m)
                        continue

                    if m := re_ch_snd_sh_rcv.match(line):
                        add_if_nonzero(ch_snd_sh_rcv_values, m)
                        continue

                    if m := re_ch_rcv_sh_snd.match(line):
                        add_if_nonzero(ch_rcv_sh_snd_values, m)
                        continue

                    if m := re_sign.match(line):
                        add_if_nonzero(sign_values, m)
                        continue

                    if m := re_verify.match(line):
                        add_if_nonzero(verify_values, m)
                        continue
        except Exception as e:
            print(f"[!] Error while reading {path}: {e}")

    def print_stat(name, values):
        if not values:
            print(f"> {name:<20} | No data")
            return 0

        values_sorted = sorted(values)
        avg = statistics.mean(values_sorted)
        med = statistics.median(values_sorted)
        mn = values_sorted[0]
        mx = values_sorted[-1]
        p95 = _percentile(values_sorted, 95)
        p99 = _percentile(values_sorted, 99)
        std = statistics.stdev(values_sorted) if len(values_sorted) > 1 else 0.0

        print(
            f"> {name:<20} | "
            f"Avg:{avg:8.3f}  Med:{med:8.3f}  Min:{mn:8.3f}  Max:{mx:8.3f}  "
            f"P95:{p95:8.3f}  P99:{p99:8.3f}  Std:{std:8.3f}  n={len(values_sorted)}"
        )
        return med

    print("-" * 130)
    print_stat("GenKey", genkey_values)
    print_stat("Encap", encaps_values)
    print_stat("Decap", decaps_values)
    print_stat("Sign", sign_values)
    print_stat("Verify", verify_values)
    print_stat("ch_rcv-sh_snd", ch_rcv_sh_snd_values)
    print_stat("Handshake", handshake_values)
    print("-" * 130)


def main():
    parser = argparse.ArgumentParser(description="Analyses custom TLS timing logs")
    parser.add_argument(
        "log_dir",
        nargs="?",
        default="install/var/log/open5gs",
        help="directory containing logs",
    )
    args = parser.parse_args()

    if not os.path.exists(args.log_dir):
        print(f"[!] Directory not found: {args.log_dir}")
        sys.exit(1)

    _analyse_logs(args.log_dir)


if __name__ == "__main__":
    main()
