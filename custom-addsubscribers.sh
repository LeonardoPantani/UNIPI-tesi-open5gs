#!/usr/bin/env bash
set -euo pipefail

DBCTL="./misc/db/open5gs-dbctl"
K="465B5CE8B199B49FAA5F0A2EE238A6BC"
OPC="E8ED289DEBA952E4283B54E88E6183CA"

for i in $(seq 1 10); do
  id_padded=$(printf "%010d" "$i")
  imsi="00101${id_padded}"
  if "$DBCTL" add "$imsi" "$K" "$OPC" >/dev/null 2>&1; then
    printf "."
  else
    printf "X"
  fi
done
echo
