#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helpers ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Determine Dotfiles Root ----
# install.sh now lives in installers/, so go up one level
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- 1) Termux Update ----
bootstrap_termux() {
    info "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
}

# ---- 2) Arch Linux Installation ----
install_arch_linux() {
    info "Ensuring proot-distro is installed..."
    pkg install -y proot-distro || error "proot-distro installation failed"

    info "Installing Arch Linux (if absent)..."
    if ! proot-distro install archlinux; then
        warn "Arch Linux already installed or installation failed; continuing."
    else
        info "Arch Linux installed successfully."
    fi
}

# ---- 3) Arch Configuration ----
arch_configure() {
    info "Entering Arch environment for setup..."
    proot-distro login archlinux -- env HOST_DOTFILES="$SCRIPT_DIR" bash -s <<'EOF'
set -euo pipefail

# ---- Helpers inside Arch ----
info()  { echo -e "\e[1;32m[INFO]\e[0m \$1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m \$1"; }

# ---- Paths & Files ----
DOTFILES="\$HOST_DOTFILES"
PKG_LIST="\$DOTFILES/installers/packages/pacman-packages.txt"

# ---- 3.1) Update & Read Package List ----
info "Updating Arch package database..."
pacman -Syu --noconfirm

if [[ ! -r "\$PKG_LIST" ]]; then
    error "Package list not found: \$PKG_LIST"
fi

# read non-empty, non-comment lines into array
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "\$PKG_LIST")

# ---- 3.2) Install Packages ----
info "Installing packages from \$PKG_LIST..."
for pkg in "\${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "\$pkg"
done

# ---- 3.3) Copy Config Files ----
info "Copying Fish and Starship configs..."
mkdir -p ~/.config/fish ~/.config
cp -f "\$DOTFILES/.config/fish/config.fish" ~/.config/fish/
cp -f "\$DOTFILES/.config/starship.toml" ~/.config/

# ---- 3.4) Copy VNC xstartup ----
info "Copying VNC xstartup..."
mkdir -p ~/.vnc
cp -f "\$DOTFILES/.vnc/xstartup" ~/.vnc/
chmod +x ~/.vnc/xstartup

# ---- 3.5) Shell & Fish Features ----
info "Changing default shell to fish..."
chsh -s /usr/bin/fish || warn "Please run 'chsh -s /usr/bin/fish' manually."

info "Disabling Fish keyboard protocols feature..."
fish -c "set -Ua fish_features no-keyboard-protocols" \
    && info "fish_features updated." \
    || warn "Please disable keyboard-protocols feature manually."

info "Arch setup complete."
EOF
}

# ---- 4) Cleanup Dotfiles ----
cleanup_dotfiles() {
    info "Removing Termux-Dotfiles directory..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Cleanup done."
}

# ---- 5) Final Message ----
print_final_message() {
    cat <<MSG

✅ All tasks completed!

• Enter Arch Linux with:  
    proot-distro login archlinux

• Once inside Arch, start VNC with:  
    vncserver :1

• In your VNC client, connect to:  
    localhost:5901

MSG
}

# ---- Main ----
main() {
    bootstrap_termux
    install_arch_linux
    arch_configure
    cleanup_dotfiles
    print_final_message
}

main "$@"
