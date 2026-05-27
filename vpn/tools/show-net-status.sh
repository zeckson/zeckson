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
    PRIMARY_GW="Direct Connection"
fi

# Human-readable translation for link#X
[[ "$PRIMARY_GW" == link#* ]] && PRIMARY_GW="Direct Connection"

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

    # Human-readable translation for link#X
    DISPLAY_GW="$GW"
    [[ "$GW" == link#* ]] && DISPLAY_GW="Direct Connection"

    IS_PRIMARY=""
    # Check for primary matching both interface AND (gateway OR direct connection)
    if [ "$IF" == "$PRIMARY_IF" ]; then
        if [ "$GW" == "$PRIMARY_GW" ] || [[ "$GW" == link* && "$PRIMARY_GW" == "Direct Connection" ]]; then
             IS_PRIMARY=" ${YELLOW}(Primary)${NC}"
        fi
    fi

    echo -e "  Destination: $DEST, Gateway: $DISPLAY_GW, Interface: ${GREEN}$IF${NC} [${BLUE}$TYPE${NC}]$IS_PRIMARY"
done

# 3. Custom Routes
echo -e "\n${YELLOW}[ Custom Routes & Active Traffic ]${NC}"

# Find recent routes from netstat
ROUTES_DATA=$(netstat -rn -f inet | grep -E "utun|ppp" | grep -v "default")
TOTAL_ROUTES=$(echo "$ROUTES_DATA" | grep -c "^" || echo 0)
STATIC_ROUTES=$(echo "$ROUTES_DATA" | grep "S" | grep -c "^" || echo 0)

echo -e "  There are ${BLUE}$TOTAL_ROUTES${NC} specific rules active on your VPN/Tunnel."
echo -e "  - ${GREEN}$STATIC_ROUTES${NC} are permanent (MANUAL) settings."
echo -e "  - $((TOTAL_ROUTES - STATIC_ROUTES)) are temporary (AUTO) connections (Hidden for clarity).\n"

# Process routes
declare -a MANUAL_ENTRIES

while read -r line; do
    DEST=$(echo "$line" | awk '{print $1}')
    FLAGS=$(echo "$line" | awk '{print $3}')
    IF=$(echo "$line" | awk '{print $4}')

    if [[ "$FLAGS" == *S* ]]; then
        # Resolve Name for Manual entries only
        LABEL=""
        if [[ "$DEST" == "255.255.255.255/32" ]] || [[ "$DEST" == "255.255.255.255" ]]; then
            LABEL="Local Broadcast (Sends data to ALL devices on the network)"
        elif [[ "$DEST" == "224.0.0/4" ]] || [[ "$DEST" == "224.0.0.0/4" ]]; then
            LABEL="Multicast (Used for device discovery, like finding printers or speakers)"
        elif [[ "$DEST" == "127.0.0.1/32" ]] || [[ "$DEST" == "127.0.0.1" ]]; then
            LABEL="Loopback (Internal traffic within your own computer)"
        elif [[ $DEST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            CLEAN_DEST=$(echo "$DEST" | cut -d'/' -f1)
            HOSTNAME=$(host "$CLEAN_DEST" 2>/dev/null | grep "domain name pointer" | awk '{print $NF}' | sed 's/\.$//')
            LABEL="${HOSTNAME:-Manual Setting}"
        else
            LABEL="$DEST"
        fi
        MANUAL_ENTRIES+=("  ${GREEN}[MANUAL]${NC} $DEST -> $LABEL")
    fi
done <<< "$ROUTES_DATA"

# 1. Print Manual Entries (Expanded)
if [ ${#MANUAL_ENTRIES[@]} -eq 0 ]; then
    echo -e "  ${BLUE}(No manual static routes found)${NC}"
else
    for entry in "${MANUAL_ENTRIES[@]}"; do
        echo -e "$entry"
    done
fi

# 2. Summary of Auto Entries (Hiding list as requested)
if [ "$TOTAL_ROUTES" -gt "$STATIC_ROUTES" ]; then
    echo -e "\n  ${BLUE}i${NC} Note: $((TOTAL_ROUTES - STATIC_ROUTES)) temporary AUTO connections are active but hidden."
fi

# 4. DNS Configuration
echo -e "\n${YELLOW}[ DNS Configuration ]${NC}"
scutil --dns | grep 'nameserver\[[0-9]\]' | sort -u | awk '{print "  " $0}'

echo -e "\n${BLUE}==============================${NC}"
