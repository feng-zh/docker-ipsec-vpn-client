# Docker image for IPsec VPN Client

ipsec-vpn-client is a VPN client that can help easy setup IPSec VPN client in Docker and *used* by the host by managing default IP route.

This image is inspired from [configure Linux VPN client using the command line](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/docs/clients.md#configure-linux-vpn-clients-using-the-command-line) instructions and is tested with [IPsec VPN Server on Docker](http://github.com/hwdsl2/docker-ipsec-vpn-server).

By using Docker `privileged` and `host` network, the container will update the default route in Linux once start successfully. The router setting will be restored once stop Docker.

## How to use this Docker image

### Environment variables

This Docker image uses the following variables, and can be easily managed via `env` file:
```
VPN_SERVER_IP=your_vpn_server_public_ip
VPN_PSEC_PSK=your_ipsec_pre_shared_key
VPN_USER=your_vpn_username
VPN_PASSWORD=your_vpn_password)
VERBOSE=true|false
```

### Start the IPSec VPN Client

Prepare env file `vpn.env` (recommended way) or use environment variables directly to create Docker container:

```
docker run --rm --name vpn-client --env-file=./vpn.env -d --privileged --net=host fengzhou/ipsec-vpn-client
```

To see more debug information, please set `VERBOSE=true` in enviornment variable in env file.

### Stop the IPSec VPN Client

Use `docker stop` command can immediately stop VPN client:

```
docker stop vpn-client
```

The default VPN routing rules will be removed once stopped, and the temporary Docker container will be removed as well.

### Troubleshooting

Use the following command to check connection logs during container is running:
```
docker logs vpn-client
```

Use the following command to check if `ppp0` network interface is created or not:
```
ip a show ppp0
```

If network route is not fully restored back, use the following command to remove any broken route rule:

```
route del default dev ppp0
```

### Limitations
* The docker-ipsec-vpn-server and this vpn client cannot be used together on the same host due to 500/udp, 4500/udp ports conflicts
* All existing default route will be redirected to VPN server and need manual route rule to split tunnel.
