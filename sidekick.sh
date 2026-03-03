#!/usr/bin/env bash
#
# +---------------------------------------------------------------------------+
# |                                 Sidekick                                  |
# |     A configuration and update tool for a Debian headless environment     |
# +---------------------------------------------------------------------------+
#
# This script is designed to help configure and update Debian 12 (Bookworm)
# and Debian 13 (Trixie) headless instances such as remote servers, home lab
# images, container environments, and virtual machines.
#
# Copyright 2026, Sean Galie
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

check_connection() {
    ping -c 1 8.8.8.8 &> /dev/null || {
        echo " Error: No internet connection detected.";
        exit 1;
    }
}

check_sudo() {
    if ! command -v sudo &> /dev/null; then
        if [[ $EUID -ne 0 ]]; then
            echo " Error: This script must be run as root or with sudo privileges."
            exit 1
        fi
        echo ""
        echo " Info: sudo is not installed. Installing now..."
        echo ""
        sleep 1
        if ! apt update && apt install -y sudo; then
            echo " Error: Failed to install sudo."
            exit 1
        fi
    fi
    if [[ $EUID -eq 0 ]]; then
        USE_SUDO=""
    else
        USE_SUDO="sudo"
    fi
    export USE_SUDO
}

check_version() {
    local DEBIAN_VERSION_FILE="/etc/debian_version"
    if [ ! -f "$DEBIAN_VERSION_FILE" ]; then
        echo " Error: This script is designed to run within Debian-based environments. Your"
        echo "   environment appears to be missing information needed to validate that this"
        echo "   environment is compatible with this script."
        echo ""
        echo " This error is based on information read from the $DEBIAN_VERSION_FILE file."
        exit 1
    fi
    local DEBIAN_VERSION_RAW
    DEBIAN_VERSION_RAW=$(<"$DEBIAN_VERSION_FILE")
    local DEBIAN_VERSION
    DEBIAN_VERSION=$(echo "$DEBIAN_VERSION_RAW" | sed -n 's/^\([0-9]\+\).*/\1/p')
    if ! [[ "$DEBIAN_VERSION" =~ ^[0-9]+$ ]] || [ "$DEBIAN_VERSION" -lt 12 ]; then
        echo " Error: This script requires an environment running Debian version 12 or"
        echo "   higher. Detected version: $DEBIAN_VERSION_RAW (parsed as $DEBIAN_VERSION)."
        echo ""
        echo " This error is based on information read from the $DEBIAN_VERSION_FILE file."
        exit 1
    fi
}

check_deps() {
    local SUDO_CMD="${USE_SUDO:-}"
    local MISSING_DEPS=()
    for DEP in curl wget gpg jq; do
        if ! command -v "$DEP" &> /dev/null; then
            MISSING_DEPS+=("$DEP")
        fi
    done
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo ""
        echo " Info: The following utilities are required and will now be installed: ${MISSING_DEPS[*]}"
        echo ""
        sleep 1
        export DEBIAN_FRONTEND=noninteractive
        if ! { $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y "${MISSING_DEPS[@]}"; }; then
            echo " Error: Failed to install required utilities: ${MISSING_DEPS[*]}"
            exit 1
        fi
        for DEP in "${MISSING_DEPS[@]}"; do
            if ! command -v "$DEP" &> /dev/null; then
                echo " Error: Utility '$DEP' was installed but is not available in PATH."
                exit 1
            fi
        done
    fi
}

check_gum() {
    if command -v gum &> /dev/null; then
        return 0
    fi
    echo ""
    echo " Info: gum from Charm is used by this script and will now be installed..."
    echo ""
    sleep 1
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    $SUDO_CMD mkdir -p /etc/apt/keyrings
    if ! curl -fsSL https://repo.charm.sh/apt/gpg.key | $SUDO_CMD gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null; then
        echo " Error: Failed to download or import GPG key."
        exit 1
    fi
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $SUDO_CMD tee /etc/apt/sources.list.d/charm.list >/dev/null
    if ! $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y gum; then
        echo " Error: Failed to install gum."
        exit 1
    fi
    if ! command -v gum &> /dev/null; then
        echo " Error: gum was installed but is not available in PATH."
        exit 1
    fi
}

check_fetch() {
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    if command -v neofetch >&2; then
        echo " Removing deprecated neofetch package..."
        sleep 1
        if ! $SUDO_CMD apt-get purge -y neofetch 2>/dev/null; then
            echo " Warning: Could not purge neofetch. Trying remove..."
            $SUDO_CMD apt-get remove -y neofetch 2>/dev/null || true
        fi
        echo " The neofetch package has been removed."
    fi
    local FASTFETCH_NEW_VERSION
    if command -v jq &> /dev/null; then
        FASTFETCH_NEW_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')
    else
        FASTFETCH_NEW_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep -o '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    fi
    if [ -z "$FASTFETCH_NEW_VERSION" ]; then
        echo " Error: Could not retrieve fastfetch version from GitHub API."
        exit 1
    fi
    local FASTFETCH_INSTALLED_VERSION
    if command -v fastfetch &> /dev/null; then
        FASTFETCH_INSTALLED_VERSION=$(fastfetch --version 2>/dev/null | sed -n 's/fastfetch \([^ ]*\).*/\1/p' || echo "unknown")
        if [ "$FASTFETCH_INSTALLED_VERSION" = "$FASTFETCH_NEW_VERSION" ]; then
            echo " Info: fastfetch $FASTFETCH_NEW_VERSION is already installed."
            return 0
        fi
        echo " Uninstalling existing fastfetch version $FASTFETCH_INSTALLED_VERSION..."
        if ! $SUDO_CMD apt-get remove -y fastfetch 2>/dev/null; then
            if ! $SUDO_CMD dpkg -r fastfetch 2>/dev/null; then
                echo " Warning: Could not uninstall existing fastfetch $FASTFETCH_INSTALLED_VERSION."
            fi
        fi
        if command -v fastfetch &> /dev/null; then
            echo " Error: fastfetch $FASTFETCH_INSTALLED_VERSION still detected after uninstall."
            exit 1
        fi
    fi
    if ! command -v fastfetch &> /dev/null; then
        local ARCH
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="aarch64" ;;
            armv7l) ARCH="armv7l" ;;
            armv6l) ARCH="armv6l" ;;
            ppc64le) ARCH="ppc64le" ;;
            riscv64) ARCH="riscv64" ;;
            s390x) ARCH="s390x" ;;
            *) echo " Error: Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        local FASTFETCH_DEB="fastfetch-linux-${ARCH}.deb"
        local FASTFETCH_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_NEW_VERSION}/${FASTFETCH_DEB}"
        local FASTFETCH_DEB_TEMP
        FASTFETCH_DEB_TEMP=$(mktemp /tmp/fastfetch-XXXXXX.deb)
        echo " Downloading fastfetch $FASTFETCH_NEW_VERSION..."
        if ! curl -fsSL "$FASTFETCH_URL" -o "$FASTFETCH_DEB_TEMP"; then
            echo " Error: Failed to download fastfetch from $FASTFETCH_URL"
            rm -f "$FASTFETCH_DEB_TEMP"
            exit 1
        fi
        echo " Installing fastfetch..."
        if ! $SUDO_CMD dpkg -i "$FASTFETCH_DEB_TEMP"; then
            echo " Error: Failed to install fastfetch via dpkg."
            rm -f "$FASTFETCH_DEB_TEMP"
            if ! $SUDO_CMD apt-get install -y "$FASTFETCH_DEB_TEMP" 2>/dev/null; then
                echo " Error: Could not install fastfetch."
                rm -f "$FASTFETCH_DEB_TEMP"
                exit 1
            fi
        fi
        rm -f "$FASTFETCH_DEB_TEMP"
        if ! command -v fastfetch &> /dev/null; then
            echo " Error: fastfetch was installed but is not available in PATH."
            exit 1
        fi
        echo " Info: fastfetch $FASTFETCH_NEW_VERSION has been installed."
    fi
}

menu_main() {
    while true; do
        local MENU_CHOICE
        MENU_CHOICE=$(gum choose \
            "Initial Setup for a new installation" \
            "Configure common security options" \
            "Install shell prompt upgrades" \
            "Upgrade from Bookworm to Trixie" \
            "Update installed packages" \
            "Close this script")

        case $MENU_CHOICE in
            "Initial Setup for a new installation")
                sidekick_setup_interactive
                ;;
            "Configure common security options")
                sidekick_secure_interactive
                ;;
            "Install shell prompt upgrades")
                sidekick_prompt_interactive
                ;;
            "Upgrade from Bookworm to Trixie")
                sidekick_upgrade_interactive
                ;;
            "Update installed packages")
                sidekick_update_interactive
                ;;
            "Close this script")
                exit 0
                ;;
            "")
                gum style --foreground 57 --padding "1 1" "Nothing selected..."
                sleep 1
                ;;
        esac
    done
}


sidekick_setup_interactive() {
    echo "I'm a placeholder for the initial interactive setup script."
    read -p "Press [Enter] to continue..."
}

sidekick_setup_automatic() {
    echo "I'm a placeholder for the initial automatic setup script."
    read -p "Press [Enter] to continue..."
}

sidekick_secure_interactive() {
    echo "I'm a placeholder for the security script."
    read -p "Press [Enter] to continue..."
}

sidekick_prompt_interactive() {
    echo "I'm a placeholder for the local starship prompt config."
    read -p "Press [Enter] to continue..."
}

sidekick_upgrade_interactive() {
    echo "I'm a placeholder for the version upgrade script."
    read -p "Press [Enter] to continue..."
}

sidekick_update_interactive() {
    echo "I'm a placeholder for the interactive update script."
    read -p "Press [Enter] to continue..."
}

sidekick_update_automatic() {
    echo "I'm a placeholder for the automatic update script."
    read -p "Press [Enter] to continue..."
}

run_menu() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    menu_main
    exit 0
}

run_setup() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_setup_automatic
}

run_secure() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_secure_interactive
}

run_prompt() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_prompt_interactive
}

run_upgrade() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_upgrade_interactive
}

run_update() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_update_automatic
}


if [ $# -eq 0 ]; then
    run_menu
else
    case "$1" in
        --setup)
            run_setup
            ;;
        --update)
            run_update
            ;;
        --upgrade)
            run_upgrade
            ;;
        --prompt)
            run_prompt
            ;;
        --secure)
            run_secure
            ;;
        *)
            echo " Sidekick - A configuration script and management tool for Debian environments."
            echo " Usage: $0 [--setup | --secure | --prompt | --upgrade |  --update]"
            exit 1
            ;;
    esac
fi
