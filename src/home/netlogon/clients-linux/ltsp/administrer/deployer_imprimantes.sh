#!/bin/sh

SE3="__SE3__"
ENVIRONNEMENT="i386"													# Nom du chroot du client lourd
CHEMIN_CUPS='/home/admin/Clients-linux/ltsp/cups'

if [ ! -d "$CHEMIN_CUPS" ]
then
	mkdir -p "$CHEMIN_CUPS"
fi

rm -rf --one-file-system "$CHEMIN_CUPS"/*

xterm -e "bash << 'EOF'
printf 'Saisir le mot de passe du compte root des clients lourds \n'
su - root -c "cp -r /etc/cups/* "$CHEMIN_CUPS"; chmod -R 700 "$CHEMIN_CUPS""
sleep 3
exit 0
EOF"

xterm -e "printf 'Saisir le mot de passe du compte root du se3 \n'; ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << 'EOF'
if [ ! d "/opt/ltsp/$ENVIRONNEMENT/etc/cups" ] 
then
	mkdir "/opt/ltsp/$ENVIRONNEMENT/etc/cups"
fi

rm -rf "/opt/ltsp/$ENVIRONNEMENT/etc/cups/"*
cp -r "$CHEMIN_CUPS/"* "/opt/ltsp/$ENVIRONNEMENT/etc/cups"

sleep 3
exit 0
EOF"
