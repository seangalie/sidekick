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
    echo "I'm a placeholder for a connection check."
    read -p "Press [Enter] to continue..."
}

check_sudo() {
    echo "I'm a placeholder for a root/superuser permissions check."
    read -p "Press [Enter] to continue..."
}

check_version() {
    echo "I'm a placeholder for a Debian version check."
    read -p "Press [Enter] to continue..."
}

check_deps() {
    echo "I'm a placeholder for a script dependencies check."
    read -p "Press [Enter] to continue..."
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
                sidekick_setup
                ;;
            "Configure common security options")
                sidekick_secure
                ;;
            "Install shell prompt upgrades")
                sidekick_prompt
                ;;
            "Upgrade from Bookworm to Trixie")
                sidekick_upgrade
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


sidekick_setup() {
    echo "I'm a placeholder for the initial setup script."
    read -p "Press [Enter] to continue..."
}

sidekick_secure() {
    echo "I'm a placeholder for the security script."
    read -p "Press [Enter] to continue..."
}

sidekick_prompt() {
    echo "I'm a placeholder for the local starship prompt config."
    read -p "Press [Enter] to continue..."
}

sidekick_upgrade() {
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
    sidekick_setup
}

run_secure() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_secure
}

run_prompt() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_prompt
}

run_upgrade() {
    check_connection
    check_sudo
    check_version
    check_deps
    check_gum
    check_fetch
    sidekick_upgrade
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
