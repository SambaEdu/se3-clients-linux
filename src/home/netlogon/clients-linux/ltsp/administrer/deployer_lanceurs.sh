#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd
CHEMIN_SKEL_BUREAU='/home/admin/Clients-linux/ltsp/skel/Bureau'

if [ ! -d "$CHEMIN_SKEL_BUREAU" ]
then
	mkdir -p "$CHEMIN_SKEL_BUREAU"
fi

rm -f --one-file-system "$CHEMIN_SKEL_BUREAU/"*".desktop"
cp /home/admin/Bureau/*.desktop "$CHEMIN_SKEL_BUREAU"

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

#systemctl stop nfs-kernel-server.service
#systemctl stop nbd-server.service

if [ ! -d "/opt/ltsp/$ENVIRONNEMENT/etc/skel/Bureau/" ]
then
	mkdir -p "/opt/ltsp/$ENVIRONNEMENT/etc/skel/Bureau/"
fi

rm -f "/opt/ltsp/$ENVIRONNEMENT/etc/skel/Bureau/"*".desktop"
cp /home/netlogon/clients-linux/ltsp/skel/Bureau/*.desktop "/opt/ltsp/$ENVIRONNEMENT/etc/skel/Bureau/"

chmod -R 700 "/opt/ltsp/$ENVIRONNEMENT/etc/skel/"

#systemctl start nfs-kernel-server.service
#systemctl start nbd-server.service

printf 'La copie des lanceurs est terminée'

sleep 3
exit 0

EOF"
