#!/bin/sh

BASE_DIR="$HOME/.kain-vpn"
STATE_FILE="$BASE_DIR/state"
CUSTOM_ROUTES_FILE="$BASE_DIR/custom.routes"
LOG_FILE="$BASE_DIR/routing.log"

mkdir -p "$BASE_DIR"

VPN_NAME_ARG="$2"
ACTION="$1"

select_vpn() {
  if [ -n "$VPN_NAME_ARG" ]; then
    VPN_NAME="$VPN_NAME_ARG"
  else
    # Check if a VPN is already connected
    CONNECTED_VPN=$(scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/' | head -n 1)
    if [ -n "$CONNECTED_VPN" ]; then
      echo "✅ Already connected to VPN: $CONNECTED_VPN"
      VPN_NAME="$CONNECTED_VPN"
    else
      # Existing graphical/manual selection logic
      VPN_NAME=$(osascript -e 'set vpnList to do shell script "scutil --nc list | grep \"(Disconnected)\" | sed -E \"s/.*\\\"(.*)\\\".*/\\1/\""
        set vpnArray to paragraphs of vpnList
        if (count of vpnArray) is 0 then
          return ""
        else
          choose from list vpnArray with title "Select VPN Service" with prompt "Choose a VPN to connect:" default items {item 1 of vpnArray}
        end if' 2>/dev/null)

      if [ "$VPN_NAME" = "false" ] || [ -z "$VPN_NAME" ]; then
        echo "📡 Available VPN services (manual entry):"
        scutil --nc list
        echo ""
        printf "Enter VPN name: "
        read VPN_NAME
      fi
    fi
  fi

  if [ -z "$VPN_NAME" ]; then
    echo "❌ No VPN name provided"
    exit 1
  fi

  # Validate VPN name and get UUID if possible
  VPN_INFO=$(scutil --nc list | grep "\"$VPN_NAME\"")
  if [ -z "$VPN_INFO" ]; then
    echo "❌ VPN service '$VPN_NAME' not found"
    exit 1
  fi
  VPN_UUID=$(echo "$VPN_INFO" | awk '{print $NF}' | sed 's/\[.*\]//g' | tr -d '()' | grep -E '^[0-9A-F-]{36}' || true)
}

connect_vpn() {
  local TARGET_VPN="${VPN_UUID:-$VPN_NAME}"
  STATUS=$(scutil --nc status "$TARGET_VPN")
  if echo "$STATUS" | grep -q "Connected"; then
    echo "✅ VPN already connected"
    return
  fi

  if echo "$STATUS" | grep -q "Connecting"; then
    echo "⏳ VPN is already connecting..."
  else
    echo "🔌 Connecting VPN: $VPN_NAME"
    scutil --nc start "$TARGET_VPN"
  fi

  i=0
  while [ $i -lt 30 ]; do
    STATUS=$(scutil --nc status "$TARGET_VPN")
    echo "  Status: $STATUS" | head -n 1
    echo "$STATUS" | grep -q "Connected" && break
    sleep 1
    i=$((i + 1))
  done

  if ! echo "$STATUS" | grep -q "Connected"; then
    echo "❌ VPN failed to connect (timeout or error)"
    echo "💡 Tip: Check 'System Settings -> VPN' or 'log show --predicate \"process == \\\"racoon\\\" || process == \\\"nesessionmanager\\\"\" --last 1m'"
    exit 1
  fi

  echo "✅ VPN connected"
}

disconnect_vpn() {
  local TARGET_VPN="${VPN_UUID:-$VPN_NAME}"
  echo "🔌 Disconnecting VPN: $VPN_NAME"
  scutil --nc stop "$TARGET_VPN"
}

detect_vpn_if() {
  # Try current default first
  IF_INFO=$(route -n get default 2>/dev/null)
  IF=$(echo "$IF_INFO" | grep interface | awk '{print $2}')
  if [ -n "$IF" ] && [ "$IF" != "en0" ] && [ "$IF" != "en1" ] && [ "$IF" != "lo0" ]; then
    # Verify it has an IP address
    if ifconfig "$IF" 2>/dev/null | grep -q "inet "; then
      DEST=$(ifconfig "$IF" 2>/dev/null | grep "inet " | awk '$3 == "-->" {print $4}')
      echo "$IF $DEST"
      return
    fi
  fi

  # Fallback: look for utun or ppp interfaces that are up AND have an IP address
  for iface in $(ifconfig -u | grep -E "^(utun|ppp)[0-9]" | cut -d: -f1); do
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
      DEST=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '$3 == "-->" {print $4}')
      echo "$iface $DEST"
      return
    fi
  done
}

get_default_gw() {
  # Try to find the physical (non-VPN) gateway
  GW=$(netstat -rn -f inet | grep default | grep -vE "utun|ppp|lo|gif|stf" | awk '{print $2}' | head -n 1)
  if [ -z "$GW" ]; then
    # Fallback: look at the primary interface via scutil
    IF=$(printf "open\nget State:/Network/Global/IPv4\nd.show" | scutil | grep "PrimaryInterface" | awk '{print $3}')
    if [ -n "$IF" ]; then
       GW=$(printf "open\nget State:/Network/Interface/$IF/IPv4\nd.show" | scutil | grep "Router" | awk '{print $3}')
    fi
  fi
  echo "$GW"
}

apply_routes() {
  VPN_IF="$1"
  VPN_GW="$2"

  # Use Gateway IP if available (more reliable for PPP), otherwise use interface
  ROUTE_TARGET="${VPN_GW:-$VPN_IF}"
  FLAG=""
  if [ -z "$VPN_GW" ]; then
    FLAG="-interface"
  fi

  if [ -f "$CUSTOM_ROUTES_FILE" ]; then
    echo "➕ Adding custom routes via $ROUTE_TARGET..."
    sudo sh -c "while IFS= read -r LINE; do
      # Extract IP part (before #)
      TARGET=\$(echo \"\$LINE\" | awk '{print \$1}')
      [ -n \"\$TARGET\" ] && route -n add \"\$TARGET\" $FLAG \"$ROUTE_TARGET\" 2>/dev/null
    done < \"$CUSTOM_ROUTES_FILE\""
  fi
}

remove_routes() {
  echo "🧹 Removing routes..."
  if [ -f "$CUSTOM_ROUTES_FILE" ]; then
    sudo sh -c "while IFS= read -r LINE; do
      # Extract IP part (before #)
      TARGET=\$(echo \"\$LINE\" | awk '{print \$1}')
      [ -n \"\$TARGET\" ] && route -n delete \"\$TARGET\" 2>/dev/null
    done < \"$CUSTOM_ROUTES_FILE\""
  fi
}

case "$ACTION" in

  on)
    echo "🚀 Enabling VPN with selective routing..."

    # Detect physical gateway BEFORE connecting VPN
    DEFAULT_GW=$(get_default_gw)
    echo "✅ Physical gateway: $DEFAULT_GW"

    if [ -z "$DEFAULT_GW" ]; then
      echo "❌ Could not detect physical gateway. Ensure you have an active internet connection."
      exit 1
    fi

    select_vpn

    # Ensure clean state by removing any previously set routes
    remove_routes

    # Get VPN server IP to protect it BEFORE connecting
    VPN_SERVER=$(scutil --nc show "$VPN_NAME" | grep CommRemoteAddress | awk '{print $3}' | tr -d '"')
    if [ -n "$VPN_SERVER" ]; then
      echo "🛡️ Protecting VPN server route: $VPN_SERVER via $DEFAULT_GW"
      sudo route -n delete -host "$VPN_SERVER" 2>/dev/null
      sudo route -n add -host "$VPN_SERVER" "$DEFAULT_GW" 2>/dev/null
    fi

    connect_vpn

    # Give OS a moment to settle
    sleep 3

    VPN_INFO_FULL=$(detect_vpn_if)
    VPN_IF=$(echo "$VPN_INFO_FULL" | awk '{print $1}')
    VPN_DEST=$(echo "$VPN_INFO_FULL" | awk '{print $2}')

    i=0
    while [ -z "$VPN_IF" ] && [ $i -lt 15 ]; do
      echo "⏳ Waiting for VPN interface and IP address... ($((i + 1))/15)"
      sleep 2
      VPN_INFO_FULL=$(detect_vpn_if)
      VPN_IF=$(echo "$VPN_INFO_FULL" | awk '{print $1}')
      VPN_DEST=$(echo "$VPN_INFO_FULL" | awk '{print $2}')
      i=$((i + 1))
    done

    if [ -z "$VPN_IF" ] || [ "$VPN_IF" = "en0" ] || [ "$VPN_IF" = "en1" ]; then
      echo "❌ VPN interface with IP address not detected (got: $VPN_IF)"
      echo "💡 Tip: The VPN might have connected but failed to obtain an IP address via IPCP/DHCP."
      exit 1
    fi

    echo "✅ VPN interface: $VPN_IF"
    [ -n "$VPN_DEST" ] && echo "✅ VPN destination IP: $VPN_DEST"

    echo "💾 Saving state..."
    echo "$DEFAULT_GW" > "$STATE_FILE"
    echo "$VPN_IF" >> "$STATE_FILE"
    echo "$VPN_NAME" >> "$STATE_FILE"
    echo "$VPN_DEST" >> "$STATE_FILE"

    echo "🔄 Restoring default route (bypass VPN)..."
    sudo route change default "$DEFAULT_GW"
    # Some VPNs (like OpenVPN with redirect-gateway def1) use 0.0.0.0/1 and 128.0.0.0/1
    # to override the default route. We must remove these to truly bypass the VPN.
    sudo route -n delete 0.0.0.0/1 2>/dev/null
    sudo route -n delete 128.0.0.0/1 2>/dev/null

    apply_routes "$VPN_IF" "$VPN_DEST"

    echo "✅ VPN connected, default route is DIRECT"

    # Save routing info for debugging
    echo "--- CONNECTED AT $(date) ---" >> "$LOG_FILE"
    netstat -rn -f inet >> "$LOG_FILE"
    echo "-----------------------------------" >> "$LOG_FILE"
    echo "📝 Routing info saved to $LOG_FILE"
    ;;

  add)
    TARGET="$2"
    if [ -z "$TARGET" ]; then
      echo "❌ No domain or IP provided"
      echo "Usage: $0 add <domain|IP>"
      exit 1
    fi

    # Extract domain if it's a URL (strips protocol and path)
    CLEAN_TARGET=$(echo "$TARGET" | sed -E 's|^[a-z]+://||; s|/.*$||')

    echo "➕ Adding $CLEAN_TARGET to proxy list..."

    # Resolve domain if it's not an IP
    if echo "$CLEAN_TARGET" | grep -qvE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
      IP=$(dig +short "$CLEAN_TARGET" | tail -n1)
      if [ -z "$IP" ]; then
        echo "❌ Could not resolve domain: $CLEAN_TARGET"
        exit 1
      fi
      echo "🔍 Resolved $CLEAN_TARGET to $IP"
      # We save both the domain and the IP to the state file
      # Format: "IP # domain" if domain exists, else just "IP"
      SAVE_ENTRY="$IP # $CLEAN_TARGET"
      SAVE_TARGET="$IP"
    else
      SAVE_ENTRY="$CLEAN_TARGET"
      SAVE_TARGET="$CLEAN_TARGET"
    fi

    # Append to custom routes if not already there
    mkdir -p "$BASE_DIR"
    touch "$CUSTOM_ROUTES_FILE"
    if ! grep -q "# $CLEAN_TARGET" "$CUSTOM_ROUTES_FILE" 2>/dev/null && ! grep -Fxq "$SAVE_TARGET" "$CUSTOM_ROUTES_FILE" 2>/dev/null; then
      echo "$SAVE_ENTRY" >> "$CUSTOM_ROUTES_FILE"
      echo "✅ Saved $SAVE_ENTRY to $CUSTOM_ROUTES_FILE"
    else
      echo "ℹ️ $CLEAN_TARGET (or its IP) is already in the list"
    fi

    # Apply immediately if VPN is on
    if [ -f "$STATE_FILE" ]; then
      VPN_IF=$(sed -n '2p' "$STATE_FILE")
      VPN_DEST=$(sed -n '4p' "$STATE_FILE")
      ROUTE_TARGET="${VPN_DEST:-$VPN_IF}"
      FLAG=""
      [ -z "$VPN_DEST" ] && FLAG="-interface"

      echo "🚀 Applying route immediately via $ROUTE_TARGET..."
      sudo route -n add "$SAVE_TARGET" $FLAG "$ROUTE_TARGET" 2>/dev/null
    fi
    ;;

  off)
    echo "🛑 Disabling split tunneling..."

    if [ ! -f "$STATE_FILE" ]; then
      echo "❌ No state found"
      exit 1
    fi

    DEFAULT_GW=$(sed -n '1p' "$STATE_FILE")
    VPN_IF=$(sed -n '2p' "$STATE_FILE")
    VPN_NAME=$(sed -n '3p' "$STATE_FILE")

    echo "🔄 Restoring default route..."
    sudo route change default "$DEFAULT_GW"

    # Save routing info BEFORE cleanup for debugging
    echo "--- DISCONNECTING AT $(date) ---" >> "$LOG_FILE"
    netstat -rn -f inet >> "$LOG_FILE"
    echo "--------------------------------------" >> "$LOG_FILE"
    echo "📝 Routing info saved to $LOG_FILE"

    remove_routes

    disconnect_vpn

    rm -f "$STATE_FILE"

    echo "✅ Split tunneling DISABLED"
    ;;

  status)
    echo "📊 Split tunneling status:"

    # 1. VPN Status
    if [ -f "$STATE_FILE" ]; then
      VPN_NAME=$(sed -n '3p' "$STATE_FILE")
      VPN_IF=$(sed -n '2p' "$STATE_FILE")
      DEFAULT_GW=$(sed -n '1p' "$STATE_FILE")
      echo "  - VPN Service: $VPN_NAME"
      echo "  - VPN Interface: $VPN_IF"
      echo "  - Physical Gateway (saved): $DEFAULT_GW"
    else
      echo "  - Status: Split tunneling is NOT active (no state file)"
      select_vpn_silent() {
        if [ -n "$VPN_NAME_ARG" ]; then
          VPN_NAME="$VPN_NAME_ARG"
        else
          # Just try to find ANY connected VPN if not specified
          VPN_NAME=$(scutil --nc list | grep Connected | sed -E 's/.*"(.*)".*/\1/' | head -n 1)
        fi
      }
      select_vpn_silent
      if [ -n "$VPN_NAME" ]; then
        echo "  - Note: VPN '$VPN_NAME' is connected but split tunneling is NOT managed by this script"
      fi
    fi

    # 2. Routing table check
    echo ""
    echo "  - Default Gateway (current): $(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')"
    echo "  - Default Interface (current): $(route -n get default 2>/dev/null | grep interface | awk '{print $2}')"

    # 3. Check for specific routes (0.0.0.0/1 and 128.0.0.0/1)
    if netstat -rn -f inet | grep -q "0.0.0.0/1"; then
      echo "  - ⚠️ 0.0.0.0/1 route exists (VPN might be overriding all traffic)"
    fi
    if netstat -rn -f inet | grep -q "128.0.0.0/1"; then
      echo "  - ⚠️ 128.0.0.0/1 route exists (VPN might be overriding all traffic)"
    fi

    # 4. Count routes via VPN
    if [ -n "$VPN_IF" ]; then
      VPN_ROUTE_COUNT=$(netstat -rn -f inet | grep -c "$VPN_IF" || true)
      echo "  - Total routes via $VPN_IF: $VPN_ROUTE_COUNT"
      if [ -f "$CUSTOM_ROUTES_FILE" ]; then
        echo "  - Custom routes listed in state:"
        sed 's/^/    /' "$CUSTOM_ROUTES_FILE"
      fi
    fi

    # 5. Check a known RU IP (e.g., yandex.ru - 77.88.55.242)
    echo ""
    echo "  - Trace to yandex.ru (77.88.55.242):"
    route -n get 77.88.55.242 | grep -E "interface|gateway" | sed 's/^/    /'
    ;;

  check)
    TARGET="$2"
    if [ -z "$TARGET" ]; then
      echo "❌ No target (IP or domain) provided"
      echo "Usage: $0 check <target>"
      exit 1
    fi
    echo "🔍 Checking routing for: $TARGET"
    route -n get "$TARGET" | grep -E "interface|gateway"
    ;;

  *)
    echo "Usage:"
    echo "  $0 on [VPN_NAME] # connect VPN, default route is direct"
    echo "  $0 off           # disconnect and cleanup"
    echo "  $0 add <host>    # add domain/IP to be routed via VPN"
    echo "  $0 status        # show current status"
    echo "  $0 check <host>  # check routing for host"
    exit 1
    ;;

esac
