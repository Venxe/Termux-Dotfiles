#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

info()  { printf "\e[1;32m[INFO]\e[0m %s\n" "$1"; }
warn()  { printf "\e[1;33m[WARN]\e[0m %s\n" "$1"; }
error() { printf "\e[1;31m[ERROR]\e[0m %s\n" "$1" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

update_termux() {
    info "Updating Termux packages"
    pkg update -y && pkg upgrade -y
}

install_proot_and_arch() {
    info "Installing proot-distro"
    pkg install -y proot-distro || error "Failed to install proot-distro"

    info "Installing Arch Linux (if absent)"
    if ! proot-distro install archlinux; then
        warn "Arch Linux installation skipped or already present"
    else
        info "Arch Linux installed"
    fi
}

configure_arch() {
    info "Configuring Arch environment"
    proot-distro login archlinux -- env HOST_DOTFILES="$SCRIPT_DIR" bash -s <<'EOF'
set -euo pipefail

info()  { printf "\e[1;32m[INFO]\e[0m %s\n" "\$1"; }
warn()  { printf "\e[1;33m[WARN]\e[0m %s\n" "\$1"; }
error() { printf "\e[1;31m[ERROR]\e[0m %s\n" "\$1" >&2; exit 1; }

DOTFILES="\$HOST_DOTFILES"
PKG_LIST="\$DOTFILES/installers/packages/pacman-packages.txt"

info "Updating package database"
pacman -Syu --noconfirm

if [[ ! -r "\$PKG_LIST" ]]; then
    error "Package list not found: \$PKG_LIST"
fi

mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "\$PKG_LIST")

info "Installing packages"
for pkg in "\${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "\$pkg"
done

info "Copying configs"
mkdir -p ~/.config/fish ~/.config
cp -f "\$DOTFILES/.config/fish/config.fish" ~/.config/fish/
cp -f "\$DOTFILES/.config/starship.toml" ~/.config/

info "Copying VNC startup script"
mkdir -p ~/.vnc
cp -f "\$DOTFILES/.vnc/xstartup" ~/.vnc/
chmod +x ~/.vnc/xstartup

info "Setting default shell to fish"
chsh -s /usr/bin/fish || warn "Run 'chsh -s /usr/bin/fish' manually"

info "Disabling fish keyboard protocols feature"
fish -c "set -Ua fish_features no-keyboard-protocols" \
  && info "fish_features updated" \
  || warn "Please set fish_features manually"

info "Arch configuration complete"
EOF
}

cleanup() {
    info "Removing dotfiles directory"
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
}

print_summary() {
    cat <<MSG

✅ Setup complete!

Enter Arch:
    proot-distro login archlinux

Inside Arch, start VNC:
    vncserver :1

Connect to:
    localhost:5901

MSG
}

main() {
    update_termux
    install_proot_and_arch
    configure_arch
    cleanup
    print_summary
}

main "$@"
