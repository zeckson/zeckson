### Scan all network with nmap

```sh
nmap -A -T4 192.168.1.*
```

### Listen for all arp packets in the network
Best for link-2-link debugging https://en.wikipedia.org/wiki/Link-local_address

```sh 
sudo tcpdump arp
```
