#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Determine Script Directory ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_ARCH_SH="$HOME/start-arch.sh"
ARCH_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/archlinux/root"

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

copy_dotfiles_to_arch() {
    info "Copying dotfiles into Arch Linux rootfs..."

    mkdir -p "$ARCH_ROOTFS/.config/fish"
    mkdir -p "$ARCH_ROOTFS/.vnc"

    # Copy Fish config
    if [ -f "$HOME/.config/fish/config.fish" ]; then
        cp -f "$HOME/.config/fish/config.fish" "$ARCH_ROOTFS/.config/fish/config.fish"
    else
        warn "Fish config not found."
    fi

    # Copy Starship config
    if [ -f "$HOME/.config/starship.toml" ]; then
        cp -f "$HOME/.config/starship.toml" "$ARCH_ROOTFS/.config/starship.toml"
    else
        warn "Starship config not found."
    fi

    # Copy VNC xstartup
    if [ -f "$HOME/.vnc/xstartup" ]; then
        cp -f "$HOME/.vnc/xstartup" "$ARCH_ROOTFS/.vnc/xstartup"
        chmod +x "$ARCH_ROOTFS/.vnc/xstartup"
    else
        warn "VNC xstartup file not found."
    fi
}

arch_install_and_configure() {
    info "Configuring packages inside Arch Linux..."
    "$START_ARCH_SH" <<'EOF'
set -euo pipefail

# ---- Helper Function ----
info() { echo -e "\e[1;32m[INFO]\e[0m $1"; }

PACKAGES=(
    fish
    starship
    xfce4
    xfce4-goodies
    tigervnc
)

info "Updating package database..."
pacman -Syu --noconfirm

info "Installing required packages..."
for pkg in "${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "$pkg"
done

info "Setting default shell to fish..."
chsh -s /usr/bin/fish || echo "[WARN] Could not change shell automatically."
EOF
}

cleanup_dotfiles() {
    info "Cleaning up Termux-Dotfiles..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Dotfiles directory removed."
}

print_final_message() {
    echo -e "\n✅ Installation and configuration complete!"
    echo "To start Arch Linux shell: $START_ARCH_SH"
    echo "To launch VNC session inside Arch:"
    echo "  $START_ARCH_SH -c 'vncserver :1'"
    echo -e "\nThen connect your VNC client to: localhost:5901"
}

main() {
    bootstrap_termux
    install_arch_linux
    copy_dotfiles_to_arch
    arch_install_and_configure
    cleanup_dotfiles
    print_final_message
}

main "$@"
