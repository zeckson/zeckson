### Unified VPN Manager Specification (`vpn.sh`)

Based on your updated requirements, the tool is now renamed to `vpn.sh`, and the command structure has been simplified by removing the `apply` keyword. The logic now relies entirely on real-time system detection, allowing us to drop the `state` file for a more robust and "stateless" operation.

#### Key Changes
1.  **Simplified Commands:** Direct usage of `proxy` and `bypass` as primary actions.
2.  **Stateless Design:** Removed the `state` file. The script now dynamically detects the physical gateway and VPN interface every time it runs. This prevents issues where the state file might become stale if the network changes or the VPN disconnects unexpectedly.
3.  **Automatic Context Detection:** The script identifies the current environment (which interface is default, which VPN is active) to decide how to apply or clear routes.

---

### Command Structure

```bash
# Routes only specific domains/IPs through the VPN (Opt-in)
./vpn.sh proxy

# Routes everything through the VPN except specific domains/IPs (Opt-out)
./vpn.sh bypass

# Show current tunnel status, active interfaces, and routing rules
./vpn.sh status

# Add a domain or IP to the respective list
./vpn.sh add proxy <domain|IP>
./vpn.sh add bypass <domain|IP>

# Clear all applied routes and restore default routing
./vpn.sh clear
```

---

### Revised Implementation Logic

#### 1. Why we dropped the `state` file
Previously, the `state` file was used to remember the "Physical Gateway" and the "VPN Interface". However, these can be reliably detected on-the-fly:
- **Physical Gateway:** Detected by looking for the default route associated with non-VPN interfaces (e.g., `en0` or `en1`).
- **VPN Interface:** Detected by looking for active `utun` or `ppp` interfaces with an assigned IP address.
- **Benefits:** No more "file not found" errors, no manual cleanup of stale files, and better reliability if the script is interrupted.

#### 2. Mode: `proxy` (Opt-in)
- **Status Check:** Ensures a VPN is connected.
- **Logic:**
    1. Detects the **Physical Gateway**.
    2. Forces the system's **default route** to use the Physical Gateway (bypassing VPN for general traffic).
    3. Iterates through `proxy.routes` and adds routes for those specific IPs via the **VPN Interface**.

#### 3. Mode: `bypass` (Opt-out)
- **Status Check:** Ensures a VPN is connected.
- **Logic:**
    1. Detects the **Physical Gateway**.
    2. Assumes the VPN has already set itself as the default route (standard VPN behavior).
    3. Iterates through `bypass.routes` and adds routes for those specific IPs via the **Physical Gateway**.

#### 4. Status & Add Commands
- **`status`:** Queries `scutil` and `netstat` to show exactly where traffic is going right now, regardless of whether a command was previously run.
- **`add`:** Performs a DNS lookup (if a domain is provided), appends it to the correct `.routes` file, and if a VPN is currently active, immediately injects the route into the kernel routing table.

### Configuration Files
- `~/.vpn/proxy.routes`: Destinations that **must** use the VPN.
- `~/.vpn/bypass.routes`: Destinations that **must** avoid the VPN.
