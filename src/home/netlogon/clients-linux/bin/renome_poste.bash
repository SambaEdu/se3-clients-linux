#!/bin/bash

if [ -z "$1" ];then
	echo "Le script prend en paramètre le nom de la machine à mettre en place"
	exit 1
fi

if [ $(id -u) != "0" ];then
	echo "Attention, le script doit être lancé en tant que root"
	exit 1
fi

NOM_CLIENT="$1"

echo "$NOM_CLIENT" > "/etc/hostname"
invoke-rc.d hostname.sh stop 
invoke-rc.d hostname.sh start

echo "
127.0.0.1    localhost
127.0.1.1    $NOM_CLIENT

# The following lines are desirable for IPv6 capable hosts
::1      ip6-localhost ip6-loopback
fe00::0  ip6-localnet
ff00::0  ip6-mcastprefix
ff02::1  ip6-allnodes
ff02::2  ip6-allrouters
" > "/etc/hosts"

exit 0
