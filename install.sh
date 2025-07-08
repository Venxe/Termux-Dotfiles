#!/data/data/com.termux/files/usr/bin/bash
set -e

# ---- Helper Functions ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; }

# ---- Required Packages ----
PACKAGES=(
    tigervnc
    xfce4
    xfce4-goodies
    fish
    starship
)

# ---- Functions ----

enable_x11_repo() {
    if ! pkg list-all | grep -q xfce4; then
        info "Enabling x11-repo..."
        pkg install -y x11-repo
    else
        info "x11-repo already enabled, skipping."
    fi
}

install_packages() {
    info "Installing required packages..."
    pkg update -y
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v "${pkg%% *}" >/dev/null 2>&1; then
            pkg install -y "$pkg"
        else
            info "$pkg is already installed, skipping."
        fi
    done
}

setup_config_files() {
    info "Copying dotfiles..."

    mkdir -p ~/.config/fish
    cp -f .config/fish/config.fish ~/.config/fish/config.fish

    mkdir -p ~/.config
    cp -f .config/starship.toml ~/.config/starship.toml
}

setup_vnc() {
    info "Configuring VNC xstartup file..."

    mkdir -p ~/.vnc
    cp -f .vnc/xstartup ~/.vnc/xstartup
    chmod +x ~/.vnc/xstartup
}

set_default_shell() {
    info "Setting default shell to fish..."
    if chsh -s fish; then
        info "Default shell successfully changed to fish."
    else
        warn "Could not change shell automatically. Please run 'chsh -s fish' manually."
    fi
}

print_final_message() {
    echo -e "\n✅ Installation complete!"
    echo "To start VNC session, run:"
    echo "  vncserver"
    echo -e "\nIn your VNC client, connect to: localhost:5901"
}

# ---- Main ----
main() {
    enable_x11_repo
    install_packages
    setup_config_files
    setup_vnc
    set_default_shell
    print_final_message
}

main "$@"
