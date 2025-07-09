#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ---- Helpers ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# ---- Paths ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---- 1) Termux Güncelleme ----
bootstrap_termux() {
    info "Updating Termux packages..."
    pkg update -y && pkg upgrade -y
}

# ---- 2) Arch Linux Kurulumu ----
install_arch_linux() {
    info "Ensuring proot-distro is installed..."
    pkg install -y proot-distro || error "proot-distro installation failed"

    info "Installing Arch Linux (if not already)..."
    if ! proot-distro install archlinux; then
        warn "Arch Linux already installed or install failed; continuing."
    else
        info "Arch Linux installed successfully."
    fi
}

# ---- 3) Arch İçinde Kurulum & Konfigürasyon ----
arch_configure() {
    info "Entering Arch environment for setup..."
    
    # $SCRIPT_DIR’i Arch içine taşı
    proot-distro login archlinux -- env HOST_DOTFILES="$SCRIPT_DIR" bash -s <<'EOF'
set -euo pipefail

# Basit log fonksiyonları
info()  { echo -e "\e[1;32m[INFO]\e[0m \$1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m \$1"; }

# Kopyalanacak dosyaların bulunduğu ana dizin
DOTFILES="\$HOST_DOTFILES"

# Yüklenecek paketler
PACKAGES=( fish starship xfce4 xfce4-goodies tigervnc )

info "Updating Arch package database..."
pacman -Syu --noconfirm

info "Installing required packages..."
pacman -S --noconfirm --needed "\${PACKAGES[@]}"

info "Copying Fish and Starship configs..."
mkdir -p ~/.config/fish ~/.config
cp -f "\$DOTFILES/.config/fish/config.fish" ~/.config/fish/
cp -f "\$DOTFILES/.config/starship.toml" ~/.config/

info "Copying VNC xstartup..."
mkdir -p ~/.vnc
cp -f "\$DOTFILES/.vnc/xstartup" ~/.vnc/
chmod +x ~/.vnc/xstartup

info "Changing default shell to fish..."
chsh -s /usr/bin/fish || warn "Run 'chsh -s /usr/bin/fish' manually."

info "Disabling Fish keyboard protocols feature..."
fish -c "set -Ua fish_features no-keyboard-protocols" \
    && info "fish_features updated." \
    || warn "Please set fish_features manually."

info "Arch setup complete."
EOF
}

# ---- 4) Dotfiles Klasörünü Temizle ----
cleanup_dotfiles() {
    info "Removing Termux-Dotfiles directory..."
    cd "$(dirname "$SCRIPT_DIR")"
    rm -rf "$SCRIPT_DIR"
    info "Cleanup done."
}

# ---- 5) Son Mesaj ----
print_final_message() {
    cat <<MSG

✅ All tasks completed!

• To enter Arch Linux:  
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
