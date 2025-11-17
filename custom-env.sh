#!/bin/bash
set -eo pipefail

BASE_DIR="$(pwd)"
INSTALL_DIR="$BASE_DIR/install/pqc-bundle"

OPENSSL_ROOT="$INSTALL_DIR/openssl"
LIBOQS_ROOT="$INSTALL_DIR/liboqs"
OQSPROV_ROOT="$INSTALL_DIR/oqs-provider"
CURL_ROOT="$INSTALL_DIR/curl"

# executables
export PATH="$OPENSSL_ROOT/bin:$CURL_ROOT/bin:$PATH"

# headers (for compiler include search)
export C_INCLUDE_PATH="$OPENSSL_ROOT/include:$CURL_ROOT/include:$LIBOQS_ROOT/include:$OQSPROV_ROOT/include:$C_INCLUDE_PATH"
export CPATH="$C_INCLUDE_PATH"

# libraries (runtime + link)
export LD_LIBRARY_PATH="$OPENSSL_ROOT/lib64:$CURL_ROOT/lib:$LIBOQS_ROOT/lib:$OQSPROV_ROOT/lib:$LD_LIBRARY_PATH"

# OpenSSL provider modules (includes oqsprovider.so)
export OPENSSL_MODULES="$OPENSSL_ROOT/lib64/ossl-modules"

# pkg-config paths (for Meson/CMake)
export PKG_CONFIG_PATH="$OPENSSL_ROOT/lib64/pkgconfig:$CURL_ROOT/lib/pkgconfig:$LIBOQS_ROOT/lib/pkgconfig:$OQSPROV_ROOT/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "[custom-env.sh] Environment configured:"
echo "  OpenSSL root:   $OPENSSL_ROOT"
echo "  liboqs root:    $LIBOQS_ROOT"
echo "  OQS Provider:   $OQSPROV_ROOT"
echo "  Curl root:      $CURL_ROOT"
echo
echo "  PATH=$PATH"
echo "  C_INCLUDE_PATH=$C_INCLUDE_PATH"
echo "  LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo "  PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
echo "  OPENSSL_MODULES=$OPENSSL_MODULES"
echo
echo "✅ Environment ready."
