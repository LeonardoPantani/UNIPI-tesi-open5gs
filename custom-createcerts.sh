#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dst_folder> <sig_alg>"
    exit 1
fi

DST_FOLDER="$1"
SIGALG="$2"

if [[ ! "$DST_FOLDER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "[!] Invalid folder name: $DST_FOLDER"
    exit 1
fi

TLS_DIR="./install/etc/open5gs/$DST_FOLDER"
NFS=(amf ausf bsf hss mme nrf nssf pcf pcrf scp sepp1 sepp2 sepp3 smf udm udr)

mkdir -p "$TLS_DIR"
echo "> Target dir: $TLS_DIR"
echo "> Using signature algorithm: $SIGALG"

is_ec=false
if [[ "$SIGALG" =~ ^(ecdsa|prime|secp) ]]; then
  is_ec=true
fi

# --- Generate CA ---
if [ ! -f "$TLS_DIR/ca.crt" ]; then
  echo "[*] Generating CA ($SIGALG)"
  if $is_ec; then
    curve="prime256v1"
    [[ "$SIGALG" =~ 384 ]] && curve="secp384r1"
    [[ "$SIGALG" =~ 521 ]] && curve="secp521r1"

    openssl ecparam -name "$curve" -genkey -noout -out "$TLS_DIR/ca.key"
  else
    openssl genpkey -algorithm "$SIGALG" -out "$TLS_DIR/ca.key" \
      -provider oqsprovider -provider default
  fi

  openssl req -x509 -new -key "$TLS_DIR/ca.key" -out "$TLS_DIR/ca.crt" \
    -days 3650 -subj "/C=KO/ST=Seoul/O=NeoPlane/CN=ca.localdomain" \
    -provider oqsprovider -provider default -sha256
fi

# --- Generate certificates for each NF ---
for nf in "${NFS[@]}"; do
  key="$TLS_DIR/$nf.key"
  crt="$TLS_DIR/$nf.crt"
  csr="$TLS_DIR/$nf.csr"

  [ -f "$key" ] && [ -f "$crt" ] && continue
  echo "> Generating $nf ($SIGALG)"

  if $is_ec; then
    curve="prime256v1"
    [[ "$SIGALG" =~ 384 ]] && curve="secp384r1"
    [[ "$SIGALG" =~ 521 ]] && curve="secp521r1"

    openssl ecparam -name "$curve" -genkey -noout -out "$key"
  else
    openssl genpkey -algorithm "$SIGALG" -out "$key" \
      -provider oqsprovider -provider default
  fi

  openssl req -new -key "$key" -out "$csr" \
    -subj "/C=KO/ST=Seoul/O=NeoPlane/CN=$nf.localdomain" \
    -provider oqsprovider -provider default -sha256

  openssl x509 -req -in "$csr" -CA "$TLS_DIR/ca.crt" -CAkey "$TLS_DIR/ca.key" \
    -CAcreateserial -out "$crt" -days 3650 \
    -provider oqsprovider -provider default -sha256

  rm -f "$csr"
done

# --- Cleanup ---
rm -f "$TLS_DIR/ca.key"
chmod 755 "$TLS_DIR"
chmod 664 "$TLS_DIR"/*
chown "$(whoami):$(whoami)" "$TLS_DIR"/*

echo "> Done."
