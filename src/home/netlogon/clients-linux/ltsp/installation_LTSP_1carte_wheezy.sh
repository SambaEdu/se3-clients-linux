#!/bin/bash
# Rédigé par Nicolas Aldegheri, le 23 mars 2015
# Sous Licence Common Creative

REP_LTSP="/mnt/_admin/clients-linux/ltsp"
REP_INST="/mnt/_admin/clients-linux/install"

. "$REP_INST/params.sh"
IP_SE3="$ip_se3"
IP_LTSP=`ifconfig eth0 | grep 'inet adr:' | cut -d: -f2 | awk '{ print $1}'`

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
echo "Il est préférable de disposer d une carte réseau 1Gbs pour servir dans les meilleurs conditions un maximum de clients         "
echo "Une fois l'installation terminée et le serveur LTSP fonctionnel, relier le serveur LTSP sur un port 1Gbs d'un de vos switch   "
echo "Etes-vous sur de vouloir continuer ? o ou n ? :																				"
read REPONSE

if [ "$REPONSE" != "o" ]; then
	exit 0;
fi


########################################################################
# Quelques vérifications pour le bon déroulement de l'installation ...
########################################################################

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Votre serveur LTSP doit avoir une adresse IP statique																		"
echo " L'est-elle ? ou avez-vous réservé son adresse IP dans le module dhcp du se3 ? o ou n ? 										"
read REPONSE
if [ "$REPONSE" != "o" ]; then
	echo "Installation interrompue"
	echo " Réserver, via le module dhcp de l'interface web du se3, l'addresse IP de votre (futur) serveur LTSP 						"
	read FIN
	exit 0;
fi
echo "------------------------------------------------------------------------------------------------------------------------------"

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
	exit 1;
fi

if [ ! -s "$REP_LTSP/addr_MAC_clients" ]; then
	echo "Installation interrompue"
	echo "Le fichier addr_MAC_client contenant la description des adresses MAC de vos clients légers est vide"
	echo "Veuillez le renseigner en mettant une addresse MAC par ligne et par client léger"
	echo "Pour récupérer rapidement l'adresse MAC de vos clients légers, vous pouvez les démarrer puis consulter le module dhcp (Gestion des baux) de l'interfac Web du SE3"
	echo "N'oubliez pas (si c'est le cas) de supprimer vos futures clients légers de la réservation active du dhcp du se3 (le dhcp du SE3 risque sinon de ne pas redémarrer ...)"
	exit 1;
fi


echo "---------------------------------------------------------------------------------------------"
echo '                    Installation du serveur d environnement et d applications                '


apt-get update
apt-get install -y ltsp-server ldm-server ltsp-docs

mkdir /opt/ltsp

if [ "$CONFIG_NBD" = "false" ]; then
	echo '/opt/ltsp *(ro,no_root_squash,async,no_subtree_check)' > /etc/exports			# Configuration du serveur NFS (faire un "man exports" pour les options)
	service nfs-kernel-server restart
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
	exit 0;
fi

echo " "
echo " INFORMATIONS : 											                 								 			 "
echo " Par défaut, les clients légers sont configurés en fat client afin d alleger le serveur LTSP				 			 "
echo " Cela suppose que vos clients légers ont au moins 1 Go de RAM pour un usage correct avec un bureau léger comme LXDE    "
echo " Si RAM < 1Go, il est possible, après l'installation, de désactiver le mode fatclient dans le fichier lts.conf   		 "
		
ltsp-build-client --arch "$ARCHI" --dist "$DISTRIB" --chroot "$ENVIRONNEMENT" --fat-client-desktop "$DESKTOP" --mirror "$MIRROIR" --purge-chroot

# Pour compatibilité avec Wheezy qui utilise le fichier default pour son boot PXE
if [ "$DISTRIB" = "jessie" ] || [ "$DISTRIB" = "trusty" ]; then
	cp "/srv/tftp/ltsp/$ENVIRONNEMENT/pxelinux.cfg/ltsp" "/srv/tftp/ltsp/$ENVIRONNEMENT/pxelinux.cfg/default"
fi

echo "         Fin de la construction de l environnement Debian Wheezy LXDE des clients légers     "
echo "---------------------------------------------------------------------------------------------"


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
   LOGNAME="$PAM_USER" /etc/se3/bin/logon ouverture
fi

exit 0' > /etc/se3/bin/ouverture_ltsp.sh

chmod 700 /etc/se3/bin/ouverture_ltsp.sh			# Mettre les droits en cohérence avec le répertoire /etc/se3


########################################################################################################################################################
# Creation du fichier de configuration lts.conf des clients légers 
########################################################################################################################################################

cat <<EOF > "/opt/ltsp/$ENVIRONNEMENT/etc/lts.conf"
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

########################################################################################################################################################
# Creation du fichier de conf dhcpd_ltsp.conf pour le DHCP du se3
########################################################################################################################################################

cat <<EOF > "$REP_LTSP/dhcpd_ltsp.conf"
group {					               # description des clients légers qui utilisent l'environnement léger
       option root-path "/opt/ltsp/$ENVIRONNEMENT";       # chemin de l'environnement léger sur le serveur LTSP
       next-server $IP_LTSP;                        	  # IP du serveur TFTP (c'est à dire du serveur LTSP)
       filename "/ltsp/$ENVIRONNEMENT/pxelinux.0";        # chemin du chargeur d'amorçage PXE
        
       }
EOF


########################################################################################################################################################
# Récupération manuelle de quelques paramètres du fichier dhcp du se3
# Nécessaire pour faire "cohabiter" les clients légers avec les autres clients du réseau se3	
########################################################################################################################################################

echo "Ouvrir un navigateur Web puis, via l'interface Web du se3, consulter le menu Configuration du module dhcp"
echo 'Entrée l adrese IP de la "Fin de la plage dynamique"'
read IP_CL_DEB
	
IP_CL_DEB1=$(echo $IP_CL_DEB | cut -d'.' --fields="1 2 3")
IP_CL_DEB2=$(echo $IP_CL_DEB | cut -d'.' -f4)
	
echo 'Entrée l adresse IP du "Début de la plage de reservation"'
read IP_CL_FIN
	
IP_CL_FIN1=$(echo $IP_CL_FIN | cut -d'.' --fields="1 2 3")
IP_CL_FIN2=$(echo $IP_CL_FIN | cut -d'.' -f4)
	
if [ $IP_CL_DEB1 != $IP_CL_FIN1 ]; then
	echo 'Il y a un problème entre l adresse IP de fin de plage active et celle de début de plage de réservation'
	exit 1
fi
	
NB_CL=$(($IP_CL_FIN2 - $IP_CL_DEB2 - 1)) 

echo " Vous pouvez intégrer au maximum $NB_CL clients légers dans le dhcp de votre se3"
echo " Vous pouvez augmenter ce nombre soit : "
echo " 		- en diminuant l'adresse de Fin de la plage dynamique dans le module dhcp du se3"
echo " 		- en augmentant l'adresse de Début de la plage de reservation dans le module dhcp du se3"
echo " Voulez-vous poursuivez l'installation ? o ou n ? "
read REPONSE
if [ "$REPONSE" != "o" ]; then
	echo "Installation interrompue"
	exit 0;
fi

i=1
for MAC in $(cat addr_MAC_clients)
do

	IP_CL="$IP_CL_DEB1.$(($IP_CL_DEB2 + $i))"				# Adresse IP du client léger
	
	sed -i -e '$d' "$REP_LTSP/dhcpd_ltsp.conf"				# On supprime l'accolade de fin du group 
	
cat <<EOF >> "$REP_LTSP/dhcpd_ltsp.conf"
	host fatclient$i { 
	hardware ethernet $MAC;	
	fixed-address $IP_CL;
	}
	
	}	
EOF

	i=$(($i + 1))    
done


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
echo " "
echo "------------------------------------------------------------------------------------------------------------------"
echo " 				L'installation du serveur LTSP est terminée	 														"
echo " "														
echo " N'oubliez pas de créer un lien symbolique sur votre serveur se3 vers le fichier dhcpd_ltsp.conf du dossier ltsp, "
echo " Pour cela, dans un termninal de votre se3, saisir en tant que root : "
echo " ln -s /home/netlogon/clients-linux/ltsp/dhcpd_ltsp.conf /etc/dhcp/dhcpd_ltsp.conf"
echo " Puis, via l'interface web du se3, dans le menu configuration du module DHCP, renseigner le fichier de conf à inclure suivant : "
echo " /etc/dhcp/dhcpd_ltsp.conf "
echo " Enfin, valider la modification (le serveur DHCP va redémarrer et inclure ce fichier de conf) "
echo " Démarrer vos clients légers et vérifier que tout fonctionne "
echo "------------------------------------------------------------------------------------------------------------------"
