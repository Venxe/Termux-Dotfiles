#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helpers ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Paths ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_ARCH_SH="$HOME/start-arch.sh"

# ---- Termux Bootstrap & Arch Install ----

bootstrap_termux() {
    info "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
}

install_arch_linux() {
    info "Ensuring proot-distro is installed..."
    pkg install -y proot-distro || error "proot-distro installation failed"

    info "Installing Arch Linux (if absent)..."
    if ! proot-distro install archlinux; then
        warn "Arch Linux already installed or install failed; continuing."
    else
        info "Arch Linux installed."
    fi

    info "Writing Arch launch script to $START_ARCH_SH..."
    cat > "$START_ARCH_SH" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login archlinux -- bash "\$@"
EOF
    chmod +x "$START_ARCH_SH"
}

# ---- Inside Arch: Configure ----

arch_install_and_configure() {
    info "Entering Arch environment for setup..."
    SCRIPT_DIR="$SCRIPT_DIR" "$START_ARCH_SH" <<'EOF'
set -euo pipefail

info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }

# ---- Variables ----
HOST_DOTFILES="${SCRIPT_DIR:-/data/data/com.termux/files/home/Termux-Dotfiles}"
PACKAGES=(fish starship xfce4 xfce4-goodies tigervnc)

info "Updating Arch and installing packages..."
pacman -Syu --noconfirm
pacman -S --noconfirm --needed "${PACKAGES[@]}"

info "Copying user configs..."
mkdir -p ~/.config/fish ~/.config
cp -f "$HOST_DOTFILES/.config/fish/config.fish" ~/.config/fish/
cp -f "$HOST_DOTFILES/.config/starship.toml" ~/.config/

info "Copying VNC xstartup..."
mkdir -p ~/.vnc
cp -f "$HOST_DOTFILES/.vnc/xstartup" ~/.vnc/
chmod +x ~/.vnc/xstartup

info "Setting default shell to fish..."
chsh -s /usr/bin/fish || warn "Please run 'chsh -s /usr/bin/fish' manually."

info "Disabling fish keyboard protocols feature..."
fish -c "set -Ua fish_features no-keyboard-protocols" \
    && info "fish_features updated." \
    || warn "Could not set fish_features; please run manually."

info "Arch setup complete."
EOF
}

# ---- Cleanup & Finish ----

cleanup_dotfiles() {
    info "Removing Termux-Dotfiles directory..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Cleanup done."
}

print_final_message() {
    cat <<MSG

✅ Installation and configuration complete!

• Start Arch shell:   $START_ARCH_SH
• Launch VNC inside: $START_ARCH_SH -c 'vncserver :1'
• Connect VNC client to: localhost:5901

MSG
}

main() {
    bootstrap_termux
    install_arch_linux
    arch_install_and_configure
    cleanup_dotfiles
    print_final_message
}

main "$@"
