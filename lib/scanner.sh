#!/usr/bin/env bash

discover_hosts() {

    log "Discovering live hosts..."

    nmap \
        -sn \
        -T3 \
        --host-timeout "${NMAP_HOST_TIMEOUT:-10m}" \
        "$NETWORK" \
        -oG - \
        | awk '/Status: Up/{print $2}' \
        | sort -V \
        > "$HOSTS_FILE"

    HOST_COUNT="$(wc -l < "$HOSTS_FILE" | tr -d ' ')"

    log "Live hosts discovered: ${HOST_COUNT}"
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
        -oX "$NMAP_XML"
        -oN "$NMAP_LOG"
    )

    if [[ "$QUICK_SCAN" == true ]]; then

        log "Quick mode enabled."
        log "Scanning common TCP ports."
        log "OS fingerprinting disabled in quick mode."

        nmap_args+=(
            --top-ports 1000
            --min-hostgroup 10
            --max-hostgroup 50
            -T4
        )

    else

        log "Full mode enabled."
        log "Scanning all TCP ports (1-65535)."

        nmap_args+=(
            -p-
        )

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