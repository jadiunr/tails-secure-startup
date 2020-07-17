# Secure startup script for Tails

ref. https://www.reddit.com/r/tailswiki/wiki/index/vpn/tor-over-vpn

- Set torrc automatically (include from exclude_nodes)
- Conncect to OpenVPN server automatically
  - Profile to use is randomly selected from ovpn_profiles
  - Firewall is also set automatically

## Supported version

```
4.8 - 20200629
ad86f5dcf6a90776976596ff41a8e72ad1b95d69
live-build: 3.0.5+really+is+2.0.12-0.tails5
live-boot: 1:20170112
live-config: 5.20190519
```

## Getting started

```
# Clone repo in your persistent directory
git clone https://github.com/jadiunr/tails-secure-startup.git /home/amnesia/Persistent/
cd /home/amnesia/Persistent/tails-secure-startup

# Insert your OVPN Profile in ovpn_profiles
cp /path/to/some_profile.ovpn ./ovpn_profiles/

# Rename (MUST) and edit exclude_nodes (optional)
cp exclude_nodes.sample exclude_nodes
vim exclude_nodes

# Execute startup.sh (MUST BE RUN AS ROOT)
./startup.sh
```
