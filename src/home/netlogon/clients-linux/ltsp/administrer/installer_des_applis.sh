#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

printf "Veuillez saisir la liste d'applications (séparées par un espace chacune) à installer dans l environnement des clients lourds \n"
printf 'Ces applications doivent être installables via apt-get avec la commande "apt-get install -f ..."'
read LISTE_APPLIS_APT_GET

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y -f "$LISTE_APPLIS_APT_GET"

sleep 3
EOF"
