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

# Default Policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow all traffic from internal network (10.229.1.0/24)
iptables -A INPUT -s 10.229.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.229.1.0/24 -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22) for all hosts
iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

# Allow ICMP (ping) from any host
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -j ACCEPT

# Allow FTP/TFTP to Windows, but block 10.229.10.0/24
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p tcp --dport 20:21 -m limit --limit 20/min -j LOG --log-prefix "DROP: FTP to Windows - " --log-level 7
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p tcp --dport 20:21 -j DROP

iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p udp --dport 69 -m limit --limit 20/min -j LOG --log-prefix "DROP: TFTP to Windows - " --log-level 7
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p udp --dport 69 -j DROP

iptables -A FORWARD -d 10.229.1.2 -p tcp --dport 20:21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -d 10.229.1.2 -p udp --dport 69 -j ACCEPT

# Allow FTP/TFTP to Linux, but block 10.229.11.0/24
iptables -A INPUT -s 10.229.11.0/24 -p tcp --dport 20:21 -m limit --limit 20/min -j LOG --log-prefix "DROP: FTP to Linux - " --log-level 7
iptables -A INPUT -s 10.229.11.0/24 -p tcp --dport 20:21 -j DROP

iptables -A INPUT -s 10.229.11.0/24 -p udp --dport 69 -m limit --limit 20/min -j LOG --log-prefix "DROP: TFTP to Linux - " --log-level 7
iptables -A INPUT -s 10.229.11.0/24 -p udp --dport 69 -j DROP

iptables -A INPUT -d 10.229.1.1 -p tcp --dport 20:21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -d 10.229.1.1 -p udp --dport 69 -j ACCEPT

# Allow Passive FTP Mode
iptables -A INPUT -p tcp --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 1024:65535 -m state --state NEW,ESTABLISHED -j ACCEPT

# Block Windows from accessing 10.229.10.0/24 (outbound)
iptables -A OUTPUT -s 10.229.1.2 -d 10.229.10.0/24 -m limit --limit 20/min -j LOG --log-prefix "DROP: Windows Outbound - " --log-level 7
iptables -A OUTPUT -s 10.229.1.2 -d 10.229.10.0/24 -j DROP

# Log all other dropped traffic
iptables -A INPUT -m limit --limit 20/min -j LOG --log-prefix "DROP: INPUT - " --log-level 7
iptables -A FORWARD -m limit --limit 20/min -j LOG --log-prefix "DROP: FORWARD - " --log-level 7
iptables -A OUTPUT -m limit --limit 20/min -j LOG --log-prefix "DROP: OUTPUT - " --log-level 7

echo "Firewall rules applied successfully!"
