#!/bin/bash


# lastupdate 20150603

LADATE=$(date +%Y%m%d%H%M%S)

# quelques couleurs ;-)
rouge='\e[0;31m'
rose='\e[1;31m'
COLTITRE='\e[0;33m'
jaune='\e[1;33m'
vert='\e[0;32m'
bleu='\e[1;34m'
neutre='\e[0;m'

# Chemin source → le répertoire où le script a été lancé
src="$(pwd)"

# répertoire install et lien
repinstall="/home/netlogon/clients-linux/install"
replink="/var/www/install"

#=====
# Les fonctions
#=====

message_debut()
{
# echo -e "$COLTITRE"
echo "---------------------------------------------------------------------"
echo "--------------         Mise en place du système      ----------------"
echo "------------------------------------------------- -------------------"
# echo -e "$vert"
# echo "- Choisir le mode expert pour avoir toutes les possibilités d'installation coté clients"
# echo "- Choisir le mode standard  pour avoir uniquement la possibilité d'installer xfce en mode auto"
# echo -e "$neutre"
# echo "Appuyez sur Entree pour continuer"
# read -t 10 dummy
#  
#echo "---- Mode (e)xpert ou (s)tandard ? --- e/s"
#read -t 10 CHOIX
#CHOIX=e
}

verifier_version_serveur()
{
if egrep -q "^6.0" /etc/debian_version
then
	echo "Votre serveur est bien version Debian Squeeze"
	echo "Le script peut se poursuivre"
else
	echo "Votre serveur n'est pas en version Squeeze."
	echo "Opération annulée !"
	exit 1
fi
}

recuperer_variables_se3()
{
# [ "$1" = "miroir-local" ] && MIROIR_LOCAL="yes"

. /etc/se3/config_c.cache.sh
. /etc/se3/config_d.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_s.cache.sh

# Pour recuperer la valeur MIROIR_LOCAL,... dans se3db
. /etc/se3/config_o.cache.sh

. /usr/share/se3/includes/functions.inc.sh 

[ -e /root/debug ] && DEBUG="yes"

# Lire la valeur de MIROIR_LOCAL et MIROIR_IP et CHEMIN_MIROIR dans la base MySQL ?
MIROIR_LOCAL=$(echo "SELECT value FROM params WHERE name='MiroirAptCliLin';"|mysql -N $dbname -u$dbuser -p$dbpass)
if [ "$MIROIR_LOCAL" = "yes" ]; then
	MIROIR_IP=$(echo "SELECT value FROM params WHERE name='MiroirAptCliLinIP';"|mysql -N $dbname -u$dbuser -p$dbpass)
	CHEMIN_MIROIR=$(echo "SELECT value FROM params WHERE name='MiroirAptCliLinChem';"|mysql -N $dbname -u$dbuser -p$dbpass)
fi

CliLinNoPreseed=$(echo "SELECT value FROM params WHERE name='CliLinNoPreseed';"|mysql -N $dbname -u$dbuser -p$dbpass)
CliLinXfce64=$(echo "SELECT value FROM params WHERE name='CliLinXfce64';"|mysql -N $dbname -u$dbuser -p$dbpass)
CliLinLXDE=$(echo "SELECT value FROM params WHERE name='CliLinLXDE';"|mysql -N $dbname -u$dbuser -p$dbpass)
CliLinGNOME=$(echo "SELECT value FROM params WHERE name='CliLinGNOME';"|mysql -N $dbname -u$dbuser -p$dbpass)
}

extraire_archive()
{
echo "Extraction de install_client_linux_archive-tftp.tar.gz."
tar -xzf ./install_client_linux_archive-tftp.tar.gz

if [ "$?" != "0" ]
then
	echo "Erreur lors de l'extraction de l'archive."
	exit 1
fi
}

installation_se3_clonage()
{
# verif présence se3-clonage
if [ ! -e "/usr/share/se3/scripts/se3_pxe_menu_ou_pas.sh" ]
then
	echo "installation du module Clonage"
	/usr/share/se3/scripts/install_se3-module.sh se3-clonage
fi
}

installation_se3_clients_linux()
{
# verif présence paquet client-linux
clients_linux_path="/home/netlogon/clients-linux"
if [ ! -e "$clients_linux_path" ]
then
	apt-get install se3-clients-linux -y --force-yes
fi
}

droits_repertoires()
{
# rights fix and directories
setfacl -m u:www-data:rx $clients_linux_path
setfacl -m d:u:www-data:rx $clients_linux_path

chmod 777 /tmp

rm -rf $repinstall
rm -rf $replink

mkdir -p $repinstall
chmod 755 $repinstall

chown root $repinstall
ln -s $repinstall $replink
}

verifier_presence_mkpasswd()
{
# verif présence mkpasswd
if [ ! -e "/usr/bin/mkpasswd" ]
then
	apt-get install whois -y
fi
}

mise_en_place_tftpboot()
{
# On vérifie si le menu Install fait référence ou non à debian-installer
t=$(grep "Installation Debian" /tftpboot/tftp_modeles_pxelinux.cfg/menu/install.menu)
if [ -z "$t" ]
then
  echo "   LABEL Installation Debian wheezy
    MENU LABEL ^Installation Debian
    KERNEL menu.c32
    APPEND pxelinux.cfg/inst_wheezy.cfg
" >> /tftpboot/tftp_modeles_pxelinux.cfg/menu/install.menu
fi

t2=$(grep "Installation Ubuntu" /tftpboot/tftp_modeles_pxelinux.cfg/menu/install.menu)
if [ -z "$t2" ]
then
echo "    
    LABEL Installation Ubuntu et xubuntu trusty
    MENU LABEL ^Installation ubuntu
    KERNEL menu.c32
    APPEND pxelinux.cfg/inst_buntu.cfg   
" >> /tftpboot/tftp_modeles_pxelinux.cfg/menu/install.menu
# cp $src/install.menu /tftpboot/tftp_modeles_pxelinux.cfg/menu/
fi

if [ -e /tftpboot/pxelinux.cfg/install.menu ]
then
	t=$(grep "Installation Debian" /tftpboot/pxelinux.cfg/install.menu)
	t=$(grep "Installation Ubuntu" /tftpboot/pxelinux.cfg/install.menu)
	if [ -z "$t" ]
	then
		cp /tftpboot/pxelinux.cfg/install.menu /tftpboot/pxelinux.cfg/install.menu.$LADATE
		cp /tftpboot/tftp_modeles_pxelinux.cfg/menu/install.menu /tftpboot/pxelinux.cfg/
	fi
else
	if [ ! -e "/tftpboot/pxelinux.cfg/maintenance.menu" ]
	then
		echo "Le menu d installation Debian n est propose qu avec le menu tftp semi-graphique."
		echo "configuration du mode semi-graphique"
		echo "Mise en place du mot de passe temporaire ci-dessous pour acceder au menu maintenance"
		CHANGEMYSQL "tftp_pass_menu_pxe" "Linux" 
		echo "----> Linux <----- mis en place. A changer au plus vite depuis l'interface de configuration tftp"
		sleep 5
		/usr/share/se3/scripts/set_password_menu_tftp.sh Linux
	fi
fi
cp $src/inst_wheezy.cfg $src/inst_buntu.cfg /tftpboot/pxelinux.cfg/
}

telecharger_archives_netboot()
{
# echo "Menage prealable"
rm -fr /tftpboot/debian-installer
rm -fr /tftpboot/ubuntu-installer

echo "Téléchargement des paquets netboot debian, ubuntu..."
cd /root
if [ "$DEBUG" = "yes" ]
then
	if [ -e "netboot-debian.tar.gz" ] && [ -e "netboot64-debian.tar.gz" ] && [ -e "netboot-ubuntu.tar.gz" ]
	then
		echo "Fichier netboot PXE existants sur le serveur" 
# 	cp $src/install.menu /tftpboot/tftp_modeles_pxelinux.cfg/menu/
	else 
		rm -f netboot*.tar.gz
		wget http://ftp.nl.debian.org/debian/dists/wheezy/main/installer-i386/current/images/netboot/netboot.tar.gz -O netboot-debian.tar.gz	
		wget http://ftp.nl.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/netboot/netboot.tar.gz -O netboot64-debian.tar.gz
		wget http://archive.ubuntu.com/ubuntu/dists/trusty/main/installer-i386/current/images/netboot/netboot.tar.gz -O netboot-ubuntu.tar.gz
	fi
else
	rm -f netboot*.tar.gz
	wget http://ftp.nl.debian.org/debian/dists/wheezy/main/installer-i386/current/images/netboot/netboot.tar.gz -O netboot-debian.tar.gz	
	wget http://ftp.nl.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/netboot/netboot.tar.gz -O netboot64-debian.tar.gz
	wget http://archive.ubuntu.com/ubuntu/dists/trusty/main/installer-i386/current/images/netboot/netboot.tar.gz -O netboot-ubuntu.tar.gz
fi
}

extraire_archives_netboot()
{
echo "extraction du fichier netboot.tar.gz" 
tar -xzf netboot-debian.tar.gz
tar -xzf netboot64-debian.tar.gz
tar -xzf netboot-ubuntu.tar.gz

mv debian-installer /tftpboot/
mv ubuntu-installer /tftpboot/
rm -f /root/pxelinux.0 /root/pxelinux.cfg /root/version.info

# http://archive.ubuntu.com/ubuntu/dists/trusty/main/installer-i386/current/images/netboot/netboot.tar.gz
}

transfert_repertoire_install()
{
cp $src/post-install* $src/preseed*.cfg $src/mesapplis*.txt $src/bashrc $src/inittab $src/tty1.conf /var/remote_adm/.ssh/id_rsa.pub /var/www/install/
chmod 755 /var/www/install/preseed* /var/www/install/post-install_debian_wheezy.sh
}

gestion_script_integration()
{
if [ -e "/home/netlogon/clients-linux/distribs/wheezy/integration/integration_wheezy.bash" ]
then
	rm -f /var/www/install/integration_wheezy.bash
	ln /home/netlogon/clients-linux/distribs/wheezy/integration/integration_wheezy.bash /var/www/install/
	chmod 755 /var/www/install/integration_wheezy.bash
fi
}

gestion_cles_publiques()
{
rm -f /var/www/paquet_cles_pub_ssh.tar.gz
if [ ! -e "/var/www/paquet_cles_pub_ssh.tar.gz" ]
then
	echo "Generation d un paquet de cles pub ssh d apres vos authorized_keys"
	cd /root/.ssh
	for fich_authorized_keys in authorized_keys authorized_keys2 /var/www/install/id_rsa.pub 
	do
		if [ -e "$fich_authorized_keys" ]
		then
			while read A
			do
				comment=$(echo "$A"|cut -d" " -f3)
				if [ -n "$comment" -a ! -e "$comment.pub" ]; then
					echo "$A" > $comment.pub
				fi
			done < $fich_authorized_keys
		fi
	done
	tar -czf /var/www/paquet_cles_pub_ssh.tar.gz *.pub
fi
}

gestion_fichiers_preseed()
{
CRYPTPASS="$(echo "$xppass" | mkpasswd -s -m md5)"
[ -z "$ntpserv" ] && ntpserv="ntp.ac-creteil.fr"

echo "Correction du fichier TFTP inst_inst_wheezy.cfg pour ajout IP du Se3"


sed -i "s|###_IP_SE3_###|$se3ip|g" /tftpboot/pxelinux.cfg/inst_wheezy.cfg
sed -i "s|###_IP_SE3_###|$se3ip|g" /tftpboot/pxelinux.cfg/inst_buntu.cfg

[ "$CliLinNoPreseed" = "yes" ] && sed -i "s|^#INSTALL_LIBRE_SANS_PRESEED||" /tftpboot/pxelinux.cfg/inst_wheezy.cfg
[ "$CliLinNoPreseed" = "yes" ] && sed -i "s|^#INSTALL_LIBRE_SANS_PRESEED||" /tftpboot/pxelinux.cfg/inst_buntu.cfg

[ "$CliLinXfce64" = "yes" ] && sed -i "s|^#XFCE64||" /tftpboot/pxelinux.cfg/inst_wheezy.cfg 
[ "$CliLinXfce64" = "yes" ] && sed -i "s|^#XFCE64||" /tftpboot/pxelinux.cfg/inst_buntu.cfg

[ "$CliLinLXDE" = "yes" ] && sed -i "s|^#LXDE||" /tftpboot/pxelinux.cfg/inst_wheezy.cfg
[ "$CliLinLXDE" = "yes" ] && sed -i "s|^#LXDE||" /tftpboot/pxelinux.cfg/inst_buntu.cfg 

[ "$CliLinGNOME" = "yes" ] && sed -i "s|^#GNOME||" /tftpboot/pxelinux.cfg/inst_wheezy.cfg
[ "$CliLinGNOME" = "yes" ] && sed -i "s|^#GNOME||" /tftpboot/pxelinux.cfg/inst_buntu.cfg
}

gestion_miroir()
{
if [ "$MIROIR_LOCAL" != "yes" ]
then
	echo "Installation et configuration de apt-cacher-ng pour se3"
	echo "Le cache sera dans /var/se3/apt-cacher-ng"
	apt-get install apt-cacher-ng -y
	rm -f /etc/apt-cacher-ng/acng.conf.*
	mv /etc/apt-cacher-ng/acng.conf /etc/apt-cacher-ng/acng.conf.$LADATE
	cat > /etc/apt-cacher-ng/acng.conf <<END
CacheDir: /var/se3/apt-cacher-ng
LogDir: /var/log/apt-cacher-ng
Port:9999
Remap-debrep: file:deb_mirror*.gz /debian ; file:backends_debian
Remap-uburep: file:ubuntu_mirrors /ubuntu ; file:backends_ubuntu
Remap-debvol: file:debvol_mirror*.gz /debian-volatile ; file:backends_debvol
Remap-cygwin: file:cygwin_mirrors /cygwin # ; file:backends_cygwin # incomplete, please create this file
ReportPage: acng-report.html
VerboseLog: 1
ExTreshold: 4
END

	# securisation acces admin pass adminse3
	echo "AdminAuth: admin:$xppass" > /etc/apt-cacher-ng/security.conf 
	chown apt-cacher-ng:apt-cacher-ng /etc/apt-cacher-ng/security.conf 
	chmod 600 /etc/apt-cacher-ng/security.conf 

	# config propre ubuntu
	echo "http://fr.archive.ubuntu.com/ubuntu/" > /etc/apt-cacher-ng/backends_ubuntu

	
	if [ ! -e /var/se3/apt-cacher-ng ]
	then 
		mv /var/cache/apt-cacher-ng /var/se3/
	fi

	service apt-cacher-ng restart
	
	
	echo "Correction des fichiers de preseed wheezy"


	for i in $(ls /var/www/install/preseed*.cfg)
	do
		sed -i "s|###_IP_SE3_###|$se3ip|g" $i
		sed -i "s|###_PASS_ROOT_###|$CRYPTPASS|g" $i
		sed -i "s|###_NTP_SERV_###|$ntpserv|g" $i 
	done
else
	if [ -z "$MIROIR_IP" -o -z "$CHEMIN_MIROIR" ]
	then
		echo "--- Adresse du miroir ?"
		read MIROIR_IP
		echo "--- Chemin dans le miroir ?"
		read CHEMIN_MIROIR
	fi

	echo "Correction des fichiers de preseed wheezy"

	for i in $(ls /var/www/install/preseed*.cfg)
	do
		sed -i "s|###_IP_SE3_###:9999|$MIROIR_IP|g" $i
		sed -i "s|###_IP_SE3_###|$se3ip|g" $i
		sed -i "s|/debian|$CHEMIN_MIROIR|g" $i 
		sed -i "s|###_PASS_ROOT_###|$CRYPTPASS|g" $i
		sed -i "s|###_NTP_SERV_###|$ntpserv|g" $i 
	done
fi
}

fichier_parametres()
{
email=$(grep "^root=" /etc/ssmtp/ssmtp.conf |cut -d"=" -f2)
if [ -z "$email" ]
then
	email=root
fi

mailhub=$(grep "^mailhub=" /etc/ssmtp/ssmtp.conf |cut -d"=" -f2)
if [ -z "$mailhub" ]
then
	mailhub=mail
fi

rewriteDomain=$(grep "^rewriteDomain=" /etc/ssmtp/ssmtp.conf |cut -d"=" -f2)
if [ -z "$rewriteDomain" ]
then
	rewriteDomain=$dhcp_domain_name
fi

tmp_proxy=$(cat /etc/profile | grep http_proxy= | cut -d= -f2|sed -e 's|"||g'|sed -e "s|.*//||")
ip_proxy=$(echo "$tmp_proxy"|cut -d":" -f1)
port_proxy=$(echo "$tmp_proxy"|cut -d":" -f2)


echo "Generation du fichier de parametres /var/www/install/params.sh"

cat > /var/www/install/params.sh << END
email="$email"
mailhub="$mailhub"
rewriteDomain="$rewriteDomain"

# Parametres Proxy:
ip_proxy="$ip_proxy"
port_proxy="$port_proxy"

# Parametres SE3:
ip_se3="$se3ip"
nom_se3="$(hostname)"
nom_domaine="$dhcp_domain_name"
ocs="$inventaire"

# Parametres LDAP:
ip_ldap="$ldap_server"
ldap_base_dn="$ldap_base_dn"
END

chmod 755 /var/www/install/params.sh
}

gestion_scripts_unefois()
{
[ -e /home/netlogon/clients-linux/unefois/PAUSE ] && mv /home/netlogon/clients-linux/unefois/PAUSE /home/netlogon/clients-linux/unefois/NO-PAUSE
cp -r $src/unefois/* /home/netlogon/clients-linux/unefois/
cp /home/netlogon/clients-linux/bin/logon_perso /home/netlogon/clients-linux/bin/logon_perso-$LADATE
sed -i -r '/initialisation_perso[[:space:]]*\(\)/,/^\}/s/^([[:space:]]*)true/\1activer_pave_numerique/' /home/netlogon/clients-linux/bin/logon_perso
# cp $src/logon_perso /home/netlogon/clients-linux/bin/

# if [ -e /home/netlogon/clients-linux/distribs/wheezy/skel/.config ];then
# 	rm -rf /home/netlogon/clients-linux/distribs/wheezy/skel/config-save*
# 	mv /home/netlogon/clients-linux/distribs/wheezy/skel/.config /home/netlogon/clients-linux/distribs/wheezy/skel/config-save-$LADATE
# fi

# if [ -e /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla ];then
# 	rm -rf /home/netlogon/clients-linux/distribs/wheezy/skel/mozilla-save*
# 	mv /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla /home/netlogon/clients-linux/distribs/wheezy/skel/mozilla-save-$LADATE
# fi

if [ ! -e /home/netlogon/clients-linux/unefois/\^\. ]
then
  mv /home/netlogon/clients-linux/unefois/all /home/netlogon/clients-linux/unefois/\^\.
else
  cp /home/netlogon/clients-linux/unefois/all/* /home/netlogon/clients-linux/unefois/\^\./
  rm -rf /home/netlogon/clients-linux/unefois/all
fi 
[ -e /home/netlogon/clients-linux/unefois/\^\* ] && mv /home/netlogon/clients-linux/unefois/\^\*/*  /home/netlogon/clients-linux/unefois/\^\./
rm -rf /home/netlogon/clients-linux/unefois/\^\*
}

gestion_profil_skel()
{
if [ -e $src/update-mozilla-profile ]
then
	rm -rf /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla
	echo  "modif install_client_linux_archive - $LADATE" > /home/netlogon/clients-linux/distribs/wheezy/skel/.VERSION
fi

[ ! -e /home/netlogon/clients-linux/distribs/wheezy/skel/.config ] && cp -r $src/.config /home/netlogon/clients-linux/distribs/wheezy/skel/
[ ! -e /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla ]&& cp -r $src/.mozilla /home/netlogon/clients-linux/distribs/wheezy/skel/
 
# cp -r  $src/.config $src/.mozilla /home/netlogon/clients-linux/distribs/wheezy/skel/
rm -f /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla/firefox/default/prefs.js-save*
mv /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla/firefox/default/prefs.js /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla/firefox/default/prefs.js-save-$LADATE
cp /etc/skel/user/profil/appdata/Mozilla/Firefox/Profiles/default/prefs.js /home/netlogon/clients-linux/distribs/wheezy/skel/.mozilla/firefox/default/
}

reconfigurer_module()
{
bash /home/netlogon/clients-linux/.defaut/reconfigure.bash 
}

#=====
# Fin des fonctions
#=====

#####
# début du programme
#
message_debut
verifier_version_serveur
recuperer_variables_se3
extraire_archive
installation_se3_clonage
installation_se3_clients_linux
droits_repertoires
verifier_presence_mkpasswd
mise_en_place_tftpboot
telecharger_archives_netboot
extraire_archives_netboot
transfert_repertoire_install
gestion_script_integration
gestion_cles_publiques
gestion_fichiers_preseed
gestion_miroir
fichier_parametres
gestion_scripts_unefois
gestion_profil_skel
reconfigurer_module
#
# fin du programme
#####
