#!/usr/bin/env bash

detect_network_linux() {

    require_command ip

    local route_info

    route_info="$(ip route get 1.1.1.1 2>/dev/null || true)"

    [[ -n "$route_info" ]] \
        || die "Unable to determine default route."

    INTERFACE="$(
        awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "dev") {
                    print $(i+1)
                    exit
                }
            }
        }' <<< "$route_info"
    )"

    LOCAL_IP="$(
        awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "src") {
                    print $(i+1)
                    exit
                }
            }
        }' <<< "$route_info"
    )"

    [[ -n "$INTERFACE" ]] \
        || die "Unable to determine network interface."

    [[ -n "$LOCAL_IP" ]] \
        || die "Unable to determine local IP."

    NETWORK="$(
        ip -o -f inet addr show dev "$INTERFACE" scope global \
        | awk -v ip="$LOCAL_IP" '
            $4 ~ "^" ip "/" {
                print $4
                exit
            }
        '
    )"

    [[ -n "$NETWORK" ]] \
        || die "Unable to determine network CIDR."
}


detect_network_macos() {

    require_command route
    require_command ifconfig
    require_command ipconfig

    INTERFACE="$(
        route -n get default 2>/dev/null \
        | awk '/interface:/{print $2}'
    )"

    [[ -n "$INTERFACE" ]] \
        || die "Unable to determine default network interface."

    LOCAL_IP="$(
        ipconfig getifaddr "$INTERFACE" 2>/dev/null || true
    )"

    [[ -n "$LOCAL_IP" ]] \
        || die "Unable to determine local IP."

    local netmask

    netmask="$(
        ifconfig "$INTERFACE" \
        | awk '/inet / && $2 == "'"$LOCAL_IP"'" {print $4; exit}'
    )"

    [[ -n "$netmask" ]] \
        || die "Unable to determine macOS netmask."

    NETWORK="$(
        python3 - "$LOCAL_IP" "$netmask" <<'PY'
import ipaddress
import sys

ip = sys.argv[1]
netmask = sys.argv[2]

# macOS may return either:
#   255.255.255.0
# or:
#   0xffffff00

if netmask.startswith("0x"):
    value = int(netmask, 16)
    netmask = str(ipaddress.IPv4Address(value))

network = ipaddress.IPv4Network(
    f"{ip}/{netmask}",
    strict=False
)

print(network)
PY
    )"

    [[ -n "$NETWORK" ]] \
        || die "Unable to calculate macOS network CIDR."
}


detect_network() {

    case "$OS" in

        macos)
            detect_network_macos
            ;;

        *)
            detect_network_linux
            ;;

    esac

    log "Interface : ${INTERFACE}"
    log "Local IP  : ${LOCAL_IP}"
    log "Network   : ${NETWORK}"
}


get_default_interface() {

    if [[ -n "${INTERFACE:-}" ]]; then
        echo "$INTERFACE"
    else
        echo ""
    fi
}