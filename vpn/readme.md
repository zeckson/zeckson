# IPsec VPN Server

Docker compose file used to host on server with all necessary info

All necessary information is [here](https://github.com/hwdsl2/docker-ipsec-vpn-server)

## Usage:

### Get info and server status:
```sh
docker logs ipsec-vpn-server
```

### Get available configs:
```sh
docker exec ipsec-vpn-server ls -l /etc/ipsec.d
```

### Fetch config files:
```sh
docker cp ipsec-vpn-server:/etc/ipsec.d/<yourfile> ./
```
