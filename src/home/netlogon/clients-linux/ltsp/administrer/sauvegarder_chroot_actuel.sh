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
	printf "Avant de faire la nouvelle sauvegarde, on deplace la sauvegarde precedente \n"
	mv -f "/var/se3/ltsp/${ENVIRONNEMENT}-"* /var/se3/ltsp/precedentes/
fi

sleep 1

printf "Realisation de la sauvegarde du chroot actuel des clients lourds (cette etape prend de 5 à 10 minutes) \n"
cp -a "/opt/ltsp/${ENVIRONNEMENT}" "/var/se3/${ENVIRONNEMENT}-${ladate}"

if [ "\$?" = "0" ] 
then
	printf "Sauvegarde réussie \n"
	exit 0
else
	printf "La sauvegarde a échoué \n"
	exit 1
fi

read REPONSE

EOF"
