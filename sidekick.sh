#!/usr/bin/env bash
#
# +---------------------------------------------------------------------------+
# |                                 Sidekick                                  |
# |    A configuration script and management tool for Debian environments     |
# +---------------------------------------------------------------------------+
#
# This script is designed to help configure and manage Debian 12 (Bookworm) and
# Debian 13 (Trixie) remote servers, local workstations, and virtual machines.
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
    local MENU_CHOICE
    MENU_CHOICE=$(gum choose \
        "Initial Setup for a new installation" \
        "Upgrade from version 12 to version 13" \
        "Configure common security options" \
        "Install shell prompt upgrades" \
        "Update installed packages" \
        "Close this script")

    case $MENU_CHOICE in
        "Initial Setup for a new installation")
            sidekick_setup
            ;;
        "Upgrade from version 12 to version 13")
            sidekick_upgrade
            ;;
        "Configure common security options")
            sidekick_secure
            ;;
        "Install shell prompt upgrades")
            sidekick_prompt
            ;;
        "Update installed packages")
            sidekick_update
            ;;
        "Close this script")
            exit 0
            ;;
        "")
            gum style --foreground 57 --padding "1 1" "Nothing selected..."
            sleep 1
            ;;
    esac
}

sidekick_setup() {
    echo "I'm a placeholder for the initial setup script."
    read -p "Press [Enter] to continue..."
    menu_main
}

sidekick_upgrade() {
    echo "I'm a placeholder for the version upgrade script."
    read -p "Press [Enter] to continue..."
    menu_main
}

sidekick_secure() {
    echo "I'm a placeholder for the security script."
    read -p "Press [Enter] to continue..."
    menu_main
}

sidekick_prompt() {
    echo "I'm a placeholder for the local starship prompt config."
    read -p "Press [Enter] to continue..."
    menu_main
}

sidekick_update() {
    echo "I'm a placeholder for the regular update script."
    read -p "Press [Enter] to continue..."
    menu_main
}

check_connection
check_sudo
check_version
check_deps
check_gum
check_fetch
menu_main
exit 0
