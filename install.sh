#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Determine Script Directory ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_ARCH_SH="$HOME/start-arch.sh"

# ---- Termux Bootstrap & Arch Installation ----

bootstrap_termux() {
    info "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
}

install_arch_linux() {
    info "Installing tools for Arch bootstrap..."
    pkg install -y proot-distro

    info "Installing Arch Linux distribution..."
    proot-distro install archlinux

    info "Generating Arch launch script..."
    cat > "$START_ARCH_SH" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login archlinux -- bash "\$@"
EOF
    chmod +x "$START_ARCH_SH"
}

# ---- Inside Arch: Package Installation & Configuration ----

arch_install_and_configure() {
    info "Entering Arch environment for configuration..."
    "$START_ARCH_SH" <<'EOF'
set -euo pipefail

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Package List ----
PACKAGES=(
    fish
    starship
    xfce4
    xfce4-goodies
    tigervnc
)

info "Updating Arch package database and upgrading..."
pacman -Syu --noconfirm

info "Installing packages in Arch..."
for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        pacman -S --noconfirm "$pkg"
    else
        info "$pkg is already installed, skipping."
    fi
done

info "Copying configuration files from Termux-Dotfiles..."
cp -f /data/data/com.termux/files/home/.config/fish/config.fish ~/.config/fish/config.fish
cp -f /data/data/com.termux/files/home/.config/starship.toml ~/.config/starship.toml

info "Copying VNC xstartup file..."
mkdir -p ~/.vnc
cp -f /data/data/com.termux/files/home/.vnc/xstartup ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup

info "Setting default shell to fish..."
chsh -s /usr/bin/fish || warn "Could not change shell automatically; please run 'chsh -s /usr/bin/fish' manually."

info "Arch configuration complete."
EOF
}

# ---- Cleanup ----

cleanup_dotfiles() {
    info "Removing Termux-Dotfiles directory..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Termux-Dotfiles directory removed."
}

# ---- Final Message ----

print_final_message() {
    echo -e "\n✅ Installation and configuration complete!"
    echo "To start Arch Linux shell: $START_ARCH_SH"
    echo "To launch VNC session inside Arch:"
    echo "  $START_ARCH_SH -c 'vncserver :1'"
    echo -e "\nConnect your VNC client to localhost:5901"
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
