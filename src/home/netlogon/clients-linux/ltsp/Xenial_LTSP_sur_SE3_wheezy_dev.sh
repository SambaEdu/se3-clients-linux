#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 23/05/2016
# Sous licence GNU

# Choisir le bureau des clients lourds Xenial : ubuntu, ubuntu-mate, xubuntu ou lubuntu
ENVIRONNEMENT="i386" 			# Nom de l'environnement (du chroot) des clients lourds
BUREAU="ubuntu-mate"			# Bureau à installer dans le chroot des clients lourds

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
echo " - créer un répertoire /opt/ltsp/i386 (le chroot) contenant la racine / des clients lourds xenial								"
echo " - Faire une sauvegarde de ce chroot dans /var/se3/ltsp																		"
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
echo " Les mots de passe saisis pour les comptes root des clients lourds et pour le compte local enseignant sont en mode querty !!!	"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Appuyer sur une touche pour continuer"
read REPONSE


# Le script de construction du chroot de Xenial n'existe pas mais celui de gutsy est parfaitement fonctionnel

if [ ! -e "/usr/share/debootstrap/scripts/xenial" ]
then
	ln -s /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/xenial
fi

VENDOR=Ubuntu CONFIG_NBD=true ltsp-build-client --arch i386 --chroot "$ENVIRONNEMENT" --fat-client-desktop "$BUREAU-desktop" --dist xenial --mirror http://fr.archive.ubuntu.com/ubuntu/ --locale fr_FR.UTF-8 --prompt-rootpass --purge-chroot


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

sleep 5


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

sleep 5

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 7-Configuration de pam_mount pour monter automatiquement les partages Samba du se3 à l ouverture de session d un utilisateur de client lourd "
echo "------------------------------------------------------------------------------------------------------------------------------"

# Configuration des partages Samba "Docs" et "Classes"
if [ "$BUREAU" = "ubuntu-mate" ]
then
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
		fstype="cifs"
		server="$IP_SE3"
		path="netlogon-linux"
		mountpoint="~/Clients-linux"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		fstype="cifs"
		server="$IP_SE3"
		path="homes/Docs"
		mountpoint="~/Docs (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		fstype="cifs"
		server="$IP_SE3"
		path="Classes"
		mountpoint="~/Classes (sur le reseau)"
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

else
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
		fstype="cifs"
		server="$IP_SE3"
		path="netlogon-linux"
		mountpoint="~/Bureau/Clients-linux"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		fstype="cifs"
		server="$IP_SE3"
		path="homes/Docs"
		mountpoint="~/Bureau/Docs (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
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

fi

sleep 5

#echo "--------------------------------------------------------------------------------------"
#echo " 8-Configuration pour l'impression avec le serveur CUPS du SE3				 		"
#echo "--------------------------------------------------------------------------------------"

#mkdir "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups"

#cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups/client.conf"
#ServerName $IP_SE3
#EOF

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 9-Configuration du proxy															"
echo "--------------------------------------------------------------------------------------"

masque_reseau=$(($(echo "$se3mask" | grep -o "255" | wc -l)*8))
ip_proxy="$(echo "$IP_PROXY" | cut -d ':' -f 1)"
port_proxy="$(echo "$IP_PROXY" | cut -d ':' -f 2)"

# Définition du proxy, si le port du proxy est défini
if [ "$port_proxy" != "" ]
then
	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.profile"
export http_proxy="http://$IP_PROXY"
export https_proxy="http://$IP_PROXY"
export no_proxy="localhost,127.0.0.1,${IP_SE3}/${masque_reseau}"
EOF

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/environment"
http_proxy="http://$IP_PROXY"
https_proxy="http://$IP_PROXY"
no_proxy="localhost,127.0.0.1,${IP_SE3}/${masque_reseau}"
EOF

# On règle le proxy d'Iceweasel avec l'option "Configuration manuelle du proxy" et en cochant "Utilser ce proxy pour tous les protocoles"
# On évite ainsi les problèmes d'accès aux sites en https, ...
# Enfin, on désactive le proxy pour l'accès aux postes du réseau pédagogique (en particulier à l'interface web du se3)
# On peut définir un paramètre de trois façons différentes :
# - defaultPref : set new default value
# - pref : set pref, but allow changes in current session
# - lockPref : lock pref, disallow changes

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/firefox/syspref.js"
	
// Define proxy when an IP and PORT are specified
lockPref("network.proxy.share_proxy_settings", true);
lockPref("network.proxy.http", "${ip_proxy}");
lockPref("network.proxy.http_port", ${port_proxy});
lockPref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, ${IP_SE3}/${masque_reseau}");
lockPref("network.proxy.type", 1);
EOF

else

# On règle le proxy d'Iceweasel avec l'option "Détection automatique des paramètres proxy pour ce réseau"
# Cette option permet de gérer les réseaux qui n'ont pas de proxy (proxy transparent) ainsi que ceux gérés par un fichier wpad.dat (avec Amon par exemple)
cat <<'EOF' >> "/opt/ltsp/$ENVIRONNEMENT/etc/firefox/syspref.js"

// Define proxy when no IP is specified for proxy
lockPref("network.proxy.type", 4);
EOF

fi

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 10-Configuration de lightdm 															"
echo "--------------------------------------------------------------------------------------"

if [ "$BUREAU" = "ubuntu" ] 
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

# Sous certain bureau, comme MATE, le clavier n'est pas mis en azerty par le serveur X
# On utilisa le commande xsetxkbmap fr pour forcer le layout du clavier en azerty
# On enfonce le clou en exécutant la commande une 2de fois à l'ouverture de session
# On en profite pour lancer le verrouillage numérique du clavier
cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf"
display-setup-script=/usr/bin/setxkbmap fr
greeter-setup-script=/usr/bin/numlockx on
session-setup-script=/usr/bin/setxkbmap fr
EOF

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 11-Configuration de l environnement $ENVIRONNEMENT des clients lourds Xenial	 		"
echo "--------------------------------------------------------------------------------------"

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y dist-upgrade
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<'EOF'
ttf-mscorefonts-installer	msttcorefonts/dldir	string	
ttf-mscorefonts-installer	msttcorefonts/dlurl	string	
ttf-mscorefonts-installer	msttcorefonts/accepted-mscorefonts-eula	boolean	true
ttf-mscorefonts-installer	msttcorefonts/present-mscorefonts-eula	note
EOF

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y -f nano aptitude less wine vlc flashplugin-installer ubuntu-restricted-extras libavcodec-extra firefox-locale-fr xterm shutter numlockx


# Pour mettre le clavier et certains éléments du bureau lubuntu en français ...
if [ "$BUREAU" = "lubuntu" ] 
then
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y ubuntu-keyboard-french language-pack-fr-base language-pack-gnome-fr-base
fi

echo "--------------------------------------------------------------------------------------"
echo " 12-Modification pour que seul le dossier Bureau apparaisse dans le home utilisateur	"
echo "--------------------------------------------------------------------------------------"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/xdg/user-dirs.defaults"
DESKTOP=Desktop
EOF

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 13-Copie du skel dans le chroot														"
echo "--------------------------------------------------------------------------------------"
find /home/netlogon/clients-linux/ltsp/skel/ -mindepth 1 -maxdepth 1 -exec cp -rf {} "/opt/ltsp/$ENVIRONNEMENT/etc/skel/" \;

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 14-Reconstruction de l'image squashfs (spécifique à Xenial avec NBD)					"
echo "--------------------------------------------------------------------------------------"
ltsp-update-image "$ENVIRONNEMENT"
service nbd-server restart

sleep 5

#echo "--------------------------------------------------------------------------------------"
#echo " 15-Choisir le boot PXE par défaut des PC du réseau									"
#echo "--------------------------------------------------------------------------------------"
#echo " Voulez-vous que tous les PC de votre réseau démarrent en client lourd Xenial ? 		"
#echo " Taper o pour oui  																	"
#read REPONSE
#if [ "$REPONSE" = "o" ]
#then
#	sed -i -e "s/^ONTIMEOUT*/ONTIMEOUT ltspXenial/g" /tftpboot/pxelinux.cfg/default		
#fi

echo "--------------------------------------"
echo " 16-Sauvegarde du chroot des clients lourds (5 minutes)	    "
echo "--------------------------------------"
if [ ! -d "/var/se3/ltsp/originale" ]
then
	mkdir -p "/var/se3/ltsp/originale"
fi
rm -rf "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"
cp -a "/opt/ltsp/$ENVIRONNEMENT" "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"

sleep 5

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 17- Configuration du menu PXE du se3 afin d ajouter une entrée pour pouvoir démarrer un PC PXE en client lourd Xenial 	    "
echo "------------------------------------------------------------------------------------------------------------------------------"

resultat=$(grep "Demarrer le pc en client lourd Xenial $BUREAU" "/tftpboot/pxelinux.cfg/default")

if [ "$resultat" = "" ]
then
cat <<EOF >> "/tftpboot/pxelinux.cfg/default"
LABEL ltsp
	MENU LABEL ^Demarrer le pc en client lourd Xenial $BUREAU
	KERNEL tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/vmlinuz
	APPEND ro initrd=tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/initrd.img init=/sbin/init-ltsp quiet splash nbdroot=$IP_SE3:/opt/ltsp/$ENVIRONNEMENT root=/dev/nbd0
	IPAPPEND 2
EOF
fi

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 17-Redémarrage du serveur se3 dans 5 secondes ...										"
echo "--------------------------------------------------------------------------------------"
sleep 5


reboot
