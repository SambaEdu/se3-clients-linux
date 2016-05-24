#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y upgrade
EOF"
