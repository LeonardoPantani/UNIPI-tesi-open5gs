#!/usr/bin/env python3
import os
import sys
import time
import argparse
import subprocess

CGROUP_ROOT = "/sys/fs/cgroup"
CGROUP_NAME = "open5gs_monitor"
CGROUP_PATH = os.path.join(CGROUP_ROOT, CGROUP_NAME)
OUTPUT_DIR = "test_results/server_metrics"
DURATION_SEC = 1800

def check_root():
    if os.geteuid() != 0:
        sys.stderr.write("[!] This script must be run as root (sudo).\n")
        sys.exit(1)

def setup_cgroup(pids):
    if os.path.exists(CGROUP_PATH):
        try:
            os.rmdir(CGROUP_PATH)
        except OSError:
            pass
    
    os.makedirs(CGROUP_PATH, exist_ok=True)

    procs_file = os.path.join(CGROUP_PATH, "cgroup.procs")
    moved_count = 0
    for pid in pids:
        try:
            with open(procs_file, "w") as f:
                f.write(str(pid))
            moved_count += 1
        except OSError:
            continue
            
    if moved_count == 0:
        raise RuntimeError("[!] Could not move any process to cgroup (processes terminated?).")

def get_open5gs_pids():
    try:
        out = subprocess.check_output(["pgrep", "-f", "open5gs-"])
        return [int(pid) for pid in out.split()]
    except subprocess.CalledProcessError:
        return []

def read_cpu_usage_usec():
    try:
        with open(os.path.join(CGROUP_PATH, "cpu.stat"), "r") as f:
            for line in f:
                if line.startswith("usage_usec"):
                    return int(line.split()[1])
    except FileNotFoundError:
        return 0
    return 0

def read_memory_bytes():
    try:
        with open(os.path.join(CGROUP_PATH, "memory.current"), "r") as f:
            return int(f.read().strip())
    except FileNotFoundError:
        return 0

def fix_file_ownership(filepath):
    sudo_uid = os.environ.get('SUDO_UID')
    sudo_gid = os.environ.get('SUDO_GID')
    
    if sudo_uid and sudo_gid:
        try:
            uid = int(sudo_uid)
            gid = int(sudo_gid)
            os.chown(filepath, uid, gid)
        except Exception as e:
            print(f"\n[!] Warning: could not change file ownership: {e}")

def main():
    check_root()

    parser = argparse.ArgumentParser(description="Monitor Open5GS metrics via Cgroups")
    parser.add_argument("mode", help="nosr or sr")
    parser.add_argument("alg_type", help="Algorithm Type")
    parser.add_argument("sig_type", help="Signature Type")
    args = parser.parse_args()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    filename = f"servermetrics_{args.mode}_usage_{args.alg_type}_{args.sig_type}.csv"
    filepath = os.path.join(OUTPUT_DIR, filename)

    pids = get_open5gs_pids()
    if not pids:
        sys.stderr.write("[!] No Open5GS processes found.\n")
        sys.exit(1)

    print(f"> Found {len(pids)} processes.")
    
    try:
        setup_cgroup(pids)
        
        print(f"> Monitoring started. Duration: {DURATION_SEC} seconds. Output: {filepath}")
        
        with open(filepath, "w") as csv:
            fix_file_ownership(filepath)
            
            csv.write("timestamp_ms,cpu_usage_usec,cpu_percent,mem_bytes\n")
            
            nproc = os.cpu_count() or 1
            
            prev_cpu_usec = read_cpu_usage_usec()
            prev_time_ns = time.perf_counter_ns()
            
            start_loop_time = time.time()
            
            for i in range(DURATION_SEC):
                target_time = start_loop_time + (i + 1)
                
                sleep_duration = target_time - time.time()
                if sleep_duration > 0:
                    time.sleep(sleep_duration)
                
                now_time_ns = time.perf_counter_ns()
                curr_cpu_usec = read_cpu_usage_usec()
                mem_bytes = read_memory_bytes()
                timestamp_ms = int(time.time() * 1000)

                delta_cpu_usec = curr_cpu_usec - prev_cpu_usec
                delta_time_ns = now_time_ns - prev_time_ns
                
                if delta_time_ns == 0: delta_time_ns = 1
                
                cpu_percent = ((delta_cpu_usec * 1000) / delta_time_ns / nproc) * 100
                
                csv.write(f"{timestamp_ms},{curr_cpu_usec},{cpu_percent:.2f},{mem_bytes}\n")
                csv.flush()

                sys.stdout.write(f"\r[{i+1}/{DURATION_SEC}] CPU: {curr_cpu_usec} usec ({cpu_percent:.2f}%) | MEM: {mem_bytes} bytes   ")
                sys.stdout.flush()

                prev_cpu_usec = curr_cpu_usec
                prev_time_ns = now_time_ns

    except KeyboardInterrupt:
        print("\n> Interrupted by user.")
    except Exception as e:
        print(f"\n[!] Unexpected exception: {e}")
    finally:
        print("\n> Cleaning up Cgroup...")
        try:
            os.rmdir(CGROUP_PATH)
        except:
            pass
        print("> Finished.")

if __name__ == "__main__":
    main()