#!/usr/bin/env python3
import argparse
import os
import re
import sys
from glob import glob

import numpy as np


METRICS = {
    "Keypair":   re.compile(r"^\s*genkey,([0-9]+(?:\.[0-9]+)?),ms\b", re.IGNORECASE),
    "Encap":     re.compile(r"^\s*encap,([0-9]+(?:\.[0-9]+)?),ms\b",  re.IGNORECASE),
    "Decap":     re.compile(r"^\s*decap,([0-9]+(?:\.[0-9]+)?),ms\b",  re.IGNORECASE),
    "Sign":      re.compile(r"^\s*sign,([0-9]+(?:\.[0-9]+)?),ms\b",   re.IGNORECASE),
    "Verify":    re.compile(r"^\s*verify,([0-9]+(?:\.[0-9]+)?),ms\b", re.IGNORECASE),
    "Handshake": re.compile(r"^\s*hshake,([0-9]+(?:\.[0-9]+)?),ms\b", re.IGNORECASE),
}


def read_metrics(log_dir: str) -> tuple[int, dict[str, np.ndarray]]:
    files = sorted(glob(os.path.join(log_dir, "*.log")))
    if not files:
        raise FileNotFoundError(f"No .log files found in: {log_dir}")

    buckets = {k: [] for k in METRICS.keys()}

    for path in files:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for raw in f:
                    line = raw.strip()
                    for name, rx in METRICS.items():
                        m = rx.match(line)
                        if not m:
                            continue
                        v = float(m.group(1))
                        if v != 0.0:
                            buckets[name].append(v)
                        break
        except Exception as e:
            print(f"[!] Error reading {path}: {e}", file=sys.stderr)

    return len(files), {k: np.asarray(v, dtype=float) for k, v in buckets.items()}


def bootstrap_ci95_median(x: np.ndarray, n_boot: int, seed: int) -> tuple[float, float, float]:
    if x.size == 0:
        return (float("nan"), float("nan"), float("nan"))
    if x.size == 1:
        v = float(x[0])
        return (v, v, v)

    rng = np.random.default_rng(seed)
    n = x.size

    idx = rng.integers(0, n, size=(n_boot, n))
    samples = x[idx]
    meds = np.median(samples, axis=1)

    stat = float(np.median(x))
    lo, hi = np.quantile(meds, [0.025, 0.975])
    return (stat, float(lo), float(hi))


def print_stats(name: str, x: np.ndarray, n_boot: int, seed: int) -> None:
    if x.size == 0:
        print(f"> {name:<12} | No data")
        return

    x = np.asarray(x, dtype=float)
    med, lo, hi = bootstrap_ci95_median(x, n_boot=n_boot, seed=seed)
    half = (hi - lo) / 2.0

    mean = float(np.mean(x))
    mn = float(np.min(x))
    mx = float(np.max(x))

    print(
        f"> {name:<12} | "
        f"Median:{med:.3f},{half:.3f}  (CI95:[{lo:8.3f}, {hi:8.3f}])  "
        f"Mean:{mean:8.3f}  Min:{mn:8.3f}  Max:{mx:8.3f}  "
        f"n={x.size}"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Analyse custom TLS timing logs (median + bootstrap CI95).")
    ap.add_argument("log_dir", nargs="?", default="install/var/log/open5gs", help="directory containing *.log files")
    ap.add_argument("--boot", type=int, default=5000, help="bootstrap resamples (default: 5000)")
    ap.add_argument("--seed", type=int, default=123, help="bootstrap seed (default: 123)")
    args = ap.parse_args()

    if not os.path.isdir(args.log_dir):
        print(f"[!] Directory not found: {args.log_dir}", file=sys.stderr)
        return 2

    try:
        n_files, data = read_metrics(args.log_dir)
    except FileNotFoundError as e:
        print(f"[!] {e}", file=sys.stderr)
        return 3

    print(f"> Analysing {n_files} files in '{args.log_dir}'...")
    print("-" * 150)
    for name in ["Keypair", "Encap", "Decap", "Sign", "Verify", "Handshake"]:
        print_stats(name, data[name], n_boot=args.boot, seed=args.seed)
    print("-" * 150)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())