#!/bin/bash
# ============================================
# PQC Custom Build Script for Open5GS thesis
# Builds:
#   - OpenSSL
#   - liboqs
#   - OQS Provider
#   - Curl
# Installs everything under ./install/pqc-bundle
# ============================================

set -euo pipefail

OPEN5GS_LIBS="gnupg mongodb-org python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt20-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson"
OPENSSL_LIBS="build-essential perl git zlib1g-dev"
LIBOQS_LIBS="astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind"
OQS_LIBS="cmake build-essential git"
CURL_LIBS="autoconf automake cmake libtool m4 perl"

BASE_DIR="$(pwd)"
INSTALL_ROOT="$BASE_DIR/install"
INSTALL_DIR="$INSTALL_ROOT/pqc-bundle"
SRC_DIR="$INSTALL_DIR/src"
OPENSSL_VER="3.5.3"
LIBOQS_VER="0.14.0"
OQS_VER="0.10.0"
CURL_VER="curl-8_16_0"
NPROC=$(nproc || echo 4)

# ========== FUNCTIONS ==========

check_missing_libs() {
    local libs=($1)
    local missing=()
    for pkg in "${libs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    echo "${missing[*]}"
}

install_missing_libs() {
    local missing=($1)
    if [ "${#missing[@]}" -ne 0 ]; then
        echo "[i] Installing missing libraries: ${missing[*]}"
        sudo apt-get update -y
        sudo apt-get install -y --no-install-recommends "${missing[@]}"
    fi
}

confirm_and_prepare() {
    local msg="$1"
    local libs="$2"
    local missing
    missing=$(check_missing_libs "$libs")

    if [ -n "$missing" ]; then
        msg="$msg\nMissing libraries that will be installed: $missing"
    else
        msg="$msg\nAll required libraries already installed."
    fi

    echo
    echo -e "$msg"
    read -rp "Proceed? [y/N]: " ans
    if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
        echo "[!] Operation cancelled by user."
        exit 1
    fi

    install_missing_libs "$missing"
}

# ========== PRECHECK: OPEN5GS DEPENDENCIES ==========
echo
echo "=== [0/4] Checking Open5GS dependencies (these should be already installed) ==="

missing_open5gs=$(check_missing_libs "$OPEN5GS_LIBS")

if apt-cache show libidn-dev > /dev/null 2>&1; then
    idn_pkg="libidn-dev"
else
    idn_pkg="libidn11-dev"
fi
if ! dpkg -s "$idn_pkg" &>/dev/null; then
    missing_open5gs="$missing_open5gs $idn_pkg"
fi

if [ -z "$missing_open5gs" ]; then
    echo "> All Open5GS dependencies already installed."
else
    echo "[!] Missing Open5GS dependencies detected:"
    echo "   $missing_open5gs"
    read -rp "Install missing Open5GS dependencies before continuing? [y/N]: " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        sudo apt-get update -y
        sudo apt-get install -y --no-install-recommends $missing_open5gs
    else
        echo "[!] Cannot continue without Open5GS dependencies."
        exit 1
    fi
fi

echo
read -rp "> To compile and install Open5GS, the folder $INSTALL_DIR will be created. Is it ok? [y/N]: " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "[!] Operation cancelled by user."
    exit 1
fi
mkdir -p "$INSTALL_DIR" "$SRC_DIR"

# ========== OPENSSL ==========
echo
echo "=== [1/4] OpenSSL $OPENSSL_VER ==="
if [ -d "$INSTALL_DIR/openssl" ]; then
    echo "> OpenSSL already installed, skipping build."
else
    confirm_and_prepare "We are about to clone, build and install OpenSSL $OPENSSL_VER." "$OPENSSL_LIBS"

    cd "$SRC_DIR"
    if [ ! -d openssl ]; then
        git clone --depth 1 --branch "openssl-$OPENSSL_VER" https://github.com/openssl/openssl.git
    fi

    cd openssl
    ./Configure --prefix="$INSTALL_DIR/openssl" --libdir=lib64 no-docs
    make -j"$NPROC"
    make install
fi

# ========== LIBOQS ==========
echo
echo "=== [2/4] liboqs $LIBOQS_VER ==="
if [ -d "$INSTALL_DIR/liboqs" ]; then
    echo "> liboqs already installed, skipping build."
else
    confirm_and_prepare "We are about to clone, build and install liboqs $LIBOQS_VER." "$LIBOQS_LIBS"

    cd "$SRC_DIR"
    if [ ! -d liboqs ]; then
        git clone --depth 1 --branch "$LIBOQS_VER" https://github.com/open-quantum-safe/liboqs.git
    fi

    cd liboqs
    mkdir -p build && cd build
    cmake -GNinja -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/liboqs" ..
    ninja
    ninja install
fi

# ========== OQS PROVIDER ==========
echo
echo "=== [3/4] OQS Provider $OQS_VER ==="
if [ -d "$INSTALL_DIR/oqs-provider" ]; then
    echo "[info] OQS Provider already installed, skipping build."
else
    confirm_and_prepare "We are about to clone, build and install oqs-provider $OQS_VER." "$OQS_LIBS"

    cd "$SRC_DIR"
    if [ ! -d oqs-provider ]; then
        git clone --depth 1 --branch "$OQS_VER" https://github.com/open-quantum-safe/oqs-provider.git
    fi

    cd oqs-provider
    mkdir -p _build && cd _build
    cmake -DOPENSSL_ROOT_DIR="$INSTALL_DIR/openssl" \
          -Dliboqs_DIR="$INSTALL_DIR/liboqs/lib/cmake/liboqs" \
          -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/oqs-provider" \
          ..
    make -j"$NPROC"
    make install
fi

# ========== CURL ==========
echo
echo "=== [4/4] Curl $CURL_VER ==="
if [ -d "$INSTALL_DIR/curl" ]; then
    echo "[info] Curl already installed, skipping build."
else
    confirm_and_prepare "We are about to clone, build and install curl $CURL_VER." "$CURL_LIBS"

    cd "$SRC_DIR"
    if [ ! -d curl ]; then
        git clone --depth 1 --branch "$CURL_VER" https://github.com/curl/curl.git
    fi

    cd curl
    autoreconf -fi
    ./configure --with-openssl="$INSTALL_DIR/openssl" --prefix="$INSTALL_DIR/curl"
    make -j"$NPROC"
    make install
fi

echo
echo "=== Build completed successfully ==="
echo "Libraries inside:     $INSTALL_DIR"
echo "Lib sources inside:   $SRC_DIR"
echo
echo "To activate the environment, run:"
echo "  source custom-env.sh"
