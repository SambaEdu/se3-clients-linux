#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "printf 'Taper 1 pour faire booter tous les PC PXE du réseau sur leur disque dur \n'; printf 'Taper 2 pour faire booter tous les PC PXE du réseau en client lourd \n'; read REPONSE; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

if [ \"\$REPONSE\" = 2 ]
then
	sed -i -e 's/^ONTIMEOUT.*/ONTIMEOUT ltsp/g' /tftpboot/pxelinux.cfg/default		
	printf 'Tous les PC PXE du réseau démarreront par défaut en client lourd ltsp'
	sleep 5
else
	sed -i -e 's/^ONTIMEOUT.*/ONTIMEOUT bootlocal/g' /tftpboot/pxelinux.cfg/default		
	printf 'Tous les PC PXE du réseau démarreront par défaut avec leur disque dur'
	sleep 5
fi

exit 0

EOF"
