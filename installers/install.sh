#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ANSI color codes
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
  [[ -f $pkgfile ]] || error_exit "Missing: $pkgfile"

  info "Updating Termux packages..."
  pkg update -y || error_exit "Failed to update pkg list."

  info "Installing Termux packages..."
  while read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    if pkg list-installed | grep -q "^$pkg"; then
      info "Termux pkg already installed: $pkg"
    else
      pkg install -y "$pkg" || error_exit "Failed to install pkg: $pkg"
    fi
  done < "$pkgfile"
}

setup_proot_distro() {
  for prog in proot-distro curl; do
    if ! command -v "$prog" &>/dev/null; then
      info "Installing missing Termux package: $prog"
      pkg install -y "$prog" || error_exit "Failed to install: $prog"
    fi
  done
}

install_arch_linux() {
  if proot-distro list | grep -q '^archlinux'; then
    info "Arch Linux already installed. Skipping."
  else
    info "Installing Arch Linux..."
    proot-distro install archlinux || error_exit "Failed to install Arch Linux."
  fi
}

update_arch_mirrors() {
  info "Updating Arch mirrorlist and system..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail

    sed -i "/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
    pacman -Syu --noconfirm

    if ! pacman -Qi reflector &>/dev/null; then
      pacman -S --noconfirm reflector
    fi

    reflector --country "US,DE,TR,GR" --latest 10 --sort age --protocol https \
      --save /etc/pacman.d/mirrorlist || echo "[WARNING] Reflector failed."
  '
}

install_arch_packages() {
  local pacfile="installers/packages/pacman-packages.txt"
  [[ -f $pacfile ]] || error_exit "Missing: $pacfile"

  cp "$pacfile" "$HOME/" || error_exit "Failed to copy package list into home."

  info "Installing Arch packages..."
  proot-distro login archlinux -- bash -lc "
    set -euo pipefail
    while read -r pkg; do
      [[ -z \"\$pkg\" || \"\$pkg\" =~ ^# ]] && continue
      if pacman -Qi \"\$pkg\" &>/dev/null; then
        echo \"[INFO] Already installed: \$pkg\"
      else
        pacman -S --needed --noconfirm \"\$pkg\" || exit 1
      fi
    done < /root/$(basename "$pacfile")
  " || error_exit "One or more Arch packages failed to install."
}

configure_shell_and_dotfiles() {
  local ROOT
  ROOT="$(cd "$(dirname "$0")" && pwd)"
  local CFG="${ROOT}/dotcfg/.config"

  info "Setting up Fish + Starship inside Arch Linux..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    if ! grep -qx "/usr/bin/fish" /etc/shells; then
      echo "/usr/bin/fish" >> /etc/shells
    fi
    chsh -s /usr/bin/fish || true
    if ! command -v starship &>/dev/null; then
      curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
  '

  info "Copying dotfiles..."
  mkdir -p "${HOME}/.config/fish"
  cp "${CFG}/fish/config.fish" "${HOME}/.config/fish/" \
    || error_exit "Failed to copy fish config."

  cp "${CFG}/starship.toml" "${HOME}/.config/" \
    || error_exit "Failed to copy starship config."

  mkdir -p "${HOME}/.vnc"
  cp "${ROOT}/vnc/xstartup" "${HOME}/.vnc/xstartup"
  chmod +x "${HOME}/.vnc/xstartup" || error_exit "Failed to set xstartup executable."

  mkdir -p "${HOME}/.config/xfce4/terminal"
  cp "${ROOT}/xfce4/terminalrc" "${HOME}/.config/xfce4/terminal/" || true
}

start_vnc_server() {
  info "Starting VNC server on :1..."
  proot-distro login archlinux -- bash -lc '
    set -euo pipefail
    if vncserver -list | grep -q "^:1"; then
      echo "[INFO] VNC :1 already running."
    else
      vncserver -geometry 1280x720 -depth 24 :1
    fi
  ' || error_exit "VNC server failed to start."
}

show_completion() {
  printf "\n%b[✔] Setup completed successfully!%b\n\n" "$GREEN" "$RESET"
  cat << EOF
🎉 XFCE4 Desktop is ready on VNC display :1

  • Connect to: localhost:5901
  • Use your VNC client with password (set on first run)

🖥️  Enter Arch Linux again:
  proot-distro login archlinux

🛑  Stop VNC server:
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
