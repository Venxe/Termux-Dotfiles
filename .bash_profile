cat > ~/.bash_profile <<'EOF'
if [ -z "$PROOT_DISTRO_RUNNING" ]; then
    proot-distro login archlinux
    exit
fi
EOF

sed -i '/proot-distro login archlinux/d' ~/.bashrc
