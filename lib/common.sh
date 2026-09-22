#!/usr/bin/env bash

log() {
    echo "[+] $*"
}

info() {
    echo "[*] $*"
}

warn() {
    echo "[!] $*" >&2
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" || die "Required command not found: $1"
}

init_run_directory() {

    mkdir -p "$DISCOVERY_DIR"

    LOCK_DIR="${DISCOVERY_DIR}/.lock"
    LOCK_FILE="${LOCK_DIR}/pid"

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        if [[ -r "$LOCK_FILE" ]]; then
            local lock_pid
            lock_pid="$(cat "$LOCK_FILE")"

            if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
                die "Another discovery run is already using ${DISCOVERY_DIR}."
            fi

            warn "Removing stale discovery lock from PID ${lock_pid:-unknown}."
            rm -rf "$LOCK_DIR"

            mkdir "$LOCK_DIR" 2>/dev/null \
                || die "Unable to acquire discovery lock for ${DISCOVERY_DIR}."
        else
            die "Another discovery run is already using ${DISCOVERY_DIR}."
        fi
    fi

    printf '%s\n' "$$" > "$LOCK_FILE"

    trap 'rm -rf "$LOCK_DIR"' EXIT
    trap 'exit 130' INT TERM

    TIMESTAMP="$(date -u '+%Y%m%d_%H%M%S')_$$"

    RUN_DIR="${DISCOVERY_DIR}/${TIMESTAMP}"

    LATEST_LINK="${DISCOVERY_DIR}/latest"
    PREVIOUS_LINK="${DISCOVERY_DIR}/previous"

    mkdir "$RUN_DIR"

    HOSTS_FILE="${RUN_DIR}/hosts.txt"
    NMAP_XML="${RUN_DIR}/nmap.xml"
    NMAP_LOG="${RUN_DIR}/nmap.txt"
    MASSCAN_LOG="${RUN_DIR}/masscan.txt"

    JSON_FILE="${RUN_DIR}/inventory.json"
    CSV_FILE="${RUN_DIR}/inventory.csv"
    HTML_FILE="${RUN_DIR}/inventory.html"

    CERTIFICATES_FILE="${RUN_DIR}/certificates.txt"
    CHANGES_FILE="${RUN_DIR}/changes.txt"

    METADATA_FILE="${RUN_DIR}/metadata.json"
}

validate_cidr() {

    local cidr="$1"

    if ! python3 - "$cidr" <<'PY'
import ipaddress
import sys

try:
    ipaddress.ip_network(sys.argv[1], strict=False)
except ValueError:
    sys.exit(1)
PY
    then
        die "Invalid network CIDR: ${cidr}"
    fi
}

create_empty_inventory() {

    cat > "$JSON_FILE" <<EOF
{
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "network": "${NETWORK}",
  "host_count": 0,
  "hosts": []
}
EOF

    printf '%s\n' 'IP,Hostname,MAC,OS,Port,Protocol,Service,Product,Version,ExtraInfo' > "$CSV_FILE"
    : > "$CERTIFICATES_FILE"

    echo "No hosts discovered." > "$CHANGES_FILE"
}

finalize_run() {

    # latest -> current run
    if [[ -L "$LATEST_LINK" ]]; then
        rm -f "$PREVIOUS_LINK"
        ln -s "$(readlink "$LATEST_LINK")" "$PREVIOUS_LINK"
    fi

    rm -f "$LATEST_LINK"

    ln -s "$TIMESTAMP" "$LATEST_LINK"

    cat > "$METADATA_FILE" <<EOF
{
  "version": "${VERSION}",
  "timestamp": "${TIMESTAMP}",
  "os": "${OS}",
  "package_manager": "${PACKAGE_MANAGER}",
  "interface": "${INTERFACE:-}",
  "local_ip": "${LOCAL_IP:-}",
  "network": "${NETWORK}",
  "quick_scan": ${QUICK_SCAN},
  "host_count": ${HOST_COUNT:-0}
}
EOF
}