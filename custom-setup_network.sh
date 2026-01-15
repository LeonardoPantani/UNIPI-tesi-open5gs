#!/bin/bash
set -u

# force execute as sudo
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# check if command exists
have() { command -v "$1" >/dev/null 2>&1; }

warn_missing() {
  echo "[WARN] '$1' not found, skipping."
}

# --- remove ogstun if already exists
if have ip && ip link show ogstun > /dev/null 2>&1; then
    ip link set ogstun down || true
    ip tuntap del name ogstun mode tun || true
fi

# --- create ogstun
if ! have ip; then
  echo "[ERROR] 'ip' command not found (iproute2 is missing). Unable to handle ogstun."
  exit 1
fi

if ! ip tuntap add name ogstun mode tun 2>/dev/null; then
  echo "[ERROR] Unable to create a TUN interface (ogstun)."
  echo "        If you are on WSL, TUN/TAP is not supported."
  exit 1
fi

ip addr add 10.45.0.1/16 dev ogstun || true
ip addr add 2001:db8:cafe::1/48 dev ogstun || true
ip link set ogstun up || true

# --- show interfaces (NO ifconfig)
echo "----------------------------------"
ip -br a || ip a || true

# --- enable forwarding
echo "----------------------------------"
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
echo "[INFO] Forwarding enabled."

# --- NAT setting
# remove rules if they already exist (best-effort)
if have iptables; then
iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || true
else
warn_missing iptables
fi

if have ip6tables; then
ip6tables -t nat -D POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE 2>/dev/null || true
else
warn_missing ip6tables
fi

# add NAT rules (best-effort)
if have iptables; then
iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE || true
fi
if have ip6tables; then
ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE || true
fi

# print debug
echo "----------------------------------"
echo "[INFO] IPv4 NAT rules:"
if have iptables; then
iptables -t nat -L POSTROUTING -n -v 2>/dev/null | grep 10.45.0.0/16 || true
fi

echo "[INFO] IPv6 NAT rules:"
if have ip6tables; then
ip6tables -t nat -L POSTROUTING -n -v 2>/dev/null | grep "2001:db8:cafe::" || true
fi

echo "----------------------------------"
if have ufw; then
ufw status || true
else
warn_missing ufw
fi

# --- add alias to hosts file
HOSTS_FILE="/etc/hosts"

add_host_entry() {
    local ip="$1"
    local alias="$2"

    if ! grep -qE "^$ip[[:space:]]+$alias(\s|$)" "$HOSTS_FILE"; then
        echo "$ip $alias" >> "$HOSTS_FILE"
        echo "[INFO] Added $alias alias for $ip in $HOSTS_FILE"
    fi
}

add_host_entry 127.0.0.5 amf.localdomain
add_host_entry 127.0.0.11 ausf.localdomain
add_host_entry 127.0.0.15 bsf.localdomain
add_host_entry 127.0.0.10 nrf.localdomain
add_host_entry 127.0.0.14 nssf.localdomain
add_host_entry 127.0.0.13 pcf.localdomain
add_host_entry 127.0.0.200 scp.localdomain
add_host_entry 127.0.0.4 smf.localdomain
add_host_entry 127.0.0.12 udm.localdomain
add_host_entry 127.0.0.20 udr.localdomain
add_host_entry 127.0.0.7 upf.localdomain

echo "----------------------------------"
cat /etc/hosts
