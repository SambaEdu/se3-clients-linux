#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd
ladate=$(date +%Y%m%d%H%M%S)

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

if [ ! -d "/var/se3/ltsp/precedentes" ]
then
	mkdir -p "/var/se3/ltsp/precedentes"
fi

if [ "\$(ls /var/se3/ltsp/ --ignore=precedentes --ignore=originale | wc -l)" -ge 1 ]
then
	echo 'Avant de faire la nouvelle sauvegarde, on deplace la sauvegarde precedente'
	mv -f "/var/se3/ltsp/${ENVIRONNEMENT}-"* /var/se3/ltsp/precedentes/
fi

sleep 1

echo 'Realisation de la sauvegarde du chroot actuel des clients lourds (cette etape prend de 5 à 10 minutes)'
cp -a "/opt/ltsp/${ENVIRONNEMENT}" "/var/se3/${ENVIRONNEMENT}-${ladate}"

if [ "\$?" = "0" ] 
then
	echo 'Sauvegarde réussie'
	exit 0
else
	echo 'La sauvegarde a échoué'
	exit 1
fi

sleep 10

EOF"
