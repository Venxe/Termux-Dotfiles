#!/data/data/com.termux/files/usr/bin/bash

set -e

# Renkli çıktı
info() { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; }

# Gerekli Termux paketleri
TERMUX_PACKAGES=(
    proot-distro
    fish
    starship
    tigervnc
)

# Paket kurulumu
install_termux_packages() {
    info "Gerekli Termux paketleri kuruluyor..."
    for pkg in "${TERMUX_PACKAGES[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            pkg install -y "$pkg"
        else
            info "$pkg zaten kurulu, atlanıyor."
        fi
    done
}

# Arch kurulumu
install_arch_if_missing() {
    if ! proot-distro list | grep -q "archlinux"; then
        info "Arch Linux indiriliyor ve kuruluyor..."
        proot-distro install archlinux
    else
        info "Arch Linux zaten kurulu, atlanıyor."
    fi
}

# Dotfile’ları kopyala
copy_dotfiles_to_arch() {
    info "Dotfiles Arch ortamına kopyalanıyor..."

    proot-distro login archlinux -- bash -c "
        mkdir -p ~/.config/fish
        cp -f /root/storage/shared/Termux-Dotfiles/.config/fish/config.fish ~/.config/fish/config.fish
        cp -f /root/storage/shared/Termux-Dotfiles/.config/starship.toml ~/.config/starship.toml
        chmod 644 ~/.config/fish/config.fish ~/.config/starship.toml
    "
}

# VNC yapılandırması
setup_vnc_xfce4() {
    info "VNC için xstartup yapılandırılıyor..."

    proot-distro login archlinux -- bash -c "
        mkdir -p ~/.vnc
        cp -f /root/storage/shared/Termux-Dotfiles/vnc/xstartup ~/.vnc/xstartup
        chmod +x ~/.vnc/xstartup
    "
}

main() {
    install_termux_packages
    install_arch_if_missing
    copy_dotfiles_to_arch
    setup_vnc_xfce4

    info "Kurulum tamamlandı."
    echo -e "\nXFCE4 ortamını başlatmak için aşağıdaki komutu çalıştırın:"
    echo "  proot-distro login archlinux -- vncserver"
}

main "$@"
