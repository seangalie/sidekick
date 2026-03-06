# Sidekick

### A configuration and update tool for a Debian headless environment

This script is designed to help configure and update Debian 12 (Bookworm)
and Debian 13 (Trixie) headless instances such as remote servers, home lab
images, container environments, and virtual machines.

Common packages installed by this script include: apt-transport-https, btop,
build-essential, bwm-ng, ca-certificates, cmake, cmatrix, curl, debian-goodies,
duf, fastfetch, git, glances, gping, gum, htop, iotop, locate, iftop, jq, make,
multitail, nano, needrestart, net-tools, p7zip, p7zip-full, sudo, tar, tldr-py,
tree, unzip, vnstat, and wget.

Optional packages offered in the interactive portions of this script include:
claude, codex, copilot, crush, fail2ban, gemini, golang, hwinfo, nodejs, npm,
ollama, opencode, python3, python3-dev, python3-pip, python3-venv, starship,
sysstat, tailscale, and tmux.

## Usage

* **`sidekick.sh`**: The script with no command flags will open a menu of choices
    to setup, configure, update, or upgrade a Debian headless environment.

* **`sidekick.sh --update`**: Using the _--update_ flag will run an automatic update
    script that will check apt, npm, and other installed package managers for
    updated information and upgraded installed packages with their dependencies.

* **`sidekick.sh --setup`**: Using the _--setup_ flag will run an automated setup
    script that will install the basic packages and the these optional packages:
    starship, hwinfo, and systat.

* **`sidekick.sh --prompt`**: The _--prompt_ flag will run the configuration
    scripts for starship and add the prompt enhancements to the local user's
    bash environment.

* **`sidekick.sh --secure`**: The _--secure_ flag will run the script for
    securing a headless environment and offer assistance in setting up a local
    firewall, installing fail2ban, and configuring useful services.

* **`sidekick.sh --upgrade`**: Using the _--upgrade_ flag will run the assistant
    to help upgrade a Debian 12 Bookworm environment to Debian 13 Trixie.

### License

Licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)
