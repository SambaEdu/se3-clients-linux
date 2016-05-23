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

if [ "\$(ls /var/se3/ltsp/ --ignore=precedentes --ignore=originale | wc -l)" -eq 1 ]
then
	
	mv "/var/se3/ltsp/${ENVIRONNEMENT}-*" "/opt/ltsp/"
	
	if [ "\$?" = "0" ] 
	then
		rm -rf "/opt/ltsp/$ENVIRONNEMENT"
		mv "/opt/ltsp/${ENVIRONNEMENT}-*" "/opt/ltsp/${ENVIRONNEMENT}"
		
		if [ "\$?" = "0" ] 
		then
			printf "Restauration réussie \n"
		else
			printf "La sauvegarde a échoué \n"
			exit 1
		fi
	else
		printf "La sauvegarde a échoué \n"
		exit 2
	fi
	
else
	printf "Aucune restauration n a ete faite \n"
	printf "Le répertoire /var/se3/ltsp contient plus d une (ou aucune) sauvegarde ... ce qui n est pas normal \n"
	exit 3
fi

systemctl start nfs-kernel-server.service
sleep 1

systemctl start nbd-server.service


sleep 4

exit 0

EOF"

exit 0
