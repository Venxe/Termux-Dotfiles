#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Color definitions using ANSI escape codes (avoid tput dependency)
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

info() {
  printf "%b[INFO]%b %s\n" "$CYAN" "$RESET" "$1"
}

error_exit() {
  printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$1" >&2
  exit 1
}

update_and_install_termux_pkgs() {
  local pkgfile="installers/packages/pkg-packages.txt"
  [[ -f $pkgfile ]] || error_exit "Termux package list not found: $pkgfile"

  info "Updating Termux package repository..."
  pkg update -y || error_exit "Failed to update Termux packages."

  info "Installing Termux packages from $pkgfile..."
  xargs -r pkg install -y < "$pkgfile" \
    || error_exit "Failed to install some Termux packages."
}

setup_proot_distro() {
  info "Ensuring proot-distro and curl are installed..."
  pkg install -y proot-distro curl \
    || error_exit "Failed to install proot-distro or curl."
}

install_arch_linux() {
  info "Installing Arch Linux distribution..."
  proot-distro install archlinux \
    || error_exit "Arch Linux installation failed."
}

update_arch_mirrors() {
  info "Updating Arch mirrorlist and package database..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    sed -i "/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
    pacman -Syu --noconfirm
    pacman -S --noconfirm reflector
    reflector --country "US,DE,TR,GR" --latest 10 --sort age --protocol https \
      --save /etc/pacman.d/mirrorlist || echo "[WARNING] Mirror optimization failed!"
  '
}

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
  mkdir -p "${HOME}/.config/fish"
  cp "${CFG}/fish/config.fish" "${HOME}/.config/fish/" \
    || error_exit "Failed to copy Fish config."

  mkdir -p "${HOME}/.config"
  cp "${CFG}/starship.toml" "${HOME}/.config/" \
    || error_exit "Failed to copy Starship config."

  mkdir -p "${HOME}/.vnc"
  cp "${ROOT}/vnc/xstartup" "${HOME}/.vnc/xstartup" \
    || error_exit "Failed to copy VNC xstartup."
  chmod +x "${HOME}/.vnc/xstartup"

  mkdir -p "${HOME}/.config/xfce4/terminal"
  cp "${ROOT}/xfce4/terminalrc" "${HOME}/.config/xfce4/terminal/" \
    || error_exit "Failed to copy XFCE4 terminal config."
}

start_vnc_server() {
  info "Starting TigerVNC server on display :1..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    vncserver -geometry 1280x720 -depth 24 :1
  ' || error_exit "Failed to start VNC server."
}

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
