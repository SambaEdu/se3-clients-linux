#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd

xterm -e "echo 'Veuillez saisir la liste d applications, séparées chacune par un espace'; read LISTE_APPLIS; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y -f "$LISTE_APPLIS_APT_GET"
sleep 3
exit 0
EOF"
