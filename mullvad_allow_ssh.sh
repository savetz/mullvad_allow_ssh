#!/usr/bin/env bash
#
# mullvad_allow_ssh.sh
#
# Usage: ./exclude_home_ip.sh <HOME_IP>
# Example: ./exclude_home_ip.sh 45.46.112.140
#
# 1. Finds your default gateway on eth0.
# 2. Adds a /32 route for your <HOME_IP> 
# 3. Installs nftables rules to mark and route traffic to/from <HOME_IP> from Mullvad
# 4. Adds a route for your home IP outside the VPN
# 5. Installs the excludeTraffic rules
# 
# Use before mullvad connect
# Does not persist: run after reboot or if <HOME_IP> changes.

###############################################################################
# Parse Input
###############################################################################
HOME_IP="$1"

if [ -z "$HOME_IP" ]; then
  echo "Usage: $0 <HOME_IP>"
  exit 1
fi

###############################################################################
# 1. Find Default Gateway for eth0
###############################################################################
GW=$(ip route show | awk '/^default via/ && /eth0/ {print $3}')
if [ -z "$GW" ]; then
  echo "Error: Could not find default gateway for eth0."
  exit 1
fi

###############################################################################
# 2. Add /32 Route for HOME_IP
###############################################################################
echo "Adding route for $HOME_IP/32 via $GW dev eth0 ..."
sudo ip route add "$HOME_IP/32" via "$GW" dev eth0
echo "Route added successfully!"

###############################################################################
# 3. Create and Load nftables excludeTraffic Rules
###############################################################################
cat <<'NFT' | sed "s|__HOME_IP_PLACEHOLDER__|$HOME_IP|g" > /tmp/excludeTraffic.rules
################################################################################
# nftables configuration to exclude SSH traffic (to/from HOME_IP) from Mullvad.
#
# For OUTGOING connections to your home IP:
################################################################################
table inet excludeTraffic {

  chain excludeOutgoing {
    type route hook output priority 0; policy accept;
    ip daddr __HOME_IP_PLACEHOLDER__ ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
  }

################################################################################
# For INCOMING SSH connections from your home IP:
################################################################################
  chain allowIncoming {
    type filter hook input priority -100; policy accept;
    # Mark NEW SSH connections so replies also bypass the VPN
    ip saddr __HOME_IP_PLACEHOLDER__ tcp dport 22 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
    # Keep established SSH sessions going
    ct state established,related accept
  }

################################################################################
# For OUTGOING replies to your home IP (server → client):
################################################################################
  chain allowOutgoing {
    type route hook output priority -100; policy accept;
    tcp sport 22 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
  }
}
NFT

echo "Loading nftables rules for home IP: $HOME_IP..."
sudo nft -f /tmp/excludeTraffic.rules
echo "Done loading rules"
echo "It's now safe to do mullvad connect"
