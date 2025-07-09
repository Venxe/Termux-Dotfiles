# Only auto-login if not already in proot and in the first session
if [ -z "$PROOT_DISTRO_RUNNING" ] && [ -z "$ARCH_ENTERED" ]; then
    export ARCH_ENTERED=1
    proot-distro login archlinux
    exit
fi
