#!/bin/bash

##### ##### #####
#
# test du montage du répertoire distant du miroir apt-cacher-ng
# envoie d'un courriel si non monté
#
#
# version 20150609
#
#
##### ##### #####

#####
# quelques variables
MAIL_ADMIN=$(cat /etc/ssmtp/ssmtp.conf | grep root | cut -d "=" -f 2)
IP_alice="192.168.1.4"
rep_apt_cacher_ng="/var/se3/apt-cacher-ng"
COURRIEL="Le répertoire distant $IP_alice:/var/www/miroir n'est pas monté sur $rep_apt_cacher_ng"


test_montage()
{
# Le répertoire distant IP_alice:/var/www/miroir devrait être monté sur le répertoire rep_apt_cacher_ng du se3
montage=`mount | grep $IP_alice`
if [ -z "$montage" ]
then
	# le répertoire IP_alice:/var/www/miroir n'étant pas monté , on envoie un message d'alerte
	echo $COURRIEL | mail $MAIL_ADMIN -s "apt-caher-ng Se3 : répertoire non monté" -a "Content-type: text/plain; charset=UTF-8"
fi
}

#####
# début du programme
#
test_montage
exit 0
#
# fin du programme
#####
