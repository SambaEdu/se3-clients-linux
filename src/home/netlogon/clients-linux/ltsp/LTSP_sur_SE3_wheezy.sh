#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 27/05/2017
# Fusionne le script Xenial et Stretch
# Sous licence GNU

# Ce script est paramétrable via les deux variables suivantes :
ENVIRONNEMENT="i386"				# i386 ou amd64
DISTRIB="xenial"				# xenial ou stretch

if [ "$DISTRIB" = "xenial" ]
then
	BUREAU="ubuntu-mate"			
else
	BUREAU="mate"
fi

# Remarque : ce script a été testé et personnalisé pour le bureau mate ...
# Il est très certainement fonctionnel, à la personnalisation du bureau prêt, avec d'autres bureaux ...
# Valeurs possibles avec xenial : ubuntu (unity), ubuntu-mate, cinnamon, xubuntu ou lubuntu
# Valeurs possibles avec stretch: lxde, mate, xfce4, gnome, cinnamon

# Début de l'installation :
# Insertion de toutes les fonctions la librairie lib.sh
. /home/netlogon/clients-linux/lib.sh

# Récupération de variables spécifiques au se3
. /etc/se3/config_c.cache.sh
. /etc/se3/config_d.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_s.cache.sh

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script installe un serveur LTSP de clients lourds $DISTRIB sur votre SE3 Wheezy											"
echo " Tout PC disposant d un boot PXE et d au moins 512 Mo de RAM pourra démarrer sur le reseau									"
echo " Votre se3 n a pas besoin d être très puissant, juste d'une carte reseau 1Gbs													"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script va simplement, sur votre se3 :																						"
echo " - créer un répertoire /opt/ltsp/i386 (le chroot) contenant la racine / des clients lourds $DISTRIB							"
echo " - Faire une sauvegarde de ce chroot dans /var/se3/ltsp																		"
echo " - installer et configurer les services NFS et NBD pour distribuer l'environnement (le chroot) des clients lourds 			"
echo " - créer un répertoire /tftpboot/ltsp contenant l'initrd et le kernel pour le boot PXE des clients lourds	$DISTRIB 			"
echo " - ajouter une entrée au menu /tftpboot/pxelinux.cfg/default pour pouvoir démarrer un PC PXE en client lourd $DISTRIB avec NBD"
echo " - ajouter une entrée au menu /tftpboot/pxelinux.cfg/maintenance pour pouvoir démarrer un client lourd $DISTRIB avec NFS 		"
echo " - configurer le chroot des clients lourds $DISTRIB pour l'identification avec l annuaire ldap et le montage automatique des partages Samba du se3  "
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Etes-vous sur de vouloir débuter l installation ? (o ou n)																				"
read REPONSE
if [ "$REPONSE" != "o" ]
then
	exit 0
fi


echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 0-Vérifications avant installation de ltsp																					"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

if [ "$ENVIRONNEMENT" != "i386" ] && [ "$ENVIRONNEMENT" != "amd64" ]
then
	echo "La variable ENVIRONNEMENT en début de script n'est pas correctement renseignée : la mettre à i386 ou à amd64"
	exit 1
fi

if [ "$DISTRIB" != "xenial" ] && [ "$DISTRIB" != "stretch" ]
then
	echo "La variable DISTRIB en début de script n'est pas correctement renseignée : la mettre à xenial ou à stretch"
	exit 1
fi

if egrep -q "^7" /etc/debian_version
then
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

if [ -z "$se3ip" ] || [ -z "$ldap_base_dn" ] || [ -z "$se3mask" ]
then
	echo 'Une des variables se3ip ou ldap_base_dn ou se3mask est vide'
	echo 'L installation de ltsp ne peut pas se poursuivre ...'
	echo 'Vérifier la définition de ces variables dans les fichiers de confs /etc/se3/config_* de votre se3'
	exit 1
fi

IP_SE3="$se3ip"
IP_PROXY="$proxy_url"
BASE_DN="$ldap_base_dn"

if [ "$DISTRIB" = 'stretch' ]
then # Sous Stretch
	PREF_FIREFOX='firefox-esr/firefox-esr.js'
else # Sous Xenial
	PREF_FIREFOX='firefox/syspref.js'
fi

REP_MONTAGE='~/Bureau'											# Valeur par défaut pour le montage des partages Samba via pam-mount
FF_MONTAGE='/home/$USER/Bureau'									# Valeur par défaut	pour la création du profil FF persistant
if [ "$BUREAU" = "mate" ] || [ "$BUREAU" = "ubuntu-mate" ]		# Sous mate, les partages doivent être montés dans ~ à la place de ~/Bureau
then
	REP_MONTAGE='~'												# Valeur pour le bureau mate
	FF_MONTAGE='/home/$USER'									# Valeur pour le bureau mate
fi

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 1-Installation du serveur ltsp (nfs, nbd, debootstrap, squashfs et la doc) :																							"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

apt-get update
apt-get install -y ltsp-server ltsp-docs

# Finalement, on garde le service NFS dans un sous-menu de maintenance car c'est bien pratique pour faire des tests 
if [ ! -d /opt/ltsp ]
then
	mkdir /opt/ltsp
fi

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 2-Configuration du service NFS (accessible depuis le sous-menu perso du menu maintenance du se3)								"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

resultat=$(grep -F '/opt/ltsp *(ro,no_root_squash,async,no_subtree_check)' /etc/exports)
if [ -z "$resultat" ]
then
cat <<EOF >> "/etc/exports"
/opt/ltsp *(ro,no_root_squash,async,no_subtree_check)                             
EOF
fi
service nfs-kernel-server restart

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 3-Construction de l environnement $ENVIRONNEMENT pour les clients lourds $DISTRIB											"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

# Le script gutsy est fonctionnel pour construire un environnement xenial
if [ ! -e "/usr/share/debootstrap/scripts/xenial" ]
then
	ln -s /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/xenial
fi

if [ "$DISTRIB" = 'xenial' ]
then
	VENDOR=Ubuntu CONFIG_NBD=true ltsp-build-client --arch "$ENVIRONNEMENT" --chroot "$ENVIRONNEMENT" --fat-client-desktop "$BUREAU-desktop" --dist "$DISTRIB" --mirror http://fr.archive.ubuntu.com/ubuntu/ --locale fr_FR.UTF-8 --prompt-rootpass --purge-chroot
else
	if [ "$ENVIRONNEMENT" = 'i386' ] 		# Arret de la prise en charge des architectures i486 depuis stretch
	then
		CONFIG_NBD=true ltsp-build-client --arch "$ENVIRONNEMENT" --chroot "$ENVIRONNEMENT" --fat-client-desktop "task-$BUREAU-desktop" --dist "$DISTRIB" --mirror http://ftp.fr.debian.org/debian/ --locale fr_FR.UTF-8 --kernel-packages linux-image-686 --prompt-rootpass --purge-chroot
	else
		CONFIG_NBD=true ltsp-build-client --arch "$ENVIRONNEMENT" --chroot "$ENVIRONNEMENT" --fat-client-desktop "task-$BUREAU-desktop" --dist "$DISTRIB" --mirror http://ftp.fr.debian.org/debian/ --locale fr_FR.UTF-8 --prompt-rootpass --purge-chroot
	fi
fi

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 4-Creation d'un compte local enseignant dans l'environnement des clients lourds												"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

ltsp-chroot --arch "$ENVIRONNEMENT" adduser enseignant
ltsp-chroot --arch "$ENVIRONNEMENT" chmod -R 700 /home/enseignant

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 5-Configuration de lts.conf afin que les clients lourds démarrent de façon complément autonome 								"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/etc/lts.conf"
[default]
LTSP_CONFIG=true
KEEP_SYSTEM_SERVICES="lightdm"      # Indique à l'environnement du client lourd de lancer lightdm lors du démarrage
DEFAULT_DISPLAY_MANAGER=""          # Lance le gestionnaire d'affichage présent dans l'environnement des clients lourds (lightdm) à la place de LDM
XKBLAYOUT=fr						# Peut être util sur Ubuntu, pour certains bureaux (lubuntu)
USE_LOCAL_SWAP=true					# Pour utiliser une éventuelle partition swap présente sur le disque dur local du client lourd
EOF

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 6-Configuration du timezone (paquet tzdata) pour éviter un décalage horaire de 2 heures										"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
tzdata	tzdata/Zones/Etc	select	UTC
tzdata	tzdata/Zones/Europe	select	Paris
tzdata  tzdata/Areas	select  Europe
EOF
echo 'Europe/Paris' > /etc/timezone
dpkg-reconfigure tzdata --frontend=noninteractive

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 7-Définir les règles polkit-1 pour désactiver la mise en veille (suspend) et l'hibernation									"
echo " 	 La désactivation user switching se fera avec dconf																			"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

# Version de polkit sur Stretch ou xenial : 0.105 => possibilité de définir les règles avec des fichiers .pkla dans /etc/polkit-1/localauthority/
# Desactivation "complète" de l'hibernation
cat << 'EOF' > "/opt/ltsp/$ENVIRONNEMENT/etc/polkit-1/localauthority/90-mandatory.d/disable-hibernate.pkla"
[Disable hibernate (upower)]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
ResultActive=no
ResultInactive=no
ResultAny=no

[Disable hibernate (logind)]
Identity=unix-user:*
Action=org.freedesktop.login1.hibernate
ResultActive=no

[Disable hibernate for all sessions (logind)]
Identity=unix-user:*
Action=org.freedesktop.login1.hibernate-multiple-sessions
ResultActive=no
EOF

# Desactivation "complète" de la mise en veille (suspend)
cat << 'EOF' >  "/opt/ltsp/$ENVIRONNEMENT/etc/polkit-1/localauthority/90-mandatory.d/disable-suspend.pkla"
[Disable suspend (upower)]
Identity=unix-user:*
Action=org.freedesktop.upower.suspend
ResultActive=no
ResultInactive=no
ResultAny=no

[Disable suspend (logind)]
Identity=unix-user:*
Action=org.freedesktop.login1.suspend
ResultActive=no

[Disable suspend for all sessions (logind)]
Identity=unix-user:*
Action=org.freedesktop.login1.suspend-multiple-sessions
ResultActive=no
EOF

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 8-Paramétrer PAM pour qu il consulte l annuaire LDAP de se3 lors de l identification d un utilisateur sur un client lourd	"
echo "   et pour qu'il réalise le montage automatique des partages Samba du se3 grace à pam_mount									"
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

# Installation des paquets nécessaires à l'identification LDAP avec PAM
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
libnss-ldapd    libnss-ldapd/nsswitch    multiselect    group, passwd, shadow
libnss-ldapd    libnss-ldapd/clean_nsswitch    boolean    false
libpam-ldapd    libpam-ldapd/enable_shadow    boolean    true 
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

ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y --no-install-recommends nslcd libnss-ldapd libpam-ldapd
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y --no-install-recommends libpam-mount cifs-utils
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y samba
    
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
ltsp-chroot --arch "$ENVIRONNEMENT" chmod -R 700 /etc/skel

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 9-Utilisation de pam_mount pour monter automatiquement les partages Samba du se3 à l ouverture de session d un utilisateur de client lourd "
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

# Afin de pouvoir monter des partages webdav
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
davfs2	davfs2/user_name	string	davfs2
davfs2	davfs2/new_user	boolean	true
davfs2	davfs2/new_group	boolean	true
davfs2	davfs2/suid_file	boolean	false
davfs2	davfs2/non_root_users_confimed	note	
davfs2	davfs2/group_name	string	davfs2
EOF
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y davfs2

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
		fstype="cifs"
		server="$IP_SE3"
		path="netlogon-linux"
		mountpoint="$REP_MONTAGE/Clients-linux"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		fstype="cifs"
		server="$IP_SE3"
		path="homes/Docs"
		mountpoint="$REP_MONTAGE/Docs (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<volume
		user="*"
		fstype="cifs"
		server="$IP_SE3"
		path="Classes"
		mountpoint="$REP_MONTAGE/Classes (sur le reseau)"
		options="nobrl,serverino,iocharset=utf8,sec=ntlmv2"
/>

<!-- Example de volume réalisant le montage automatique d'un partage webdav à l'ouverture de session : à décommenter et renseigner l'url du serveur webdav
<volume
        user="*"
        fstype="davfs"
        path="http://URL_SERVEUR_WEBDAV/remote.php/webdav/"
        mountpoint="~/Owncloud"
        options="username=%(USER),uid=%(USER),gid=%(GROUP),noexec,nodev,nosuid,dir_mode=0700,file_mode=0700"
/>
-->

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
echo " 10-Configuration du proxy															"
echo "--------------------------------------------------------------------------------------"
sleep 5

masque_reseau=$(($(echo "$se3mask" | grep -o "255" | wc -l)*8))
ip_proxy="$(echo "$IP_PROXY" | cut -d ':' -f 1)"
port_proxy="$(echo "$IP_PROXY" | cut -d ':' -f 2)"

# Définition du proxy, si le port du proxy est défini
if [ ! -z "$port_proxy" ]
then
	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.profile"
export https_proxy="http://$IP_PROXY"
export no_proxy="localhost,127.0.0.1,${IP_SE3}/${masque_reseau}"
EOF

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/environment"
https_proxy="http://$IP_PROXY"
no_proxy="localhost,127.0.0.1,${IP_SE3}/${masque_reseau}"
EOF

	cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/apt.conf.d/95proxy"
Acquire::https::Proxy "http://$IP_PROXY/";
EOF

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/wgetrc"
https_proxy = http://$IP_PROXY/
use_proxy = on
EOF

# On règle le proxy de Firefox avec l'option "Configuration manuelle du proxy" et en cochant "Utilser ce proxy pour tous les protocoles"
# On évite ainsi les problèmes d'accès aux sites en https, ...
# Enfin, on désactive le proxy pour l'accès aux postes du réseau pédagogique (en particulier à l'interface web du se3)
# On peut définir un paramètre de trois façons différentes :
# - defaultPref : set new default value 
# - pref : set pref, but allow changes in current session
# - lockPref : lock pref, disallow changes

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/$PREF_FIREFOX"
// Define proxy when an IP and PORT are specified
pref("network.proxy.type", 1);
pref("network.proxy.share_proxy_settings", true);
pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, ${IP_SE3}/${masque_reseau}");
pref("network.proxy.backup.ftp", "${ip_proxy}");
pref("network.proxy.backup.ftp_port", ${port_proxy});
pref("network.proxy.backup.socks", "${ip_proxy}");
pref("network.proxy.backup.socks_port", ${port_proxy});
pref("network.proxy.backup.ssl", "${ip_proxy}");
pref("network.proxy.backup.ssl_port", ${port_proxy});
pref("network.proxy.http", "${ip_proxy}");
pref("network.proxy.http_port", ${port_proxy});
pref("network.proxy.ftp", "${ip_proxy}");
pref("network.proxy.ftp_port", ${port_proxy});
pref("network.proxy.socks", "${ip_proxy}");
pref("network.proxy.socks_port", ${port_proxy});
pref("network.proxy.ssl", "${ip_proxy}");
pref("network.proxy.ssl_port", ${port_proxy});
EOF
else
# On règle le proxy d'Iceweasel avec l'option "Détection automatique des paramètres proxy pour ce réseau"
# Cette option permet de gérer les réseaux qui n'ont pas de proxy (proxy transparent) ainsi que ceux gérés par un fichier wpad.dat (avec Amon par exemple)
	cat <<'EOF' >> "/opt/ltsp/$ENVIRONNEMENT/etc/$PREF_FIREFOX"
// Define proxy when no IP is specified for proxy
pref("network.proxy.type", 4);
EOF
fi

echo "--------------------------------------------------------------------------------------"
echo " 11-Configuration de lightdm 															"
echo "--------------------------------------------------------------------------------------"
sleep 5

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

# Sous certain bureau, comme mate ou lubuntu, le clavier n'est pas mis en azerty par le serveur X
# On utilisa le commande xsetxkbmap fr pour forcer le layout du clavier en azerty
# On enfonce le clou en exécutant la commande une 2de fois à l'ouverture de session
# On en profite pour lancer le verrouillage numérique du clavier
cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf"
display-setup-script=/usr/bin/setxkbmap fr
greeter-setup-script=/usr/bin/numlockx on
session-setup-script=/usr/bin/setxkbmap fr
EOF

# Création d'un lanceur qui va se charger de créer un profil firefox persistant dans le partage Docs de l'utilisateur qui se loggue
# La logique est la suivante :
# Si un répertoire .mozilla est présent dans le "~" alors on ne fait rien car cela signifie que l'administrateur a déposé un .mozilla modèle sur le serveur ltsp dans /etc/skel/.mozilla afin de le rendre non persistant
# Sinon, on créé un profil .mozilla persistant dans le partage Docs/.ltsp/.mozilla en copiant, s'il existe, un éventuel modèle mis par l'administrateur dans /home/.mozilla sur le serveur ltsp.
# Restera à voir comment gérer les maj des profils firefox persistants ...

# On crée la partie "variable" du script (FF_MONTAGE vaut ~ ou ~/Bureau selon le bureau installé dans le chroot)
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/usr/local/bin/logon.sh"
#!/bin/sh
# Script executé en tant qu utilisateur apres l ouverture de session et qui se charge de créer un profil firefox persistant par utilisateur dans le partage samba Docs/.ltsp/.mozilla
REP_DOCS="$FF_MONTAGE"
EOF

# On crée la partie "fixe" du script:
cat <<'EOF' >> "/opt/ltsp/$ENVIRONNEMENT/usr/local/bin/logon.sh"
exec > "/home/$USER/.logon.log" 2>&1
set -x

# Cette fonction a pour but de rendre personalisable et persistant certains répertoires présent dans le home de l'utilisateur qui se loggue
# Si "~/$REP_NAME" n'existe pas, elle crée un lien symbolique de "~/$REP_NAME" vers le partage samba "//Docs/.ltsp/$REP_NAME"
# Si l'administrateur dépose un repertoire modèle "$REP_NAME" dans /etc/skel2 sur le serveur ltsp (chroot) alors  
# ce repertoire "/etc/skel2/$REP_NAME" sera utilisé pour initialiser "//Docs/.ltsp/$REP_NAME" de l'utilisateur qui se loggue

rendre_repertoire_persistant()
{
local REP_NAME="$1"
# On vérifie qu'on peut créer le lien symbolique à savoir :
# - que le répertoire $REP_NAME n'existe pas dans le home de l'utilisateur
# - que le partage /homes/Docs est monté dans le home de l'utilisateur qui se loggue
if [ ! -d "/home/$USER/$REP_NAME" ] && [ -d "$REP_DOCS/Docs (sur le reseau)" ] && [ $(mount | grep '/homes/Docs' | wc -l)  != 0 ]
then
	# Si la repertoire REP_NAME n'existe pas sur le partage Samba de l'utilisateur, alors on cherche à l'initialiser un éventuelle repertoire du même nom présent dans /etc/skel2
	if [ ! -d "$REP_DOCS/Docs (sur le reseau)/.ltsp/$REP_NAME" ]
	then	
		[ ! -d "$REP_DOCS/Docs (sur le reseau)/.ltsp" ] && mkdir "$REP_DOCS/Docs (sur le reseau)/.ltsp"
        if [ -d "/etc/skel2/$REP_NAME" ]
        then
			cp -r "/etc/skel2/$REP_NAME" "$REP_DOCS/Docs (sur le reseau)/.ltsp/$REP_NAME"
        else
			mkdir "$REP_DOCS/Docs (sur le reseau)/.ltsp/$REP_NAME"
        fi
	fi
	# La commande cp précédente peut prendre du temps, surtout si le repertoire REP_NAME a une taille importante :
	# il est donc possible que l'utilisateur crée le répertoire REP_NAME dans son HOME avant que le lien symbolique ne soit créé ...
	# cela peut se produire par exemple si l'utilisateur lance rapidement firefox et que /etc/skel3/.mozilla a une taille importante ...
	# Si REP_NAME apparaît avant la création du lien, on ne crée pas ce dernier : REP_NAME sera persistant à la prochaine connexion de l'utilisateur.
    [ ! -d "/home/$USER/$REP_NAME" ] && ln -s "$REP_DOCS/Docs (sur le reseau)/.ltsp/$REP_NAME" "/home/$USER/$REP_NAME" 
fi
}

#rendre_repertoire_persistant .mozilla
#rendre_repertoire_persistant .wine

exit 0
EOF

ltsp-chroot --arch "$ENVIRONNEMENT" chmod 755 /usr/local/bin/logon.sh

# Création du lanceur .desktop qui se chargera d'exécuter le script précédent à l'ouverture de session
rm -rf "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.config/autostart"
mkdir -p "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.config/autostart"

cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.config/autostart/logon.desktop"
[Desktop Entry]
Type=Application
Name=FirefoxProfil
Exec=/usr/local/bin/logon.sh
Terminal=false
EOF

echo "--------------------------------------------------------------------------------------"
echo " 12-Configuration de l environnement $ENVIRONNEMENT des clients lourds $DISTRIB	 	"
echo "--------------------------------------------------------------------------------------"
sleep 5

if [ "$DISTRIB" = "xenial" ]
then
# Add _apt permissions on update-notifier
ltsp-chroot --arch "$ENVIRONNEMENT" adduser --force-badname --system --home /nonexistent --no-create-home --quiet _apt
ltsp-chroot --arch "$ENVIRONNEMENT" chown _apt /var/lib/update-notifier/package-data-downloads/partial/

# Préconfiguration de ttf-mscorefonts-installer sous Ubuntu
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<'EOF'
ttf-mscorefonts-installer	msttcorefonts/dldir	string	
ttf-mscorefonts-installer	msttcorefonts/dlurl	string	
ttf-mscorefonts-installer	msttcorefonts/accepted-mscorefonts-eula	boolean	true
ttf-mscorefonts-installer	msttcorefonts/present-mscorefonts-eula	note
EOF

# Dépots Ubuntu partenaire
# echo 'deb http://archive.canonical.com/ubuntu xenial partner' >> "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list"

ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
#ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y dist-upgrade
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y -f nano unzip aptitude less flashplugin-installer firefox-locale-fr xterm shutter numlockx
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y chromium-browser chromium-browser-l10n
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y pepperflashplugin-nonfree
ltsp-chroot --arch "$ENVIRONNEMENT" update-pepperflashplugin-nonfree --install

	case "$BUREAU" in
    ubuntu-mate)	# Sous le bureau Mate (Bureau par défaut)
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y ubuntu-restricted-extras
    ;;
    
    ubuntu)			# Sous le bureau Unity
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y ubuntu-restricted-extras ubuntu-restricted-addons
    ;;
    
    xubuntu)		# Sous le bureau Xubuntu
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y xubuntu-restricted-extras xubuntu-restricted-addons xfce4-goodies xfwm4-themes
    ;;
    
    lubuntu)		# Sous le bureau Lubuntu
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y lubuntu-restricted-extras lubuntu-restricted-addons
    ;;
    
    cinnamon)		
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y cinnamon-desktop-environment cinnamon-l10n
    ;;

    *)
		true
    ;;
    esac

else 	# sous Stretch
# Définitions des dépôts Debian
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list"
deb http://ftp.fr.debian.org/debian stretch main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch main non-free contrib

deb http://security.debian.org/ stretch/updates main 
deb-src http://security.debian.org/ stretch/updates main 

deb http://ftp.fr.debian.org/debian stretch-updates main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch-updates main non-free contrib

deb http://ftp.fr.debian.org/debian stretch-backports main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch-backports main non-free contrib
EOF
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
#ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y dist-upgrade 
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y nano unzip aptitude less firmware-linux ttf-mscorefonts-installer firefox-esr-l10n-fr numlockx system-config-printer
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y flashplugin-nonfree
ltsp-chroot --arch "$ENVIRONNEMENT" update-flashplugin-nonfree --install				# Ne semble plus fonctionnelle sous Stretch ...
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y chromium chromium-l10n
	if [ "$ENVIRONNEMENT" = "amd64" ] # Depuis Jessie, le paquet pepperflashplugin-nonfree n'est dispo que sous architecture amd64
	then 
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y pepperflashplugin-nonfree
		ltsp-chroot --arch "$ENVIRONNEMENT" update-pepperflashplugin-nonfree --install
	fi
fi

# Afin de pouvoir imprimer et scanner :
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y cups sane

# Problème : 	pour les TNI/VPI, Openboard (successeur d'Open Sankore 2.5) n'est disponible qu'en .deb sur Ubuntu 14.04 et 16.04 en architecture 64
#				et le paquet ne semble pas facilemenet installable sur Stretch Amd64:  des dépendances sont non satisfaites et un "apt-get install -f" ne les résout pas ...
if [ "$DISTRIB" = "xenial" ]
then
	case "$ENVIRONNEMENT" in

    i386)		# le parquet Open-Sankore 2.5 de Precise fonctionne encore sur xenial : on l'utiliser car Open-board n'est pas dispo en i386
		# Penser à activer le composing, sous Mate : Menu > Centre de Contrôle > Paramètres du bureau > Fenêtres > Cocher "Use compositing/Utiliser le compositing"
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y libphonon4
		ltsp-chroot --arch "$ENVIRONNEMENT" rm rf --one-file-system 'Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip' opensankore
		ltsp-chroot --arch "$ENVIRONNEMENT" wget -O 'Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip' 'http://www.cndp.fr/open-sankore/OpenSankore/Releases/v2.5.1/Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip' && ltsp-chroot --arch "$ENVIRONNEMENT" unzip -d opensankore 'Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip' && ltsp-chroot --arch "$ENVIRONNEMENT" dpkg -i /opensankore/Open-Sankore_2.5.1_i386.deb
		ltsp-chroot --arch "$ENVIRONNEMENT" rm -f "Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip"
        ltsp-chroot --arch "$ENVIRONNEMENT" rm -rf --one-file-system /opensankore
    ;;
    
    amd64)		# Open-board (le successeur d'Open-Sankoré) n'est disponible qu'en version amd64 ...
		ltsp-chroot --arch "$ENVIRONNEMENT" rm -f openboard_ubuntu_16.04_1.3.5_amd64.deb
		ltsp-chroot --arch "$ENVIRONNEMENT" wget -O 'openboard_ubuntu_16.04_1.3.5_amd64.deb' 'https://github.com/OpenBoard-org/OpenBoard/releases/download/v1.3.5/openboard_ubuntu_16.04_1.3.5_amd64.deb' && ltsp-chroot --arch "$ENVIRONNEMENT" dpkg -i openboard_ubuntu_16.04_1.3.5_amd64.deb
		ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -f -y
		ltsp-chroot --arch "$ENVIRONNEMENT" rm -f openboard_ubuntu_16.04_1.3.5_amd64.deb
    ;;

    *)
		true
    ;;
    esac
fi

# Logiciels bureautique:
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y libreoffice libreoffice-l10n-fr scribus freeplane

# Logiciels pour le son/video:
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y vlc audacity openshot kdenlive breeze-icon-theme imagination libav-tools

# Logiciels pour la physique:
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install stellarium avogadro 

# Logiciels mathématiques :
# Dépot pour install geogebra 5 avec la commande apt-get :
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list.d/geogebra.list"
deb http://www.geogebra.net/linux/ stable main
EOF
# Ajouter la clé du dépot geogebra5
ltsp-chroot --arch "$ENVIRONNEMENT" wget https://static.geogebra.org/linux/office@geogebra.org.gpg.key && ltsp-chroot --arch "$ENVIRONNEMENT" apt-key add office@geogebra.org.gpg.key
ltsp-chroot --arch "$ENVIRONNEMENT" rm -f office@geogebra.org.gpg.key

ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y algobox scilab geogebra5

# Logiciels graphisme:
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y install inkscape xia blender sweethome3d mypaint pinta 

# Logiciels pour ICN/ISN (à compléter):
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install scratch ghex geany rurple-ng

if [ "$DISTRIB" = "stretch" ]
then
	# Ajout du dépôt sid (unstable) pour tester python3-pygame
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install idle-python3.5
	cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list.d/sid.list"
deb http://ftp.fr.debian.org/debian/ unstable main
EOF
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update && ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install python3-pygame/unstable
	# Pour éviter d'installer d'autres paquets de la branche unstable :
	rm -f "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list.d/sid.list"
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
else   # Sous Xenial ....
	# Installation de pygame (1.9.2) pour Python 3 mais avec un dépôt non officiel ...
	#ltsp-chroot --arch "$ENVIRONNEMENT" add-apt-repository -y ppa:thopiekar/pygame
	#ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update && ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y idle-python3.5 python3-pygame
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -y idle-python3.5
fi

# sonic-pi
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
jackd2   jackd/tweak_rt_limits   boolean false
EOF
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install sonic-pi

# wireshark 
# Il n'est pas possible de faire un setuid dans un chroot pour des raisons de sécurité
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
wireshark-common	wireshark-common/install-setuid	boolean	false
EOF
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install wireshark

# Pour désactiver le "warning" qui s'affiche au lancement de wireshark ... 
# sed -i 's/disable_lua = false/disable_lua = true/' "/opt/ltsp/$ENVIRONNEMENT/etc/wireshark/init.lua"

# On utilisera donc sudo pour lancer wireshark : par défaut, seul les membres du groupe admins du se3 pourront le lancer
# Mais il est possible d'ajouter un groupe classe (ICN/ISN) en ajoutant une ligne au fichier ci-dessous
echo '%admins	ALL=(root) NOPASSWD: /usr/bin/wireshark' > "/opt/ltsp/$ENVIRONNEMENT/etc/sudoers.d/wireshark"

# On modifie le lanceur de wireshark pour le lancer avec sudo
sed -i 's/Exec=wireshark %f/Exec=sudo wireshark %f/' "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/wireshark.desktop"
# Fin de wireshark

### Installation Arduino ###
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install arduino

# On déplace le dossier sketchbook (contenant ardublock) dans le repertoire /opt/arduino/ et on récupère ardublock
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir -p "/opt/arduino/sketchbook/tools/ArduBlockTool/tool" "/opt/arduino/sketchbook/libraries"
ltsp-chroot --arch "$ENVIRONNEMENT" wget -P "/opt/arduino/sketchbook/tools/ArduBlockTool/tool" 'https://github.com/SambaEdu/se3-clients-linux/raw/master/src/home/netlogon/clients-linux/ltsp/stretch/opt/arduino/sketchbook/tools/ArduBlockTool/tool/ardublock-all-20130712.jar'
ltsp-chroot --arch "$ENVIRONNEMENT" chown -R root:root "/opt/arduino"
ltsp-chroot --arch "$ENVIRONNEMENT" chmod -R 755 "/opt/arduino"

# On copie le fichier de de préférence dans le skel :
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir "/etc/skel/.arduino"
ltsp-chroot --arch "$ENVIRONNEMENT" wget -P "/etc/skel/.arduino" 'https://raw.githubusercontent.com/SambaEdu/se3-clients-linux/master/src/home/netlogon/clients-linux/ltsp/skel/.arduino/preferences.txt'

# Utilisation du module pam_group.so pour ajouter les utilisateurs au groupe dialout (nécessaire pour pouvoir communiquer avec la carte arduino)
sed -i '/pam_mount.so/i \auth	optional	pam_group.so' "/opt/ltsp/$ENVIRONNEMENT/etc/pam.d/common-auth"

# le fichier pam common-auth a été modifié : il est nécessaire de préconfigurer le module libpam-runtime afin qu'il accepte les modifs apportées
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<'EOF'
libpam-runtime	libpam-runtime/no_profiles_chosen	error
libpam-runtime	libpam-runtime/override	boolean	false
libpam-runtime	libpam-runtime/conflicts	error
libpam-runtime	libpam-runtime/profiles	multiselect	unix, libpam-mount, ldap, systemd, gnome-keyring
EOF

# Configuration du fichier de conf de pam_group.so
echo '*;*;*;Al0000-2400;dialout' >> "/opt/ltsp/$ENVIRONNEMENT/etc/security/group.conf"

# Blockly arduino en local
ltsp-chroot --arch "$ENVIRONNEMENT" wget -O gh-pages.zip "https://github.com/technologiescollege/Blockly-at-rduino/archive/gh-pages.zip" && ltsp-chroot --arch "$ENVIRONNEMENT" unzip "gh-pages.zip" -d "/opt/"
ltsp-chroot --arch "$ENVIRONNEMENT" rm -f "gh-pages.zip"
### Fin Arduino ###

### Installation Processing ###
archive_processing='processing-3.3.3'
version_processing="$archive_processing"

if [ "$ENVIRONNEMENT" = "amd64" ]
then
	version_processing="${archive_processing}-linux64"
fi

if [ "$ENVIRONNEMENT" = "i386" ]
then
	version_processing="${archive_processing}-linux32"
fi

# Nettoyage avant installation
ltsp-chroot --arch "$ENVIRONNEMENT" rm -rf --one-file-system "$archive_processing" "${version_processing}.tgz"

# Téléchargement de l'archive et désarchivage
ltsp-chroot --arch "$ENVIRONNEMENT" wget -O "${version_processing}.tgz" "http://download.processing.org/${version_processing}.tgz" && ltsp-chroot --arch "$ENVIRONNEMENT" tar zxvf "${version_processing}.tgz"
ltsp-chroot --arch "$ENVIRONNEMENT" rm -f "${version_processing}.tgz"
ltsp-chroot --arch "$ENVIRONNEMENT" mv -f "$archive_processing" "/opt/processing"
# Le repertoire sketchbook est créé dans /opt/processing/
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir -p "/opt/processing/sketchbook/examples" "/opt/processing/sketchbook/libraries" 
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir "/opt/processing/sketchbook/modes" "/opt/processing/sketchbook/tools" 
ltsp-chroot --arch "$ENVIRONNEMENT" chown -R root:root /opt/processing
ltsp-chroot --arch "$ENVIRONNEMENT" chmod -R 755 /opt/processing

# On copie les fichier de conf de processing dans le skel :
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir -p "/etc/skel/.processing/console" 
echo 'fr' > "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.processing/language.txt"
ltsp-chroot --arch "$ENVIRONNEMENT" wget -P "/etc/skel/.processing" 'https://raw.githubusercontent.com/SambaEdu/se3-clients-linux/master/src/home/netlogon/clients-linux/ltsp/skel/.processing/preferences.txt'
### Fin Processing ###

### Installation de mBlock pour le robot mbot
if [ "$ENVIRONNEMENT" = "amd64" ]   # La version 4 de mblock est disponible sous forme d'archive seulement pour une architecture amd64
then
	ltsp-chroot --arch "$ENVIRONNEMENT" wget -O 'mBlock-4.0.0-linux-4.0.0.tar.gz' 'https://github.com/Makeblock-official/mBlock/releases/download/V4.0.0-Linux/mBlock-4.0.0-linux-4.0.0.tar.gz' && ltsp-chroot --arch "$ENVIRONNEMENT" tar zxvf 'mBlock-4.0.0-linux-4.0.0.tar.gz'
	ltsp-chroot --arch "$ENVIRONNEMENT" rm -f 'mBlock-4.0.0-linux-4.0.0.tar.gz'
	ltsp-chroot --arch "$ENVIRONNEMENT" mv -f mBlock "/opt/mBlock"
	ltsp-chroot --arch "$ENVIRONNEMENT" mkdir /opt/mBlock/mblock-setting
	ltsp-chroot --arch "$ENVIRONNEMENT" chown -R root:root /opt/mBlock
else	 							# Mais un paquet .deb existe tout de même pour les architectures i386
	# Le téléchargement de ce paquet (disponible sur le site officiel de mblock) est très lent et échoue très souvent ... 
	# De plus, le paquet ajoute et lance au démarrage du client, un service ideserviceplus dont le rôle n'est pas documenté sur internet
	#ltsp-chroot --arch "$ENVIRONNEMENT" wget -O mBlock.deb 'https://mblockdev.blob.core.chinacloudapi.cn/mblock-src/mBlock.deb'
	#ltsp-chroot --arch "$ENVIRONNEMENT" dpkg -i mBlock.deb
	#ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -f -y
	#ltsp-chroot --arch "$ENVIRONNEMENT" rm -f mBlock.deb && chown -R root:root "/opt/ltsp/$ENVIRONNEMENT/opt/makeblock"
	echo 'Pas de version de mblock installable pour architecture i386'
fi
# Créer le lanceur mblock et le mettre dans le dash du bureau mate
## Fin de l'installation de mblock

if [ "$ENVIRONNEMENT" = "amd64" ]
then	# Prise en charge de l'architecture i386 pour 'installation de wine
	ltsp-chroot --arch "$ENVIRONNEMENT" dpkg --add-architecture i386
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
	ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y wine
	#ltsp-chroot --arch "$ENVIRONNEMENT" dpkg --remove-architecture i386
	#ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update
else
	ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y wine
fi

### Installation d'Adobe Air (un paquet .deb semble n'exister que sous Ubuntu)
if [ "$DISTRIB" = "xenial" ]
then
	ltsp-chroot --arch "$ENVIRONNEMENT" wget -O "adobe-air_${ENVIRONNEMENT}.deb" "http://drive.noobslab.com/data/apps/AdobeAir/adobeair_2.6.0.2_${ENVIRONNEMENT}.deb" && ltsp-chroot --arch "$ENVIRONNEMENT" dpkg -i "adobe-air_${ENVIRONNEMENT}.deb"
	ltsp-chroot --arch "$ENVIRONNEMENT" apt-get install -f -y
	ltsp-chroot --arch "$ENVIRONNEMENT" rm -f "adobe-air_${ENVIRONNEMENT}.deb"
	
	# Desactivation d'apport (fenêtre de signalement de bug logiciel)
	echo 'enabled=0' > "/opt/ltsp/$ENVIRONNEMENT/etc/default/apport"
fi
#### Fin de l'installation d'Adobe Air
# Pour installer Scratch 2, il suffira de lancer un client lourd, puis d'ouvrir un émulateur de console et saisir en tant que root :
#version_scratch2='Scratch-455'
# wget "https://scratch.mit.edu/scratchr2/static/sa/${version_scratch2}.air"
# Adobe\ AIR\ Application\ Installer
# Selectionner le paquet .air de scrath2 puis une fois l'installation terminée et scratch 2 configurée comme souhaité, faire un:
# scp -r '/opt/scratch 2' "root@IP_SERVEUR_LTSP:/opt/$ENVIRONEMENT/opt/"
# Copie le lanceur Sratch 2 disponible sur le bureau :
# scp ~/Bureau/scratch2.desktop "root@IP_SERVEUR_LTSP:/opt/$ENVIRONEMENT/etc/skel/Bureau"
### Fin de l'installation de scratch 2

echo "--------------------------------------------------------------------------------------"
echo " 13-Modification pour que seul le dossier Bureau apparaisse dans le home utilisateur	"
echo "--------------------------------------------------------------------------------------"
sleep 5

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/xdg/user-dirs.defaults"
DESKTOP=Desktop
EOF

echo "--------------------------------------------------------------------------------------"
echo " 14-Copie du skel dans le chroot (création des lanceurs)								"
echo "--------------------------------------------------------------------------------------"
sleep 5

#find "/home/netlogon/clients-linux/ltsp/${DISTRIB}/skel/" -mindepth 1 -maxdepth 1 -exec cp -rf {} "/opt/ltsp/$ENVIRONNEMENT/etc/skel/" \;
# Création des lanceurs dans les menus d'applications :

# copie de dconf/user dans le skel
ltsp-chroot --arch "$ENVIRONNEMENT" mkdir -p /etc/skel/.config/dconf
ltsp-chroot --arch "$ENVIRONNEMENT" wget -P /etc/skel/.config/dconf "https://github.com/SambaEdu/se3-clients-linux/blob/master/src/home/netlogon/clients-linux/ltsp/$DISTRIB/skel/.config/dconf/user"

if [ "$DISTRIB" = "stretch" ]
then # sous debian, c'est le navigateur s'appelle firefox-esr 
# Pour Blockly Arduino :
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/blockly.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=Application
Terminal=false
Name=Blockly Arduino
Name[fr_FR]=Blockly Arduino
Comment=Logiciel de programmation
Exec=firefox-esr %u file:///opt/Blockly-at-rduino-gh-pages/index.html?lang=fr&card=arduino_uno&webaccess=true&localcodebender=false&toolbox=toolbox_arduino_all&toolboxids=CAT_LOGIC,CAT_LOOPS,CAT_MATH,CAT_VARIABLES,CAT_FUNCTIONS,CAT_ARDUINO
Icon=/opt/Blockly-at-rduino-gh-pages/favicon.png
Icon[fr_FR]=/opt/Blockly-at-rduino-gh-pages/favicon.png
Categories=Education;Programmation
EOF

# Pour Xcas online :
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/xcas.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=Application
Terminal=false
Name=Xcas Online
Name[fr_FR]=Xcas Online
Comment=Logiciel de calcul formel
Exec=firefox-esr %u http://www.xcasenligne.fr/giac_online/demoGiacPhp.php
Icon=/usr/share/icons/hicolor/256x256/apps/Xcaslogo.png
Icon[fr_FR]=/usr/share/icons/hicolor/256x256/apps/Xcaslogo.png
Categories=Education;Programmation
EOF

else  # sous ubuntu, le navigateur s'appelle firefox et non firefox-esr
# Pour Blockly Arduino :
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/blockly.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=Application
Terminal=false
Name=Blockly Arduino
Name[fr_FR]=Blockly Arduino
Comment=Logiciel de programmation
Exec=firefox %u file:///opt/Blockly-at-rduino-gh-pages/index.html?lang=fr&card=arduino_uno&webaccess=true&localcodebender=false&toolbox=toolbox_arduino_all&toolboxids=CAT_LOGIC,CAT_LOOPS,CAT_MATH,CAT_VARIABLES,CAT_FUNCTIONS,CAT_ARDUINO
Icon=/opt/Blockly-at-rduino-gh-pages/favicon.png
Icon[fr_FR]=/opt/Blockly-at-rduino-gh-pages/favicon.png
Categories=Education;Programmation
EOF

# Pour Xcas online :
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/xcas.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=Application
Terminal=false
Name=Xcas Online
Name[fr_FR]=Xcas Online
Comment=Logiciel de calcul formel
Exec=firefox %u http://www.xcasenligne.fr/giac_online/demoGiacPhp.php
Icon=/usr/share/icons/hicolor/256x256/apps/Xcaslogo.png
Icon[fr_FR]=/usr/share/icons/hicolor/256x256/apps/Xcaslogo.png
Categories=Education;Programmation
EOF

fi

# Icones pour Xcas
ltsp-chroot --arch "$ENVIRONNEMENT" wget -P "/usr/share/icons/hicolor/256x256/apps" 'https://upload.wikimedia.org/wikipedia/fr/2/2d/Xcaslogo.png'

# Pour processing :
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/processing.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[fr_FR]=/opt/processing/lib/icons/pde-48.png
Name[fr_FR]=processing
Exec=/opt/processing/processing
Name=processing
Icon=/opt/processing/lib/icons/pde-48.png
Categories=Education;Programmation
EOF

# Pour mBlock (V4) sous architecture amd64 (en architecture i386, le .deb se charge de créer le lanceur)
if [ "$ENVIRONNEMENT" = "amd64" ]
then
cat <<'EOF' > "/opt/ltsp/$ENVIRONNEMENT/usr/share/applications/mblock.desktop"
#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[fr_FR]=/opt/mBlock/resources/web/images/loading_panda.png
Name[fr_FR]=mBlock
Exec=/opt/mBlock/mblock
Name=mBlock
Icon=/opt/mBlock/resources/web/images/loading_panda.png
Categories=Education;Programmation
EOF
fi

echo "--------------------------------------------------------------------------------------"
echo " 15-Extinction de tous les clients lourds à 19h par défaut							"
echo "--------------------------------------------------------------------------------------"
sleep 5

echo '0 19 * * * root /sbin/poweroff' > "/opt/ltsp/$ENVIRONNEMENT/etc/cron.d/extinction_clients_lourds"

echo "--------------------------------------------------------------------------------------"
echo " 16-Reconstruction de l'image squashfs (pour NBD)					"
echo "--------------------------------------------------------------------------------------"
sleep 5

if [ "$DISTRIB" = "stretch" ]
then	# Sous ltsp wheezy, pour un chroot debian, c'est nfs qui est utilisé par défaut, il faut utiliser l'option --config-nbd pour configurer nbd
	ltsp-update-image --config-nbd "$ENVIRONNEMENT"
else    # pour un chroot ubuntu, nbd est configuré par défaut pendant la construction du chroot donc l'option --config-nbd est inutile ...
	ltsp-update-image "$ENVIRONNEMENT"
fi
service nbd-server restart

echo "--------------------------------------"
echo " 17-Sauvegarde du chroot des clients lourds (5 minutes)	    "
echo "--------------------------------------"
sleep 5

if [ ! -d "/var/se3/ltsp/originale" ]
then
	mkdir -p "/var/se3/ltsp/originale"
fi
rm -rf "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"
cp -a "/opt/ltsp/$ENVIRONNEMENT" "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 18- Configuration du menu PXE du se3 afin d ajouter une entrée pour pouvoir démarrer un PC PXE en client lourd $DISTRIB 	    "
echo "------------------------------------------------------------------------------------------------------------------------------"
sleep 5

# En "production", c'est le service NBD qui est utilisé pour monter l'environnement des clients lourds
resultat=$(grep "Demarrer le pc en client lourd $DISTRIB $ENVIRONNEMENT avec NBD" "/tftpboot/pxelinux.cfg/default")

if [ -z "$resultat" ]
then
cat <<EOF >> "/tftpboot/pxelinux.cfg/default"
LABEL ltsp"$DISTRIB"
	MENU LABEL ^Demarrer le pc en client lourd $DISTRIB $ENVIRONNEMENT avec NBD
	KERNEL tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/vmlinuz
	APPEND ro initrd=tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/initrd.img init=/sbin/init-ltsp quiet nbdroot=$IP_SE3:/opt/ltsp/$ENVIRONNEMENT root=/dev/nbd0
	IPAPPEND 2
EOF
fi

# Mais, on garde quand même le service NFS pour sa souplesse dans le sous-menu perso du menu maintenance.
# Ce menu n'est accessible qu'à l'admin du se3 et évite de reconstruire l'image squashfs après un modif dans le chroot (pratique pour tester des installations).
resultat=$(grep "Demarrer le pc en client lourd $DISTRIB $ENVIRONNEMENT avec NFS" "/tftpboot/pxelinux.cfg/perso.menu")

if [ -z "$resultat" ]
then
cat <<EOF >> "/tftpboot/pxelinux.cfg/perso.menu"
LABEL ltsp"$DISTRIB"
        MENU LABEL ^Demarrer le pc en client lourd $DISTRIB $ENVIRONNEMENT avec NFS
        KERNEL tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/vmlinuz
        APPEND ro initrd=tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/initrd.img init=/sbin/init-ltsp quiet ip=dhcp boot=nfs nfsroot=$IP_SE3:/opt/ltsp/$ENVIRONNEMENT
        IPAPPEND 2
EOF
fi

# On active (éventuellement) le sous-menu perso dans le menu maintenance
sed -i 's/'^###perso###'//' '/tftpboot/pxelinux.cfg/maintenance.menu'

if [ "$DISTRIB" = "xenial" ]
then
echo "-------------------------------------------------------------------------------------------------------"
echo " 19-Redemarrage dans 5 secondes du serveur pour remettre la local en français (pour Ubuntu uniquement) "
echo "-------------------------------------------------------------------------------------------------------"
sleep 5	&& reboot
fi

exit 0
