#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

info()  { printf '\e[1;32m[INFO]\e[0m %s\n' "$1"; }
warn()  { printf '\e[1;33m[WARN]\e[0m %s\n' "$1"; }
error() { printf '\e[1;31m[ERROR]\e[0m %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOTCFG_DIR="$SCRIPT_DIR/dotcfg"

update_termux() {
    info "Updating Termux packages"
    pkg update -y && pkg upgrade -y
}

install_arch() {
    info "Ensuring proot-distro is installed"
    pkg install -y proot-distro || error "Failed to install proot-distro"

    info "Installing Arch Linux if necessary"
    if ! proot-distro install archlinux; then
        warn "Arch Linux install skipped or already present"
    else
        info "Arch Linux installed"
    fi
}

configure_arch() {
    info "Configuring Arch Linux environment"
    proot-distro login archlinux -- env DOTCFG="$DOTCFG_DIR" bash -s <<'EOF'
set -euo pipefail

info()  { printf '\e[1;32m[INFO]\e[0m %s\n' "$1"; }
warn()  { printf '\e[1;33m[WARN]\e[0m %s\n' "$1"; }
error() { printf '\e[1;31m[ERROR]\e[0m %s\n' "$1" >&2; exit 1; }

PKG_LIST="$DOTCFG/installers/packages/pacman-packages.txt"

info "Updating package database"
pacman -Syu --noconfirm

if [[ ! -r "$PKG_LIST" ]]; then
    error "Cannot read package list at $PKG_LIST"
fi

mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$PKG_LIST")

info "Installing packages from list"
for pkg in "${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "$pkg"
done

info "Deploying configuration files"
cp -rf "$DOTCFG/.config" ~/
cp -rf "$DOTCFG/.vnc" ~/
chmod +x ~/.vnc/xstartup

info "Changing default shell to fish"
chsh -s /usr/bin/fish || warn "Please run 'chsh -s /usr/bin/fish' manually"

info "Disabling fish keyboard‑protocols feature"
fish -c "set -Ua fish_features no-keyboard-protocols" \
    && info "fish_features updated" \
    || warn "Please disable fish_features manually"

info "Arch Linux configuration complete"
EOF
}

configure_autologin() {
    info "Installing .bashrc for automatic Arch login"
    cp -f "$DOTCFG/.bashrc" ~/.bashrc
    info ".bashrc deployed"
}

cleanup() {
    info "Removing Termux‑Dotfiles directory"
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
}

print_summary() {
    cat <<MSG

✅ Setup complete!

• Termux will auto‑launch Arch on first shell.  
• To enter Arch manually: proot‑distro login archlinux  
• Inside Arch, start VNC: vncserver :1  
• VNC client connect to: localhost:5901

MSG
}

main() {
    update_termux
    install_arch
    configure_arch
    configure_autologin
    cleanup
    print_summary
}

main "$@"
