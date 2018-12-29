#!/bin/sh

VPN_VERBOSE=0
_SHUTDOWN=0

if [ "${VERBOSE}" == "true" ]; then
  VPN_VERBOSE=1
  set -x
fi

if [ -z "${VPN_SERVER_IP}" ]; then
  echo Need environment variable VPN_SERVER_IP for remote vpn server id 1>&2
  exit 1
fi

if [ -z "${VPN_IPSEC_PSK}" ]; then
  echo Need environment variable VPN_IPSEC_PSK for remote vpn server ipsec pre shared key 1>&2
  exit 1
fi

if [ -z "${VPN_USER}" ]; then
  echo Need environment variable VPN_USER for remote vpn username 1>&2
  exit 1
fi

if [ -z "${VPN_PASSWORD}" ]; then
  echo Need environment variable VPN_PASSWORD for remote vpn password 1>&2
  exit 1
fi

DEFAULT_GW=$(ip route show 0.0.0.0/0 | awk '/default/ {print $3}')

LOCAL_PORT=$(shuf -i 2048-65000 -n 1)

SED_TEMPLATE="s/VPN_SERVER_IP/${VPN_SERVER_IP}/;s/VPN_IPSEC_PSK/${VPN_IPSEC_PSK}/;s/VPN_USER/${VPN_USER}/;s/VPN_PASSWORD/${VPN_PASSWORD}/;s/DEFAULT_GW/${DEFAULT_GW}/;s/LOCAL_PORT/${LOCAL_PORT}/"

TEMPLATE_DIR=/opt/src

sed "$SED_TEMPLATE" $TEMPLATE_DIR/ipsec.conf > /etc/ipsec.conf
sed "$SED_TEMPLATE" $TEMPLATE_DIR/ipsec.secrets > /etc/ipsec.secrets
sed "$SED_TEMPLATE" $TEMPLATE_DIR/xl2tpd.conf > /etc/xl2tpd/xl2tpd.conf
sed "$SED_TEMPLATE" $TEMPLATE_DIR/options.l2tpd.client > /etc/ppp/options.l2tpd.client

function tail_wait() {
  file=$1
  msg=$2
  if [ ${VPN_VERBOSE} == 0 ]; then
    exec 3>&2
    exec 2> /dev/null
  fi
  touch $file
  tail -f -n +0 $file 2>/dev/null | while read line; do
    [[ ${_SHUTDOWN} == 1 ]] && exit 2
    [[ ${VPN_VERBOSE} == 1 ]] && echo "$line"
    case "$line" in
      *"$msg"*)
        pkill -P $$ tail >& /dev/null
        break
      ;;
      *)
      ;;
    esac
  done 
  if [ ${VPN_VERBOSE} == 0 ]; then
    exec 2>&3
    exec 3>&-
  fi
}

chmod 600 /etc/ipsec.secrets
#rm -rf /etc/strongswan/ipsec.conf
#ln -s /etc/ipsec.conf /etc/strongswan/ipsec.conf
#rm -rf /etc/strongswan/ipsec.secrets
#ln -s /etc/ipsec.secrets /etc/strongswan/ipsec.secrets
chmod 600 /etc/ppp/options.l2tpd.client

rm -rf /var/run/xl2tpd
mkdir -p /var/run/xl2tpd
touch /var/run/xl2tpd/l2tp-control

ipsec start
sleep 1
if [ ${VPN_VERBOSE} == 1 ]; then
  ipsec up myvpn | tee /var/log/vpn.log
else
  ipsec up myvpn >& /var/log/vpn.log
fi
tail_wait /var/log/vpn.log "established successfully"
echo ipsec is started

[[ ${VPN_VERBOSE} == 1 ]] && ipsec statusall


INSTALLED=0

function install() {
  [[ ${_SHUTDOWN} == 1 ]] && exit 2
  echo "c myvpn" > /var/run/xl2tpd/l2tp-control
  echo VPN client is connecting...
  tail_wait /var/log/xl2tpd.log "start_pppd"
  while ! ip a show ppp0 | grep UP >& /dev/null; do
    [[ ${_SHUTDOWN} == 1 ]] && exit 2
    echo waiting for ppp0 ...
    sleep 1
  done
  route add ${VPN_SERVER_IP} gw ${DEFAULT_GW}
  route add default dev ppp0
  echo Default route is changed from ${DEFAULT_GW} to ppp0

  INSTALLED=1
}

function uninstall() {
  _SHUTDOWN=1
  trap - 0 2 3 15
  if [ "${INSTALLED}" == 0 ]; then
    return
  fi

  route del default dev ppp0
  route del ${VPN_SERVER_IP} gw ${DEFAULT_GW}
  echo Default route is changed back from ppp0 to ${DEFAULT_GW}
  echo "d myvpn" > /var/run/xl2tpd/l2tp-control
  if [ ${VPN_VERBOSE} == 1 ]; then
    ipsec down myvpn
  else
    ipsec down myvpn >& /dev/null
  fi

  INSTALLED=0
}

trap 'uninstall; [[ -e /proc/${PID} ]] && kill -TERM ${PID}' 0 2 3 15

/usr/sbin/xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D >& /var/log/xl2tpd.log &

PID=$!

tail_wait /var/log/xl2tpd.log "Listening on IP address"

install

wait $PID

uninstall

wait $PID
