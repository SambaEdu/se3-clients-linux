#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

printf "Attention, cette action va déconnecter tous les clients lourds du réseau \n"
printf "Ce script devrait être lancé lorsqu'aucun client lourd n'est en fonctionnement \n"
printf "Etes-vous sur de vouloir poursuivre ? \n"
printf "Taper o pour oui \n"
read REPONSE

if [ "$REPONSE" != "o" ]
then
	exit 0
fi

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

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
