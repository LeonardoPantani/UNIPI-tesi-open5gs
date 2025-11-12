#!/usr/bin/env python3
import os
import re
import sys
import statistics
from glob import glob

LOG_DIR = "install/var/log/open5gs"
TLS_DIR = os.path.join(LOG_DIR, "tls")

def main():
    if len(sys.argv) < 1:
        print(f"Usage: {sys.argv[0]} [cleanup?]")
        sys.exit(1)

    cleanup = len(sys.argv) > 1 and sys.argv[1].lower() in ("y")

    encaps_values = []
    decaps_values = []
    handshake_values = []

    re_encaps = re.compile(r"\[TLS-KEM\]\s+Encaps time \(server\):\s+([\d.]+)\s+ms")
    re_decaps = re.compile(r"\[TLS-KEM\]\s+Decaps time \(client\):\s+([\d.]+)\s+ms")
    re_handshake = re.compile(r"\[TLS\]\s+Handshake time \(server side\):\s+([\d.]+)\s+ms")

    log_files = sorted(glob(os.path.join(LOG_DIR, "*.log")))
    if not log_files:
        print(f"no .log file found in {LOG_DIR}")
        sys.exit(0)

    for path in log_files:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "[TLS-KEM]" in line or "[TLS]" in line:
                    if m := re_encaps.search(line):
                        encaps_values.append(float(m.group(1)))
                    elif m := re_decaps.search(line):
                        decaps_values.append(float(m.group(1)))
                    elif m := re_handshake.search(line):
                        handshake_values.append(float(m.group(1)))

    if encaps_values:
        print(f"Encaps (server) avg: {statistics.mean(encaps_values):.3f} ms, median: {statistics.median(encaps_values):.3f} ms (n={len(encaps_values)})")
    else:
        print("Encaps (server) avg: no data")

    if decaps_values:
        print(f"Decaps (client) avg: {statistics.mean(decaps_values):.3f} ms, median: {statistics.median(decaps_values):.3f} ms (n={len(decaps_values)})")
    else:
        print("Decaps (client) avg: no data")

    if handshake_values:
        print(f"Handshake (server side) avg: {statistics.mean(handshake_values):.3f} ms, median: {statistics.median(handshake_values):.3f} ms (n={len(handshake_values)})")
    else:
        print("Handshake (server side) avg: no data")
    
    print(f"Copy and paste: {statistics.median(encaps_values):.3f},{statistics.median(decaps_values):.3f},{statistics.median(handshake_values):.3f}")

    if cleanup:
        print("\nDeleting log and TLS files...")

        for f in log_files:
            try:
                os.remove(f)
            except Exception as e:
                print(f"Failed to remove {f}: {e}")

        if os.path.isdir(TLS_DIR):
            tls_files = glob(os.path.join(TLS_DIR, "*"))
            for f in tls_files:
                try:
                    os.remove(f)
                except Exception as e:
                    print(f"Failed to remove {f}: {e}")

        print("All log and TLS files removed.")

if __name__ == "__main__":
    main()