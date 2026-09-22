#!/usr/bin/env bash

detect_os() {

    OS=""
    OS_NAME=""
    OS_VERSION=""

    case "$(uname -s)" in

        Darwin)

            OS="macos"

            OS_NAME="macOS"
            OS_VERSION="$(sw_vers -productVersion 2>/dev/null || true)"

            ;;

        Linux)

            if [[ -f /etc/os-release ]]; then

                # shellcheck disable=SC1091
                source /etc/os-release

                OS_NAME="${PRETTY_NAME:-Linux}"
                OS_VERSION="${VERSION_ID:-}"

                case "${ID:-}" in

                    debian|ubuntu|linuxmint|pop)
                        OS="debian"
                        ;;

                    fedora|rhel|centos|rocky|almalinux)
                        OS="fedora"
                        ;;

                    arch|manjaro|endeavouros)
                        OS="arch"
                        ;;

                    alpine)
                        OS="alpine"
                        ;;

                    *)
                        OS="linux"
                        ;;

                esac

            else

                OS="linux"
                OS_NAME="Linux"

            fi

            ;;

        *)

            die "Unsupported operating system: $(uname -s)"

            ;;

    esac
}


detect_package_manager() {

    case "$OS" in

        debian)

            if command_exists apt-get; then
                PACKAGE_MANAGER="apt"
            else
                die "apt-get not found."
            fi

            ;;

        fedora)

            if command_exists dnf; then
                PACKAGE_MANAGER="dnf"
            elif command_exists yum; then
                PACKAGE_MANAGER="yum"
            else
                die "Neither dnf nor yum found."
            fi

            ;;

        arch)

            if command_exists pacman; then
                PACKAGE_MANAGER="pacman"
            else
                die "pacman not found."
            fi

            ;;

        alpine)

            if command_exists apk; then
                PACKAGE_MANAGER="apk"
            else
                die "apk not found."
            fi

            ;;

        macos)

            if command_exists brew; then
                PACKAGE_MANAGER="brew"
            else
                PACKAGE_MANAGER="none"
            fi

            ;;

        linux)

            PACKAGE_MANAGER="unknown"

            ;;

        *)

            die "No package manager definition for: ${OS}"

            ;;

    esac
}


detect_privileges() {

    if [[ "$(id -u)" -eq 0 ]]; then

        SUDO=""
        IS_ROOT=true
        CAN_ELEVATE=true

    elif command_exists sudo; then

        if sudo -n true 2>/dev/null; then
            SUDO="sudo -n"
            CAN_ELEVATE=true
        else
            SUDO=""
            CAN_ELEVATE=false
        fi

        IS_ROOT=false

    else

        SUDO=""
        IS_ROOT=false
        CAN_ELEVATE=false

    fi
}