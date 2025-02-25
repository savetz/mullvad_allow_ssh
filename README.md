# mullvad_allow_ssh
ssh into your remote linux server while running mullvad VPN

The problem: I had an ssh connection open to my remote linux server. I activated the mullvad VPN with `mullvad connect` — and, naturally, my ssh connection dropped.

The solution: this script, which builds `ip route` and `nft` rules to allow ssh traffic from a single specified "Home" IP address.

Usage: `./exclude_home_ip.sh HOME_IP>`
Example: `./exclude_home_ip.sh 45.46.112.140`

1. Finds your default gateway on eth0.
2. Adds a /32 route for your HOME_IP
3. Installs nftables rules to mark and route traffic to/from HOME_IP from Mullvad
4. Adds a route for your home IP outside the VPN
5. Installs the excludeTraffic rules

Run this before `mullvad connect`
Does not persist: run after reboot or if your HOME_IP changes.
