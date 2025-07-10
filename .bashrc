# ~/.bashrc — auto-login to Arch on first Termux launch
if [[ "$PREFIX" == /data/data/com.termux/files/usr && -z "$PROOT_DISTRO_RUNNING" ]]; then
    proot-distro login archlinux
    exit
fi
