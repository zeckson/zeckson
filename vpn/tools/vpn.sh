#!/bin/sh

BASE_DIR="$HOME/.vpn"
PROXY_ROUTES="$BASE_DIR/proxy.routes"
BYPASS_ROUTES="$BASE_DIR/bypass.routes"

mkdir -p "$BASE_DIR"

# --- Helper Functions ---

get_physical_gw() {
    # Detect the physical (non-VPN) gateway
    GW=$(netstat -rn -f inet | grep default | grep -vE "utun|ppp|lo|gif|stf" | awk '{print $2}' | head -n 1)
    if [ -z "$GW" ]; then
        # Fallback via scutil
        IF=$(printf "open\nget State:/Network/Global/IPv4\nd.show" | scutil | grep "PrimaryInterface" | awk '{print $3}')
        if [ -n "$IF" ]; then
            GW=$(printf "open\nget State:/Network/Interface/$IF/IPv4\nd.show" | scutil | grep "Router" | awk '{print $3}')
        fi
    fi
    echo "$GW"
}

detect_vpn_if() {
    # Look for active utun or ppp interfaces that have an IP address
    for iface in $(ifconfig -u | grep -E "^(utun|ppp)[0-9]" | cut -d: -f1); do
        if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
            DEST=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '$3 == "-->" {print $4}')
            echo "$iface $DEST"
            return
        fi
    done
}

is_vpn_active() {
    scutil --nc list | grep -q "Connected"
}

resolve_target() {
    TARGET="$1"
    # Extract domain if it's a URL
    CLEAN_TARGET=$(echo "$TARGET" | sed -E 's|^[a-z]+://||; s|/.*$||')

    if echo "$CLEAN_TARGET" | grep -qvE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        IP=$(dig +short "$CLEAN_TARGET" | tail -n1)
        if [ -z "$IP" ]; then
            echo "ERROR: Could not resolve $CLEAN_TARGET" >&2
            return 1
        fi
        echo "$IP $CLEAN_TARGET"
    else
        echo "$CLEAN_TARGET"
    fi
}

apply_routes_from_file() {
    FILE="$1"
    TARGET_GW="$2"
    USE_INTERFACE_FLAG="$3" # "-interface" or empty

    if [ -f "$FILE" ]; then
        echo "➕ Applying routes from $FILE via $TARGET_GW..."
        while IFS= read -r LINE || [ -n "$LINE" ]; do
            # Extract IP part (before #)
            IP=$(echo "$LINE" | awk '{print $1}')
            if [ -n "$IP" ]; then
                if [ -n "$USE_INTERFACE_FLAG" ]; then
                    sudo route -n add "$IP" -interface "$TARGET_GW" >/dev/null 2>&1
                else
                    sudo route -n add "$IP" "$TARGET_GW" >/dev/null 2>&1
                fi
            fi
        done < "$FILE"
    fi
}

clear_routes() {
    echo "🧹 Clearing custom routes..."
    # Clear both proxy and bypass routes
    for FILE in "$PROXY_ROUTES" "$BYPASS_ROUTES"; do
        if [ -f "$FILE" ]; then
            while IFS= read -r LINE || [ -n "$LINE" ]; do
                IP=$(echo "$LINE" | awk '{print $1}')
                [ -n "$IP" ] && sudo route -n delete "$IP" >/dev/null 2>&1
            done < "$FILE"
        fi
    done

    # Restore default gateway if it was shifted
    PHYS_GW=$(get_physical_gw)
    if [ -n "$PHYS_GW" ]; then
        sudo route change default "$PHYS_GW" >/dev/null 2>&1
    fi
}

# --- Main Commands ---

case "$1" in
    proxy)
        if ! is_vpn_active; then
            echo "❌ VPN is not active. Routing rules will not be applied."
            exit 1
        fi

        PHYS_GW=$(get_physical_gw)
        VPN_INFO=$(detect_vpn_if)
        VPN_IF=$(echo "$VPN_INFO" | awk '{print $1}')
        VPN_DEST=$(echo "$VPN_INFO" | awk '{print $2}')

        if [ -z "$VPN_IF" ]; then
            echo "❌ VPN interface not detected."
            exit 1
        fi

        echo "🚀 Mode: PROXY ALL (Bypass exceptions)"
        echo "✅ Physical Gateway: $PHYS_GW"
        echo "✅ VPN Interface: $VPN_IF"

        # 1. Set VPN as default gateway
        TARGET_ROUTE_GW="${VPN_DEST:-$VPN_IF}"
        FLAG=""
        [ -z "$VPN_DEST" ] && FLAG="-interface"

        if [ -n "$FLAG" ]; then
            sudo route change default -interface "$TARGET_ROUTE_GW"
        else
            sudo route change default "$TARGET_ROUTE_GW"
        fi

        # 2. Add bypass routes via Physical GW
        apply_routes_from_file "$BYPASS_ROUTES" "$PHYS_GW" ""

        echo "✅ Done."
        ;;

    bypass)
        if ! is_vpn_active; then
            echo "❌ VPN is not active. Routing rules will not be applied."
            exit 1
        fi

        PHYS_GW=$(get_physical_gw)
        VPN_INFO=$(detect_vpn_if)
        VPN_IF=$(echo "$VPN_INFO" | awk '{print $1}')
        VPN_DEST=$(echo "$VPN_INFO" | awk '{print $2}')

        if [ -z "$PHYS_GW" ]; then
            echo "❌ Physical gateway not detected."
            exit 1
        fi

        echo "🚀 Mode: BYPASS ALL (Proxy exceptions)"
        echo "✅ Physical Gateway: $PHYS_GW"

        # 1. Force default route to Physical GW
        sudo route change default "$PHYS_GW"
        # Remove VPN overrides if present (often added by OpenVPN/Tunnelblick)
        sudo route -n delete 0.0.0.0/1 >/dev/null 2>&1
        sudo route -n delete 128.0.0.0/1 >/dev/null 2>&1

        # 2. Add proxy routes via VPN
        if [ -n "$VPN_IF" ]; then
            TARGET_ROUTE_GW="${VPN_DEST:-$VPN_IF}"
            FLAG=""
            [ -z "$VPN_DEST" ] && FLAG="-interface"
            apply_routes_from_file "$PROXY_ROUTES" "$TARGET_ROUTE_GW" "$FLAG"
        else
             echo "⚠️ VPN interface not detected, skipping proxy exceptions."
        fi

        echo "✅ Done."
        ;;

    status)
        echo "📊 VPN Manager Status:"
        if is_vpn_active; then
            VPN_NAME=$(scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/' | head -n 1)
            VPN_INFO=$(detect_vpn_if)
            echo "  - VPN: Connected ($VPN_NAME)"
            echo "  - Interface: $(echo "$VPN_INFO" | awk '{print $1}')"
        else
            echo "  - VPN: Disconnected"
        fi

        PHYS_GW=$(get_physical_gw)
        CUR_GW=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
        CUR_IF=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')

        echo "  - Physical Gateway: $PHYS_GW"
        echo "  - Current Default: $CUR_GW ($CUR_IF)"

        # Check routes
        PROXY_COUNT=$(grep -c "^" "$PROXY_ROUTES" 2>/dev/null || echo 0)
        BYPASS_COUNT=$(grep -c "^" "$BYPASS_ROUTES" 2>/dev/null || echo 0)
        echo "  - Configured Proxy Routes: $PROXY_COUNT"
        echo "  - Configured Bypass Routes: $BYPASS_COUNT"

        # Test reachability for common services
        echo ""
        echo "  - Routing Check (yandex.ru - 77.88.55.242):"
        route -n get 77.88.55.242 | grep -E "interface|gateway" | sed 's/^/    /'
        ;;

    add)
        MODE="$2"
        TARGET="$3"
        if [ "$MODE" != "proxy" ] && [ "$MODE" != "bypass" ]; then
            echo "Usage: $0 add <proxy|bypass> <domain|IP>"
            exit 1
        fi
        if [ -z "$TARGET" ]; then
            echo "❌ No domain or IP provided."
            exit 1
        fi

        RESOLVED=$(resolve_target "$TARGET")
        if [ $? -ne 0 ]; then exit 1; fi

        IP=$(echo "$RESOLVED" | awk '{print $1}')
        DOMAIN=$(echo "$RESOLVED" | awk '{print $2}')

        FILE="$([ "$MODE" = "proxy" ] && echo "$PROXY_ROUTES" || echo "$BYPASS_ROUTES")"

        SAVE_ENTRY="$IP"
        [ -n "$DOMAIN" ] && SAVE_ENTRY="$IP # $DOMAIN"

        if ! grep -q "^$IP" "$FILE" 2>/dev/null; then
            echo "$SAVE_ENTRY" >> "$FILE"
            echo "✅ Added to $MODE list: $SAVE_ENTRY"
        else
            echo "ℹ️ $IP is already in the $MODE list."
        fi

        # Apply immediately if VPN is active and relevant
        if is_vpn_active; then
            PHYS_GW=$(get_physical_gw)
            VPN_INFO=$(detect_vpn_if)
            VPN_IF=$(echo "$VPN_INFO" | awk '{print $1}')
            VPN_DEST=$(echo "$VPN_INFO" | awk '{print $2}')

            CUR_DEFAULT_IF=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')

            # If current default is VPN, we only care about adding bypass routes
            # If current default is Physical, we only care about adding proxy routes
            # BUT the user might want to add a route and have it applied regardless of current mode?
            # Actually, the logic should be: if we add to proxy list, apply it via VPN.
            # If we add to bypass list, apply it via Physical GW.

            if [ "$MODE" = "proxy" ]; then
                if [ -n "$VPN_IF" ]; then
                    TARGET_GW="${VPN_DEST:-$VPN_IF}"
                    FLAG=""
                    [ -z "$VPN_DEST" ] && FLAG="-interface"
                    sudo route -n add "$IP" $FLAG "$TARGET_GW" >/dev/null 2>&1 && echo "🚀 Applied route via VPN."
                fi
            else
                if [ -n "$PHYS_GW" ]; then
                    sudo route -n add "$IP" "$PHYS_GW" >/dev/null 2>&1 && echo "🚀 Applied route via Physical GW."
                fi
            fi
        fi
        ;;

    clear)
        clear_routes
        echo "✅ All custom routes cleared."
        ;;

    *)
        echo "Usage: $0 {proxy|bypass|status|add|clear}"
        echo "  proxy             Everything via VPN, except bypass list"
        echo "  bypass            Everything via Physical GW, except proxy list"
        echo "  status            Show current tunnel and routing status"
        echo "  add <mode> <host> Add a host to proxy or bypass list"
        echo "  clear             Remove all applied routes"
        exit 1
        ;;
esac
