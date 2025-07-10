# ~/.bashrc (Termux‑only auto‑login)
if [[ "$PREFIX" == "/data/data/com.termux/files/usr" && \
      -z "$PROOT_DISTRO_RUNNING" && \
      "$SHLVL" -eq 1 ]]; then
    proot-distro login archlinux
    exit
fi
