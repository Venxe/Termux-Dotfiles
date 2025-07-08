#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Script Paths ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_ARCH_SH="$HOME/start-arch.sh"

# ---- Termux Bootstrap & Arch Installation ----

bootstrap_termux() {
    info "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
}

install_arch_linux() {
    info "Installing proot-distro..."
    pkg install -y proot-distro || error "Failed to install proot-distro"

    info "Installing Arch Linux distribution..."
    if ! proot-distro install archlinux; then
        warn "Arch Linux is already installed or installation failed; continuing anyway."
    else
        info "Arch Linux installed successfully."
    fi

    info "Creating Arch launch script..."
    cat > "$START_ARCH_SH" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login archlinux -- bash "\$@"
EOF
    chmod +x "$START_ARCH_SH"
}

# ---- Arch Configuration ----

arch_install_and_configure() {
    info "Entering Arch for package installation and configuration..."
    "$START_ARCH_SH" <<'EOF'
set -euo pipefail

info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }

PACKAGES=(
    fish
    starship
    xfce4
    xfce4-goodies
    tigervnc
)

info "Updating Arch packages..."
pacman -Syu --noconfirm

info "Installing required packages..."
for pkg in "${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "$pkg"
done

info "Copying dotfiles from Termux to Arch..."

if [ -f /data/data/com.termux/files/home/.config/fish/config.fish ]; then
    mkdir -p ~/.config/fish
    cp -f /data/data/com.termux/files/home/.config/fish/config.fish ~/.config/fish/config.fish
else
    warn "Fish config not found."
fi

if [ -f /data/data/com.termux/files/home/.config/starship.toml ]; then
    mkdir -p ~/.config
    cp -f /data/data/com.termux/files/home/.config/starship.toml ~/.config/starship.toml
else
    warn "Starship config not found."
fi

if [ -f /data/data/com.termux/files/home/.vnc/xstartup ]; then
    mkdir -p ~/.vnc
    cp -f /data/data/com.termux/files/home/.vnc/xstartup ~/.vnc/xstartup
    chmod +x ~/.vnc/xstartup
else
    warn "VNC xstartup file not found."
fi

info "Setting fish as default shell..."
chsh -s /usr/bin/fish || warn "chsh failed; run 'chsh -s /usr/bin/fish' manually if needed."

info "Arch configuration complete."
EOF
}

# ---- Cleanup ----

cleanup_dotfiles() {
    info "Cleaning up Termux-Dotfiles..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Dotfiles directory removed."
}

# ---- Final Message ----

print_final_message() {
    echo -e "\n✅ Installation and configuration complete!"
    echo "To start Arch Linux shell: $START_ARCH_SH"
    echo "To launch VNC session inside Arch:"
    echo "  $START_ARCH_SH -c 'vncserver :1'"
    echo -e "\nThen connect your VNC client to: localhost:5901"
}

# ---- Main ----

main() {
    bootstrap_termux
    install_arch_linux
    arch_install_and_configure
    cleanup_dotfiles
    print_final_message
}

main "$@"
