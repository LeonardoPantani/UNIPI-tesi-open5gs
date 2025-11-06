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

set -eo pipefail

OPEN5GS_LIBS="curl gnupg python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt20-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson"
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

# ========== MONGODB INSTALLATION ==========
echo
echo "=== [1/10] Checking MongoDB installation ==="

if ! command -v mongod &>/dev/null; then
    echo "[!] MongoDB not detected. Installing MongoDB 8.0..."
    sudo apt-get update -y
    sudo apt-get install -y curl gnupg
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
    sudo apt-get update -y
    sudo apt-get install -y mongodb-org

    if ! pgrep -x mongod >/dev/null; then
        echo "> Starting MongoDB service..."
        sudo systemctl start mongod
    fi

    echo "> Enabling MongoDB service to start on boot..."
    sudo systemctl enable mongod
    echo "=== MongoDB installed and running ==="
else
    echo "> MongoDB already installed, skipping."
fi

# ========== PRECHECK: OPEN5GS DEPENDENCIES ==========
echo
echo "=== [2/10] Checking Open5GS dependencies (these should be already installed) ==="

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

if [ ! -d $INSTALL_DIR ]; then
    echo
    read -rp "> To compile and install Open5GS, the folder $INSTALL_DIR will be created. Is it ok? [y/N]: " ans
    if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
        echo "[!] Operation cancelled by user."
        exit 1
    fi
    mkdir -p "$INSTALL_DIR" "$SRC_DIR"
fi

# ========== OPENSSL ==========
echo
echo "=== [3/10] OpenSSL $OPENSSL_VER ==="
if [ -d "$INSTALL_DIR/openssl" ]; then
    echo "> OpenSSL already installed, skipping."
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
echo "=== [4/10] liboqs $LIBOQS_VER ==="
if [ -d "$INSTALL_DIR/liboqs" ]; then
    echo "> liboqs already installed, skipping."
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
echo "=== [5/10] OQS Provider $OQS_VER ==="
if [ -d "$INSTALL_DIR/oqs-provider" ]; then
    echo "> OQS Provider already installed, skipping."
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
echo "=== [6/10] Curl $CURL_VER ==="
if [ -d "$INSTALL_DIR/curl" ]; then
    echo "> Curl already installed, skipping."
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
echo "=== Libraries built successfully ==="
echo "> Libraries inside:     $INSTALL_DIR"
echo "> Lib sources inside:   $SRC_DIR"

# ========== CONFIGURE gNB CONNECTION ADDRESS ==========
echo
echo "=== [7/10] gNB Connection Configuration ==="

# look for files that contain the string
files_found=($(grep -l "ADDRESS_PLACEHOLDER" ./configs/open5gs/*.yaml.in 2>/dev/null || true))

if [ "${#files_found[@]}" -eq 0 ]; then
    echo "> No configuration files with 'ADDRESS_PLACEHOLDER' found, skipping."
else
    read -rp "> Enter the IP address the gNB should use to connect to the AMF/UPF (or 'n' to skip): " gnb_addr

    if [[ "$gnb_addr" != "n" && "$gnb_addr" != "N" && -n "$gnb_addr" ]]; then
        while true; do
            echo "> You entered: $gnb_addr"
            read -rp "> This is ok? [y/N]: " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                for file in "${files_found[@]}"; do
                    sed -i "s|ADDRESS_PLACEHOLDER|$gnb_addr|g" "$file"
                done
                echo "> Configuration updated successfully."
                break
            elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
                read -rp "> Enter a new IP address: " gnb_addr
            else
                echo "[!] Please answer y or n."
            fi
        done
    else
        echo "> Skipping gNB address configuration."
    fi
fi

# ========== OPEN5GS BUILD (optional) ==========
echo
echo "=== [8/10] Building Open5GS ==="
if [ ! -d "$INSTALL_ROOT/etc" ] || [ ! -d "$INSTALL_ROOT/bin" ] || [ ! -d "$INSTALL_ROOT/lib" ]; then
    read -rp "> It seems Open5GS is not installed yet. Do you want to build it now? [y/N]: " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        source ./custom-env.sh
        meson setup build --prefix="$PWD/install"
        cd build
        ninja -j"$(nproc)"
        ninja install
        cd ..
        echo "=== Open5GS built successfully ==="
    else
        echo "> Skipping Open5GS build. You will have to build Open5GS by yourself! Use the VSCode Task or execute this  commands:"
        echo "[i] source ./custom-env.sh && meson setup build --prefix=$PWD/install && cd build && ninja -j$(nproc) && ninja install"
    fi
else
    echo "> Open5GS installation already detected, skipping."
fi


# ========== CERTIFICATES (optional) ==========
echo
echo "=== [9/10] Generating Custom Certificates ==="
if [ ! -d "$INSTALL_ROOT/etc/open5gs/tls2" ]; then
    echo
    read -rp "> Do you want to generate custom TLS certificates now? [y/N]: " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        if [ -x "./custom-createcerts.sh" ]; then
            source ./custom-env.sh
            ./custom-createcerts.sh
            echo "=== Certificates generated successfully ==="
        else
            echo "[!] ./custom-createcerts.sh not found or not executable."
        fi
    else
        echo "> Skipping certificate generation."
    fi
else
    echo "> Custom certificates already created, skipping."
fi

# ========== NETWORK SETUP (optional) ==========
echo
echo "=== [10/10] Network Setup ==="
read -rp "> Do you want to setup the network (create aliases, enable port forwarding, and add firewall rules)? [y/N]: " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    if [ -x "./custom-setup_network.sh" ]; then
        ./custom-setup_network.sh
        echo "=== Network setup completed successfully ==="
    else
        echo "[!] ./custom-setup_network.sh not found or not executable."
    fi
else
    echo "> Skipping network setup."
fi

echo
echo "Note: on first run, you should add subscribers via the custom-addsubscribers.sh script, otherwise devices will not be accepted by the network."
echo "( ˶ˆᗜˆ˵ ) Enjoy!"