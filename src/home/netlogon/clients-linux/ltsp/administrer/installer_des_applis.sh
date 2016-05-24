#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "printf 'Veuillez saisir la liste d applications, séparées chacune par un espace \n'; read LISTE_APPLIS; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' \"ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y -f \"\$LISTE_APPLIS\"\"; printf 'Installations terminées'; sleep 5"
