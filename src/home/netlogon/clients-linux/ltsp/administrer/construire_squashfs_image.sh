#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd



xterm -e "printf 'Attention, cette action va déconnecter tous les clients lourds du réseau \n'; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'

service nbd-server stop

if [ -d /opt/ltsp/images ]
then
	printf 'Construction de l image squashfs : cette etape prend quelques minutes \n'
	ltsp-update-image "$ENVIRONNEMENT"
	exit 0
else
	printf 'Le repertoire /opt/ltsp du se3 ne contient aucune image squashfs \n'
	printf 'Cela signifie que votre serveur LTSP actuel n utilise pas le service nbd mais plutôt nfs pour monter le chroot des clients lourds \n'
	printf 'Le bureau des clients lourds est très certainement sous Debian \n'
	printf 'Aucune image squashfs n a ete construite \n'
	sleep 10
	exit 1
fi

service nbd-server start

EOF"
