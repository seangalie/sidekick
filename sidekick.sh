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
    local debian_version_file="/etc/debian_version"

    if [ ! -f "$debian_version_file" ]; then
        echo " Error: This script is designed to run within Debian-based environments. Your"
        echo "   environment appears to be missing information needed to validate that this"
        echo "   environment is compatible with this script."
        echo ""
        echo " This error is based on information read from the $debian_version_file file."
        exit 1
    fi
    local debian_version_raw
    debian_version_raw=$(<"$debian_version_file")
    local debian_version
    debian_version=$(echo "$debian_version_raw" | sed -n 's/^\([0-9]\+\).*/\1/p')
    if ! [[ "$debian_version" =~ ^[0-9]+$ ]] || [ "$debian_version" -lt 12 ]; then
        echo " Error: This script requires an environment running Debian version 12 or"
        echo "   higher. Detected version: $debian_version_raw (parsed as $debian_version)."
        echo ""
        echo " This error is based on information read from the $debian_version_file file."
        exit 1
    fi
}

check_deps() {
    local missing_deps=()
    for dep in curl wget gpg jq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo ""
        echo " Info: The following utilities are required and will now be installed: ${missing_deps[*]}"
        echo ""
        sleep 1
        if ! { $USE_SUDO apt update && $USE_SUDO apt install -y "${missing_deps[@]}"; }; then
            echo " Error: Failed to install required utilities: ${missing_deps[*]}"
            exit 1
        fi
    fi
}

check_gum() {
    echo "I'm a placeholder for a check that gum is installed, and to install it if it isn't."
    read -p "Press [Enter] to continue..."
}

check_fetch() {
    echo "I'm a placeholder for a check that the fetch utility is installed, and to install it if it isn't."
    read -p "Press [Enter] to continue..."
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
