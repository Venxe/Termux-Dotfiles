#!/data/data/com.termux/files/usr/bin/bash

set -e

# === Yardımcı Fonksiyonlar ===
info() { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; }

# === Gerekli Termux Paketleri ===
TERMUX_PACKAGES=(proot-distro)

install_termux_packages() {
    info "Termux paketleri kontrol ediliyor..."
    for pkg in "${TERMUX_PACKAGES[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            info "$pkg kuruluyor..."
            pkg install -y "$pkg"
        else
            info "$pkg zaten kurulu."
        fi
    done
}

# === Arch Linux Kurulumu (ilk seferde sonlandırmadan önce kontrol ekler) ===
install_or_prepare_arch() {
    if ! proot-distro list | grep -q "archlinux"; then
        info "Arch Linux kurulumu başlatılıyor..."
        proot-distro install archlinux
        info "Kurulum tamamlandı, script yeniden başlatılıyor..."
        exec "$0" "$@"  # Scripti yeniden başlat
    else
        info "Arch Linux zaten kurulu."
    fi
}

# === Dotfiles Kopyalama ===
copy_dotfiles_to_arch() {
    local shared_path="/root/storage/shared/Termux-Dotfiles"

    info "Dotfile'lar Arch ortamına kopyalanıyor..."
    proot-distro login archlinux -- bash -c "
        mkdir -p ~/.config/fish
        cp -f $shared_path/.config/fish/config.fish ~/.config/fish/config.fish
        cp -f $shared_path/.config/starship.toml ~/.config/starship.toml
        chmod 644 ~/.config/fish/config.fish ~/.config/starship.toml
    "
}

# === xstartup Kopyalama ===
copy_xstartup_script() {
    local shared_path="/root/storage/shared/Termux-Dotfiles"

    info "xstartup dosyası kopyalanıyor..."
    proot-distro login archlinux -- bash -c "
        mkdir -p ~/.vnc
        cp -f $shared_path/vnc/xstartup ~/.vnc/xstartup
        chmod +x ~/.vnc/xstartup
    "
}

# === Arch İçinde Gerekli Paketleri Kur ===
install_arch_packages() {
    info "Arch Linux içinde gerekli paketler kuruluyor..."
    proot-distro login archlinux -- bash -c "
        pacman -Syu --noconfirm &&
        pacman -S --noconfirm tigervnc xfce4 xfce4-goodies fish starship
    "
}

# === Ana Fonksiyon ===
main() {
    info "🚀 Termux Dotfiles Kurulumu Başlatılıyor..."
    install_termux_packages
    install_or_prepare_arch "$@"
    install_arch_packages
    copy_dotfiles_to_arch
    copy_xstartup_script

    info "✅ Kurulum tamamlandı."
    echo -e "\n🎉 XFCE4 ortamını başlatmak için aşağıdaki komutları kullanabilirsin:\n"
    echo "  proot-distro login archlinux"
    echo "  vncpasswd        # İlk kez çalıştırıyorsan şifre ayarla"
    echo "  vncserver :1     # VNC başlat"
    echo -e "\n🔗 Ardından VNC Viewer ile localhost:5901 üzerinden bağlantı kurabilirsin.\n"
}

main "$@"
