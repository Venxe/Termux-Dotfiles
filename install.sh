#!/data/data/com.termux/files/usr/bin/bash
set -e

# ---- Yardımcı Fonksiyonlar ----
info()  { echo -e "\e[1;32m[INFO]\e[0m $1"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; }

# ---- Gerekli Paketler ----
PACKAGES=(
    tigervnc
    xfce4
    xfce4-goodies
    fish
    starship
)

# ---- Fonksiyonlar ----

enable_x11_repo() {
    if ! pkg list-all | grep -q xfce4; then
        info "x11-repo etkinleştiriliyor..."
        pkg install -y x11-repo
    else
        info "x11-repo zaten etkin, atlanıyor."
    fi
}

install_packages() {
    info "Gerekli paketler kuruluyor..."
    pkg update -y
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v "${pkg%% *}" >/dev/null 2>&1; then
            pkg install -y "$pkg"
        else
            info "$pkg zaten kurulu, atlanıyor."
        fi
    done
}

setup_config_files() {
    info "Dotfiles kopyalanıyor..."

    mkdir -p ~/.config/fish
    cp -f .config/fish/config.fish ~/.config/fish/config.fish

    mkdir -p ~/.config
    cp -f .config/starship.toml ~/.config/starship.toml
}

setup_vnc() {
    info "VNC xstartup dosyası ayarlanıyor..."

    mkdir -p ~/.vnc
    cp -f vnc/xstartup ~/.vnc/xstartup
    chmod +x ~/.vnc/xstartup
}

print_final_message() {
    echo -e "\n✅ Kurulum tamamlandı!"
    echo "VNC başlatmak için:"
    echo "  vncserver"
    echo -e "\nBağlantı için VNC Viewer'da adres: localhost:5901"
}

# ---- Ana ----
main() {
    enable_x11_repo
    install_packages
    setup_config_files
    setup_vnc
    print_final_message
}

main "$@"
