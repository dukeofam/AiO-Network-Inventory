#!/usr/bin/env bash
#
# Network Discovery & Infrastructure Inventory
#
# Cross-platform network discovery tool.
#
# Supported:
#   - Debian / Ubuntu
#   - Fedora / RHEL / Rocky / AlmaLinux
#   - Arch / Manjaro
#   - Alpine
#   - macOS
#
# Usage:
#   sudo ./discover.sh
#   sudo ./discover.sh --network 192.168.1.0/24
#   sudo ./discover.sh --output /var/lib/network-discovery
#   sudo ./discover.sh --no-install
#   sudo ./discover.sh --quick
#
# ============================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/os.sh"
source "${SCRIPT_DIR}/lib/packages.sh"
source "${SCRIPT_DIR}/lib/network.sh"
source "${SCRIPT_DIR}/lib/scanner.sh"
source "${SCRIPT_DIR}/lib/certificates.sh"
source "${SCRIPT_DIR}/lib/inventory.sh"
source "${SCRIPT_DIR}/lib/diff.sh"

VERSION="2.0.0"

NMAP_HOST_TIMEOUT="${NMAP_HOST_TIMEOUT:-10m}"
NMAP_MAX_RETRIES="${NMAP_MAX_RETRIES:-2}"
MASSCAN_RATE="${MASSCAN_RATE:-10000}"
MASSCAN_PORTS="${MASSCAN_PORTS:-}"

DISCOVERY_DIR="${DISCOVERY_DIR:-${SCRIPT_DIR}/network-discovery}"
TARGET_NETWORK=""
NO_INSTALL=false
QUICK_SCAN=false

usage() {
    cat <<EOF

Network Discovery & Infrastructure Inventory v${VERSION}

Usage:
    $0 [options]

Options:

    --network CIDR
        Scan explicitly specified network.

        Example:
        --network 192.168.1.0/24

    --output DIR
        Directory for scan results.

        Default:
        ./network-discovery

    --quick
        Faster scan.
        Sweeps TCP ports 1-10000 with Masscan and skips OS detection.

    MASSCAN_PORTS=1-65535
        Override the Masscan TCP port range.

    MASSCAN_RATE=10000
        Masscan packets per second.

    --no-install
        Never attempt to install missing dependencies.

    --version
        Show version.

    --help
        Show this help.

Examples:

    sudo $0

    sudo $0 --network 10.20.0.0/24

    sudo $0 --quick

    sudo $0 --no-install

EOF
}

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------

while [[ $# -gt 0 ]]; do

    case "$1" in

        --network)
            [[ $# -ge 2 ]] || die "--network requires CIDR."
            TARGET_NETWORK="$2"
            shift 2
            ;;

        --output)
            [[ $# -ge 2 ]] || die "--output requires a directory."
            DISCOVERY_DIR="$2"
            shift 2
            ;;

        --quick)
            QUICK_SCAN=true
            shift
            ;;

        --no-install)
            NO_INSTALL=true
            shift
            ;;

        --version)
            echo "$VERSION"
            exit 0
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            die "Unknown option: $1"
            ;;

    esac

done

# ------------------------------------------------------------
# Initialization
# ------------------------------------------------------------

init_run_directory

log "Network Discovery & Infrastructure Inventory"
log "Version: ${VERSION}"
echo

detect_os
detect_package_manager
detect_privileges

log "OS              : ${OS}"
log "Package manager : ${PACKAGE_MANAGER}"

if [[ "$NO_INSTALL" == true ]]; then
    log "Automatic package installation disabled."
fi

install_dependencies "$NO_INSTALL"

# ------------------------------------------------------------
# Network
# ------------------------------------------------------------

if [[ -n "$TARGET_NETWORK" ]]; then

    validate_cidr "$TARGET_NETWORK"

    NETWORK="$TARGET_NETWORK"

    log "Using explicitly specified network: ${NETWORK}"

else

    detect_network

fi

# ------------------------------------------------------------
# Discovery
# ------------------------------------------------------------

if ! discover_ports; then

    warn "No open TCP ports discovered."

    create_empty_inventory
    generate_reports
    finalize_run

    exit 0

fi

scan_hosts

# ------------------------------------------------------------
# Inventory
# ------------------------------------------------------------

parse_nmap_inventory
scan_certificate_details
generate_certificate_summary
generate_reports

# ------------------------------------------------------------
# Change detection
# ------------------------------------------------------------

compare_previous_scan

# ------------------------------------------------------------
# Finalize
# ------------------------------------------------------------

finalize_run

echo
echo "============================================================"
echo " Discovery complete"
echo "============================================================"
echo
echo "Network       : ${NETWORK}"
echo "Hosts         : ${HOST_COUNT}"
echo
echo "Results:"
echo "  Directory   : ${RUN_DIR}"
echo "  HTML        : ${HTML_FILE}"
echo "  JSON        : ${JSON_FILE}"
echo "  CSV         : ${CSV_FILE}"
echo "  Certificates: ${CERTIFICATES_FILE}"
echo "  Changes     : ${CHANGES_FILE}"
echo
echo "Latest:"
echo "  ${LATEST_LINK}"
echo