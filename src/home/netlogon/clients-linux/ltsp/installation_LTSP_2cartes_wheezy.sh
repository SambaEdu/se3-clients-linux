#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 30 mars 2015
# Sous Licence Common Creative

REP_LTSP="/mnt/_admin/clients-linux/ltsp"
REP_INST="/mnt/_admin/clients-linux/install"

. "$REP_INST/params.sh"
IP_SE3="$ip_se3"
IP_AMON="$ip_proxy"

HOTE=`cat /etc/hostname`
export VENDOR="Debian"			# Debian ou Ubuntu
export CONFIG_NBD="false"		# mettre à true pour Ubuntu
DISTRIB="wheezy"				# wheezy ou jessie ou trusty
ARCHI="i386"					# i386 ou amd64
DESKTOP="lxde"					# lxde ou xfce4 ou gnome ou ubuntu-desktop

if [ "$VENDOR" = "Debian" ]; then
	MIRROIR="http://$IP_SE3:9999/debian/"
else
	MIRROIR="http://$IP_SE3:9999/ubuntu/"
fi

ENVIRONNEMENT="$DISTRIB-$DESKTOP-$ARCHI"

echo "------------------------------------------------------------------------------------------------------------------------------"
echo 'Ce script "transforme" votre client Debian Wheezy en serveur LTSP (serveur d environnement et d applications)                 '
echo "Votre serveur LTSP doit disposer de deux cartes réseaux 1 Gbs, dont l'une connectée au réseau pédagogique et l'autre au switch de clients légers "
echo "L'interface réseau sur le réseau péda sera configurée en client dhcp du SE3.       											"
echo "Etes-vous sur de vouloir continuer ? o ou n ? :																				"
read REPONSE

if [ "$REPONSE" != "o" ]; then
	exit 0;
fi


########################################################################
# Quelques vérifications pour le bon déroulement de l'installation ...
########################################################################

LOGIN=$(who i am | cut -d ' ' -f1)
if [ "$LOGIN" != "admin" ]; then
	echo "Installation interrompue"
	echo "Vous vous êtes connecté sur le poste avec l'identifiant $LOGIN"
	echo "Pour installer LTSP, vous devez vous identifier sur le poste avec le compte admin du se3 "
	read FIN
	exit 1
fi

if [ ! -d /etc/se3 ]; then
	echo "Installation interrompue"
	echo 'Votre client Linux Debian Wheezy ne semble pas intégré au domaine Samba Edu 3'
	echo 'Lancer le script d integration Wheezy ou réaliser l installation de Debian Wheezy sur ce poste à partir du module tftp de l interface Web du se3'
	read FIN
	exit 1
fi

if [ -z IP_SE3 ]; then
	echo "Installation interrompue"
	echo "Impossible de déterminer l'adresse IP de votre SE3"
	echo "Veuillez la renseigner dans le fichier clients-linux/install/param.sh"
fi

if [ -z IP_AMON ]; then
	echo "Installation interrompue"
	echo "Impossible de déterminer l'adresse IP de votre AMON"
	echo "Veuillez la renseigner dans la variable ip_proxy du fichier clients-linux/install/param.sh"
fi

NB_INTERFACES=`ifconfig -a | grep -c ^eth*`
if [ "$NB_INTERFACES" -ne "2" ]; then
	echo "Installation interrompue"
	echo "Le PC doit disposer de deux cartes réseaux éthernet 1Gbs pour lancer ce script ... "
	read FIN
	exit 1
fi

########################################################################################################################################################
# Configuration des interfaces réseaux
########################################################################################################################################################

# On détecte la carte éthernet connectée au réseau pédagogique et on teste le bon fonctionnement de cette interface
INTERFACES=`ifconfig -a | grep ^eth* | cut -d ' ' -f1`
INTERFACE1=`echo $INTERFACES | cut -d ' ' -f1`
INTERFACE2=`echo $INTERFACES | cut -d ' ' -f2`

TEST=`ping -c 10 -I "$INTERFACE1" "$IP_SE3" | grep "0% packet loss"`

if [ -n "$TEST" ]; then
	IFACE_PEDA="$INTERFACE1"
	IFACE_LEGER="$INTERFACE2"
else 
	TEST=`ping -c 10 -I "$INTERFACE2" "$IP_SE3" | grep "0% packet loss"`
	if [ -n "$TEST" ]; then
		IFACE_PEDA="$INTERFACE2"
		IFACE_LEGER="$INTERFACE1"
	else
		echo "Installation interrompue"
		echo "Impossible de détecter la carte éthernet reliée au réseau pédagogique (ou la connection n'est pas de bonne qualité ...)"
		echo '"Pinguer" votre se3 et vérifier qu aucun paquet n est perdu'
		exit 1
	fi
fi

IP_LTSP=`ifconfig $IFACE_PEDA | grep 'inet adr:' | cut -d: -f2 | awk '{ print $1}'`

# Ne sachant pas ce qui a été fait au préalable, on réécrit le fichier interfaces en configurant l'interface peda en client dhcp du serveur SE3

cat <<EOF > "/etc/network/interfaces"
auto lo
iface lo inet loopback

auto $IFACE_PEDA
iface $IFACE_PEDA inet dhcp

auto $IFACE_LEGER
iface $IFACE_LEGER inet static
address 192.168.67.1                  
netmask 255.255.255.0				  
EOF

service networking restart
sleep 3

########################################################################################################################################################
# On transforme le serveur LTSP en routeur NAT pour que les fat clients puissent sortir de leur sous-réseau (pour naviguer sur Internet par exemple ..)
########################################################################################################################################################

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" "/etc/sysctl.conf"
sysctl -p /etc/sysctl.conf
sleep 3
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables-save > /etc/iptables_ltsp
echo 'post-up iptables-restore < /etc/iptables_ltsp' >> "/etc/network/interfaces"	# Pour restaurer l'iptable au démarrage du serveur LTSP

service networking restart
sleep 3

echo "---------------------------------------------------------------------------------------------"
echo '                    Installation du serveur d environnement et d applications                '

apt-get update
apt-get install -y ltsp-server-standalone

mkdir /opt/ltsp

if [ "$CONFIG_NBD" = "false" ]; then
	echo '/opt/ltsp *(ro,no_root_squash,async,no_subtree_check)' > /etc/exports			# Configuration du serveur NFS (faire un "man exports" pour les options)
	service nfs-kernel-server restart
	sleep 3
fi

ln -s /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/trusty
	

echo '                    Fin de l installation du serveur d environnement de d applications       '
echo "---------------------------------------------------------------------------------------------"


echo "---------------------------------------------------------------------------------------------------------------------------------"
echo " Voulez-vous construire un environnement $VENDOR $DISTRIB $DESKTOP $ARCHI pour vos clients légers avec NBD à $CONFIG_NBD ? "
echo " o ou n ?"
read REPONSE
if [ "$REPONSE" != "o" ]; then
	echo "Installation interrompue"
	read FIN
	exit 0
fi

echo " "
echo " INFORMATIONS : 											                 								 			 "
echo " Par défaut, les clients légers sont configurés en fat client afin d alleger le serveur LTSP				 			 "
echo " Cela suppose que vos clients légers ont au moins 1 Go de RAM pour un usage correct avec un bureau léger comme LXDE    "
echo " Si RAM < 1Go, il est possible, après l'installation, de désactiver le mode fatclient dans le fichier lts.conf   		 "
		
ltsp-build-client --arch "$ARCHI" --dist "$DISTRIB" --chroot "$ENVIRONNEMENT" --fat-client-desktop "$DESKTOP" --mirror "$MIRROIR" --locale "fr_FR.UTF-8" --purge-chroot

# Pour compatibilité avec Wheezy qui utilise le fichier default pour son boot PXE
if [ "$DISTRIB" = "jessie" ] || [ "$DISTRIB" = "trusty" ]; then
	cp "/srv/tftp/ltsp/$ENVIRONNEMENT/pxelinux.cfg/ltsp" "/srv/tftp/ltsp/$ENVIRONNEMENT/pxelinux.cfg/default"
fi

echo "         Fin de la construction de l environnement $VENDOR $DISTRIB $DESKTOP $ARCHI pour vos clients légers avec NBD à $CONFIG_NBD     "
echo "---------------------------------------------------------------------------------------------------------------------------------------"


######################################################################################################
# Configuration du service DHCP du serveur LTSP
######################################################################################################

echo "----------------------------------------------------------------------------------------------"
echo " 				Configuration du service DHCP du serveur LTSP									"

sed -i -e "s/^INTERFACES=.*/INTERFACES=\"$IFACE_LEGER\"/g" "/etc/default/isc-dhcp-server"

if [ ! -e /etc/dhcp/dhcpd_save.conf ]; then
	mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd_save.conf		# Sauvegarde du fichier de conf dhcpd.conf avant modif
fi

# Construction du fichier de configuration DHCP du serveur LTSP (ce fichier est celui fourni par défaut par le projet LTSP et disponible à /etc/ltsp/dhcpd.conf)
cat <<EOF > "/etc/dhcp/dhcpd.conf"
#
# Default LTSP dhcpd.conf config file.
#

authoritative;                                     

subnet 192.168.67.0 netmask 255.255.255.0 {
    range 192.168.67.20 192.168.67.250;            # Plage d'adresse desservie par le serveur DHCP du serveur LTSP
    option domain-name "sous.reseau.clients.legers";  # nom DNS du sous-réseau de clients légers
    option domain-name-servers $IP_AMON;         # adresse IP du serveur DNS (adresse IP de Amon)
    option broadcast-address 192.168.67.255;
    option routers 192.168.67.1;                   # adresse du routeur (serveur LTSP)
    next-server 192.168.67.1;                      # adresse du serveur TFTP (serveur LTSP)
#    get-lease-hostnames true;
    option subnet-mask 255.255.255.0;
    option root-path "/opt/ltsp/$ENVIRONNEMENT";             # Chemin de l'environnement des CL sur le serveur LTSP

    if substring( option vendor-class-identifier, 0, 9 ) = "PXEClient" {
        filename "/ltsp/$ENVIRONNEMENT/pxelinux.0";          # Chemin du chargeur d'amorçage réseau PXE sur le serveur LTSP
    } else {
        filename "/ltsp/$ENVIRONNEMENT/nbi.img";             # Charger d'amorçage Etherboot
    }
}
EOF

service isc-dhcp-server restart
sleep 3

echo "         Fin de la configuration DHCP du serveur LTSP    	 "
echo "---------------------------------------------------------------------------------------------------------------------------------------"														

echo "---------------------------------------------------------------------------------------------"
echo '                    Intégration du serveur LTSP au se3     						           '

########################################################################################################################################################
# Modification du module PAM du serveur LTSP de ssh pour qu'un utilisateur du client léger puisse s'identifier avec ses identifiants de l'annuaire LDAP du se3
########################################################################################################################################################

if [ -e /etc/pam.d/sshd_save ]; then
	cp -f /etc/pam.d/sshd_save /etc/pam.d/sshd			# Il s'agit d'une réinstallation
else
	cp /etc/pam.d/sshd /etc/pam.d/sshd_save				# Sauvegarde avant modification
fi

sed -i -e 's/^@include.*/&.AVEC-LDAP/' /etc/pam.d/sshd																			# Identification avec l'annuaire LDAP du se3
sed -i '/@include common-auth.AVEC-LDAP/a \auth optional pam_script.so' /etc/pam.d/sshd											# On ajoute le module pam_script.so qui est nessaire pour l'identification LDAP
sed -i '/@include common-session.AVEC-LDAP/i \session required pam_mkhomedir.so skel=/etc/se3/skel umask=0077' /etc/pam.d/sshd	# Création du home directory de l'utilisateur à l'image de celui du skel du se3
sed -i '/auth optional pam_script.so/a \auth optional pam_exec.so /etc/se3/bin/ouverture_ltsp.sh' /etc/pam.d/sshd				# Execution du script qui réalise, en autre, le montage automatique des partages Samba du se3, dans le répertoire /mnt du serveur LTSP


########################################################################################################################################################
# Création du script réalisant le montage automatique des partages Samba Edu 3 dans le répertoire /mnt, sur le serveur LTSP
########################################################################################################################################################

echo '#!/bin/bash

if [ -x /etc/se3/bin/logon ]; then
   export LOGNAME="$PAM_USER"
   /etc/se3/bin/logon ouverture
fi

exit 0' > /etc/se3/bin/ouverture_ltsp.sh

chmod 700 /etc/se3/bin/ouverture_ltsp.sh			# Mettre les droits en cohérence avec le répertoire /etc/se3


########################################################################################################################################################
# Creation du fichier de configuration lts.conf des clients légers 
########################################################################################################################################################

cat <<EOF > "/srv/tftp/ltsp/$ENVIRONNEMENT/lts.conf"
# Pour obtenir une liste détaillée ainsi qu'une explication des paramètres de ce fichier, saisir sur le serveur LTSP : man lts.conf
[default]				      # Paramètres par défaults
LTSP_CONFIG=True			
LTSP_FATCLIENT=True			  # Par défault tous les clients légers sont paramétrés en fat client
LOCAL_APPS_EXTRAMOUNTS=/mnt   # Montage du dossier /mnt du serveur LTSP dans l environnement du fat client afin d obtenir les partages Samba

LDM_LANGUAGE=fr_FR.UTF-8
LDM_DIRECTX=True			  # Par défaut, on ne cripte pas les échanges graphiques, pour plus de fluidité
XKBLAYOUT=fr
X_NUMLOCK=True

[leger]					      # Configuration en client léger
LTSP_FATCLIENT=False

[hybrid]			 	      # Configuration en client hybride
LTSP_FATCLIENT=False
LOCAL_APPS=True                       # Activer le mode hybride 
LOCAL_APPS_MENU=True                  # Autoriser les applications disponibles dans la liste d applications du bureau du serveur LTSP à s exécuter avec les ressources (RAM et Processeur) du client léger
LOCAL_APPS_MENU_ITEMS=vlc,gimp	 	  # Liste des applications .desktop qui doivent être exécutées avec les ressources du client léger (ces applications doivent au préalable être chrootée dans l'environnement du client léger ...)

EOF


echo "                    Fin de l'intégration du serveur LTSP au se3     						   "
echo "---------------------------------------------------------------------------------------------"

echo "---------------------------------------------------------------------------------------------"
echo "            Installation des applications de base dans l'environnement des fat clients 	   "

########################################################################################################################################################
# Modification des sources des depots de l'environnement des fat client
########################################################################################################################################################


if [ "$VENDOR" = "Debian" ]; then

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/apt/sources.list"

deb http://$IP_SE3:9999/debian $DISTRIB main non-free contrib
deb-src http://$IP_SE3:9999/debian $DISTRIB main non-free contrib

deb http://$IP_SE3:9999/security.debian.org/ $DISTRIB/updates main 
deb-src http://$IP_SE3:9999/security.debian.org/ $DISTRIB/updates main 

deb http://$IP_SE3:9999/debian $DISTRIB-updates main non-free contrib
deb-src http://$IP_SE3:9999/debian $DISTRIB-updates main non-free contrib

deb http://$IP_SE3:9999/debian $DISTRIB-backports main non-free contrib
deb-src http://$IP_SE3:9999/debian $DISTRIB-backports main non-free contrib

EOF

fi

########################################################################################################################################################
# Installation des applis de base (pouvant être installé avec un apt-get)
########################################################################################################################################################
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get update				
ltsp-chroot --arch "$ENVIRONNEMENT" apt-get -y install numlockx aptitude								

if [ "$VENDOR" = "Ubuntu" ]; then
	MESAPPLIS="mesapplis-ubuntu.txt"
else
	MESAPPLIS="mesapplis-debian.txt"
fi

for PAQUET in $(cat "$REP_LTSP/$MESAPPLIS")
do
	#installation des paquets
	echo -e "=========================="
	echo -e "on installe $PAQUET"
	echo -e "=========================="
	sleep 2
	
	ltsp-chroot -m --arch "$ENVIRONNEMENT" aptitude install -y --full-resolver "$PAQUET"	# Applications de base de Debian
	
done

#ltsp-chroot -m --arch "$ENVIRONNEMENT" aptitude -y --full-resolver install `cat "$REP_LTSP/$MESAPPLIS"`	# Applications de base de Debian

########################################################################################################################################################
# Installation d'Epoptes Maître sur le serveur LTSP
########################################################################################################################################################
apt-get install -y epoptes				# On installe l'application maître sur le serveur LTSP
gpasswd -a admin epoptes				# On ajoute le compte admin comme utilisateur d'epoptes maître

########################################################################################################################################################
# Installation d'Epoptes client dans l'environnement des fat clients
########################################################################################################################################################
ltsp-chroot --arch "$ENVIRONNEMENT" aptitude install -y epoptes-client
sed -i -e "s/^#SERVER.*/SERVER=$IP_LTSP/g" "/opt/ltsp/$ENVIRONNEMENT/etc/default/epoptes-client"		# On indique l'IP d'epoptes maître (c'est à dire celle du serveur LTSP)
ltsp-chroot --arch "$ENVIRONNEMENT" epoptes-client -c													# On récupère le certificat du maître


########################################################################################################################################################
# Dans le cas de l'utilisation de NBD à la place de NFS (sous Ubuntu par exemple), on reconstruit l'image compressée ... (compter un quart d'heure)
########################################################################################################################################################
if [ "$CONFIG_NBD" = "true" ]; then
	ltsp-update-image "$ENVIRONNEMENT"
	service nbd-server restart
fi

echo "            Fin de l'installation des applis dans l'environnement des fat clients 	   	   "
echo "---------------------------------------------------------------------------------------------"

echo "            Fin de l'installation du serveur LTSP à deux cartes réseaux 	   	   "
echo " Démarrer des clients légers de votre sous-réseau et vérifier que tout fonctionne "
echo "------------------------------------------------------------------------------------------------------------------"
