#!/bin/bash
#
# 
#############################################################################
# Script permettant de restaurer les données importantes
# pour un redémarrage du serveur SE3
# ou pour une migration d'un ancien serveur à un nouveau serveur se3
#
# version du 16/04/2014
# modifiée le 30/09/2015
#
# Auteurs :		Louis-Maurice De Sousa louis.de.sousa@crdp.ac-versailles.fr
#				François-Xavier Vial Francois.Xavier.Vial@crdp.ac-versailles.fr
#				Rémy Barroso remy.barroso@crdp.ac-versailles.fr
#
# Modifié par :	Michel Suquet Michel-Emi.Suquet@ac-versailles.fr
#				
#
#	Ce programme est un logiciel libre : vous pouvez le redistribuer ou
#	le modifier selon les termes de la GNU General Public Licence tels
#	que publiés par la Free Software Foundation : à votre choix, soit la
#	version 3 de la licence, soit une version ultérieure quelle qu'elle
#	soit.
#
#	Ce programme est distribué dans l'espoir qu'il sera utile, mais SANS
#	AUCUNE GARANTIE ; sans même la garantie implicite de QUALITÉ
#	MARCHANDE ou D'ADÉQUATION À UNE UTILISATION PARTICULIÈRE. Pour
#	plus de détails, reportez-vous à la GNU General Public License.
#
#	Vous devez avoir reçu une copie de la GNU General Public License
#	avec ce programme. Si ce n'est pas le cas, consultez
#	<http://www.gnu.org/licenses/>] 
#
# Fonctionnalités : à utiliser conjointement au script sauve_serveur.sh
#
#############################################################################


#####
# Définition des variables
#
# Elles sont modifiables pour adaptation à la situation locale
# Elles sont à faire correspondre avec celles du script de sauvegarde si elles ont été modifiées
#
#MAIL="votre_adresse_mel"	# Adresse mel d'envoi du compte-rendu
# cette variable MAIL est récupérée directement sur le se3
# voir la fonction recuperer_mail ci-dessous
##### #####
SAUV="SauveGarde"			# Nom du répertoire de sauvegarde de /var/se3/save
SAUVHOME="SauveGardeHome"	# Nom du répertoire de sauvegarde de /home et de /var/se3
##### #####
DATERESTAURATION=$(date +%F+%0kh%0M)	# Date de la restauration
DATEDEBUT=$(date +%s)					# Début de la restauration
DATEJOUR=$(date +%A)					# Jour de la restauration
COURRIEL="/root/mail.txt"				# compte-rendu de la restauration
MONTAGE="/mnt/sav"
SAUVEGARDE=$MONTAGE/$SAUV
SAUVEGARDEHOME=$MONTAGE/$SAUVHOME

#####
# quelques couleurs ;-)
#
rouge='\e[0;31m'
rose='\e[1;31m'
orange='\e[0;33m'
jaune='\e[1;33m'
vert='\e[0;32m'
bleu='\e[1;34m'
neutre='\e[0;m'

#----- -----
# les fonctions
#----- -----

recuperer_mail()
{
# on récupère l'adresse mel de l'administrateur
echo -e "${jaune}`date +%R` ${neutre}Récupération de l'adresse de messagerie de l'administrateur${neutre}" 2>&1 | tee -a $COURRIEL
MAIL=$(cat /etc/ssmtp/ssmtp.conf | grep ^root | cut -d "=" -f 2)
echo -e "l'adresse de messagerie est $MAIL" 2>&1 | tee -a $COURRIEL
}

mise_a_jour()
{
# Mise à jour
echo -e ""
echo -e "${jaune}`date +%R` ${neutre}Mise à jour du se3${neutre}" 2>&1 | tee -a $COURRIEL
sleep 1
aptitude update
/usr/share/se3/scripts/se3_update_system.sh
echo -e ""
}

arret_des_serveurs()
{
echo -e "${jaune}`date +%R` ${neutre}Arrêt du serveur ldap${neutre}" 2>&1 | tee -a $COURRIEL
/etc/init.d/slapd stop
echo -e "${jaune}`date +%R` ${neutre}Arrêt du serveur samba" 2>&1 | tee -a $COURRIEL
/etc/init.d/samba stop
}

lancement_des_serveurs()
{
echo -e "${jaune}`date +%R` ${neutre}Démarrage du serveur ldap" 2>&1 | tee -a $COURRIEL
/etc/init.d/slapd start
echo -e "${jaune}`date +%R` ${neutre}Démarrage du serveur samba" 2>&1 | tee -a $COURRIEL
/etc/init.d/samba start
}

restaure_varse3home()
{
SAVHOME=`ls $MONTAGE | grep $SAUVHOME`
if [ -n "$SAVHOME" ]	# faut-il faire un test plus subtil ?
then
	echo -e ""
	echo -e "${neutre}Une sauvegarde de /home et /var/se3 est présente"
	echo -e "${orange}Cette restauration peut durer plusieurs heures"
	echo -e "${bleu}Voulez-vous restaurer ces données ? ${neutre}(oui ou OUI) ${vert}\c"
	read REPONSE
	case $REPONSE in
		oui|OUI)
			echo -e "${jaune}`date +%R` ${neutre}Restauration des homes" 2>&1 | tee -a $COURRIEL
			cd /
			cp -ar $SAUVEGARDEHOME/home/* /home
			echo -e "${jaune}`date +%R` ${neutre}Restauration de /var/se3" 2>&1 | tee -a $COURRIEL
			cd /
			cp -ar $SAUVEGARDEHOME/se3/* /var/se3
			echo -e "${jaune}`date +%R` ${neutre}Restauration des ACL de /var/se3" 2>&1 | tee -a $COURRIEL
			cd /var/se3
			setfacl --restore=$SAUVEGARDEHOME/varse3.acl
			cd /home
			echo -e "${jaune}`date +%R` ${neutre}Restauration des droits" 2>&1 | tee -a $COURRIEL
			/usr/share/se3/sbin/restore_droits.sh
			;;
		*)
			echo -e "${jaune}`date +%R` ${neutre}Pas de restauration des homes et de /var/se3" 2>&1 | tee -a $COURRIEL
			;;
	esac
else
	echo -e ""
	echo -e "${jaune}`date +%R` ${orange}Pas de répertoire $SAVHOME${neutre}" 2>&1 | tee -a $COURRIEL
	echo -e "Pas de restauration possible des homes et de /var/se3"
	sleep 1
fi
}

restaure_conf_imprimante()
{
cd /
mkdir /savetc
cd /savetc
tar zxf $SAUVEGARDE/etc/etc.$JOUR.tar.gz
test1=$(ls /savetc/etc/cups/ | grep printers.conf)
test2=$(test -d /savetc/etc/samba/printers_se3/ && ls /savetc/etc/samba/printers_se3/)
if [ "$test1" != "" ] || [ "$test2" != "" ]
then
	echo -e "${jaune}`date +%R` ${neutre}Restauration de la conf des imprimantes" 2>&1 | tee -a $COURRIEL
	[ "$test1" != "" ] && cp -ar /savetc/etc/cups/printers.conf* /etc/cups/
	[ "$test2" != "" ] && [ ! -d /etc/samba/printers_se3/ ] && mkdir -p /etc/samba/printers_se3
	[ "$test2" != "" ] && cp -ar /savetc/etc/samba/printers_se3/* /etc/samba/printers_se3
else
	echo -e "${jaune}`date +%R` ${orange}Pas de conf d'imprimante à restaurer${neutre}" 2>&1 | tee -a $COURRIEL
fi
}

restaure_ldap()
{
echo -e "${jaune}`date +%R` ${neutre}Nettoyage ldap" 2>&1 | tee -a $COURRIEL
cp -r /var/lib/ldap /var/lib/ldapold
rm -Rf /var/lib/ldap/*
echo -e "${jaune}`date +%R` ${neutre}Gestion du DB_CONFIG" 2>&1 | tee -a $COURRIEL
cp /var/lib/ldapold/DB_CONFIG /var/lib/ldap
echo -e "${jaune}`date +%R` ${neutre}Restauration de la base ldap" 2>&1 | tee -a $COURRIEL
slapadd  -l $SAUVEGARDE/ldap/ldap.$JOUR.ldif
chown -R openldap:openldap /var/lib/ldap
}

restaure_mysql()
{
echo -e "${jaune}`date +%R` ${neutre}Nettoyage mysql" 2>&1 | tee -a $COURRIEL
cp -r /var/lib/mysql /var/lib/mysql.ori
rm -Rf /var/lib/mysql/se3db/*
echo -e "${jaune}`date +%R` ${neutre}Restauration se3db"  2>&1 | tee -a $COURRIEL
mysql --database se3db < $SAUVEGARDE/mysql/se3db.$JOUR.sql
echo -e "${jaune}`date +%R` ${neutre}Redémarrage du serveur mysql" 2>&1 | tee -a $COURRIEL
/etc/init.d/mysql restart
}

restaure_samba()
{
cd /
echo -e "${jaune}`date +%R` ${neutre}Restauration de Samba" 2>&1 | tee -a $COURRIEL
cp -ar $SAUVEGARDEHOME/samba/* /etc/samba
echo -e "${jaune}`date +%R` ${neutre}Restauration du secrets.tdb" 2>&1 | tee -a $COURRIEL
cp $SAUVEGARDE/secrets.tdb /var/lib/samba/secrets.tdb
}

restaure_imprimantes()
{
if [ -f "$SAUVEGARDE/printers.tgz" ]
then
	echo -e "${jaune}`date +%R` ${neutre}Restauration des imprimantes" 2>&1 | tee -a $COURRIEL
	cp $SAUVEGARDE/printers.tgz /etc/cups
	cd /etc/cups
	tar zxf printers.tgz
	#cd -
else
	echo -e "${jaune}`date +%R` ${orange}Pas d'imprimante à restaurer${neutre}" 2>&1 | tee -a $COURRIEL
fi
}

restaure_adminse3()
{
echo -e "${jaune}`date +%R` ${neutre}Création du compte adminse3" 2>&1 | tee -a $COURRIEL
create_adminse3.sh
}

restaure_dhcp()
{
echo -e "${jaune}`date +%R` ${neutre}Restauration configuration DHCP" 2>&1 | tee -a $COURRIEL
/usr/share/se3/scripts/makedhcpdconf
}

abandonner()
{
echo -e "${neutre}"
echo -e "${orange}Restauration abandonnée, vous pourrez la relancer en utilisant ${neutre}restaure_serveur.sh"
echo -e "${neutre}"
[ -d $MONTAGE ] && mount | grep $MONTAGE >/dev/null && umount $MONTAGE
[ -d $MONTAGE ] && rm -r $MONTAGE
}

choix_archive_sauvegarde()
{
# 1 argument : la partition à examiner
[ ! -d $MONTAGE ] && mkdir $MONTAGE
mount /dev/$1 $MONTAGE
pasbon="true"
Sauvegardedisponible=$(ls -ltr $SAUVEGARDE/etc/ | awk -- '{ print $9 " " $6 " " $7 }' | grep etc | sed "s/etc//g" | sed "s/tar.gz//g" | sed "s/\.//g")
echo -e ""
while $pasbon :
do
	# affichage des sauvegardes disponibles
	echo -e "${neutre}Sur le disque $1, voici les sauvegardes disponibles :"
	echo "$Sauvegardedisponible"
	echo -e "${neutre}ne saisir que les trois premières lettres du jour : lun, mar,…"
	echo -e "ou bien q pour abandonner"
	echo -e "${bleu}Vous souhaitez restaurer la sauvegarde de quel jour ?${vert} \c"
	read JOUR
	# on vérifie que le choix est correct
	case "$JOUR" in
		dim|lun|mar|mer|jeu|ven|sam|Sun|Mon|Tue|Wed|Thu|Fri|Sat)
			if [ -f $SAUVEGARDE/etc/etc.$JOUR.tar.gz ]
			then
				pasbon="false"
			else
				echo -e "${orange}Il n'y a pas d'archive pour le jour choisi"
				echo -e "${neutre}"
			fi
			;;
		q)
			# abandon en cours possible
			abandonner
			return 1
			;;
		*)
			echo -e "${rouge}Le choix saisi ${vert}$JOUR${rouge} est incorrect${neutre}"
			echo -e "Exemples de choix corrects : lun, mar, mer, jeu, ven, sam, dim ou Sun, Mon,…"
			echo -e "${orange}Si vous voulez abandonner la restauration, choisir q${neutre}"
			echo -e ""
			;;
	esac
done
}

trouver_archive_sauvegarde()
{
# 1 argument : la partition à examiner
[ ! -d $MONTAGE ] && mkdir $MONTAGE
mount /dev/$1 $MONTAGE
Sauvegardedisponible=$(ls -l $SAUVEGARDE/etc/ | awk -- '{ print $9 " " $6 " " $7 }'| grep etc | sed "s/etc//g" | sed "s/tar.gz//g" | sed "s/\.//g")
if [ "$Sauvegardedisponible" = "  " ]
then
	# Il n'y pas d'archive de sauvegarde
	umount $MONTAGE
	rm -r $MONTAGE
	return 1
else
	# il y a au moins une archive de sauvegarde
	umount $MONTAGE
	rm -r $MONTAGE
	return 0
fi
}

trouver_sauvegarde()
{
# 1 argument : la partition à examiner
[ -d $MONTAGE ] && mount | grep $MONTAGE >/dev/null && umount $MONTAGE
[ ! -d $MONTAGE ] && mkdir $MONTAGE
mount /dev/$1 $MONTAGE
# Y a-t-il un répertoire SauveGarde, sans que ce soit SauveGardeHome ?
SAV=$(ls $MONTAGE | grep $SAUV | grep -v $SAUVHOME)
if [ -n "$SAV" ]
then
	# il y a un répertoire SauveGarde
	umount $MONTAGE
	rm -r $MONTAGE
	return 0
else
	# il n'y a pas de répertoire SauveGarde
	umount $MONTAGE
	rm -r $MONTAGE
	return 1
fi
}

trouver_disque()
{
echo -e "${neutre}\c"
# on repère les disques branchés
DISQUES=$(fdisk -l | grep ^/dev | grep -v Extended | grep -v swap | gawk -F" " '/[^:]/ {print $1}'| sed 's:/dev/::')
# on collecte les candidats : sauvegarde ayant au moins une archive quotidienne
for part in $DISQUES
do
	trouver_sauvegarde $part
	case $? in
		0)
			# le candidat contient un répertoire SauveGarde
			# reste à savoir s'il contient des archives
			trouver_archive_sauvegarde $part
			if [ "$?" = "0" ]
			then
				# le candidat contient au moins une archive
				candidat[${#candidat[*]}]="$part"
			fi
			;;
		*)
			# ne convient pas pour la restauration
			;;
	esac
done
# on examine la liste des candidats collectés
if [ -z $candidat ]
then
	# aucun candidat : bizarre
	echo -e ""
	echo -e "${rouge}Aucun disque ne contient de répertoire ${orange}$SAUV${rouge} ou d'archive quotidienne${neutre}"
	abandonner
	exit 1
else
	# tester s'il y a plusieurs disques possédant une sauvegarde
	nombre=$(echo ${#candidat[*]})
	case $nombre in
		1)
			# un seul disque possède une sauvegarde : normal
			PART=$candidat
			;;
		*)
			# plusieurs disques possèdent des sauvegardes : bizarre
			echo -e ""
			echo -e "${rouge}Plusieurs disques possèdent une sauvegarde :${neutre} \c"
			echo ${candidat[*]}
			echo -e "${neutre}Il ne faut qu'un seul disque possédant une sauvegarde${neutre}"
			abandonner
			exit 1
			;;
	esac
	choix_archive_sauvegarde $PART
	if [ $? = "0" ]
	then
		return 0
	else
		exit 1
	fi
	
fi
}

gestion_temps()
{
DATEFIN=$(date +%s)				# Fin de la restauration en secondes
TEMPS=$(($DATEFIN-$DATEDEBUT))	# durée de la restauration, en secondes
HEURES=$(( TEMPS/3600 ))
MINUTES=$(( (TEMPS-HEURES*3600)/60 ))
# gestion de l'accord pour les heures ; pour les minutes, elles seront souvent plusieurs ;-)
case $HEURES in
	0)
		echo "Restauration effectuée en environ $MINUTES minutes" 2>&1 | tee -a $COURRIEL
	;;
	1)
		echo "Restauration effectuée en environ $HEURES heure et $MINUTES minutes" 2>&1 | tee -a $COURRIEL
	;;
	*)
		echo "Restauration effectuée en environ $HEURES heures et $MINUTES minutes" 2>&1 | tee -a $COURRIEL
	;;
esac
}

menage()
{
rm -rf /savetc
echo -e "${jaune}`date +%R` ${neutre}Travail terminé : ${vert}se3 restauré${neutre}" 2>&1 | tee -a $COURRIEL
gestion_temps
#echo -e "${neutre}" 2>&1 | tee -a $COURRIEL
echo -e "Le se3 doit redémarrer pour prendre en compte toutes les modifications" 2>&1 | tee -a $COURRIEL
umount $MONTAGE
rm -r $MONTAGE
}

courriel()
{
# Envoi du compte-rendu
echo "Un fichier récapitulatif est disponible si nécessaire : $COURRIEL" >> $COURRIEL
echo "" >> $COURRIEL
OBJET="Restauration Se3 : compte-rendu"
cat $COURRIEL | mail $MAIL -s "$OBJET" -a "Content-type: text/plain; charset=UTF-8"
}

redemarrer()
{
echo -e "${neutre}Un compte-rendu de la restauration a été envoyé par la messagerie"
echo -e "${bleu}Souhaitez-vous redémarrer maintenant ? ${neutre}(oui ou OUI)${vert} \c"
read REPONSE2
case $REPONSE2 in
	oui|OUI)
		echo -e "${neutre}"
		reboot
		;;
	*)
		echo -e ""
		echo -e "${neutre}À bientôt ! N'oubliez pas de redémarrer…${neutre}"
		echo -e ""
		;;
esac
}

restaurer_serveur()
{
arret_des_serveurs
restaure_samba
restaure_conf_imprimante
restaure_ldap
restaure_varse3home
restaure_imprimantes
lancement_des_serveurs
restaure_mysql
restaure_adminse3
restaure_dhcp
}

#----- -----
# fin des fonctions
#----- -----

#####
# Début du programme
#
echo -e "" > $COURRIEL
echo -e "${bleu}Restauration du se3 ${neutre}$DATERESTAURATION${neutre}\n" 2>&1 | tee -a $COURRIEL
echo -e "Ce script va restaurer la configuration de votre SE3 à partir d'une sauvegarde"
echo -e "${orange}Assurez-vous d'avoir installé tous les modules du se3 préalablement utilisés"
echo -e "Si vous installez ces modules *après* la restauration, les fichiers de configuration seront remis à zéro"
echo -e ""
echo -e "${neutre}N'oubliez pas de brancher sur un port usb le disque comportant une sauvegarde de votre se3"
echo -e "-------------------"
echo -e "${bleu}Souhaitez-vous procéder à la restauration maintenant ? ${neutre}(oui ou  OUI)${vert} \c"
read REPONSE1
case $REPONSE1 in
	oui|OUI)
		trouver_disque				# une sauvegarde est-elle disponible ?
		[ $? != "0" ] && exit 1
		mise_a_jour					# mise à jour du se3 avant la restauration
		restaurer_serveur			# on lance la restauration
		menage						# on essaye de revenir dans l'état de départ du script
		recuperer_mail				# on récupére l'adresse de messagerie pour l'envoi du compte-rendu
		courriel					# on envoi le compte-rendu de la restauration
		redemarrer					# demande de redémarrage du serveur
		;;
	*)
		abandonner
		;;
esac
exit 0
#
# Fin du programme
#####
