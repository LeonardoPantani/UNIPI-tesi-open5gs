#!/usr/bin/env bash
set -euo pipefail

DIR="./install/var/log/open5gs/tls"
OUT="core_sslkeylog.log"
TMP="$(mktemp "${DIR}/.tmp_core_sslkeylog.XXXXXX")"

cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT

shopt -s nullglob
files_found=false
while IFS= read -r file; do
  files_found=true
  cat "$file" >> "$TMP"
done < <(find "$DIR" -maxdepth 1 -type f -name '*.log' ! -name "$OUT" -printf '%T@ %p\n' | sort -n | awk '{ $1=""; sub(/^ /,""); print }')

if ! $files_found; then
  echo "Warning: no .log files found in $DIR (excluding $OUT)." >&2
  exit 1
fi

mv -f "$TMP" "$DIR/$OUT"
trap - EXIT
chmod 640 "$DIR/$OUT"
