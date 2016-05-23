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

if [ -d /opt/ltsp/images ]
then
	printf "Construction de l image squashfs : cette etape prend quelques minutes \n"
	ltsp-update-image "$ENVIRONNEMENT"
	exit 0
else
	printf "Le repertoire /opt/ltsp sur votre se3 ne contient aucune image squashsf \n"
	printf "Cela signifie que votre serveur LTSP actuel n utilise pas le service nbd mais plutôt nfs pour monter le chroot des clients lourds \n"
	printf "Il est très probable que vous utilisiez un bureau sous Debian pour vos clients lourds et il est alors inutile de construire une image squashfs \n"
	printf "Aucune image squashfs n a ete construite \n"
	read REPONSE
	exit 1
fi

EOF"
