#!/usr/bin/env bash
set -euo pipefail

DBCTL="./misc/db/open5gs-dbctl"
K="465B5CE8B199B49FAA5F0A2EE238A6BC"
OPC="E8ED289DEBA952E4283B54E88E6183CA"

# --- argument parsing ---
DEFAULT_N=10

if [ $# -gt 1 ]; then
    echo "Usage: $0 [num_subscribers]"
    exit 1
fi

if [ $# -eq 1 ]; then
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -le 0 ]; then
        echo "Usage: $0 [num_subscribers]"
        exit 1
    fi
    N="$1"
else
    N="$DEFAULT_N"
fi

# --- main loop ---
for i in $(seq 1 "$N"); do
  id_padded=$(printf "%010d" "$i")
  imsi="00101${id_padded}"
  if "$DBCTL" add "$imsi" "$K" "$OPC" >/dev/null 2>&1; then
    printf "."
  else
    printf "X"
  fi
done
echo
