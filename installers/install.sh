#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Color definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

info() {
  printf "%b[INFO]%b %s\n" "$CYAN" "$RESET" "$1"
}

error_exit() {
  printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$1" >&2
  exit 1
}

# 1) Update Termux pkg and install Termux-level packages
update_and_install_termux_pkgs() {
  local pkgfile="installers/packages/pkg-packages.txt"
  [[ -f $pkgfile ]] || error_exit "Termux package list not found: $pkgfile"

  info "Updating Termux package repository..."
  pkg update -y || error_exit "Failed to update Termux packages."

  info "Installing Termux packages from $pkgfile..."
  xargs -r pkg install -y < "$pkgfile" \
    || error_exit "Failed to install some Termux packages."
}

# 2) Install proot-distro and curl
setup_proot_distro() {
  info "Ensuring proot-distro and curl are installed..."
  pkg install -y proot-distro curl \
    || error_exit "Failed to install proot-distro or curl."
}

# 3) Install Arch Linux in proot-distro
install_arch_linux() {
  info "Installing Arch Linux distribution..."
  proot-distro install archlinux \
    || error_exit "Arch Linux installation failed."
}

# 4) Update mirrors inside Arch and install reflector
update_arch_mirrors() {
  info "Updating Arch mirrorlist and package database..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail

    # Enable [multilib]
    sed -i "/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//" /etc/pacman.conf

    # Enable ParallelDownloads
    sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf

    # Full system upgrade
    pacman -Syu --noconfirm

    # Install reflector
    pacman -S --noconfirm reflector

    # Optimize mirrorlist
    reflector --country "US,DE,TR,GR" --latest 10 --sort age --protocol https \
      --save /etc/pacman.d/mirrorlist || echo "[WARNING] Mirror optimization failed!"
  '
}

# 5) Install Arch packages from list
install_arch_packages() {
  local pacfile="installers/packages/pacman-packages.txt"
  [[ -f $pacfile ]] || error_exit "Arch package list not found: $pacfile"

  info "Copying Arch package list into Arch root..."
  cp "$pacfile" "$HOME/" || error_exit "Failed to copy $pacfile into home."

  info "Installing Arch packages from $pacfile..."
  proot-distro login archlinux -- bash -lc "
    set -euo pipefail
    pacman -Sy --noconfirm
    xargs -r pacman -S --needed --noconfirm < /root/$(basename "$pacfile")
  " || error_exit "Failed to install some Arch packages."
}

# 6) Configure shell, prompt, dotfiles and VNC xstartup
configure_shell_and_dotfiles() {
  local ROOT
  ROOT="$(cd "$(dirname "$0")" && pwd)"
  local CFG="${ROOT}/dotcfg/.config"

  info "Configuring Fish shell and installing Starship prompt..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    chsh -s /usr/bin/fish || true
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  '

  info "Deploying configuration files to \$HOME..."
  # Fish
  mkdir -p "${HOME}/.config/fish"
  cp "${CFG}/fish/config.fish" "${HOME}/.config/fish/" \
    || error_exit "Failed to copy Fish config."

  # Starship
  mkdir -p "${HOME}/.config"
  cp "${CFG}/starship.toml" "${HOME}/.config/" \
    || error_exit "Failed to copy Starship config."

  # VNC xstartup
  mkdir -p "${HOME}/.vnc"
  cp "${ROOT}/vnc/xstartup" "${HOME}/.vnc/xstartup" \
    || error_exit "Failed to copy VNC xstartup."
  chmod +x "${HOME}/.vnc/xstartup"

  # XFCE4 terminal
  mkdir -p "${HOME}/.config/xfce4/terminal"
  cp "${ROOT}/xfce4/terminalrc" "${HOME}/.config/xfce4/terminal/" \
    || error_exit "Failed to copy XFCE4 terminal config."
}

# 7) Start VNC server (which will invoke .vnc/xstartup)
start_vnc_server() {
  info "Starting TigerVNC server on display :1..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    vncserver -geometry 1280x720 -depth 24 :1
  ' || error_exit "Failed to start VNC server."
}

# 8) Show completion instructions
show_completion() {
  printf "\n%b[✔] Setup completed successfully!%b\n\n" "$GREEN" "$RESET"
  cat << EOF
You can now connect to your new XFCE4 desktop via VNC:
  • Server: localhost:5901
  • Password: (set on first vncserver run)

To re-enter your Arch environment later:
  proot-distro login archlinux

To stop the VNC server:
  proot-distro login archlinux -- bash -lc "vncserver -kill :1"
EOF
}

main() {
  update_and_install_termux_pkgs
  setup_proot_distro
  install_arch_linux
  update_arch_mirrors
  install_arch_packages
  configure_shell_and_dotfiles
  start_vnc_server
  show_completion
}

main "$@"
