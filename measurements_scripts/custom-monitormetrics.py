#!/usr/bin/env python3
import os
import time
import argparse
import subprocess

CGROUP_PATH = os.path.join("/sys/fs/cgroup", "open5gs_monitor")
OUTPUT_DIR = "measurements_results/server_metrics/performance/uereg/only_one"
NUM_EXPECTED_PROCESSES = 13
SAMPLE_INTERVAL = 0.05
PROCESSES_START_TIMEOUT = 20
DURATION_SEC = 200  # default duration


def _get_original_user():
    sudo_uid = os.environ.get("SUDO_UID")
    sudo_gid = os.environ.get("SUDO_GID")

    if sudo_uid and sudo_gid:
        return int(sudo_uid), int(sudo_gid)
    else:
        return os.getuid(), os.getgid()


def _setup_cgroup(pids):
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
        raise RuntimeError(
            "[!] Could not move any process to cgroup (processes terminated?)."
        )


def _get_open5gs_pids():
    try:
        out = subprocess.check_output(["pgrep", "-f", "open5gs-"])
        return [int(pid) for pid in out.split()]
    except subprocess.CalledProcessError:
        return []


def _read_cpu_usage_usec():
    try:
        with open(os.path.join(CGROUP_PATH, "cpu.stat"), "r") as f:
            for line in f:
                if line.startswith("usage_usec"):
                    return int(line.split()[1])
    except FileNotFoundError:
        return 0
    return 0


def _read_memory_bytes():
    try:
        with open(os.path.join(CGROUP_PATH, "memory.current"), "r") as f:
            return int(f.read().strip())
    except FileNotFoundError:
        return 0


def main():
    if os.geteuid() != 0:
        print("[!] This script must be run as root.")
        return

    parser = argparse.ArgumentParser(description="Monitor Open5GS metrics via Cgroups.")
    parser.add_argument("MODE", choices=["nosr", "sr"], help="nosr or sr")
    parser.add_argument("ALG_TYPE", help="Algorithm Type")
    parser.add_argument("SIG_TYPE", help="Signature Type")
    parser.add_argument(
        "--time",
        type=int,
        default=DURATION_SEC,
        help="Measurement duration in seconds (0 = manual stop with Ctrl+C)",
    )

    args = parser.parse_args()

    duration_sec = args.time

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    base_filename = f"servermetrics_{args.MODE}_usage_{args.ALG_TYPE}_{args.SIG_TYPE}"
    extension = ".csv"
    filepath = os.path.join(OUTPUT_DIR, f"{base_filename}{extension}")

    # add _2, _3 to files if already exist
    if os.path.exists(filepath):
        counter = 2
        while True:
            new_filepath = os.path.join(OUTPUT_DIR, f"{base_filename}_{counter}{extension}")
            if not os.path.exists(new_filepath):
                filepath = new_filepath
                break
            counter += 1

    print("> Waiting for Open5GS processes to start...")
    start = time.time()
    pids = []

    while time.time() - start < PROCESSES_START_TIMEOUT:
        pids = _get_open5gs_pids()
        if len(pids) == NUM_EXPECTED_PROCESSES:
            break

    if not pids:
        print(
            f"[!] No Open5GS processes started within {PROCESSES_START_TIMEOUT} seconds."
        )
        return

    print(f"> Found {len(pids)} processes: {pids}")

    try:
        _setup_cgroup(pids)

        if duration_sec == 0:
            print(f"> Monitoring started. Duration: unlimited (Ctrl+C to stop).")
        else:
            print(
                f"> Monitoring started. Duration: {duration_sec} seconds. Output: {filepath}"
            )

        with open(filepath, "w") as csv:
            csv.write("timestamp_ms,cpu_usage_usec,cpu_percent,mem_bytes\n")

            nproc = os.cpu_count() or 1
            prev_cpu_usec = _read_cpu_usage_usec()
            prev_time_ns = time.perf_counter_ns()

            i = 0
            while True:
                if duration_sec != 0 and i * SAMPLE_INTERVAL >= duration_sec:
                    break

                time.sleep(SAMPLE_INTERVAL)

                now_time_ns = time.perf_counter_ns()
                curr_cpu_usec = _read_cpu_usage_usec()
                mem_bytes = _read_memory_bytes()
                timestamp_ms = int(time.time() * 1000)

                delta_cpu_usec = curr_cpu_usec - prev_cpu_usec
                delta_time_ns = now_time_ns - prev_time_ns
                if delta_time_ns == 0:
                    delta_time_ns = 1

                cpu_percent = ((delta_cpu_usec * 1000) / delta_time_ns / nproc) * 100

                csv.write(
                    f"{timestamp_ms},{curr_cpu_usec},{cpu_percent:.2f},{mem_bytes}\n"
                )
                csv.flush()

                print(
                    f"\r[{i}] CPU: {curr_cpu_usec} usec ({cpu_percent:.2f}%) | MEM: {mem_bytes} bytes ",
                    end="",
                    flush=True,
                )

                prev_cpu_usec = curr_cpu_usec
                prev_time_ns = now_time_ns
                i += 1

    except KeyboardInterrupt:
        print("\n> Interrupted by user.")
    except Exception as e:
        print(f"\n[!] Unexpected exception: {e}")
    finally:
        try:
            os.rmdir(CGROUP_PATH)
        except:
            pass

        orig_uid, orig_gid = _get_original_user()
        try:
            os.chown(OUTPUT_DIR, orig_uid, orig_gid)
            os.chown(filepath, orig_uid, orig_gid)
        except:
            pass

        print("> Finished.")
        try:
            subprocess.run(
                ["python3", "measurements_scripts/custom-showmetrics.py", filepath]
            )
        except Exception as e:
            print(f"[!] Failed to run custom-showmetrics.py: {e}")


if __name__ == "__main__":
    main()
