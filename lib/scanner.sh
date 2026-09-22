#!/usr/bin/env bash

discover_ports() {

    local scan_ports="${MASSCAN_PORTS:-1-65535}"

    if [[ "$QUICK_SCAN" == true && -z "${MASSCAN_PORTS:-}" ]]; then
        scan_ports="1-10000"
    fi

    log "Discovering open TCP ports with Masscan..."
    log "Port range: ${scan_ports}; rate: ${MASSCAN_RATE} packets/sec."

    local masscan_args=(
        "$NETWORK"
        -p "$scan_ports"
        --rate "$MASSCAN_RATE"
        --wait 3
        -oL "$MASSCAN_LOG"
    )

    if [[ "${IS_ROOT:-false}" == true ]]; then
        masscan "${masscan_args[@]}"
    elif [[ "${CAN_ELEVATE:-false}" == true ]]; then
        $SUDO masscan "${masscan_args[@]}"
    else
        die "Masscan requires root privileges or passwordless sudo."
    fi

    awk '$1 == "open" && $2 == "tcp" {print $4}' "$MASSCAN_LOG" \
        | sort -V -u > "$HOSTS_FILE"

    MASSCAN_PORT_LIST="$(
        awk '$1 == "open" && $2 == "tcp" {print $3}' "$MASSCAN_LOG" \
            | sort -n -u \
            | paste -sd, -
    )"

    HOST_COUNT="$(wc -l < "$HOSTS_FILE" | tr -d ' ')"

    if [[ -z "$MASSCAN_PORT_LIST" ]]; then
        warn "Masscan found no open TCP ports."
        return 1
    fi

    log "Masscan found ${HOST_COUNT} hosts with open TCP ports."
    log "Targeted ports: ${MASSCAN_PORT_LIST}"
}


scan_hosts() {

    log "Starting detailed network scan..."

    local nmap_args=()

    nmap_args+=(
        -sV
        --version-light
        --open
        -T3
        --host-timeout "${NMAP_HOST_TIMEOUT:-10m}"
        --max-retries "${NMAP_MAX_RETRIES:-2}"
        --script ssl-cert
        -iL "$HOSTS_FILE"
        -p "$MASSCAN_PORT_LIST"
        -oX "$NMAP_XML"
        -oN "$NMAP_LOG"
    )

    if [[ "$QUICK_SCAN" == true ]]; then

        log "Quick mode enabled."
        log "Scanning common TCP ports."
        log "OS fingerprinting disabled in quick mode."

        nmap_args+=(
            --min-hostgroup 10
            --max-hostgroup 50
            -T4
        )

    else

        log "Full mode enabled."
        log "Enriching every Masscan-discovered open TCP port."

    fi

    # OS detection needs elevated privileges and is reserved for full scans.
    if [[ "$QUICK_SCAN" == true ]]; then

        nmap "${nmap_args[@]}"

    elif [[ "$IS_ROOT" == true ]]; then

        nmap_args+=(
            -O
        )

    else

        if [[ "${CAN_ELEVATE:-false}" == true ]]; then

            log "Running Nmap through sudo for OS detection."

            $SUDO nmap "${nmap_args[@]}"

            return

        else

            warn "No sudo available."
            warn "OS detection will be skipped."

        fi

    fi

    nmap "${nmap_args[@]}"
}