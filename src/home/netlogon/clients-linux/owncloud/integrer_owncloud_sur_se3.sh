#!/bin/sh
# Rédigé par Nicolas Aldegheri le 29/04/2016
# Sous licence GNU/Linux
# Ce script intégre Owncloud sur un serveur SE3 wheezy. L'intégration consiste à :
# - installer la partie "Owncloud" uniquement : c'est possible avec un dépôt depuis la version 9 d'Owncloud.
# - configurer le module ldap d'Owncloud pour qu'il consulte l'annuaire ldap du se3
# - installer et configurer le module "Stockage Externe" d' Owncloud afin de pouvoir accéder aux partages Samba "Docs" et "Classes" du se3 depuis l'extérieur de l'établissement
# - créer un partage Cloud spécifique à Owncloud, accessible en webdav (via un navigateur web par exemple), qui permettra le partage entre membres d'un même groupe
# Par défaut : 
# - tous les utilisateurs se3 ont accès aux partages Docs et Classes du se3.
# - le compte administrateur d'Owncloud est identique au compte admin de l'interface web du se3
# - les quotas par défaut des utilisateurs sur le partage Cloud sont réglés par défaut à 100 Mo : ils pourront être ajustés par la suite via l'interface d'administrateur d'Owncloud
# Une fois l'installation terminée, il est possible de personnaliser le cloud en se connectant à http://IP_SE3/owncloud avec un compte admin du se3.

# Pour de le débuggage :
SORTIE="/root/compte_rendu_integration_owncloud.txt"

#########################################################
echo "Etape 0 : Quelques vérifications avant de lancer le script"
#########################################################

# On récupère éventuellement le numéro de version d'OC passé en paramètre du script d'intégration
# Si aucun numéro n'est indiqué, ce sera la version stable d'OC qui sera installée

case "$@" in
            9.0)
                echo "La version 9.0 d'Owncloud va être installée sur votre se3" 
                VERSION_OC="9.0"
            ;;
            
            9.1)
                echo "La version 9.1 d'Owncloud n'est pas encore sortie ... : on quitte le script d'installation" 
                VERSION_OC="9.1"
                exit 1
            ;;
            
            9.2)
                echo "La version 9.2 d'Owncloud n'est pas encore sortie ... : on quitte le script d'installation" 
                VERSION_OC="9.2"
                exit 1
            ;;
            
            *) 
                echo "La version stable d'Owncloud va être installée sur votre se3"
                VERSION_OC="stable"
            ;;
esac

# Vérification que le script est lancé sur un se3 wheezy
if egrep -q "^7" /etc/debian_version
then
		echo "Votre serveur est bien version Debian Wheezy"
		echo "Le script peut se poursuivre"
		VERSION_SE3='Debian_7.0'
else
		echo "Votre serveur se3 n'est pas en version Wheezy"
		echo "Le script va s'arrêter ..."
		exit 1
fi

echo "Etape 1 : Récupération des variables se3"
# Récupération des paramétres spécifiques au se3 :
. /etc/se3/config_c.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/setup_se3.data
. /etc/se3/config_o.cache.sh

echo "Etape 2 : Mise en place des variables Owncloud"
# Quelques variables spécifiques à Owncloud :
ocpath='/var/www/owncloud'
htuser='www-data'
htgroup='www-data'
rootuser='root'
rep_courant=$(pwd)

echo "Etape 3 : Récupération sur github du fichier .json pour le Stockage externe"
# Récupération du fichier .json décrivant les partages Samba du module Stockage externe
wget https://raw.githubusercontent.com/SambaEdu/se3-clients-linux/master/src/home/netlogon/clients-linux/owncloud/partages_samba_se3.json > "$SORTIE" 2>&1

echo "Etape 4 : Installation complémentaires de paquets web nécessaires à Owncloud"
#  La procédure d'installation suivie ici est celle décrite pour un serveur Ubuntu Trusty dans la doc officielle d'OC
apt-get install -y apache2 libapache2-mod-php5 >> "$SORTIE" 2>&1
apt-get install -y php5-gd php5-json php5-mysql php5-curl >> "$SORTIE" 2>&1
apt-get install -y php5-intl php5-mcrypt php5-imagick >> "$SORTIE" 2>&1

echo "Etape 5 : Ajout du dépot owncloud aux sources du se3 puis installation du paquet owncloud-files"
# L'installation est réalisé à partir du dépot de la version stable d'Owncloud.
# Sous Wheezy, depuis Owncloud 9, il est alors possible de n'installer que la partie Owncloud
# Cela permet d'utiliser le serveur Web et la base de donnée MySQL du serveur se3

wget -nv "https://download.owncloud.org/download/repositories/$VERSION_OC/$VERSION_SE3/Release.key" -O Release.key >> "$SORTIE" 2>&1
apt-key add - < Release.key >> "$SORTIE" 2>&1
rm -f Release.key >> "$SORTIE" 2>&1

#sh -c "echo 'deb http://download.owncloud.org/download/repositories/stable/Debian_7.0/ /' > /etc/apt/sources.list.d/owncloud.list" >> "$SORTIE" 2>&1
echo "deb http://download.owncloud.org/download/repositories/$VERSION_OC/$VERSION_SE3/ /" > /etc/apt/sources.list.d/owncloud.list
apt-get update >> "$SORTIE" 2>&1
apt-get install -y owncloud-files >> "$SORTIE" 2>&1

echo "Etape 6 : Ajout au se3 du fichier de configuration d'Owncloud"
# Fichier de configuration d'Apache fourni par la communauté d'Owncloud pour Ubuntu et ses dérivées
cat <<EOF >/etc/apache2/sites-available/owncloud.conf
Alias /owncloud "/var/www/owncloud/"
<Directory /var/www/owncloud/>
Options +FollowSymlinks
AllowOverride All
<IfModule mod_dav.c>
Dav off
</IfModule>
SetEnv HOME /var/www/owncloud
SetEnv HTTP_HOME /var/www/owncloud
</Directory>
EOF

ln -s /etc/apache2/sites-available/owncloud.conf /etc/apache2/sites-enabled/owncloud.conf  >> "$SORTIE" 2>&1

#echo "Etape 6 bis : Désactivation de reqtimeout_module pour éviter que php coute les upload"
#cat <<EOF >"/etc/apache2/mods-available/reqtimeout.conf"
#<IfModule reqtimeout_module>
#  RequestReadTimeout header=0
#  RequestReadTimeout body=0
#</IfModule>
#EOF

echo "Etape 7 : Activation des modules Apache utils à Owncloud"
# Module indispensable au bon fonctionnement d'Owncloud :
a2enmod rewrite  >> "$SORTIE" 2>&1
# Modules complémentaires utils à Owncloud : mod_headers, mod_env, mod_dir and mod_mime:
a2enmod headers  >> "$SORTIE" 2>&1
a2enmod env  >> "$SORTIE" 2>&1
a2enmod dir  >> "$SORTIE" 2>&1
a2enmod mime  >> "$SORTIE" 2>&1

# Si utilisation de mod_fcgi à la place de mod_php, autorisé aussi (sur Apache2.4)
# a2enmod setenvif

service apache2 restart >> "$SORTIE" 2>&1

#######################################################################################
echo "Etape 8 - Finalisation de l'installation : intégration au se3"
#######################################################################################
# Mise des droits temporaires pour finaliser l'installation d'owncloud : les droits seront reserrés à la fin de l'installation
chown -R "$htuser":"$htgroup" "$ocpath" >> "$SORTIE" 2>&1

# On se place dans le "bon" répertoire pour utiliser la commande occ utile pour intégré owncloud au se3
cd "$ocpath" >> "$SORTIE" 2>&1

# Création du skelette pour les utilisateurs d'OC
mv "$ocpath/core/skeleton" "$ocpath/core/skeleton_save" 
mkdir -p "$ocpath/core/skeleton/Cloud"
chown -R "$htuser":"$htgroup" "$ocpath/core/skeleton"

########################################
echo "Etape 8.1 : Installation Wizard"
########################################
# Installation "wizard"
sudo -u "$htuser" php occ maintenance:install --database "mysql" --database-name "owncloud" --database-user "root" --database-pass "$MYSQLPW" --admin-user "admin" --admin-pass "$dbpass" --data-dir "$ocpath/data"

########################################
echo "Etape 8.2 : Configuration de config.php"
########################################
# Configurer la langue par défaut de l'interface web en français
sudo -u "$htuser" php occ config:system:set default_language --value="fr"

# Configuration des trusted_domains
# On supprime localhost
sudo -u "$htuser" php occ config:system:set trusted_domains 0 --value="$se3ip"
sudo -u "$htuser" php occ config:system:set trusted_domains 1 --value="$domain"

# Définition du proxy, s'il existe ...
if [ "$proxy_url" != "" ]
then
	sudo -u "$htuser" php occ config:system:set proxy --value="$proxy_url"
fi

# Définition du quota par défaut des utilisateurs
# Ne connaissant pas l'espace disponible pour le repertoire data OC dans /var/se3 : on le fixe à 100 MB par défaut
# Il sera toujours possible à l'admin du se3 d'ajuster ce paramètre via l'interface web d'administration d'Owncloud
sudo -u "$htuser" php occ config:app:set files default_quota --value="100 MB"

# Définition d'un cache local selon les recommandations d' Owncloud"
apt-get install -y php-apc >> "$SORTIE" 2>&1
sudo -u "$htuser" php occ config:system:set memcache.local --value='\OC\Memcache\APC'
service apache2 restart >> "$SORTIE" 2>&1

#######################################################################################################
echo "Etape 8.3 : Configuration du module ldap d'Owncloud afin qu'il consulte l'annuaire ldap du se3"
#######################################################################################################
# Normalement, le paquet est installé ... mais dans le doute ...
apt-get install -y php5-ldap >> "$SORTIE" 2>&1

# Activation du module ldap d'Owncloud
sudo -u "$htuser" php occ app:enable user_ldap

# La 1ère configuration ldap créée ne possède pas de sid, on l'appelle avec un ""
sudo -u "$htuser" php occ ldap:create-empty-config
#sudo -u "$htuser" php occ ldap:set-config "" ldapHost "$ldap_server"
sudo -u "$htuser" php occ ldap:set-config "" ldapHost "localhost"
sudo -u "$htuser" php occ ldap:set-config "" ldapPort "$ldap_port"
sudo -u "$htuser" php occ ldap:set-config "" ldapBase "$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapAgentName "uid=admin,ou=People,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapAgentPassword "$dbpass"
sudo -u "$htuser" php occ ldap:set-config "" ldapBaseGroups "ou=Groups,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapBaseUsers "ou=People,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupDisplayName "cn"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilterMode "0"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilterObjectclass "top"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupMemberAssocAttr "memberUid"
sudo -u "$htuser" php occ ldap:set-config "" ldapExperiencedAdmin "1"
sudo -u "$htuser" php occ ldap:set-config "" ldapLoginFilter "(&(|(objectclass=person))(|(uid=%uid)))"  
sudo -u "$htuser" php occ ldap:set-config "" ldapLoginFilterAttributes "uid"
sudo -u "$htuser" php occ ldap:set-config "" ldapUserDisplayName "cn"
sudo -u "$htuser" php occ ldap:set-config "" ldapUserFilterMode "0"
sudo -u "$htuser" php occ ldap:set-config "" ldapUserFilter "(|(objectclass=person))"
sudo -u "$htuser" php occ ldap:set-config "" ldapUserFilterObjectclass "person"

sudo -u "$htuser" php occ ldap:set-config "" ldapAttributesForUserSearch "uid;sn"

# Inutile en principe vu que owncloud est installé sur le même serveur que l'annuaire ldap 
#sudo -u "$htuser" php occ ldap:set-config "" turnOffCertCheck "1"
#sudo -u "$htuser" php occ ldap:set-config "" ldapTLS "0"

# L'annuaire ldap du se3 ne dispose pas l'attribut MemberOf pour déterminer le groupe auquel appartient l'utilisateur
sudo -u "$htuser" php occ ldap:set-config "" useMemberOfToDetectMembership "0"
sudo -u "$htuser" php occ ldap:set-config "" ldapConfigurationActive "1"

# Quota par défaut des utilisateurs de l'annuaire ldap (en octets) : 2Mo par défaut
# Le quota des utilisateurs est défini dans la configuration system ...
#sudo -u "$htuser" php occ ldap:set-config "" ldapQuotaDefault "2 MB"

# Choisir uid comme nom de répertoire des utilisateurs d'Owncloud afin qu'il soit identique à celui d'un utilisateur du se3 présent dans /home
sudo -u "$htuser" php occ ldap:set-config "" homeFolderNamingRule "attr:uid"

# Autoriser uniquement le partage entre certains groupes de l'annuaire ldap du se3
sudo -u "$htuser" php occ config:app:set core shareapi_only_share_with_group_members --value "yes"
sudo -u "$htuser" php occ config:app:set core shareapi_only_with_group_members --value "yes"
sudo -u "$htuser" php occ config:app:set core shareapi_allow_group_sharing --value "yes"
sudo -u "$htuser" php occ config:app:set core shareapi_allow_links --value "no"
sudo -u "$htuser" php occ config:app:set core shareapi_allow_resharing --value "no"
sudo -u "$htuser" php occ config:app:set core incoming_server2server_share_enabled --value "no"
sudo -u "$htuser" php occ config:app:set core outgoing_server2server_share_enabled --value "no"

# On recherche les groupes autorisés à faire du partage, cad Equipe*, Cours* Matieres, Profs, admins et on les ajoute à la conf du ldap d'OC
filtre_groupes1='Profs;admins'
filtre_groupes2='(&(|(objectclass=top))(|(cn=Profs)(cn=admins)'

#resultats="$(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Equipe_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"
#resultats="$resultats $(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Matiere_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"
#resultats="$resultats $(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Cours_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"

#for groupese3 in "$resultats"
#do
#	filtre_groupes="$filtre_groupes(cn=$groupese3)"
#done

ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Equipe_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //" > resultats
ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Matiere_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //" >> resultats
ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Cours_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //" >> resultats

for groupese3 in $(cat resultats)
do
	filtre_groupes1="$filtre_groupes1;$groupese3"
	filtre_groupes2="$filtre_groupes2(cn=$groupese3)"
done

rm -f resultats

# On ferme les parenthèses du filtre 2
filtre_groupes2="$filtre_groupes2))"

sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilterGroups "$filtre_groupes1"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilter "$filtre_groupes2"


##################################################################
echo "Etape 8.4 : Configuration du module Stockage Externe CIFS/SMB"
##################################################################

# Pour un bon fonctionnement de ce module, la documentation recommande d'installer php5-libsmbclient
echo "deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/$VERSION_SE3/ /" > /etc/apt/sources.list.d/php5-libsmbclient.list
wget "http://download.opensuse.org/repositories/isv:ownCloud:community/$VERSION_SE3/Release.key" >> "$SORTIE" 2>&1
apt-key add - < Release.key
rm -f Release.key
apt-get update >> "$SORTIE" 2>&1
apt-get install -y smbclient php5-libsmbclient >> "$SORTIE" 2>&1 

# Activation du module de stockage externe 
sudo -u "$htuser" php occ app:enable files_external

# Par défaut, la local est 'en', ce qui pose des problèmes avec les caractéres spéciaux dans les noms de répertoires et de fichiers
sed -i -e "s/const LOCALE = 'en_US.UTF-8'/const LOCALE ='fr_FR.UTF-8'/g" "$ocpath/apps/files_external/3rdparty/icewind/smb/src/Server.php"  >> "$SORTIE" 2>&1 

# On copie et on met les droits sur le fichier .json contenant la configuration des partages samba "Docs" et "Classes" du se3
if [ -e "$rep_courant/partages_samba_se3.json" ]
then
	cp -f "$rep_courant/partages_samba_se3.json" "$ocpath/partages_samba_se3.json"
	sed -i -e "s/__IPSE3__/$se3ip/g" "$ocpath/partages_samba_se3.json" >> "$SORTIE" 2>&1 
    chown "$htuser":"$htgroup" "$ocpath/partages_samba_se3.json"
	chmod 750 "$ocpath/partages_samba_se3.json"
	sudo -u "$htuser" php occ files_external:import "$ocpath/partages_samba_se3.json"
	rm -f "$ocpath/partages_samba_se3.json"
else
	echo "le fichier partages_samba_se3.json décrivant les partages se3 n'est pas présent dans le répertoire contenant" 
	echo "le script d'installation : la configuration du module Stockage Externe sera de ce fait incomplète ..."
fi

##################################################################
echo "Etape 8.5 : Reserrer les droits sur le repertoire owncloud (selon les recommandations de la doc officielle)"
##################################################################

# Script pour mettre les "bons" droits sur le répertoire owncloud (fourni dans la doc officielle d'owncloud)

cat <<EOF > "/usr/share/se3/scripts/mettre_droits_sur_data_owncloud.sh"

#!/bin/sh
printf "Creating possible missing Directories\n"
mkdir -p $ocpath/data
mkdir -p $ocpath/assets

printf "chmod Files and Directories\n"
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750

printf "chown Directories\n"
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chmod +x ${ocpath}/occ

printf "chmod/chown .htaccess\n"
if [ -f ${ocpath}/.htaccess ]
then
chmod 0644 ${ocpath}/.htaccess
chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi

if [ -f ${ocpath}/data/.htaccess ]
then
chmod 0644 ${ocpath}/data/.htaccess
chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi
exit 0
EOF

bash /usr/share/se3/scripts/mettre_droits_sur_data_owncloud.sh >> "$SORTIE" 2>&1

#######################################################################################################################################
# Correction d'un bug (apparu suite à une upgrade d'Owncloud 9.0) sur les directives RewriteRule et RewriteBase du .htaccess d'owncloud 9
# L'erreur sur RewriteRule impose de compléter l'url d'OC avec index.php (http://.../index.php) pour pouvoir accéder à la fenêtre d'identification
# L'erreur du RewriteBase rend impossible la navigation dans l'interface web d'OC
#######################################################################################################################################
sed -i 's/RewriteRule . index.php/RewriteRule .* index.php/g' "$ocpath/.htaccess"
sed -i -e 's/^.*RewriteBase \/.*$/  RewriteBase \/owncloud/g' "$ocpath/.htaccess"
########################################################################################################################################

#################################################################################################################
echo "Etape 8.6 : On déplace le repertoire data d'Owncloud dans /var/se3 car il y a plus de place "
echo "et cela permettra d'utiliser le système de sauvegarde des données du se3 pour sauvegarde les données d'OC"
#################################################################################################################
# On déplace le répertoire data d'OC dans /var/se3 car il y a plus de place que dans /var/www/owncloud
sudo -u "$htuser" php occ config:system:set datadirectory --value="/var/se3/dataOC" 
mv "$ocpath/data" /var/se3/dataOC >> "$SORTIE" 2>&1


#################################################################################################################
echo "Etape 8.7 : Faire executer cron.php par cron plutôt qu'ajax (recommandation de la doc officielle d'Owncloud)"
#################################################################################################################

# La doc d'Owncloud recommande d'executer cron.php par cron plutôt qu'ajax, lors de l'utilisation du module stockage externe
# cron.php sera lancé tous les quarts d'heure.
sudo -u "$htuser" php occ background:cron 
{ crontab -l -u "$htuser"; echo '*/15  *  *  *  * php -f /var/www/owncloud/cron.php'; } | crontab -u "$htuser" - >> "$SORTIE" 2>&1

##################################################################################################################
#echo "Etape 8.8 : Création d'un partage samba nommé owncloud sur le se3"
#echo "Ce partage a pour but de rendre en plus accessible le Cloud des utilisateurs via samba, sur le réseau péda"
##################################################################################################################

## On met les droits sur le répertoire data d'OC 
#setfacl -m g:Profs:x /var/se3/dataOC  >> "$SORTIE" 2>&1
#setfacl -m g:Eleves:x /var/se3/dataOC  >> "$SORTIE" 2>&1
#setfacl -m g:admins:x /var/se3/dataOC  >> "$SORTIE" 2>&1

## On crée le script qui va permettre de : 
## - créer, s'il n'existe pas déjà, le skelette d'owncloud de l'utilisateur lorsqu'il y accède via samba
## - mettre les droits sur le repertoire data d'OC afin que l'utilisateur puisse y accéder via samba et via OC 

#cat << 'EOF' > "/usr/share/se3/scripts/donner_acces_partage_owncloud.sh"
##!/bin/sh

#user="$1"

## On crée éventuellement le répertoire owncloud de l'utilisateur, s'il n'existe pas déjà
#if [ ! -d "/var/se3/dataOC/$user" ]
#then
	#mkdir -p "/var/se3/dataOC/$user/cache" "/var/se3/dataOC/$user/files"
	#cp -r /var/www/owncloud/core/skeleton/* "/var/se3/dataOC/$user/files/"
	#chown -R www-data:www-data "/var/se3/dataOC/$user"
	#chmod -R 750 "/var/se3/dataOC/$user"
#fi

## Mise des droits pour que l'utilisateur puisse accéder à ses données via samba
#setfacl -Rm d:u:"$user":rwx,u:"$user":rwx "/var/se3/dataOC/$user"

## Mise des droits pour que l'utilisateur puisse accéder à ses données via OC
#setfacl -Rm d:u:www-data:rwx,d:g:www-data:rx,u:www-data:rwx,g:www-data:rx "/var/se3/dataOC/$user"

#exit 0

#EOF

## Mise des droits sur le script en cohérence avec le se3
#chown www-se3:root /usr/share/se3/scripts/donner_acces_partage_owncloud.sh  >> "$SORTIE" 2>&1
#chmod 550 /usr/share/se3/scripts/donner_acces_partage_owncloud.sh  >> "$SORTIE" 2>&1

## Lorsqu'un fichier est rajouté/supprimé dans le repertoire data d'OC via le partage samba,
## il faut refaire un scan du dossier de cet utilisateur pour intégrer/supprimer ce nouveau fichier à OC
#cat << 'EOF' > "/usr/share/se3/scripts/mettre_aplomb_data_owncloud.sh"
##!/bin/sh

#user="$1"

#sudo -u www-data php /var/www/owncloud/occ files:scan --quiet --path="/$user/files"
#exit 0

#EOF

## Mise des droits sur le script en cohérence avec le se3
#chown www-se3:root /usr/share/se3/scripts/mettre_aplomb_data_owncloud.sh  >> "$SORTIE" 2>&1
#chmod 550 /usr/share/se3/scripts/mettre_aplomb_data_owncloud.sh  >> "$SORTIE" 2>&1

## On crée le partage owncloud
#cat <<EOF > "/etc/samba/smb_owncloud.conf"
#[owncloud]
	#comment= Cloud de %u
	#path = /var/se3/dataOC/%u/files
	#read only = No
	#browseable = Yes
	#valid users = @admins, @Profs, @Eleves
	#root preexec = /usr/share/se3/scripts/donner_acces_partage_owncloud.sh %u
	#root postexec = /usr/share/se3/scripts/mettre_aplomb_data_owncloud.sh %u
#EOF

## S'il n'existe pas déjà, on rajoute le fichier de configuration du partage Owncloud à la conf de Samba
#resultat=$(grep "smb_owncloud.conf" "/etc/samba/smb.conf")

#if [ "$resultat" = "" ]
#then
#cat <<EOF >> "/etc/samba/smb.conf"
#include = /etc/samba/smb_owncloud.conf
#EOF
#fi

#service samba restart  >> "$SORTIE" 2>&1

##################################################################################################################
#echo "Etape 8.9 : Faire un cleanup et un scan complet des fichiers utilisateur deux fois par jour (à 12:40 et à 18:40)"
##################################################################################################################
## On effectue quotiennement, en tache cron, un cleanup et un scan de tous les fichiers data d'OC afin de mettre à jour la cache d'OC
## Cela a pour but d'éviter que des fichiers créés/supprimés via la partage samba ne soient pas réactualisés dans Owncloud
#{ crontab -l -u "$htuser"; echo '40 12 * * * php /var/www/owncloud/occ files:cleanup --quiet'; } | crontab -u "$htuser" -
#{ crontab -l -u "$htuser"; echo '45 12 * * * php /var/www/owncloud/occ files:scan --quiet --all'; } | crontab -u "$htuser" -

#{ crontab -l -u "$htuser"; echo '40 18 * * * php /var/www/owncloud/occ files:cleanup --quiet'; } | crontab -u "$htuser" -
#{ crontab -l -u "$htuser"; echo '45 18 * * * php /var/www/owncloud/occ files:scan --quiet --all'; } | crontab -u "$htuser" -


##################################################################################################################
#echo "Etape 8.10 : Utiliser l'uid plutôt que le uuid afin de pouvoir repérer un utilisateur et faire un scan sur ces fichiers après un accès via samba"
##################################################################################################################
#sudo -u "$htuser" php occ ldap:set-config "" ldap_expert_username_attr "uid"
#sudo -u "$htuser" php occ ldap:set-config "" ldap_expert_uuid_user_attr "uid"


#################################################################################################################
echo "Etape 9 : Suppression d'Owncloud de la liste des dépôts du se3 afin d'éviter une maj automatique d'OC lors d'un apt-get upgrade sur le se3"
echo "Pour réaliser une maj d'OC, il faudra lancer à la main le script /usr/share/se3/scripts/upgrade_owncloud.sh "
#################################################################################################################

rm -f /etc/apt/sources.list.d/owncloud.list /etc/apt/sources.list.d/php5-libsmbclient.list  >> "$SORTIE" 2>&1
apt-get update >> "$SORTIE" 2>&1

# Création du scritp pour faire un upgrade d'Owncloud
cat << 'EOF' > "/usr/share/se3/scripts/upgrade_owncloud.sh"
#!/bin/sh

# Vérification que le script est lancé sur un se3 wheezy
if egrep -q "^7" /etc/debian_version
then
		echo "Votre serveur est bien version Debian Wheezy"
		echo "Le script peut se poursuivre"
		VERSION_SE3='Debian_7.0'
else
		echo "Votre serveur se3 n'est pas en version Wheezy"
		echo "Le script va s'arrêter ..."
		exit 1
fi

case "$@" in
            9.0)
                echo "Mise à jour vers la version 9.0 d'OC" 
                VERSION_OC="9.0"
            ;;
            
            9.1)
                echo "La version 9.1 d'Owncloud n'est pas encore sortie ... : la maj n'est pas encore possible" 
                VERSION_OC="9.1"
                exit 1
            ;;
            
            9.2)
                echo "La version 9.2 d'Owncloud n'est pas encore sortie ... : la maj n'est pas encore possible" 
                VERSION_OC="9.2"
                exit 1
            ;;
            
            *) 
                echo "La maj va être réalisée vers la version stable d'Owncloud"
                VERSION_OC="stable"
            ;;
esac

# On se place dans le repertoire pour utiliser la commande occ
cd /var/www/owncloud

# On remet data à l'endroit où le paquet owncloud-files l'a initialement installé (recommandation doc officielle)
sudo -u www-data php occ config:system:set datadirectory --value="/var/www/owncloud/data" 
mv /var/se3/dataOC /var/www/owncloud/data

# On remet les droits tels qu'ils étaient définis par l'installation d'Owncloud (on les resserera après la mise à jour)
chown -R www-data:www-data /var/www/owncloud
chmod -R 750 /var/www/owncloud

# On rajoute temporairement les dépots pour faire la maj
echo "deb http://download.owncloud.org/download/repositories/$VERSION_OC/$VERSION_SE3/ /" > /etc/apt/sources.list.d/owncloud.list
echo "deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/$VERSION_SE3/ /" > /etc/apt/sources.list.d/php5-libsmbclient.list

# On place OC en mode maintenance pour couper son accès aux utilisateurs
# sudo -u www-data php occ maintenance:mode --on

# On désactive toutes les applications tierce (est-ce réellement nécessaire ? inutile en mode maintenance ?)
# sudo -u www-data php occ app:disable user_ldap
# sudo -u www-data php occ app:disable files_external

# On met à jour le paquet owncloud-files
apt-get update && apt-get install owncloud-files

# On finalise la mise à jour avec occ
sudo -u www-data php occ upgrade
# ou sans le mode simulation (qui peut prendre plusieurs heures ...)
# sudo -u www-data php occ upgrade --skip-migration-test

#######################################################################################################################################
# Correction d'un bug (apparu avec Owncloud 9.0.2) sur les directives RewriteRule et RewriteBase du .htaccess d'owncloud
# Ce bug va peut-être disparaître dans les maj ultérieures d'OC mais dans le doute, on réécrit correctement ces directives
#######################################################################################################################################
sed -i 's/RewriteRule . index.php/RewriteRule .* index.php/g' "/var/www/owncloud/.htaccess"
sed -i -e 's/^.*RewriteBase \/.*$/  RewriteBase \/owncloud/g' "/var/www/owncloud/.htaccess"
########################################################################################################################################

# On réactive les applications tierce (TODO : est-ce réellement nécessaire ? je ne les ai pas toutes désactivées ...)
# sudo -u www-data php occ app:enable user_ldap
# sudo -u www-data php occ app:enable files_external

# On remets les droits sur le repertoire data d'OC
bash /usr/share/se3/scripts/mettre_droits_sur_data_owncloud.sh

# On redéplace le repertoire data dans /var/se3
sudo -u www-data php occ config:system:set datadirectory --value="/var/se3/dataOC" 
mv /var/www/owncloud/data /var/se3/dataOC

# On supprime les depots d'OC pour éviter une maj d'OC non désirée (via un apt-get upgrade du se3 ...)
rm -f /etc/apt/sources.list.d/owncloud.list /etc/apt/sources.list.d/php5-libsmbclient.list
# On remet à jour apt-get
apt-get update

# On quitte le mode maintenance
# sudo -u www-data php occ maintenance:mode --off

# On nettoie et rescane l'ensemble des fichiers des utilisateurs pour mettre à jour le cache d'OC
sudo -u www-data php /var/www/owncloud/occ files:cleanup --quiet
sudo -u www-data php /var/www/owncloud/occ files:scan --quiet --all

exit 0

EOF

chown www-se3:root /usr/share/se3/scripts/upgrade_owncloud.sh >> "$SORTIE" 2>&1
chmod 550 /usr/share/se3/scripts/upgrade_owncloud.sh >> "$SORTIE" 2>&1

###########################################################################################################
echo " Etape 10 : Installation des applications bookmarks et autres applications utiles"
###########################################################################################################


#installation de l'application favoris
# l'application bookmarks est maintenant dans les applications officielles présentes il faut la télécharger et l activer

cd /var/www/owncloud/apps/
wget https://ovin.schiwon.me/index.php/s/3ROfUXOtwYIEY47/download >> "$SORTIE" 2>&1
mv download bookmarks.zip >> "$SORTIE" 2>&1
unzip bookmarks.zip >> "$SORTIE" 2>&1
chown -R www-data:www-data bookmarks >> "$SORTIE" 2>&1
rm  -f bookmarks.zip >> "$SORTIE" 2>&1
cd ..
sudo -u www-data php occ app:enable bookmarks

#announcement center pour envoyer une notification à tous les utilisateurs du cloud.
cd /var/www/owncloud/apps/
wget https://github.com/owncloud/announcementcenter/releases/download/v1.1.2/announcementcenter-1.1.2.zip >> "$SORTIE" 2>&1
unzip announcementcenter-1.1.2.zip >> "$SORTIE" 2>&1
rm announcementcenter-1.1.2.zip >> "$SORTIE" 2>&1
chown -R www-data:www-data /var/www/owncloud/apps >> "$SORTIE" 2>&1
sudo -u www-data php /var/www/owncloud/occ app:enable announcementcenter >> "$SORTIE" 2>&1

#application music
cd /var/www/owncloud/apps/
wget https://apps.owncloud.com/CONTENT/content-files/164319-music.zip >> "$SORTIE" 2>&1
unzip 164319-music.zip >> "$SORTIE" 2>&1
rm 164319-music.zip >> "$SORTIE" 2>&1
chown -R www-data:www-data /var/www/owncloud/apps >> "$SORTIE" 2>&1
sudo -u www-data php /var/www/owncloud/occ app:enable music >> "$SORTIE" 2>&1

#app documents
cd /var/www/owncloud/apps
wget https://github.com/owncloud/documents/releases/download/v0.12.0/documents.zip
unzip documents.zip
rm documents.zip
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable documents

#calendrier
cd /var/www/owncloud/apps
wget https://github.com/owncloud/calendar/releases/download/v1.2.2/calendar.tar.gz
tar -xzvf calendar.tar.gz
rm -r calendar.tar.gz
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable calendarntcenter-1.1.2.zip
unzip announcementcenter-1.1.2.zip
rm announcementcenter-1.1.2.zip
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable announcementcenter

#application music
cd /var/www/owncloud/apps/
wget https://apps.owncloud.com/CONTENT/content-files/164319-music.zip
unzip 164319-music.zip
rm 164319-music.zip
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable music

#app documents
cd /var/www/owncloud/apps
wget https://github.com/owncloud/documents/releases/download/v0.12.0/documents.zip
unzip documents.zip
rm documents.zip
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable documents

#calendrier
cd /var/www/owncloud/apps
wget https://github.com/owncloud/calendar/releases/download/v1.2.2/calendar.tar.gz
tar -xzvf calendar.tar.gz
rm -r calendar.tar.gz
chown -R www-data:www-data /var/www/owncloud/apps
sudo -u www-data php /var/www/owncloud/occ app:enable calendar




#installation de l'application messagerie/chat interne
# En VM cela marche très bien. On rencontre de grosses lenteurs sur une serveur en prod avec un annuaire de 1000 personnes. A tester manuellement
#cd /var/www/owncloud/apps/
#wget https://github.com/simeonackermann/OC-User-Conversations/archive/master.zip >> "$SORTIE" 2>&1
#unzip master.zip >> "$SORTIE" 2>&1
#mv OC* conversations >> "$SORTIE" 2>&1
#chown -R www-data:www-data conversations/ >> "$SORTIE" 2>&1
#cd ..
#sudo -u www-data php occ app:enable conversations
#cd apps
#rm -f master.zip


#################################################################################################################
echo " Fin de l'installation : vous devez pouvoir vous connecter à votre serveur owncloud à l'adresse http://IP_SE3/owncloud"
echo " Le compte administrateur de votre serveur Owncloud est identique à celui du compte admin de l'interface web de votre se3"
#################################################################################################################
exit 0
