#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Eğer Windows satır sonu varsa düzelt
# (dos2unix yoksa /data/data/com.termux/files/usr/bin/bash içerisinde çalışır)
if grep -q $'\r' "$0"; then
  sed -i 's/\r$//' "$0"
fi

# ---- Helpers ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Determine Dotfiles Root ----
# install.sh installers/ içinde, bu yüzden üst dizine çıkıyoruz
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
        warn "Arch already present or install failed; continuing."
    else
        info "Arch installed."
    fi
}

# ---- 3) Arch Configuration ----
arch_configure() {
    info "Entering Arch environment for setup..."
    # Burada "--" önemli: proot-distro args bölümünü ayırır
    proot-distro login archlinux -- \
      env HOST_DOTFILES="$SCRIPT_DIR" bash -s <<'EOF'
set -euo pipefail

info()  { echo -e "\e[1;32m[INFO]\e[0m \$1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m \$1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m \$1" >&2; exit 1; }

DOTFILES="\$HOST_DOTFILES"
PKG_LIST="\$DOTFILES/installers/packages/pacman-packages.txt"

info "Updating Arch package database..."
pacman -Syu --noconfirm

if [[ ! -r "\$PKG_LIST" ]]; then
    error "Package list not found: \$PKG_LIST"
fi

info "Reading package list..."
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "\$PKG_LIST")

info "Installing packages..."
for pkg in "\${PACKAGES[@]}"; do
    pacman -S --noconfirm --needed "\$pkg"
done

info "Copying configs..."
mkdir -p ~/.config/fish ~/.config
cp -f "\$DOTFILES/.config/fish/config.fish" ~/.config/fish/
cp -f "\$DOTFILES/.config/starship.toml" ~/.config/

info "Copying VNC xstartup..."
mkdir -p ~/.vnc
cp -f "\$DOTFILES/.vnc/xstartup" ~/.vnc/
chmod +x ~/.vnc/xstartup

info "Setting default shell to fish..."
chsh -s /usr/bin/fish || warn "Run 'chsh -s /usr/bin/fish' manually."

info "Disabling Fish keyboard protocols feature..."
fish -c "set -Ua fish_features no-keyboard-protocols" \
    && info "fish_features updated." \
    || warn "Please disable feature manually."

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

• Enter Arch:  
    proot-distro login archlinux

• Inside Arch, start VNC:  
    vncserver :1

• VNC client → localhost:5901

MSG
}

main() {
    bootstrap_termux
    install_arch_linux
    arch_configure
    cleanup_dotfiles
    print_final_message
}

main "$@"
