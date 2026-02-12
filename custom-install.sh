#!/bin/bash

set -e 

OPEN5GS_LIBS="iptables curl gnupg python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt20-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson"
OPENSSL_LIBS="build-essential perl git zlib1g-dev"
LIBOQS_LIBS="astyle cmake gcc ninja-build libssl-dev python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml valgrind"
OQS_LIBS="cmake build-essential git"
CURL_LIBS="autoconf automake cmake libtool m4 perl libpsl-dev"

BASE_DIR="$(pwd)"
INSTALL_ROOT="$BASE_DIR/install"
INSTALL_DIR="$INSTALL_ROOT/pqc-bundle"
SRC_DIR="$INSTALL_DIR/src"
OPENSSL_VER="3.5.3"
LIBOQS_VER="0.14.0"
OQS_VER="0.10.0"
CURL_VER="curl-8_16_0"
NPROC=$(nproc || echo 4)
TRUST_MODE=false

# ========== arguments handling ==========
usage() { echo "Usage: $0 [-t]"; exit 1; }

while getopts "t" o; do
    case "${o}" in
        t)
            TRUST_MODE=true
            echo ">>> TRUST MODE ENABLED: No prompts will be shown."
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# ========== helper functions ==========
wait_for_apt_locks() {
    local locks=("/var/lib/dpkg/lock-frontend" "/var/lib/dpkg/lock" "/var/lib/apt/lists/lock")
    
    for lock in "${locks[@]}"; do
        while sudo fuser "$lock" >/dev/null 2>&1; do
            echo "[!] Lock $lock is held by another process. Waiting 5s..."
            sleep 5
        done
    done
    echo "[*] Apt locks are free."
}

safe_apt_install() {
    wait_for_apt_locks
    sudo apt-get install -y "$@"
}

safe_apt_update() {
    wait_for_apt_locks
    sudo apt-get update -y
}

ask_confirm_always() {
    local prompt="$1"
    read -rp "$prompt [y/N]: " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

ask_confirm() {
    local prompt="$1"
    
    if [ "$TRUST_MODE" = true ]; then
        echo "$prompt [TRUST MODE: assuming Yes]"
        return 0 # 0 = true (yes)
    fi

    read -rp "$prompt [y/N]: " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        return 0
    else
        return 1 # 1 = false (no)
    fi
}

check_missing_libs() {
    local libs=()
    read -r -a libs <<< "$1"
    local missing=()
    for pkg in "${libs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    echo "${missing[*]}"
}

install_missing_libs() {
    local missing=()
    read -r -a missing <<< "$1"
    if [ "${#missing[@]}" -ne 0 ]; then
        echo "[i] Installing missing libraries: ${missing[*]}"
        safe_apt_update
        safe_apt_install "${missing[@]}"
    fi
}

confirm_and_prepare() {
    local msg="$1"
    local libs_array=()
    read -r -a libs_array <<< "$2"
    
    local missing
    missing=$(check_missing_libs "${libs_array[*]}")

    if [ -n "$missing" ]; then
        msg="$msg\nMissing libraries that will be installed: $missing"
    else
        msg="$msg\nAll required libraries already installed."
    fi

    echo -e "\n$msg"
    
    if ask_confirm "Proceed?"; then
        install_missing_libs "$missing"
    else
        echo "[!] Operation cancelled by user."
        exit 1
    fi
}

# ========== MAIN SCRIPT ==========

# Check sudo privileges upfront
echo "=== [0/10] Checking privileges ==="
sudo -v || { echo "[!] This script requires sudo privileges for apt."; exit 1; }

# ========== MONGODB INSTALLATION ==========
echo
echo "=== [1/10] Checking MongoDB installation ==="

if ! command -v mongod &>/dev/null; then
    if ask_confirm "[!] MongoDB not detected. Install it?"; then
        install_missing_libs "curl gnupg"

        if [ -f /etc/os-release ]; then . /etc/os-release; fi
        os_version=${VERSION_ID%%.*}
        case $os_version in
            20) codename="focal"    ;;
            22) codename="jammy"    ;;
            24) codename="noble"    ;;
            26) codename="resolute" ;;
            *)  codename="jammy"    ;;
        esac

        curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor --yes
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $codename/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
        
        safe_apt_update
        safe_apt_install mongodb-org

        if ! pgrep -x mongod >/dev/null; then
            sudo systemctl start mongod
        fi
        sudo systemctl enable mongod
        echo "=== MongoDB installed and running ==="
    else
        echo "> Skipping MongoDB installation."
    fi
else
    echo "> MongoDB already installed, skipping."
fi

# ========== PRECHECK: OPEN5GS DEPENDENCIES ==========
echo
echo "=== [2/10] Checking Open5GS dependencies ==="

missing_open5gs=$(check_missing_libs "$OPEN5GS_LIBS")
if apt-cache show libidn-dev > /dev/null 2>&1; then idn_pkg="libidn-dev"; else idn_pkg="libidn11-dev"; fi
if ! dpkg -s "$idn_pkg" &>/dev/null; then missing_open5gs="$missing_open5gs $idn_pkg"; fi

if [ -n "$missing_open5gs" ]; then
    echo "[!] Missing: $missing_open5gs"
    if ask_confirm "Install missing Open5GS dependencies?"; then
        install_missing_libs "$missing_open5gs"
    else
        echo "[!] Cannot continue."
        exit 1
    fi
else
    echo "> Dependencies already installed."
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo
    if ! ask_confirm "> Create folder $INSTALL_DIR?"; then
        exit 1
    fi
    mkdir -p "$INSTALL_DIR" "$SRC_DIR"
fi

# ========== OPENSSL ==========
echo
echo "=== [3/10] OpenSSL $OPENSSL_VER ==="
if [ -d "$INSTALL_DIR/openssl" ]; then
    echo "> OpenSSL already installed."
else
    confirm_and_prepare "Build OpenSSL $OPENSSL_VER?" "$OPENSSL_LIBS"
    cd "$SRC_DIR"
    [ ! -d openssl ] && git clone --depth 1 --branch "openssl-$OPENSSL_VER" https://github.com/openssl/openssl.git
    cd openssl
    ./Configure --prefix="$INSTALL_DIR/openssl" --libdir=lib64 no-docs enable-trace
    make -j"$NPROC"
    make install
fi

# ========== LIBOQS ==========
echo
echo "=== [4/10] liboqs $LIBOQS_VER ==="
if [ -d "$INSTALL_DIR/liboqs" ]; then
    echo "> liboqs already installed."
else
    confirm_and_prepare "Build liboqs $LIBOQS_VER?" "$LIBOQS_LIBS"
    cd "$SRC_DIR"
    [ ! -d liboqs ] && git clone --depth 1 --branch "$LIBOQS_VER" https://github.com/open-quantum-safe/liboqs.git
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
    echo "> OQS Provider already installed."
else
    confirm_and_prepare "Build oqs-provider $OQS_VER?" "$OQS_LIBS"
    cd "$SRC_DIR"
    [ ! -d oqs-provider ] && git clone --depth 1 --branch "$OQS_VER" https://github.com/open-quantum-safe/oqs-provider.git
    cd oqs-provider
    mkdir -p _build && cd _build
    cmake -DOPENSSL_ROOT_DIR="$INSTALL_DIR/openssl" \
          -Dliboqs_DIR="$INSTALL_DIR/liboqs/lib/cmake/liboqs" \
          -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/oqs-provider" \
          -DCMAKE_BUILD_TYPE=Debug \
          ..
    make -j"$NPROC"
    make install
fi

# ========== CURL ==========
echo
echo "=== [6/10] Curl $CURL_VER ==="
if [ -d "$INSTALL_DIR/curl" ]; then
    echo "> Curl already installed."
else
    confirm_and_prepare "Build curl $CURL_VER?" "$CURL_LIBS"
    cd "$SRC_DIR"
    [ ! -d curl ] && git clone --depth 1 --branch "$CURL_VER" https://github.com/curl/curl.git
    cd curl
    autoreconf -fi
    ./configure --with-openssl="$INSTALL_DIR/openssl" --prefix="$INSTALL_DIR/curl"
    make -j"$NPROC"
    make install
fi

cd "$BASE_DIR"

# ========== NETWORK & SUBSCRIBERS ==========
echo
echo "=== [7/10] Network Setup ==="
if ask_confirm "Setup network (firewall/nat)?"; then
    [ -x "./custom-setup_network.sh" ] && ./custom-setup_network.sh
fi

echo
echo "=== [8/10] Add Subscribers ==="
if ask_confirm "Add default subscribers to MongoDB?"; then
    [ -x "./custom-addsubscribers.sh" ] && ./custom-addsubscribers.sh
fi

cd "$BASE_DIR"

# ========== CONFIGURE gNB CONNECTION ADDRESS ==========
echo
echo "=== [9/10] gNB Connection Configuration ==="

mapfile -t files_found < <(grep -l "ADDRESS_PLACEHOLDER" ./configs/open5gs/*.yaml.in 2>/dev/null || true)
if [ "${#files_found[@]}" -eq 0 ]; then
    echo "> No configuration files with 'ADDRESS_PLACEHOLDER' found."
else
    if ask_confirm_always "Replace ADDRESS_PLACEHOLDER in Open5GS config templates now?"; then
        while true; do
            read -rp "> Enter gNB IP (or 'n' to skip): " gnb_addr

            if [[ "$gnb_addr" == "n" ]]; then
                echo "> Skipped."
                break
            fi

            if [[ -n "$gnb_addr" ]]; then
                for file in "${files_found[@]}"; do
                    sed -i "s|ADDRESS_PLACEHOLDER|$gnb_addr|g" "$file"
                done
                echo "> Config updated."
                break
            fi

            echo "[!] Empty input. Please enter an IP or 'n' to skip."
        done
    else
        echo "> Skipping gNB address configuration."
    fi
fi

# ========== OPEN5GS BUILD ==========
echo
echo "=== [10/10] Building Open5GS ==="

mapfile -t files_found < <(grep -l "ADDRESS_PLACEHOLDER" ./configs/open5gs/*.yaml.in 2>/dev/null || true)
if [ "${#files_found[@]}" -ne 0 ]; then
    echo "[!] Cannot build: ADDRESS_PLACEHOLDER still present in configuration files."
    echo "    Replace it first, then re-run the build step."
    exit 1
fi

if ! ask_confirm_always "Build Open5GS now?"; then
    echo "> Skipping Open5GS build."
    exit 0
fi

if [ -f ./custom-env.sh ]; then
    source ./custom-env.sh
fi

if [ ! -d build ]; then
    meson setup build --prefix="$PWD/install"
else
    meson setup build --prefix="$PWD/install" --reconfigure
fi

cd build
ninja -j"$NPROC"
ninja install
cd ..

echo
echo "( ˶ˆᗜˆ˵ ) Build process completed successfully!"
