#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

#systemctl stop nfs-kernel-server.service
#systemctl stop nbd-server.service

if [ ! -d "/opt/ltsp/$ENVIRONNEMENT/etc/skel" ]
then
	mkdir -p "/opt/ltsp/$ENVIRONNEMENT/etc/skel"
fi

rm -rf "/opt/ltsp/$ENVIRONNEMENT/etc/skel/"*
cp -r /home/netlogon/clients-linux/ltsp/skel/* "/opt/ltsp/$ENVIRONNEMENT/etc/skel/"

#systemctl start nfs-kernel-server.service
#systemctl start nbd-server.service

sleep 3
EOF"
