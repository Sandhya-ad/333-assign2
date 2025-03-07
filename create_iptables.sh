#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

echo "Setting up firewall rules..."
sysctl -w net.ipv4.ip_forward=1

# Flush existing rules
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t mangle -F


iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -N LOG_AND_DROP
iptables -A LOG_AND_DROP -j LOG --log-prefix "Dropped: "
iptables -A LOG_AND_DROP -j DROP

# Allow all traffic from internal network (10.229.1.0/24)
iptables -A INPUT -s 10.229.1.0/24 -d 10.229.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.229.1.0/24 -d 10.229.1.0/24 -j ACCEPT

# Allow established connections
# iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22) for all hosts
iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

# Allow ICMP (ping) from any host
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT

# Allow FTP/TFTP to Windows, but block 10.229.10.0/24
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p tcp --dport 20:21 -j LOG_AND_DROP

iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p udp --dport 69 -j LOG_AND_DROP

iptables -A FORWARD -d 10.229.1.2 -p tcp --dport 20:21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -d 10.229.1.2 -p udp --dport 69 -j ACCEPT

# Allow FTP/TFTP to Linux, but block 10.229.11.0/24
iptables -A INPUT -s 10.229.11.0/24 -p tcp --dport 20:21 -j LOG_AND_DROP

iptables -A INPUT -s 10.229.11.0/24 -p udp --dport 69 -j LOG_AND_DROP

iptables -A INPUT -d 10.229.1.1 -p tcp --dport 20:21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -d 10.229.1.1 -p udp --dport 69 -j ACCEPT

# Allow Passive FTP Mode
iptables -A INPUT -p tcp --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 1024:65535 -m state --state NEW,ESTABLISHED -j ACCEPT

# Block Windows from accessing 10.229.10.0/24 (outbound)
iptables -A FORWARD -s 10.229.1.2 -d 10.229.10.0/24 -j LOG_AND_DROP

# Drop by default
iptables -A INPUT -d 10.229.1.0/24 -j LOG_AND_DROP
iptables -A FORWARD -d 10.229.1.0/24 -j LOG_AND_DROP

echo "Firewall rules applied successfully!"