# ~/.bashrc — auto‑login to Arch on first Termux launch
if [[ -z "$PROOT_DISTRO_RUNNING" && "$SHLVL" -eq 1 ]]; then
    proot-distro login archlinux
    exit
fi
