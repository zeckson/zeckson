### Scan all network with nmap

```sh
nmap -A -T4 192.168.1.*
```

### Listen for all arp packets in the network
Best for link-2-link debugging https://en.wikipedia.org/wiki/Link-local_address

```sh 
tcpdump arp
```

### Look for an open ports and connection
Best for finding out binded ports by processes

```shell script
netstat -peanut
```

### Port-forward with SSH

```shell
ssh -NL $local_port:$hostname:$hostport $ssh_server -v
```
