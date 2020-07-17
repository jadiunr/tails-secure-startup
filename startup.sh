#!/bin/bash
##########################################################################
# Secure startup script for Tails
#
# Benefits
#   - Set torrc automatically (include from exclude_nodes)
#   - Conncect to OpenVPN server automatically
#     - Profile to use is randomly selected from ovpn_profiles
#     - Firewall settings are also set automatically
#
# Requirements:
#   - must be run as root
#   - openvpn config file named "tov.ovpn" in /home/amnesia/Persistent/secure_startup/ovpn_profiles/*.ovpn
#   - openvpn must be configured to use an IP as remote host (vs. host name)
#   - openvpn must be configured to use tun (vs. tap)
#   - IPv4 in LAN, this script disables IPv6 (remove this, if you need IPv6)
##########################################################################

set -eu

# check necessary rights
if [ ! `id -u` = 0 ] ; then
  echo "error: This script needs to be run using 'sudo SCRIPT' or in 'root terminal'" >&2
  echo "exiting now" >&2
  exit 1
fi


# set working directory
unset workdir
workdir=/home/amnesia/Persistent/tails-secure-startup


# torrc setting
perl -p -i -e "s/.*(StrictNodes|ExcludeNodes).*\n//g" /etc/tor/torrc
cat ${workdir}/exclude_nodes >> /etc/tor/torrc


# shuffle and select one profile
unset ovpn_path
ovpn_path=`ls -1 ${workdir}/ovpn_profiles/*.ovpn | shuf | head -1`
echo Now using: `basename $ovpn_path`


# clean tov.ovpn from DOS line breaks if necessary
if `grep -r $'\r' $ovpn_path >/dev/null`
then
  unset tovcfgperm
  tovcfgperm=`stat -c%a $ovpn_path`
  tr -d $'\r' < $ovpn_path > /tmp/tmp.ovpn && mv /tmp/tmp.ovpn $ovpn_path
  chmod "$tovcfgperm" $ovpn_path
  unset tovcfgperm
fi


# disable IPv6 - IPv6 is exploited to circumvent default IPv4-routes to VPN server to reveal users real IP(v6) address
grep "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf || echo net.ipv6.conf.all.disable_ipv6 = 1 >> /etc/sysctl.conf
sysctl -p


# populate vars
unset vpnserver_ip
unset vpnserver_port
unset vpnserver_proto

vpnserver_ip=`grep "^remote " $ovpn_path | perl -walne 'print $F[1]'`

if [[ -z "$vpnserver_ip" ]]
then
  echo "error: VPN server IP not found in `basename ${ovpn_path}`!" >&2
  exit 1
fi

if ! [[ "$vpnserver_ip" =~ ^[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+$ ]]
then
  echo "error: 'remote' appears not to be an IP address in `basename ${ovpn_path}`" >&2
  exit 1
fi

vpnserver_port=`grep "^remote " $ovpn_path | perl -walne 'print $F[2]'`

if [[ -z "$vpnserver_port" ]]
then
  vpnserver_port=`grep "^port " $ovpn_path | perl -walne 'print $F[1]'`
fi

if [[ -z "$vpnserver_port" ]]
then
  echo "error: VPN server port not found in `basename ${ovpn_path}`!" >&2
  exit 1
fi

if ! [[ "$vpnserver_port" =~ ^[0-9]+$ ]]
then
  echo "error: 'port' appears not to be an integer (number)e in `basename ${ovpn_path}`" >&2
  exit 1
fi

vpnserver_proto=`grep "^remote " $ovpn_path | perl -walne 'print $F[3]'`

if [[ -z "$vpnserver_proto" ]]
then
  vpnserver_proto=`grep "^proto " $ovpn_path | perl -walne 'print $F[1]'`
fi

if [[ -z "$vpnserver_proto" ]]
then
  echo "info: VPN server protocol not found in `basename ${ovpn_path}`, using UDP" >&2
  vpnserver_proto=udp
fi

# install openvpn
if [ ! -f /usr/sbin/openvpn ]
then
  apt-cache search openvpn 2>/dev/null | grep "openvpn - virtual private network daemon" || apt-get update
  apt-get install -y openvpn
fi

# configure ferm.conf to allow access to vpnserver_ip:vpnserver_port using vpnserver_proto for user root
sed '/# White-list access to Openvpnserver:port for user root/,/\}/d' /etc/ferm/ferm.conf
awk ' \
  /White-list access to local resources/ { \
    print "            # White-list access to Openvpnserver:port for user root" RS \
          "            daddr '$vpnserver_ip' proto '$vpnserver_proto' dport '$vpnserver_port' {" RS \
          "                mod owner uid-owner root ACCEPT;" RS \
          "            }" RS RS $0;next \
  }1
' /etc/ferm/ferm.conf > /tmp/ferm.conf && mv /tmp/ferm.conf /etc/ferm

# restrict debian-tor from "everything" to "everything using interface tun0"
# if [[ ! $(cat /etc/ferm/ferm.conf | grep "# But only when using tun0.") ]]
# then
#   awk ' \
#     /mod owner uid-owner debian-tor ACCEPT;/{ \
#       print "            # But only when using tun0." RS \
#             "            outerface tun0 mod owner uid-owner debian-tor ACCEPT;";next \
#     }1
#   ' /etc/ferm/ferm.conf >/tmp/ferm.conf && mv /tmp/ferm.conf /etc/ferm
# fi
# delete ferm cache
rm -f /var/cache/ferm/*
# reload ferm
/etc/init.d/ferm reload

# start openvpn in foreground (so it's easier to kill or for interactive login)
# openvpn --script-security 2 --up /usr/local/sbin/restart-tor --config $ovpn_path
openvpn --config $ovpn_path
# start openvpn in background (bc you hate that additional window ;))
#openvpn $ovpn_path --script-security 2 --up /usr/local/sbin/restart-tor --config $ovpn_path &
