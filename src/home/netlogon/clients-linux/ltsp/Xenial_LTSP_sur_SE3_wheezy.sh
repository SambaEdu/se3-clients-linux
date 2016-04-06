#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 04/04/2016
# Sous licence GNU

# Choisir l'environnement des clients lourds Xenial : ubuntu, xubuntu ou lubuntu
ENVIRONNEMENT="lubuntu" 

# Récupération des variables spécifiques au se3
. /etc/se3/config_c.cache.sh
. /etc/se3/config_d.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_s.cache.sh

IP_SE3="$se3ip"
IP_PROXY="$proxy_url"
BASE_DN="$ldap_base_dn"

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script installe un serveur LTSP de clients lourds Xenial sur votre SE3 Wheezy												"
echo " Tout PC disposant d un boot PXE et d au moins 512 Mo de RAM pourra démarrer sur le reseau									"
echo " Votre se3 n a pas besoin d être très puissant, juste d'une carte reseau 1Gbs													"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script va simplement, sur votre se3 :																						"
echo " - créer un répertoire /opt/ltsp/lubuntu (le chroot) contenant la racine / des clients lourds xenial							"
echo " - installer et configurer les services NFS et NBD pour distribuer l'environnement (le chroot) des clients lourds 			"
echo " - créer un répertoire /tftpboot/ltsp contenant l'initrd et le kernel pour le boot PXE des clients lourds	xenial 				"
echo " - ajouter une entrée au menu /tftpboot/pxelinux.cfg/default pour pouvoir démarrer un PC PXE en client lourd Xenial 			"
echo " - configurer le chroot des clients lourds xenial pour l'identification avec l annuaire ldap et le montage automatique des partages Samba du se3  "
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Etes-vous sur de vouloir débuter l installation ? o ou n ? :																				"
read REPONSE
if [ "$REPONSE" != "o" ]
then
	exit 0;
fi


echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 0-Vérifications sur le se3 avant installation de ltsp																		"
echo "------------------------------------------------------------------------------------------------------------------------------"
if egrep -q "^7" /etc/debian_version; then
		echo "Votre serveur est bien version Debian Wheezy"
		echo "Le script peut se poursuivre"
else
		echo "Votre serveur se3 n'est pas en version Wheezy"
		echo "Le script va s'arrêter ..."
		exit 1
fi

if [ ! -e "/home/netlogon/clients-linux" ]
then
	echo "Installation du paquet se3-client-linux pour le montage des partages Samba"
	apt-get install se3-clients-linux -y --force-yes
fi

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 1-Installation du serveur ltsp (nfs, nbd, debootstrap, squashfs et la doc) :																							"
echo "------------------------------------------------------------------------------------------------------------------------------"
apt-get update
apt-get install -y ltsp-server ltsp-docs

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 2-Construction de l environnement $ENVIRONNEMENT pour les clients lourds Xenial												"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " ATTENTION : la construction du chroot xenial change la locale du serveur ...													"
echo " A la fin, les mots de passe saisis pour les comptes root et enseignant sont en mode querty !!!								"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Appuyer sur une touche pour continuer"
read REPONSE


# Le script de construction du chroot de Xenial n'existe pas dans le paquet ltsp de wheezy
# Mais en regardant le paquet ltsp pour Jessie, on remarque que c'est simplement un lien vers le script gutsy
# Et en testant gutsy sous wheezy, on remarque que le script est fonctionnel pour xenial ...

if [ ! -e "/usr/share/debootstrap/scripts/xenial" ]
then
	ln -s /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/xenial
fi

VENDOR=Ubuntu CONFIG_NBD=true ltsp-build-client --arch i386 --chroot "$ENVIRONNEMENT" --fat-client-desktop "$ENVIRONNEMENT-desktop" --dist xenial --mirror http://fr.archive.ubuntu.com/ubuntu/ --locale fr_FR.UTF-8 --prompt-rootpass --purge-chroot

echo "--------------------------------------"
echo " Sauvegarde du chroot (5 minutes)	    "
echo "--------------------------------------"
cp -a "/opt/ltsp/$ENVIRONNEMENT" /opt/ltsp/xenial_save

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 3-Creation d'un compte local enseignant dans l'environnement des clients lourds												"
echo "------------------------------------------------------------------------------------------------------------------------------"
#mdp = "$(mkpasswd enseignant)"
#ltsp-chroot -m --arch "$ENVIRONNEMENT" useradd --create-home --password "$mdp" enseignant
ltsp-chroot -m --arch "$ENVIRONNEMENT" adduser enseignant
ltsp-chroot -m --arch "$ENVIRONNEMENT" chmod -R 700 /home/enseignant

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 4-Configuration de lts.conf afin que les clients lourds démarrent de façon complément autonome 								"
echo "------------------------------------------------------------------------------------------------------------------------------"
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lts.conf"
[default]
KEEP_SYSTEM_SERVICES="lightdm"              # Indique à l'environnement du client lourd de lancer lightdm lors du démarrage
DEFAULT_DISPLAY_MANAGER=""                  # Lance lightdm à la place de LDM
XKBLAYOUT=fr
EOF


echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 5- Configuration du menu PXE du se3 afin d ajouter une entrée pour pouvoir démarrer un PC PXE en client lourd Xenial 	    "
echo "------------------------------------------------------------------------------------------------------------------------------"
cat <<EOF >> "/tftpboot/pxelinux.cfg/default"
LABEL ltspXenial
	MENU LABEL ^Demarrer le pc en client lourd Xenial $ENVIRONNEMENT
	KERNEL tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/vmlinuz
	APPEND ro initrd=tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/initrd.img init=/sbin/init-ltsp quiet splash nbdroot=$IP_SE3:/opt/ltsp/$ENVIRONNEMENT root=/dev/nbd0
	IPAPPEND 2
EOF

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 6-Paramétrer PAM pour qu il consulte l annuaire LDAP de se3 lors de l identification d un utilisateur sur un client lourd	"
echo "   et pour qu'il réalise le montage automatique des partages Samba du se3 grace au module pam_mount							"
echo "------------------------------------------------------------------------------------------------------------------------------"

# Installation des paquets nécessaires à l'identification LDAP avec PAM
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
libnss-ldapd    libnss-ldapd/nsswitch    multiselect    group, passwd, shadow
libnss-ldapd    libnss-ldapd/clean_nsswitch    boolean    false
libpam-ldapd    libpam-ldapd/enable_shadow    boolean    true
# Xenial : preseed responses for nslcd must be completed ...
#nslcd    nslcd/ldap-bindpw    password    
#nslcd    nslcd/ldap-starttls    boolean    false
#nslcd    nslcd/ldap-base    string    $BASE_DN
#nslcd    nslcd/ldap-reqcert    select    
#nslcd    nslcd/ldap-uris    string    ldap://$SE3/
#nslcd    nslcd/ldap-binddn    string    
nslcd	nslcd/ldap-bindpw	password
nslcd	nslcd/ldap-starttls	boolean	true
nslcd	nslcd/ldap-sasl-authcid	string	
nslcd	nslcd/ldap-uris	string	ldap://$SE3/
nslcd	nslcd/ldap-auth-type	select	simple
nslcd	nslcd/ldap-sasl-mech	select	
nslcd	nslcd/ldap-base	string	$BASE_DN
nslcd	nslcd/ldap-sasl-secprops	string	
nslcd	nslcd/ldap-sasl-krb5-ccname	string	/var/run/nslcd/nslcd.tkt
nslcd	libraries/restart-without-asking	boolean	false
nslcd	nslcd/ldap-sasl-realm	string	
nslcd	nslcd/ldap-sasl-authzid	string	
nslcd	nslcd/ldap-cacertfile	string
nslcd	nslcd/restart-services	string	
nslcd	nslcd/ldap-reqcert	select	never
samba-common    samba-common/encrypt_passwords    boolean    true
samba-common    samba-common/dhcp    boolean    false
samba-common    samba-common/workgroup    string    $se3_domain
samba-common    samba-common/do_debconf    boolean    true
EOF

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y --no-install-recommends nslcd libnss-ldapd libpam-ldapd
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y --no-install-recommends libpam-mount cifs-utils
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y samba
    
# Sécurisation des communications entre le module PAM du client lourd et l'annuaire LDAP du se3
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/nslcd.conf"
# /etc/nslcd.conf
# nslcd configuration file. See nslcd.conf(5) for details.

# The user and group nslcd should run as.
uid nslcd
gid nslcd

# The location at which the LDAP server(s) should be reachable.
uri ldap://$IP_SE3/

# The search base that will be used for all queries.
base $BASE_DN

# SSL options
ssl start_tls
tls_reqcert never
EOF

#Indiquer au client lourd que le serveur SE3 est le serveur WINS du réseau
sed -i -r -e "s/^.*wins +server +=.*$/wins server = $IP_SE3/" "/opt/ltsp/$ENVIRONNEMENT/etc/samba/smb.conf"

# Utilisation du module pam_mkhomedir.so pour créer automatiquement le home directory d'un utilisateur qui se connecte sur un client lourd
sed -i '/@include common-session/i \session required pam_mkhomedir.so skel=/etc/skel umask=0077' "/opt/ltsp/$ENVIRONNEMENT/etc/pam.d/lightdm"

# Mise des droits sur le skelette des home directory des utilisateurs de clients lourds
ltsp-chroot -m --arch "$ENVIRONNEMENT" chmod -R 700 /etc/skel

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 7-Configuration de pam_mount pour monter automatiquement les partages Samba du se3 à l ouverture de session d un utilisateur de client lourd "
echo "------------------------------------------------------------------------------------------------------------------------------"

# Configuration des partages Samba "Docs" et "Classes"
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml"
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE pam_mount SYSTEM "pam_mount.conf.xml.dtd">
<!--
	See pam_mount.conf(5) for a description.
-->

<pam_mount>

		<!-- debug should come before everything else,
		since this file is still processed in a single pass
		from top-to-bottom -->

<debug enable="0" />

		<!-- Volume definitions -->
<volume
		user="admin"
		pgrp="lcs-users"
		fstype="cifs"
		server="$IP_SE3"
		path="netlogon-linux"
		mountpoint="~/Bureau/Clients-linux (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		pgrp="lcs-users"
		fstype="cifs"
		server="$IP_SE3"
		path="homes/Docs"
		mountpoint="~/Bureau/Docs (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		pgrp="lcs-users"
		fstype="cifs"
		server="$IP_SE3"
		path="Classes"
		mountpoint="~/Bureau/Classes (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>
		<!-- pam_mount parameters: General tunables -->

<!--
<luserconf name=".pam_mount.conf.xml" />
-->

<!-- Note that commenting out mntoptions will give you the defaults.
     You will need to explicitly initialize it with the empty string
     to reset the defaults to nothing. -->
<mntoptions allow="nosuid,nodev,loop,encryption,fsck,nonempty,allow_root,allow_other" />
<!--
<mntoptions deny="suid,dev" />
<mntoptions allow="*" />
<mntoptions deny="*" />
-->
<mntoptions require="nosuid,nodev" />

<logout wait="0" hup="0" term="0" kill="0" />


		<!-- pam_mount parameters: Volume-related -->

<mkmountpoint enable="1" remove="true" />


</pam_mount>
EOF


echo "--------------------------------------------------------------------------------------"
echo " 8-Configuration pour l'impression avec le serveur CUPS du SE3				 		"
echo "--------------------------------------------------------------------------------------"

mkdir "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups/client.conf"
ServerName $IP_SE3
EOF

echo "--------------------------------------------------------------------------------------"
echo " 9-Configuration du proxy															"
echo "--------------------------------------------------------------------------------------"

cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.profile"
export http_proxy="http://$IP_PROXY"
export https_proxy="http://$IP_PROXY"
export no_proxy="localhost,127.0.0.1,$IP_SE3"
EOF

cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/environment"
http_proxy="http://$IP_PROXY"
https_proxy="http://$IP_PROXY"
no_proxy="localhost,127.0.0.1,$IP_SE3"
EOF



echo "--------------------------------------------------------------------------------------"
echo " 10-Configuration de lightdm 															"
echo "--------------------------------------------------------------------------------------"

if [ "$ENVIRONNEMENT" = "ubuntu" ] 
then
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf"
[SeatDefaults]
greeter-show-manual-login=false
greeter-hide-users=true
allow-guest=false
EOF
else
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf"
[SeatDefaults]
greeter-show-manual-login=true
greeter-hide-users=true
allow-guest=false
EOF
fi

echo "--------------------------------------------------------------------------------------"
echo " 11-Configuration de l environnement $ENVIRONNEMENT des clients lourds Xenial	 		"
echo "--------------------------------------------------------------------------------------"

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y dist-upgrade
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
wolfram-engine shared/accepted-wolfram-eula boolean true
EOF
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y -f nano aptitude less wine vlc flashplugin-installer ubuntu-restricted-extras libavcodec-extra firefox-locale-fr

# Inutile pour xenial qui possede nativement la version 5 de LO
#ltsp-chroot --arch "$ENVIRONNEMENT" apt-get remove -y libreoffice*
#ltsp-chroot --arch "$ENVIRONNEMENT" add-apt-repository -y ppa:libreoffice/ppa
#ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update 
#ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y -f install libreoffice libreoffice-l10n-fr


# Pour mettre le clavier et certains éléments du bureau lubuntu en français ...
if [ "$ENVIRONNEMENT" = "lubuntu" ] 
then
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y ubuntu-keyboard-french language-pack-fr-base language-pack-gnome-fr-base
fi

echo "--------------------------------------------------------------------------------------"
echo " 12-Modification pour que seul le dossier Bureau apparaisse dans le home utilisateur	"
echo "--------------------------------------------------------------------------------------"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/xdg/user-dirs.defaults"
DESKTOP=Desktop
EOF

echo "--------------------------------------------------------------------------------------"
echo " 13-Reconstruction de l'image squashfs (spécifique à Xenial avec NBD)					"
echo "--------------------------------------------------------------------------------------"
ltsp-update-image "$ENVIRONNEMENT"
service nbd-server restart

echo "--------------------------------------------------------------------------------------"
echo " 14-Choisir le boot PXE par défaut des PC du réseau									"
echo "--------------------------------------------------------------------------------------"
echo " Voulez-vous que tous les PC de votre réseau démarrent en client lourd Xenial ? 		"
echo " Taper o pour oui  																	"
read REPONSE
if [ "$REPONSE" = "o" ]
then
	sed -i -e "s/^ONTIMEOUT*/ONTIMEOUT ltspXenial/g" /tftpboot/pxelinux.cfg/default		
fi

echo "--------------------------------------------------------------------------------------"
echo " 15-Redémarrage du serveur se3 dans 5 secondes ...										"
echo "--------------------------------------------------------------------------------------"
sleep 5
reboot
