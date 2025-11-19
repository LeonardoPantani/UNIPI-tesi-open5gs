#!/bin/bash


# force execute as sudo
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# remove ogstun if already exists
if ip link show ogstun > /dev/null 2>&1; then
    ip link set ogstun down
    ip tuntap del name ogstun mode tun
fi

# remove rules if they already exist
iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null
ip6tables -t nat -D POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE 2>/dev/null

# create ogstun
ip tuntap add name ogstun mode tun
ip addr add 10.45.0.1/16 dev ogstun
ip addr add 2001:db8:cafe::1/48 dev ogstun
ip link set ogstun up

# show interfaces
echo "----------------------------------"
ifconfig -a

# enable port forw
echo "----------------------------------"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# nat setting
iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE

# print debug
echo "----------------------------------"
echo "[INFO] IPv4 NAT rules:"
iptables -t nat -L POSTROUTING -n -v | grep 10.45.0.0/16

echo "[INFO] IPv6 NAT rules:"
ip6tables -t nat -L POSTROUTING -n -v | grep 2001:db8:cafe::

echo "----------------------------------"
ufw status

# --- add alias to os file
HOSTS_FILE="/etc/hosts"

add_host_entry() {
    local ip="$1"
    local alias="$2"

    if ! grep -qE "^$ip[[:space:]]+$alias(\s|$)" "$HOSTS_FILE"; then
        echo "$ip $alias" >> "$HOSTS_FILE"
        echo "[INFO] Aggiunto alias $alias per $ip in $HOSTS_FILE"
    fi
}

# alias for nf
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
