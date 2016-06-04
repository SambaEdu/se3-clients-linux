#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'

#systemctl stop nfs-kernel-server.service
#systemctl stop nbd-server.service

rm -rf "/opt/ltsp/$ENVIRONNEMENT/etc/skel"
cp -r /home/netlogon/clients-linux/ltsp/skel "/opt/ltsp/$ENVIRONNEMENT/etc/"

chmod -R 700 "/opt/ltsp/$ENVIRONNEMENT/etc/skel/"

#systemctl start nfs-kernel-server.service
#systemctl start nbd-server.service

printf 'Le déploiement du skel est terminé \n'

sleep 3
EOF"
