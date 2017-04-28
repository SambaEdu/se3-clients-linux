#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 16/04/2017
# Sous licence GNU

# Choisir l'environnement des clients lourds : lxde, mate, xfce4, gnome, cinnamon
ENVIRONNEMENT="i386"
BUREAU="mate"						# Bureau à installer dans le chroot des clients lourds 

# Insertion de toutes les fonctions la librairie lib.sh
. /home/netlogon/clients-linux/lib.sh

# Récupération de variables spécifiques au se3
. /etc/se3/config_c.cache.sh
. /etc/se3/config_d.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_s.cache.sh

IP_SE3="$se3ip"
IP_PROXY="$proxy_url"
BASE_DN="$ldap_base_dn"

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script installe un serveur LTSP de clients lourds Stretch sur votre SE3 Wheezy												"
echo " Tout PC disposant d un boot PXE et d au moins 512 Mo de RAM pourra démarrer sur le reseau									"
echo " Votre se3 n a pas besoin d être très puissant, juste d'une carte reseau 1Gbs													"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Ce script va simplement, sur votre se3 :																						"
echo " - créer un répertoire /opt/ltsp/i386 (le chroot) contenant la racine / des clients lourds Stretch								"
echo " - Faire une sauvegarde de ce chroot dans /var/se3/ltsp																		"
echo " - installer et configurer les services NFS et NBD pour distribuer l'environnement (le chroot) des clients lourds 			"
echo " - créer un répertoire /tftpboot/ltsp contenant l'initrd et le kernel pour le boot PXE des clients lourds	Stretch 				"
echo " - ajouter une entrée au menu /tftpboot/pxelinux.cfg/default pour pouvoir démarrer un PC PXE en client lourd Stretch 			"
echo " - configurer le chroot des clients lourds Stretch pour l'identification avec l annuaire ldap et le montage automatique des partages Samba du se3  "
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

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 1-Installation du serveur ltsp (nfs, nbd, debootstrap, squashfs et la doc) :																							"
echo "------------------------------------------------------------------------------------------------------------------------------"
apt-get update
apt-get install -y ltsp-server ltsp-docs

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 2-Configuration du service NFS (/etc/exports) :																				"
echo "------------------------------------------------------------------------------------------------------------------------------"

if [ ! -d /opt/ltsp ]
then
mkdir /opt/ltsp
fi

cat <<EOF > "/etc/exports"
/opt/ltsp *(ro,no_root_squash,async,no_subtree_check)				  
EOF
service nfs-kernel-server restart

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 3-Construction de l environnement $ENVIRONNEMENT pour les clients lourds Stretch														"
echo "------------------------------------------------------------------------------------------------------------------------------"
ltsp-build-client --arch i386 --chroot "$ENVIRONNEMENT" --fat-client-desktop "task-$BUREAU-desktop" --dist stretch --mirror http://ftp.fr.debian.org/debian/ --locale fr_FR.UTF-8 --kernel-packages linux-image-686 --prompt-rootpass --purge-chroot

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 4-Creation d'un compte local enseignant dans l'environnement des clients lourds												"
echo "------------------------------------------------------------------------------------------------------------------------------"
#mdp = "$(mkpasswd enseignant)"
#ltsp-chroot -m --arch "$ENVIRONNEMENT" useradd --create-home --password "$mdp" enseignant
ltsp-chroot -m --arch "$ENVIRONNEMENT" adduser enseignant
ltsp-chroot -m --arch "$ENVIRONNEMENT" chmod -R 700 /home/enseignant

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 5-Configuration de lts.conf afin que les clients lourds démarrent de façon complément autonome 								"
echo "------------------------------------------------------------------------------------------------------------------------------"
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lts.conf"
[default]
LTSP_CONFIG=true
KEEP_SYSTEM_SERVICES="lightdm"      # Indique à l'environnement du client lourd de lancer lightdm lors du démarrage
DEFAULT_DISPLAY_MANAGER=""          # Lance le gestionnaire d'affichage présent dans l'environnement des clients lourds (lightdm) à la place de LDM
EOF

sleep 5

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 6-Paramétrer PAM pour qu il consulte l annuaire LDAP de se3 lors de l identification d un utilisateur sur un client lourd	"
echo "   et pour qu'il réalise le montage automatique des partages Samba du se3 grace à pam_mount									"
echo "------------------------------------------------------------------------------------------------------------------------------"

# Installation des paquets nécessaires à l'identification LDAP avec PAM
ltsp-chroot --arch "$ENVIRONNEMENT" debconf-set-selections <<EOF
libnss-ldapd    libnss-ldapd/nsswitch    multiselect    group, passwd, shadow
libnss-ldapd    libnss-ldapd/clean_nsswitch    boolean    false
libpam-ldapd    libpam-ldapd/enable_shadow    boolean    true
nslcd    nslcd/ldap-bindpw    password    
nslcd    nslcd/ldap-starttls    boolean    true
nslcd    nslcd/ldap-base    string    $BASE_DN
nslcd    nslcd/ldap-reqcert    select   
nslcd    nslcd/ldap-uris    string    ldap://$IP_SE3/
nslcd    nslcd/ldap-binddn    string    
samba-common    samba-common/encrypt_passwords    boolean    true
samba-common    samba-common/dhcp    boolean    false
samba-common    samba-common/workgroup    string    WORKGROUP
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
echo " 8-Utilisation de pam_mount pour monter automatiquement les partages Samba du se3 à l ouverture de session d un utilisateur de client lourd "
echo "------------------------------------------------------------------------------------------------------------------------------"

# Installation des paquets nécessaires pour réaliser les montages automatiques des partages Samba à l'ouverture de session d'un utilisateur de clients lourds
#ltsp-chroot -m -a "$ENVIRONNEMENT" apt-get install -y --no-install-recommends libpam-mount cifs-utils

# Installation de samba (même si c'est en principe inutile sur un client samba ...) car cela accélère énormément le montage des partages Samba (une dizaine de secondes !).
#ltsp-chroot -m -a "$ENVIRONNEMENT" apt-get install -y samba

# Configuration des partages Samba "Docs" et "Classes"
if [ "$BUREAU" = "mate" ]
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


#echo "--------------------------------------------------------------------------------------"
#echo " 9-Configuration pour l'impression avec le serveur CUPS du SE3				 		"
#echo "--------------------------------------------------------------------------------------"

#mkdir "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups"

#cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/skel/.cups/client.conf"
#ServerName $IP_SE3
#EOF

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

	cat <<EOF >> "/opt/ltsp/$ENVIRONNEMENT/etc/firefox-esr/firefox-esr.js"

// Define proxy when an IP and PORT are specified
pref("network.proxy.share_proxy_settings", true);
pref("network.proxy.http", "${ip_proxy}");
pref("network.proxy.http_port", ${port_proxy});
pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, ${IP_SE3}/${masque_reseau}");
pref("network.proxy.type", 1);
EOF

else

# On règle le proxy d'Iceweasel avec l'option "Détection automatique des paramètres proxy pour ce réseau"
# Cette option permet de gérer les réseaux qui n'ont pas de proxy (proxy transparent) ainsi que ceux gérés par un fichier wpad.dat (avec Amon par exemple)
cat <<'EOF' >> "/opt/ltsp/$ENVIRONNEMENT/etc/firefox-esr/firefox-esr.js"

// Define proxy when no IP is specified for proxy
pref("network.proxy.type", 4);
EOF

fi

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 10-Configuration de lightdm 															"
echo "--------------------------------------------------------------------------------------"

# Activation du verrouillage numérique du clavier
mv "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf" "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm_default.conf"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lightdm/lightdm.conf"
[SeatDefaults]
greeter-setup-script=/usr/bin/numlockx on
EOF

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 11-Configuration de l environnement $ENVIRONNEMENT des clients lourds stretch	 		"
echo "--------------------------------------------------------------------------------------"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list"

deb http://ftp.fr.debian.org/debian stretch main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch main non-free contrib

deb http://security.debian.org/ stretch/updates main 
deb-src http://security.debian.org/ stretch/updates main 

deb http://ftp.fr.debian.org/debian stretch-updates main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch-updates main non-free contrib

deb http://ftp.fr.debian.org/debian stretch-backports main non-free contrib
deb-src http://ftp.fr.debian.org/debian stretch-backports main non-free contrib

EOF

ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get -y dist-upgrade 
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y nano aptitude less firmware-linux wine ttf-mscorefonts-installer vlc firefox-esr-l10n-fr system-config-printer numlockx
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y flashplugin-nonfree
ltsp-chroot -m --arch "$ENVIRONNEMENT" update-flashplugin-nonfree --install

# Ajout du navigateur Chromium et de flash pour Chromium
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y chromium chromium-l10n

if [ "$ENVIRONNEMENT" = "amd64" ]
then 
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y pepperflashplugin-nonfree
ltsp-chroot -m --arch "$ENVIRONNEMENT" update-pepperflashplugin-nonfree --install
fi

# Afin de pouvoir imprimer: 
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y cups

# Logiciels "mathématiques":
# Dépot pour install geogebra 5 avec la commande apt-get :
cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list.d/geogebra.list
deb http://www.geogebra.net/linux/ stable main
EOF
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y algobox scilab geogebra5

echo "--------------------------------------------------------------------------------------"
echo " 12-Modification pour que seul le dossier Bureau apparaisse dans le home utilisateur	"
echo "--------------------------------------------------------------------------------------"

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/xdg/user-dirs.defaults"
DESKTOP=Desktop
EOF


echo "--------------------------------------------------------------------------------------"
echo " 13-Copie du skel dans le chroot														"
echo "--------------------------------------------------------------------------------------"
find /home/netlogon/clients-linux/ltsp/skel/ -mindepth 1 -maxdepth 1 -exec cp -rf {} "/opt/ltsp/$ENVIRONNEMENT/etc/skel/" \;

sleep 5


echo "--------------------------------------------------------------------------------------"
echo " 14-Extinction de tous les clients lourds à 19h par défaut							"
echo "--------------------------------------------------------------------------------------"
echo '0 19 * * * root /sbin/poweroff' > "/opt/ltsp/$ENVIRONNEMENT/etc/cron.d/extinction_clients_lourds"

sleep 5

echo "--------------------------------------"
echo " 15-Sauvegarde du chroot des clients lourds (5 minutes)	    "
echo "--------------------------------------"
if [ ! -d "/var/se3/ltsp/originale" ]
then
	mkdir -p "/var/se3/ltsp/originale"
fi
rm -rf "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"
cp -a "/opt/ltsp/$ENVIRONNEMENT" "/var/se3/ltsp/originale/$ENVIRONNEMENT-originale"

sleep 5

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " 16- Configuration du menu PXE du se3 afin d ajouter une entrée pour pouvoir démarrer un PC PXE en client lourd Jessie 	    "
echo "------------------------------------------------------------------------------------------------------------------------------"

resultat=$(grep "Demarrer le pc en client lourd Stretch $BUREAU" "/tftpboot/pxelinux.cfg/default")

if [ "$resultat" = "" ]
then
cat <<EOF >> "/tftpboot/pxelinux.cfg/default"
LABEL ltspStretch
	MENU LABEL ^Demarrer le pc en client lourd Stretch $BUREAU
	KERNEL tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/vmlinuz
	APPEND ro initrd=tftp://$IP_SE3/ltsp/$ENVIRONNEMENT/initrd.img init=/sbin/init-ltsp quiet ip=dhcp boot=nfs nfsroot=$IP_SE3:/opt/ltsp/$ENVIRONNEMENT
	IPAPPEND 2
EOF
fi

sleep 5

echo "--------------------------------------------------------------------------------------"
echo " 17-Redémarrage du serveur se3 dans 5 secondes ...										"
echo "--------------------------------------------------------------------------------------"
sleep 5

reboot
