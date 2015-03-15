#!/bin/bash

# Script pour renommer la machine à lancer dans un terminal.
# Peut-être à mettre dans l'arborescence du paquet ? Mais où ?

# ATTENTION : script non testé sur tous les OS.

# Pour devenir sudo.
sudo true

if [ "$1" = "" ]; then
    # On relance le script lui-même mais avec sudo cette fois.
    sudo "$0" "arg"
    exit 0
fi

# On récupère le nom du client.
read -r -p "Nom du client : " NOM_CLIENT

# On édite le fichier /etc/hostname.
echo "$NOM_CLIENT" > /etc/hostname

# On édite le fichier /etc/hosts.
echo "
127.0.0.1    localhost
127.0.1.1    $NOM_CLIENT

# The following lines are desirable for IPv6 capable hosts
::1      ip6-localhost ip6-loopback
fe00::0  ip6-localnet
ff00::0  ip6-mcastprefix
ff02::1  ip6-allnodes
ff02::2  ip6-allrouters
" > /etc/hosts

# Pour Squeeze uniquement.
NOM_DE_CODE=$(lsb_release --codename | cut -f 2)

if [ "$NOM_DE_CODE" = "squeeze" ]; then
    sed -i -r -e "s/^.*send host-name.*$/send host-name \"$NOM_CLIENT\";/g" \
        /etc/dhcp/dhclient.conf
fi

reboot

