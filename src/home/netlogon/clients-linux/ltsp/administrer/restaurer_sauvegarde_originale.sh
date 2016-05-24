#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd



xterm -e "echo 'Attention, cette action va deconnecter tous les clients lourds !!!'; sleep 10; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

systemctl stop nfs-kernel-server.service
systemctl stop nbd-server.service

if [ -d "/var/se3/ltsp/originale/${ENVIRONNEMENT}-originale" ]
then	
	rm -rf "/opt/ltsp/$ENVIRONNEMENT"
	mv  "/var/se3/ltsp/originale/${ENVIRONNEMENT}-originale" "/opt/ltsp/${ENVIRONNEMENT}"
	
else
	printf "Aucune restauration n a ete faite \n"
	printf "Le répertoire /var/se3/ltsp/originale ne contient pas la sauvegarde originale du chroot des clients lourds (faites à l installation de ltsp) \n"
fi

systemctl start nfs-kernel-server.service
sleep 1

systemctl start nbd-server.service

sleep 4

exit 0

EOF"

exit 0
