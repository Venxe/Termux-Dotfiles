#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

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
  while read -r pkg; do
    [[ -z $pkg || $pkg =~ ^# ]] && continue
    if pkg list-installed | grep -qx "$pkg"; then
      info "Skipping already-installed pkg: $pkg"
    else
      info "Installing pkg: $pkg"
      pkg install -y "$pkg" || error_exit "Failed to install Termux pkg: $pkg"
    fi
  done < "$pkgfile"
}

setup_proot_distro() {
  for prog in proot-distro curl; do
    if command -v $prog >/dev/null; then
      info "Skipping already-installed: $prog"
    else
      info "Installing: $prog"
      pkg install -y $prog || error_exit "Failed to install Termux pkg: $prog"
    fi
  done
}

install_arch_linux() {
  if proot-distro list | grep -q '^archlinux'; then
    info "Arch Linux is already installed. Skipping installation."
  else
    info "Installing Arch Linux distribution..."
    if ! proot-distro install archlinux; then
      info "Warning: Arch Linux installation may already exist or failed, continuing..."
    fi
  fi
}

update_arch_mirrors() {
  info "Enabling community repo and updating Arch mirrorlist..."

  local TMP_SCRIPT="/tmp/update-mirrors.sh"
  cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

sed -i "/^\[community\]/,/^Include/s/^#//" /etc/pacman.conf
sed -i "/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//" /etc/pacman.conf
sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf

pacman -Syu --noconfirm

pacman -S --noconfirm reflector || echo "[WARNING] reflector installation failed"

reflector --country "US,DE,TR,GR" --latest 10 --sort age --protocol https \
  --save /etc/pacman.d/mirrorlist || echo "[WARNING] Mirror optimization failed!"
EOF

  chmod +x "$TMP_SCRIPT"

  proot-distro login archlinux -- bash -c "bash $TMP_SCRIPT" \
    || error_exit "Failed to update Arch mirrorlist."

  rm -f "$TMP_SCRIPT"
}

install_arch_packages() {
  local pacfile="installers/packages/pacman-packages.txt"
  [[ -f $pacfile ]] || error_exit "Arch package list not found: $pacfile"

  info "Copying Arch package list into Arch root..."
  proot-distro login archlinux -- bash -c "cat > /root/pacman-packages.txt" < "$pacfile" \
    || error_exit "Failed to copy package list into Arch Linux"

  info "Installing Arch packages from $pacfile..."

  local TMP_SCRIPT="/tmp/install-packages.sh"
  cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

pacman -Sy --noconfirm

while read -r pkg; do
  [[ -z $pkg || $pkg =~ ^# ]] && continue
  if pacman -Qi $pkg &>/dev/null; then
    echo "[INFO] Skipping already-installed: $pkg"
  else
    pacman -S --needed --noconfirm $pkg || exit 1
  fi
done < /root/pacman-packages.txt
EOF

  chmod +x "$TMP_SCRIPT"

  proot-distro login archlinux -- bash -c "bash $TMP_SCRIPT" \
    || error_exit "Failed to install some Arch packages."

  rm -f "$TMP_SCRIPT"
}

configure_shell_and_dotfiles() {
  local ROOT
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  local CFG="${ROOT}/dotcfg/.config"

  info "Configuring Fish shell and installing Starship prompt..."

  local TMP_SCRIPT="/tmp/configure-shell.sh"
  cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

if ! grep -qx "/usr/bin/fish" /etc/shells; then
  echo "/usr/bin/fish" >> /etc/shells
fi

chsh -s /usr/bin/fish || true

if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi
EOF

  chmod +x "$TMP_SCRIPT"

  proot-distro login archlinux -- bash -c "bash $TMP_SCRIPT" \
    || error_exit "Failed to configure shell and starship."

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

  local TMP_SCRIPT="/tmp/start-vnc.sh"
  cat > "$TMP_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

if vncserver -list | grep -q "^:1"; then
  echo "[INFO] VNC :1 is already running"
else
  vncserver -geometry 1280x720 -depth 24 :1
fi
EOF

  chmod +x "$TMP_SCRIPT"

  proot-distro login archlinux -- bash -c "bash $TMP_SCRIPT" \
    || error_exit "Failed to start VNC server."

  rm -f "$TMP_SCRIPT"
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
