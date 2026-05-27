#!/bin/bash

# show-net-status.sh - Show current networking and routing in a human-readable way.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Network Status Summary ===${NC}"

# 0. Primary Traffic Path
echo -e "\n${YELLOW}[ Primary Traffic Path ]${NC}"
PRIMARY_GW=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
PRIMARY_IF=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')

# Fallback: if gateway is not explicitly listed, check if it's a point-to-point interface (VPN)
if [ -z "$PRIMARY_GW" ] && [ -n "$PRIMARY_IF" ]; then
    PRIMARY_GW="Point-to-Point (link)"
fi

if [ -n "$PRIMARY_IF" ]; then
    TYPE="Direct (Physical)"
    [[ "$PRIMARY_IF" == utun* ]] || [[ "$PRIMARY_IF" == ppp* ]] && TYPE="VPN (Proxied)"
    echo -e "  Your default traffic goes via ${GREEN}$PRIMARY_IF${NC} to ${GREEN}$PRIMARY_GW${NC} [${BLUE}$TYPE${NC}]"
else
    echo -e "  ${RED}No primary default gateway found!${NC}"
fi

# 1. Active Interfaces
echo -e "\n${YELLOW}[ Active Interfaces ]${NC}"
ifconfig -u | grep -E "^[a-z0-9]+: " | cut -d: -f1 | while read -r iface; do
    IP=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
    if [ -n "$IP" ]; then
        DESC=""
        if [[ "$iface" == utun* ]] || [[ "$iface" == ppp* ]]; then
            DESC=" (VPN/Tunnel)"
        elif [[ "$iface" == en0 ]]; then
            DESC=" (Wi-Fi/Ethernet)"
        elif [[ "$iface" == lo0 ]]; then
            DESC=" (Loopback)"
        fi
        echo -e "  ${GREEN}$iface${NC}: $IP$DESC"
    fi
done

# 2. Default Gateways
echo -e "\n${YELLOW}[ Default Gateways ]${NC}"
netstat -rn -f inet | grep default | while read -r line; do
    DEST=$(echo "$line" | awk '{print $1}')
    GW=$(echo "$line" | awk '{print $2}')
    IF=$(echo "$line" | awk '{print $4}')

    TYPE="Direct"
    [[ "$IF" == utun* ]] || [[ "$IF" == ppp* ]] && TYPE="VPN"

    IS_PRIMARY=""
    # Check for primary matching both interface AND (gateway OR point-to-point link)
    if [ "$IF" == "$PRIMARY_IF" ]; then
        if [ "$GW" == "$PRIMARY_GW" ] || [[ "$GW" == link* && "$PRIMARY_GW" == "Point-to-Point (link)" ]]; then
             IS_PRIMARY=" ${YELLOW}(Primary)${NC}"
        fi
    fi

    echo -e "  Destination: $DEST, Gateway: $GW, Interface: ${GREEN}$IF${NC} [${BLUE}$TYPE${NC}]$IS_PRIMARY"
done

# 3. Custom Routes
echo -e "\n${YELLOW}[ Custom Routes ]${NC}"

# Find recent routes from netstat
ROUTES_DATA=$(netstat -rn -f inet | grep -E "utun|ppp" | grep -v "default")
TOTAL_ROUTES=$(echo "$ROUTES_DATA" | grep -c "^" || echo 0)

echo -e "  ${BLUE}Active non-default routes (VPN/Custom traffic):${NC}"
echo "$ROUTES_DATA" | head -n 20 | while read -r line; do
    DEST=$(echo "$line" | awk '{print $1}')
    GW=$(echo "$line" | awk '{print $2}')
    IF=$(echo "$line" | awk '{print $4}')

    # Try to resolve IP if it's not already a hostname or a broad subnet
    HOSTNAME=""
    if [[ $DEST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        HOSTNAME=$(host "$DEST" 2>/dev/null | grep "domain name pointer" | awk '{print $NF}' | sed 's/\.$//')

        # If no reverse DNS, try common identifiers
        if [ -z "$HOSTNAME" ]; then
            if [[ $DEST == 17.* ]]; then HOSTNAME="Apple Service"; fi
            if [[ $DEST == 198.18.* ]]; then HOSTNAME="Internal VPN/Benchmark Range"; fi
        fi
        [ -n "$HOSTNAME" ] && HOSTNAME=" ($HOSTNAME)"
    fi

    echo -e "    $DEST$HOSTNAME via $GW ($IF)"
done

if [ "$TOTAL_ROUTES" -gt 20 ]; then
    echo -e "    ${RED}... and $((TOTAL_ROUTES - 20)) more (Total: $TOTAL_ROUTES)${NC}"
fi

# 4. DNS Configuration
echo -e "\n${YELLOW}[ DNS Configuration ]${NC}"
scutil --dns | grep 'nameserver\[[0-9]\]' | sort -u | awk '{print "  " $0}'

# 5. Packet Filter (PF) - brief status
echo -e "\n${YELLOW}[ PF (Packet Filter) Status ]${NC}"
PF_INFO=$(sudo pfctl -s info 2>/dev/null)
PF_STATUS=$(echo "$PF_INFO" | grep "Status:" || echo "Could not check (sudo required)")
PF_RULES_COUNT=$(sudo pfctl -sr 2>/dev/null | grep -c "^" || echo 0)
PF_NAT_COUNT=$(sudo pfctl -sn 2>/dev/null | grep -c "^" || echo 0)

echo "  $PF_STATUS"
echo -e "  Rules: ${BLUE}$PF_RULES_COUNT${NC}, NAT/Redirections: ${BLUE}$PF_NAT_COUNT${NC}"

echo -e "\n${BLUE}==============================${NC}"
