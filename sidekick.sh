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
        echo " Info: sudo is not installed. Installing now..."
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
        if ! {
            $SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y "${MISSING_DEPS[@]}";
        }; then
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
        echo " Info: Removing deprecated neofetch package..."
        sleep 1
        if ! $SUDO_CMD apt-get purge -y neofetch 2>/dev/null; then
            echo " Warning: Could not purge neofetch. Trying remove..."
            $SUDO_CMD apt-get remove -y neofetch 2>/dev/null || true
        fi
        echo " Info: The neofetch package has been removed."
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

apt_update_simple() {
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    gum style --foreground 57 --padding "1 1" "Updating package lists..."
    sleep 1
    if ! $SUDO_CMD apt-get update -y; then
        echo " Error: Failed to update package lists."
        exit 1
    fi
    echo " Info: Local package listings have been updated."
    echo " Updating installed packages..."
    sleep 1
    if ! $SUDO_CMD apt-get upgrade -y; then
        echo " Error: Failed to upgrade packages."
        exit 1
    fi
    if ! $SUDO_CMD apt-get full-upgrade -y; then
        echo " Error: Failed to run full-upgrade."
        exit 1
    fi
    gum style --foreground 212 --padding "1 1" "Installed packages have been updated."
}

apt_fullupdate() {
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade and package cleanup..."
    sleep 1
    $USE_SUDO apt update
    $USE_SUDO apt install --fix-missing
    $USE_SUDO apt upgrade --allow-downgrades
    $USE_SUDO apt full-upgrade --allow-downgrades -V
    $USE_SUDO apt install -f
    $USE_SUDO apt autoremove --purge
    $USE_SUDO apt autoclean
    $USE_SUDO apt clean
    gum style --foreground 212 --padding "1 1" "Packages have been updated and cleanup tools have completed."
}

setup_pkgs_base() {
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    local DEBIAN_VERSION_NUM="${DEBIAN_VERSION:-}"
    if [ -z "$DEBIAN_VERSION_NUM" ]; then
        DEBIAN_VERSION_NUM=$(< /etc/debian_version | sed -n 's/^\([0-9]\+\).*/\1/p')
    fi
    gum style --foreground 57 --padding "1 1" "Installing common packages for development servers..."
    sleep 1
    local PKGS_BASE="apt-transport-https btop build-essential bwm-ng ca-certificates cmake cmatrix debian-goodies duf git glances htop iotop locate iftop jq make multitail nano needrestart net-tools p7zip p7zip-full tar tldr-py tree unzip vnstat"
    if ! $SUDO_CMD apt-get install -y $PKGS_BASE; then
        echo " Error: Failed to install base packages."
        exit 1
    fi
    gum style --foreground 212 --padding "1 1" "Common packages for development servers have been installed."
    if [ "$DEBIAN_VERSION_NUM" -lt 13 ] 2>/dev/null; then
        gum style --foreground 57 --padding "1 1" "Installing common packages specific to Debian 12..."
        sleep 1
        echo 'deb [signed-by=/usr/share/keyrings/azlux.gpg] https://packages.azlux.fr/debian/ bookworm main' | $SUDO_CMD tee /etc/apt/sources.list.d/azlux.list >/dev/null
        if ! curl -fsSL https://azlux.fr/repo.gpg.key 2>/dev/null | gpg --dearmor 2>/dev/null | $SUDO_CMD tee /usr/share/keyrings/azlux.gpg >/dev/null; then
            echo " Warning: Failed to download or import GPG key for azlux repository."
        else
            if ! $SUDO_CMD apt-get update -y 2>/dev/null; then
                echo " Warning: Failed to update package lists after adding azlux repository."
            else
                if ! $SUDO_CMD apt-get install -y software-properties-common gping 2>/dev/null; then
                    echo " Warning: Failed to install software-properties-common or gping."
                fi
            fi
        fi
        gum style --foreground 212 --padding "1 1" "Common packages specific to Debian 12 have been installed."
    fi
    if [ "$DEBIAN_VERSION_NUM" -ge 13 ] 2>/dev/null; then
        gum style --foreground 57 --padding "1 1" "Installing common packages specific to Debian 13..."
        sleep 1

        if ! $SUDO_CMD apt-get install -y gping; then
            echo " Warning: Failed to install gping."
        fi
        gum style --foreground 212 --padding "1 1" "Common packages specific to Debian 13 have been installed."
    fi
}

setup_pkgs_option() {
    local SUDO_CMD="${USE_SUDO:-}"
    export DEBIAN_FRONTEND=noninteractive
    gum style --foreground 212 --padding "1 1" "Choose which package groups to configure:"
    local -a PKG_OPTIONS=()
    while IFS= read -r option; do
        PKG_OPTIONS+=("$PKG_OPTION")
    done < <(gum choose --no-limit \
        "Node.js Support and Package Management" \
        "Python Programming Language Support" \
        "Go Programming Language Support" \
        "Starship Prompt Enhancements" \
        "System Information Utilities" \
        "Tailscale Virtual Networking" \
        "Local LLMs powered by Ollama" \
        "Terminal AI Coding Agents" \
        "Terminal Multiplexer")
    for PKG_OPTION in "${PKG_OPTIONS[@]}"; do
        case $PKG_OPTION in
            "Node.js Support and Package Management")
                gum style --foreground 57 --padding "1 1" "Installing node.js support and npm from Debian package repositories..."
                sleep 1
                if ! $SUDO_CMD apt install -y nodejs npm; then
                    echo " Warning: Failed to install nodejs and npm."
                else
                    gum style --foreground 212 --padding "1 1" "Node.js support and npm have been installed."
                fi
                ;;
            "Python Programming Language Support")
                gum style --foreground 57 --padding "1 1" "Installing python support from Debian package repositories..."
                sleep 1
                if ! $SUDO_CMD apt install -y python3 python3-pip python3-dev python3-venv build-essential; then
                    echo " Warning: Failed to install nodejs and npm."
                else
                    gum style --foreground 212 --padding "1 1" "Python support has been installed."
                fi
                ;;
            "Go Programming Language Support")
                gum style --foreground 57 --padding "1 1" "Installing go language support from Debian package repositories..."
                sleep 1
                if ! $SUDO_CMD apt-get install -y golang; then
                    echo " Error: Failed to install golang."
                else
                    gum style --foreground 212 --padding "1 1" "Go language support has been installed."
                fi
                ;;
            "Starship Prompt Enhancements")
                gum style --foreground 57 --padding "1 1" "Installing starship prompt enhancements..."
                sleep 1
                if command -v starship &> /dev/null; then
                    echo " Info: Starship is already installed."
                else
                    if ! curl -sS https://starship.rs/install.sh | sh -s -- -y; then
                        echo " Error: Failed to install starship."
                    fi
                fi
                if command -v starship &> /dev/null; then
                    if [ -f "$HOME/.bashrc" ]; then
                        if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
                            echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
                        fi
                    else
                        echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
                    fi
                    if [ ! -d "$HOME/.config" ]; then
                        mkdir -p "$HOME/.config"
                    fi
                    if [ ! -f "$HOME/.config/starship.toml" ]; then
                        touch "$HOME/.config/starship.toml"
                        if command -v starship &> /dev/null; then
                            starship preset plain-text-symbols -o "$HOME/.config/starship.toml" 2>/dev/null || true
                        fi
                    fi
                    if command -v fastfetch &> /dev/null; then
                        local FASTFETCH_BLOCK='uptime; echo ""; fastfetch; echo ""; df -h'
                        if [ -f "$HOME/.bashrc" ] && ! grep -Fxq "$FASTFETCH_BLOCK" "$HOME/.bashrc"; then
                            echo "$FASTFETCH_BLOCK" >> "$HOME/.bashrc"
                        fi
                    fi

                    gum style --foreground 212 --padding "1 1" "Starship prompt enhancements have been installed."
                else
                    echo " Error: Starship installation verification failed."
                fi
                ;;
            "System Information Utilities")
                gum style --foreground 57 --padding "1 1" "Installing system information utilities..."
                sleep 1
                if ! $SUDO_CMD apt-get install -y hwinfo sysstat; then
                    echo " Error: Failed to install system information utilities."
                else
                    gum style --foreground 212 --padding "1 1" "System information utilties have been installed."
                fi
                ;;
            "Tailscale Virtual Networking")
                gum style --foreground 57 --padding "1 1" "Installing Tailscale virtual networking..."
                sleep 1
                if command -v tailscale &> /dev/null; then
                    echo " Info: Tailscale is already installed."
                else
                    if ! curl -fsSL https://tailscale.com/install.sh | sh; then
                        echo " Error: Failed to install Tailscale."
                    fi
                fi
                if command -v tailscale &> /dev/null; then
                    gum style --foreground 57 --padding "1 1" "Prompting for Tailscale activation..."
                    $USE_SUDO tailscale up --qr
                    if gum confirm "Do you want this environment to be an exit node?"; then
                        $USE_SUDO tailscale set --advertise-exit-node=true
                        echo 'net.ipv4.ip_forward = 1' | $USE_SUDO tee -a /etc/sysctl.d/99-tailscale.conf
                        echo 'net.ipv6.conf.all.forwarding = 1' | $USE_SUDO tee -a /etc/sysctl.d/99-tailscale.conf
                        $USE_SUDO sysctl -p /etc/sysctl.d/99-tailscale.conf
                    else
                        $USE_SUDO tailscale set --advertise-exit-node=false
                    fi
                    $USE_SUDO tailscale set --accept-routes=false
                    $USE_SUDO tailscale set --accept-dns=false
                    gum style --foreground 212 --padding "1 1" "Tailscale virtual networking has been installed."
                else
                    echo " Warning: Tailscale installation verification failed."
                fi
                ;;
           "Local LLMs powered by Ollama")
                gum style --foreground 57 --padding "1 1" "Installing Ollama for Local LLM use..."
                sleep 1
                if command -v ollama &> /dev/null; then
                    echo " Info: Ollama is already installed."
                else
                    if ! curl -fsSL https://ollama.com/install.sh | sh; then
                        echo " Error: Failed to install Ollama."
                    fi
                fi
                if command -v ollama &> /dev/null; then
                    gum style --foreground 212 --padding "1 1" "Ollama for Local LLM use has been installed."
                else
                    echo " Warning: Ollama installation verification failed."
                fi
                ;;
            "Terminal AI Coding Agents")
                gum style --foreground 57 --padding "1 1" "Installing Terminal AI Coding Agents..."
                sleep 1
                if ! command -v npm &> /dev/null; then
                    echo " Installing npm first..."
                    if ! $SUDO_CMD apt-get install -y npm; then
                        echo " Error: Failed to install npm."
                    fi
                fi
                gum style --foreground 212 --padding "1 1" "Choose which coding agents to install:"
                local -a AGENT_OPTIONS=()
                while IFS= read -r option; do
                    AGENT_OPTIONS+=("$AGENT_OPTION")
                done < <(gum choose --no-limit \
                    "Claude Code" \
                    "Codex CLI from OpenAI" \
                    "Google Gemini CLI" \
                    "Opencode from SST" \
                    "Charm Crush" \
                    "Github Copilot CLI")
                for PKG_OPTION in "${PKG_OPTIONS[@]}"; do
                    case $PKG_OPTION in
                        "Claude Code")
                            gum style --foreground 57 --padding "1 1" "Installing Claude Code..."
                            if command -v claude &> /dev/null; then
                                echo " Info: Claude Code is already installed."
                            else
                                if ! curl -fsSL https://claude.ai/install.sh | bash; then
                                    echo " Error: Failed to install Claude Code."
                                fi
                            fi
                            if command -v claude &> /dev/null; then
                                gum style --foreground 212 --padding "1 1" "Claude Code has been installed."
                            else
                                echo " Warning: Claude Code installation verification failed."
                            fi
                            ;;
                        "Codex from OpenAI")
                            gum style --foreground 57 --padding "1 1" "Installing Codex..."
                            if command -v npm &> /dev/null; then
                                if ! $SUDO_CMD npm install -g @openai/codex 2>/dev/null; then
                                    echo " Warning: Failed to install codex via npm."
                                else
                                    if command -v codex &> /dev/null; then
                                        gum style --foreground 212 --padding "1 1" "Codex has been installed."
                                    fi
                                fi
                            else
                                echo " Warning: npm not available, cannot install codex."
                            fi
                            ;;
                        "Google Gemini CLI")
                            gum style --foreground 57 --padding "1 1" "Installing Gemini..."
                            if command -v npm &> /dev/null; then
                                if ! $SUDO_CMD npm install -g @google/gemini-cli 2>/dev/null; then
                                    echo " Warning: Failed to install gemini via npm."
                                else
                                    if command -v gemini &> /dev/null; then
                                        gum style --foreground 212 --padding "1 1" "Gemini has been installed."
                                    fi
                                fi
                            else
                                echo " Warning: npm not available, cannot install gemini."
                            fi
                            ;;
                        "Opencode from SST")
                            gum style --foreground 57 --padding "1 1" "Installing Opencode..."
                            if command -v npm &> /dev/null; then
                                if ! $SUDO_CMD npm install -g opencode-ai@latest 2>/dev/null; then
                                    echo " Warning: Failed to install opencode-ai via npm."
                                else
                                    if command -v opencode &> /dev/null; then
                                        gum style --foreground 212 --padding "1 1" "Opencode has been installed."
                                    fi
                                fi
                            else
                                echo " Warning: npm not available, cannot install opencode."
                            fi
                            ;;
                        "Charm Crush")
                            gum style --foreground 57 --padding "1 1" "Installing Crush from Charm..."
                            if ! $SUDO_CMD apt-get install -y crush; then
                                echo " Warning: Failed to install crush via apt."
                            else
                                gum style --foreground 212 --padding "1 1" "Charm Crush has been installed."
                            fi
                            ;;
                        "Github Copilot CLI")
                            gum style --foreground 57 --padding "1 1" "Installing Copilot CLI..."
                            if command -v copilot &> /dev/null; then
                                echo " Info: Copilot CLI is already installed."
                            else
                                if ! curl -fsSL https://gh.io/copilot-install | bash; then
                                    echo " Error: Failed to install Copilot CLI."
                                fi
                            fi
                            if command -v claude &> /dev/null; then
                                gum style --foreground 212 --padding "1 1" "Copilot CLI has been installed."
                            else
                                echo " Warning: Copilot CLI installation verification failed."
                            fi
                            ;;
                        *)
                            gum style --foreground 57 --padding "1 1" "No coding agents selected, skipping..."
                            sleep 1
                            ;;
                    esac
                done
            "Terminal Multiplexer")
                gum style --foreground 57 --padding "1 1" "Installing tmux from Debian package repositories..."
                sleep 1
                if ! $SUDO_CMD apt-get install -y tmux; then
                    echo " Error: Failed to install tmux."
                else
                    if command -v tmux &> /dev/null; then
                        gum style --foreground 212 --padding "1 1" "Tmux has been installed."
                    else
                        echo " Warning: tmux installed but command not found."
                    fi
                fi
                ;;
            *)
                gum style --foreground 57 --padding "1 1" "No package groups selected, skipping..."
                sleep 1
                ;;
        esac
    done
}

menu_main() {
    gum style --foreground 212 --padding "1 1" "Sidekick - A configuration and update tool for a Debian headless environment"
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
