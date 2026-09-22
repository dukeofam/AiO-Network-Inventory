#!/usr/bin/env bash

log() {
    echo "[+] $*"
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

create_masscan_inventory() {

    log "Building inventory directly from Masscan output..."

    python3 - "$MASSCAN_LOG" "$JSON_FILE" "$CSV_FILE" <<'PY'
import csv
import datetime
import json
import sys

masscan_file, json_file, csv_file = sys.argv[1:]
hosts = {}

with open(masscan_file, encoding="utf-8") as source:
    for line in source:
        fields = line.split()
        if len(fields) < 4 or fields[:2] != ["open", "tcp"]:
            continue

        port = int(fields[2])
        ip = fields[3]
        host = hosts.setdefault(ip, {
            "ip": ip,
            "hostname": "",
            "mac": "",
            "os": "",
            "ports": []
        })

        if any(item["port"] == port for item in host["ports"]):
            continue

        host["ports"].append({
            "port": port,
            "protocol": "tcp",
            "service": "",
            "product": "",
            "version": "",
            "extrainfo": "",
            "certificate": {}
        })

inventory = {
    "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "host_count": len(hosts),
    "hosts": list(hosts.values())
}

with open(json_file, "w", encoding="utf-8") as target:
    json.dump(inventory, target, indent=2)
    target.write("\n")

with open(csv_file, "w", newline="", encoding="utf-8") as target:
    writer = csv.writer(target)
    writer.writerow(["IP", "Hostname", "MAC", "OS", "Port", "Protocol", "Service", "Product", "Version", "ExtraInfo"])
    for host in inventory["hosts"]:
        for port in host["ports"]:
            writer.writerow([
                host["ip"], host["hostname"], host["mac"], host["os"],
                port["port"], port["protocol"], port["service"],
                port["product"], port["version"], port["extrainfo"]
            ])
PY

    : > "$CERTIFICATES_FILE"
    echo "Discovery-only mode: Nmap enrichment was skipped." > "$CHANGES_FILE"
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
    "discovery_only": ${DISCOVERY_ONLY:-false},
  "host_count": ${HOST_COUNT:-0}
}
EOF
}