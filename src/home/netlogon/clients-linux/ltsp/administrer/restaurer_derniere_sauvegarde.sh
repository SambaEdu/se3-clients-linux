#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "echo 'Attention, cette action va deconnecter tous les clients lourds !!!'; sleep 10; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'

service nfs-kernel-server stop
service nbd-server stop

if [ \"\$(ls /var/se3/ltsp/ --ignore=precedentes --ignore=originale | wc -l)\" -eq 1 ]
then
	rm -rf "/opt/ltsp/${ENVIRONNEMENT}"
	printf 'Restauration de la dernière sauvegarde réalisée (durée : de 5 à 10 minutes) \n'
	cp -a  "/var/se3/ltsp/${ENVIRONNEMENT}"-* "/opt/ltsp/${ENVIRONNEMENT}"
else
	printf 'Aucune restauration n a ete faite \n'
	printf 'Le répertoire /var/se3/ltsp contient plus d une (ou aucune) sauvegarde ... ce qui n est pas normal \n'
fi

service nfs-kernel-server start
service nbd-server start
sleep 5

exit 0

EOF"
