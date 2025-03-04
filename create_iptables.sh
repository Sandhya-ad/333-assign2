#!/bin/bash

# Ensure the script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

echo "Setting up firewall rules..."

# Flush existing rules to start fresh
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t mangle -F

# Set default policies to drop all inbound and forwarded traffic unless explicitly allowed
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT  # Outbound traffic is generally allowed except for specific restrictions

# Enable IP forwarding (needed for routing between networks)
sysctl -w net.ipv4.ip_forward=1

# Allow returning traffic for established connections and related traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

###############################################################################################################
#  Allow any host from any network to access the TFTP and FTP service of your Windows host
#  EXCEPT for hosts from the network 10.229.10.0/24 (which should be blocked)
###############################################################################################################

# Block FTP (port 21 for control, port 20 for data transfer) from 10.229.10.0/24
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p tcp --dport 20:21 -j DROP

# Allow FTP traffic to Our Windows from all other sources
iptables -A FORWARD -d 10.229.1.2 -p tcp --dport 20:21 -m state --state NEW,ESTABLISHED -j ACCEPT

# Passive FTP (which uses a dynamic port range for data transfer)
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p tcp --dport 1024:65535 -j DROP
iptables -A FORWARD -p tcp --dport 1024:65535 -m state --state NEW,ESTABLISHED -j ACCEPT

# Block TFTP (UDP port 69) from 10.229.10.0/24 but allow it from all other sources
iptables -A FORWARD -s 10.229.10.0/24 -d 10.229.1.2 -p udp --dport 69 -j DROP
iptables -A FORWARD -d 10.229.1.2 -p udp --dport 69 -j ACCEPT

###############################################################################################################
#  Allow any host from any network to access the TFTP and FTP service of your Linux host
#  EXCEPT for hosts from the network 10.229.11.0/24 (which should be blocked)
###############################################################################################################

# Block FTP access to Our Linux (port 21 for control, port 20 for data transfer) from 10.229.11.0/24
iptables -A INPUT -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --dport 21 -j DROP
iptables -A INPUT -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --dport 20 -j DROP

# Ensure FTP traffic is dropped for both incoming (server) and outgoing (client) packets
iptables -A INPUT -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --sport 21 -j DROP
iptables -A INPUT -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --sport 20 -j DROP

# Block passive FTP connections (dynamic ports) from 10.229.11.0/24
iptables -A FORWARD -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --dport 1024:65535 -j DROP
iptables -A FORWARD -s 10.229.11.0/24 -d 10.229.1.1 -p tcp --sport 1024:65535 -j DROP

# Allow FTP traffic to Our Linux from all other sources
iptables -A INPUT -d 10.229.1.1 -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -d 10.229.1.1 -p tcp --dport 20 -m state --state NEW,ESTABLISHED -j ACCEPT

# Block TFTP (UDP port 69) from 10.229.11.0/24 but allow it from all other sources
iptables -A INPUT -s 10.229.11.0/24 -d 10.229.1.1 -p udp --dport 69 -j DROP
iptables -A INPUT -d 10.229.1.1 -p udp --dport 69 -j ACCEPT

###############################################################################################################
#  Allow any host from any network to connect to the SSH service on any of your group’s hosts
#  as well as allow ICMP echo messages (pings) from any host from any network.
###############################################################################################################

# Allow SSH (port 22) connections to Our Linux from any network
iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow SSH (port 22) connections to be forwarded to Our Windows
iptables -A FORWARD -p tcp --dport 22 -d 10.229.1.2 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -p tcp --sport 22 -s 10.229.1.2 -m state --state ESTABLISHED -j ACCEPT

# Allow ICMP (ping) traffic to and from Our Linux
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# Allow ICMP (ping) traffic to be forwarded to Our Windows
iptables -A FORWARD -p icmp --icmp-type echo-request -d 10.229.1.2 -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -s 10.229.1.2 -j ACCEPT

###############################################################################################################
#  Outbound restriction: Block Our Windows from accessing any services on hosts in 10.229.10.0/24.
#  However, allow reverse connections from 10.229.10.0/24 to Our Windows.
###############################################################################################################
iptables -A OUTPUT -s 10.229.1.2 -d 10.229.10.0/24 -j DROP

###############################################################################################################
#  Logging violations for debugging
###############################################################################################################

iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-INPUT-Dropped: " --log-level 7
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "IPTables-FORWARD-Dropped: " --log-level 7
iptables -A OUTPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-OUTPUT-Dropped: " --log-level 7

echo "Firewall rules applied successfully!"
