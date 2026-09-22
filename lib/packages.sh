#!/usr/bin/env bash

install_dependencies() {

    local no_install="${1:-false}"

    local missing=()

    command_exists nmap || missing+=("nmap")
    command_exists masscan || missing+=("masscan")
    command_exists python3 || missing+=("python3")
    command_exists openssl || missing+=("openssl")

    if [[ "${#missing[@]}" -eq 0 ]]; then

        log "Required dependencies are installed."

        return

    fi

    warn "Missing dependencies: ${missing[*]}"

    if [[ "$no_install" == true ]]; then

        die "Missing dependencies and --no-install was specified."

    fi

    if [[ "${IS_ROOT:-false}" != true && "${CAN_ELEVATE:-false}" != true ]]; then
        die "Missing dependencies, and passwordless sudo is unavailable for installation."
    fi

    case "$PACKAGE_MANAGER" in

        apt)

            log "Installing dependencies using apt..."

            ${SUDO} apt-get update

            ${SUDO} DEBIAN_FRONTEND=noninteractive \
                apt-get install -y \
                nmap \
                masscan \
                python3 \
                openssl

            ;;

        dnf)

            log "Installing dependencies using dnf..."

            ${SUDO} dnf install -y \
                nmap \
                masscan \
                python3 \
                openssl

            ;;

        yum)

            log "Installing dependencies using yum..."

            ${SUDO} yum install -y \
                nmap \
                masscan \
                python3 \
                openssl

            ;;

        pacman)

            log "Installing dependencies using pacman..."

            ${SUDO} pacman -Sy --noconfirm \
                nmap \
                masscan \
                python \
                openssl

            ;;

        apk)

            log "Installing dependencies using apk..."

            ${SUDO} apk add \
                nmap \
                masscan \
                python3 \
                openssl

            ;;

        brew)

            if ! command_exists brew; then

                die "Homebrew is not installed.

Install Homebrew first:
https://brew.sh/

Then run this script again."

            fi

            log "Installing dependencies using Homebrew..."

            command_exists nmap || brew install nmap
            command_exists masscan || brew install masscan
            command_exists python3 || brew install python
            command_exists openssl || brew install openssl

            ;;

        *)

            die "Unsupported package manager: ${PACKAGE_MANAGER}

Install manually:
    nmap
    python3
    openssl"

            ;;

    esac

    command_exists nmap \
        || die "nmap is still unavailable after installation."

    command_exists masscan \
        || die "masscan is still unavailable after installation."

    command_exists python3 \
        || die "python3 is still unavailable after installation."

    command_exists openssl \
        || die "openssl is still unavailable after installation."
}