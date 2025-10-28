#!/bin/bash

# Usage: ./generate_tls.sh [sigalg]

# Valid SIGNATURE ALGS USABLE FOR TLS:
# --- ML-DSA
# mldsa44 p256_mldsa44 rsa3072_mldsa44 mldsa65 p384_mldsa65 mldsa87 p521_mldsa87
# --- Falcon
# falcon512 p256_falcon512 rsa3072_falcon512 falconpadded512 p256_falconpadded512 rsa3072_falconpadded512 falcon1024 p521_falcon1024 falconpadded1024 p521_falconpadded1024
# --- SPHINCS-SHA2
# sphincssha2128fsimple p256_sphincssha2128fsimple rsa3072_sphincssha2128fsimple sphincssha2128ssimple p256_sphincssha2128ssimple rsa3072_sphincssha2128ssimple sphincssha2192fsimple p384_sphincssha2192fsimple
# --- SPHINCS-SHAKE
# sphincsshake128fsimple p256_sphincsshake128fsimple rsa3072_sphincsshake128fsimple
# --- MAYO
# mayo1 p256_mayo1 mayo2 p256_mayo2 mayo3 p384_mayo3 mayo5 p521_mayo5
# --- CROSS
# CROSSrsdp128balanced
# --- UOV
# OV_Ip_pkc p256_OV_Ip_pkc OV_Ip_pkc_skc p256_OV_Ip_pkc_skc
# --- SNOVA
# snova2454 p256_snova2454 snova2454esk p256_snova2454esk snova37172 p256_snova37172 snova2455 p384_snova2455 snova2965 p521_snova2965

SIGALG=${1:-mldsa44}
TLS_DIR="./install/etc/open5gs/tls2"
NFS=("amf" "ausf" "bsf" "hss" "mme" "nrf" "nssf" "pcf" "pcrf" "scp" "sepp1" "sepp2" "sepp3" "smf" "udm" "udr")

mkdir -p "$TLS_DIR"
echo "[*] Target dir: $TLS_DIR"
echo "[*] Using signature algorithm: $SIGALG"

# generating CA cert
if [ ! -f "$TLS_DIR/ca.crt" ]; then
  echo "[*] Generating CA ($SIGALG)"
  openssl genpkey -algorithm "$SIGALG" \
    -out "$TLS_DIR/ca.key" \
    -provider oqsprovider -provider default

  openssl req -x509 -new -key "$TLS_DIR/ca.key" \
    -out "$TLS_DIR/ca.crt" -days 3650 -subj "/C=KO/ST=Seoul/O=NeoPlane/CN=ca.localdomain" \
    -provider oqsprovider -provider default -sha256

  
fi

# generating cert for every NF
for nf in "${NFS[@]}"; do
  crt="$TLS_DIR/$nf.crt"
  key="$TLS_DIR/$nf.key"
  if [ ! -f "$crt" ] || [ ! -f "$key" ]; then
    echo "[*] Generating $nf ($SIGALG)"
    openssl genpkey -algorithm "$SIGALG" \
      -out "$key" \
      -provider oqsprovider -provider default

    openssl req -new -key "$key" -out "$TLS_DIR/$nf.csr" \
      -subj "/C=KO/ST=Seoul/O=NeoPlane/CN=$nf.localdomain" \
      -provider oqsprovider -provider default -sha256

    openssl x509 -req -in "$TLS_DIR/$nf.csr" \
      -CA "$TLS_DIR/ca.crt" -CAkey "$TLS_DIR/ca.key" -CAcreateserial \
      -out "$crt" -days 3650 -sha256 \
      -provider oqsprovider -provider default

    rm "$TLS_DIR/$nf.csr"
  fi
done

# remove ca key
rm "$TLS_DIR/ca.key"

# fix permissions
echo "[*] Setting permissions"
chmod 755 "$TLS_DIR"
chmod 664 "$TLS_DIR"/*
chown $(whoami):$(whoami) "$TLS_DIR"/*

echo "[*] Done"
