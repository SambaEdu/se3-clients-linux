#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"	# Nom du chroot du client lourd



xterm -e "echo 'Attention, cette action va deconnecter tous les clients lourds !!!'; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'

service nfs-kernel-server stop
service nbd-server.service stop

if [ -d "/var/se3/ltsp/originale/${ENVIRONNEMENT}-originale" ]
then	
	rm -rf "/opt/ltsp/${ENVIRONNEMENT}"
	printf 'Restauration de l environnement original (durée : de 5 à 10 minutes) \n'
	cp -a  "/var/se3/ltsp/originale/${ENVIRONNEMENT}-originale" "/opt/ltsp/${ENVIRONNEMENT}"
	
else
	printf 'Aucune restauration n a ete faite \n'
	printf 'Le répertoire /var/se3/ltsp/originale ne contient pas la sauvegarde originale du chroot des clients lourds (faites à l installation de ltsp) \n'
fi

service nfs-kernel-server start
sleep 1

service nbd-server start

sleep 4

exit 0

EOF"
