# ~/.bashrc (Auto‑login to Arch Linux)
if [ -z "$PROOT_DISTRO_RUNNING" ] && [ "$SHLVL" -eq 1 ]; then
    proot-distro login archlinux
fi
