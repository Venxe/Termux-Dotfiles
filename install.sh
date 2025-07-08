#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Paths ----
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
        warn "Arch Linux already installed or installation failed; continuing."
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
    info "Copying dotfiles from Termux-Dotfiles to Arch rootfs..."

    local dotfiles_dir="$SCRIPT_DIR"

    mkdir -p "$ARCH_ROOTFS/.config/fish"
    mkdir -p "$ARCH_ROOTFS/.config"
    mkdir -p "$ARCH_ROOTFS/.vnc"

    if [ -f "$dotfiles_dir/.config/fish/config.fish" ]; then
        cp -f "$dotfiles_dir/.config/fish/config.fish" "$ARCH_ROOTFS/.config/fish/config.fish"
        touch "$ARCH_ROOTFS/.config/fish/config.fish"
    else
        warn "Fish config not found in Termux-Dotfiles."
    fi

    if [ -f "$dotfiles_dir/.config/starship.toml" ]; then
        cp -f "$dotfiles_dir/.config/starship.toml" "$ARCH_ROOTFS/.config/starship.toml"
        touch "$ARCH_ROOTFS/.config/starship.toml"
    else
        warn "Starship config not found in Termux-Dotfiles."
    fi

    if [ -f "$dotfiles_dir/.vnc/xstartup" ]; then
        cp -f "$dotfiles_dir/.vnc/xstartup" "$ARCH_ROOTFS/.vnc/xstartup"
        chmod +x "$ARCH_ROOTFS/.vnc/xstartup"
        touch "$ARCH_ROOTFS/.vnc/xstartup"
    else
        warn "VNC xstartup file not found in Termux-Dotfiles."
    fi
}

arch_install_and_configure() {
    info "Entering Arch environment for package installation and configuration..."
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

info "Updating Arch package database..."
pacman -Syu --noconfirm

info "Installing required packages..."
for pkg in "${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "$pkg"
done

info "Setting default shell to fish..."
chsh -s /usr/bin/fish || warn "Could not change shell automatically; run 'chsh -s /usr/bin/fish' manually if needed."

info "Arch Linux configuration complete."
EOF
}

cleanup_dotfiles() {
    info "Removing Termux-Dotfiles directory..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Termux-Dotfiles directory removed."
}

print_final_message() {
    echo -e "\n✅ Installation and configuration complete!"
    echo "To start Arch Linux shell: $START_ARCH_SH"
    echo "To launch VNC session inside Arch:"
    echo "  $START_ARCH_SH -c 'vncserver :1'"
    echo -e "\nConnect your VNC client to localhost:5901"
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
