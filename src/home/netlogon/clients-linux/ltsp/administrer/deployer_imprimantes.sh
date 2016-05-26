#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd
CHEMIN_CUPS='/home/admin/Clients-linux/ltsp/cups'

rm -rf --one-file-system "$CHEMIN_CUPS"

xterm -e "printf 'Saisir le mot de passe du compte root des clients lourds \n'; su - root -c 'cp -r /etc/cups "$CHEMIN_CUPS"; sleep 3'"

xterm -e "printf 'Vérifier que le partage Clients-linux/ltsp/cups n'est pas vide \n'; printf 'Puis saisir le mot de passe du compte root du se3 \n'; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'

rm -rf "/opt/ltsp/$ENVIRONNEMENT/etc/cups"
cp -r "/home/netlogon/clients-linux/ltsp/cups" "/opt/ltsp/$ENVIRONNEMENT/etc/"

sleep 3
exit 0
EOF"
