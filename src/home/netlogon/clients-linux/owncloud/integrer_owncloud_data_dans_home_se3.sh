#!/bin/sh
# Rédigé par Nicolas Aldegheri le 21/04/2016
# Sous licence GNU/Linux
# Ce script intégre Owncloud sur un serveur SE3 wheezy. L'intégration consiste à :
# - installer la partie "Owncloud" uniquement (possible depuis la version 9 d'Owncloud) dans le répertoire /var/www/owncloud du se3
# - configurer le module ldap d'Owncloud pour qu'il consulte l'annuaire ldap du se3
# - installer et configurer le module "Stockage Externe" d' Owncloud afin de pouvoir accéder aux partages Samba "Docs" et "Classes" du se3 depuis l'extérieur de l'établissement
# Par défaut : 
# - seul les groupes "Profs" et "admins" ont accés à la fonctionnalité "Stockage Externe" du se3.
# - le compte administrateur d'Owncloud est le même que celui du compte admin de l'interface web du se3.
# Une fois l'installation terminée, se connecter à l'interface web d'administration du se3 puis :
# - régler le quota par défaut des utilisateurs à une petite valeur (2 MB) car la racine / du se3 (contenant /var/www/owncloud) n'a pas une très grande taille ... 
# - personnaliser son Cloud : ajouter d'autres partages Samba du se3, ajouter une documentation au skelette d'Owncloud, activer/désactiver des applications, ...

# Pour de le débuggage :
SORTIE="/root/compte_rendu_integration_owncloud.txt"

echo "Etape 1 : Récupération des variables nécessaires à l'installation"
# Récupération des paramétres spécifiques au se3 :
. /etc/se3/config_c.cache.sh
. /etc/se3/config_l.cache.sh
. /etc/se3/config_m.cache.sh
. /etc/se3/setup_se3.data
. /etc/se3/config_o.cache.sh

# Quelques variables spécifiques à Owncloud :
ocpath='/var/www/owncloud'
htuser='www-data'
htgroup='www-data'
rootuser='root'
rep_courant=$(pwd)

echo "Etape 2 : Installation des paquets nécessaires à Owncloud"
#  Cette installation suivie ici est celle décrite pour un serveur Ubuntu Trusty dans la documentation officielle d'Owncloud
apt-get install -y apache2 libapache2-mod-php5 > "$SORTIE" 2>&1
apt-get install -y php5-gd php5-json php5-mysql php5-curl >> "$SORTIE" 2>&1
apt-get install -y php5-intl php5-mcrypt php5-imagick >> "$SORTIE" 2>&1

echo "Etape 3 : Ajout du dépot owncloud aux sources du se3 puis installation du paquet owncloud-files"
echo "(ce paquet ne contient que la partie Owncloud 9, le serveur web du se3 étant conservé)"
# L'installation est réalisé à partir du dépot de la version stable d'Owncloud.
# Sous Wheezy, depuis Owncloud 9, il est alors possible de n'installer que la partie Owncloud
# Cela permet d' utiliser le serveur Apache2 et la base de donnée MySQL du serveur owncloud

wget -nv https://download.owncloud.org/download/repositories/stable/Debian_7.0/Release.key -O Release.key >> "$SORTIE" 2>&1
apt-key add - < Release.key 
rm -f Release.key

sh -c "echo 'deb http://download.owncloud.org/download/repositories/stable/Debian_7.0/ /' >> /etc/apt/sources.list.d/owncloud.list"
apt-get update >> "$SORTIE" 2>&1
apt-get install -y owncloud-files >> "$SORTIE" 2>&1

echo "Etape 4 : Ajout au se3 du fichier de configuration d'Apache fourni par Owncloud"
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

ln -s /etc/apache2/sites-available/owncloud.conf /etc/apache2/sites-enabled/owncloud.conf

#echo "Etape 5 : Désactivation de reqtimeout_module pour éviter que php coute les upload"
#cat <<EOF >"/etc/apache2/mods-available/reqtimeout.conf"
#<IfModule reqtimeout_module>
#  RequestReadTimeout header=0
#  RequestReadTimeout body=0
#</IfModule>
#EOF

echo "Etape 6 : Activation des modules Apache utils à Owncloud"
# Activation des modules Apache utiles à Owncloud :
# Module indispensable au bon fonctionnement d'Owncloud :
a2enmod rewrite
# Modules complémentaires utiles à Owncloud : mod_headers, mod_env, mod_dir and mod_mime:
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime

# Si utilisation de mod_fcgi à la place de mod_php, autorisé aussi (sur Apache2.4)
# a2enmod setenvif

echo "Etape 7 : Redemarrage d'Apache 2"
service apache2 restart >> "$SORTIE" 2>&1

echo "Etape 8 - Finalisation de l'installation : intégration au se3"
# Mise des droits temporaires pour finaliser l'installation d'owncloud : les droits seront reserrés à la fin de l'installation
chown -R "$htuser":"$htgroup" "$ocpath" >> "$SORTIE" 2>&1

# On se place dans le "bon" répertoire pour utiliser la commande occ utile pour intégré owncloud au se3
cd "$ocpath" >> "$SORTIE" 2>&1

echo "Etape 8.1 Configuration générale"

# Utiliser le /home du se3 comme répertoire data d'Owncloud
# Mise des droits sur le /home du se3 afin que Owncloud puisse écrire
setfacl -Rm d:u:www-data:rwx,d:g:www-data:rx,u:www-data:rwx,g:www-data:rx /home
# On supprimer les droits www-data dans les repertoires autres que les users de /home :
setfacl -Rm d:u:www-data:---,d:g:www-data:---,u:www-data:---,g:www-data:--- /home/netlogon /home/profiles /home/templates /home/admin

# le /home du se3 a les droits 775 (nécessaire pour les montages Samba du se3 par exemple)
# Or owncloud impose à son répertoire data d'avoir les droits 770 et il n'est pas possible de paramétrer cet umask ...
# Je n'ai pas trouvé d'autre solution que de modifier le code source d'Owncloud pour changer ce paramètre .. ce qui n'est vraiment pas propre du tout 
# De ce fait, cette modification sautera à chaque maj d'owncloud et il faudra donc la refaire à chaque fois ...
sed -i -e "s/perms, -1) != '0'/perms, -1) != '5'/g"  "$ocpath/lib/private/util.php"
sed -i -e "s/dataDirectory, 0770/dataDirectory, 0775/g"  "$ocpath/lib/private/util.php"
sed -i -e "s/perms, 2, 1) != '0'/perms, 2, 1) != '5'/g"  "$ocpath/lib/private/util.php"

########################################################################################
# 1ère solution :
# Cette solution consiste à dire à l'installation wizard d'Owncloud d'utiliser le /home du se3 comme repertoire data
# Installation "wizard" avec indication d'utiliser le /home du se3 comme répertoire data d'Owncloud
#sudo -u "$htuser" php occ maintenance:install --database "mysql" --database-name "owncloud" --database-user "root" --database-pass "$MYSQLPW" --admin-user "admowncloud" --admin-pass "$dbpass" --data-dir "/home"
# Fin de la 1ère solution
##########################################################################################

##########################################################################################
# 2ème solution pour utiliser le home du se3 comme répertoire data d'Owncloud :
# Cette solution consiste à garder le repertoire data par défaut d'Owncloud à savoir /var/www/owncloud/data
# puis à la fin de l'installation créer un lien symbolique vers le /home du se3
#
sudo -u "$htuser" php occ maintenance:install --database "mysql" --database-name "owncloud" --database-user "root" --database-pass "$MYSQLPW" --admin-user "admowncloud" --admin-pass "$dbpass"

# se reporter à la fin de l'installation pour la création du lien et la mise des droits
########################################################################################

# Configurer la langue par défaut de l'interface web en français
sudo -u "$htuser" php occ config:system:set default_language --value="fr"

# Configuration de config/config.php pour configurer les trusted domain et éventuellement le proxy
sudo -u "$htuser" php occ config:system:set trusted_domains 1 --value="$se3ip"
sudo -u "$htuser" php occ config:system:set trusted_domains 2 --value="$domain"


# Définition du proxy
if [ "$proxy_url" != "" ]
then
	sudo -u "$htuser" php occ config:system:set proxy --value="$proxy_url"
fi

echo "Etape 8.2 Configuration pour consulter l'annuaire du se3"
# Normalement, le paquet est installé ... mais dans le doute ...
apt-get install -y php5-ldap >> "$SORTIE" 2>&1

# Activation du module ldap d'Owncloud
sudo -u "$htuser" php occ app:enable user_ldap

# La 1ère configuration ldap créée ne possède pas de sid, on l'appelle avec un ""
sudo -u "$htuser" php occ ldap:create-empty-config
sudo -u "$htuser" php occ ldap:set-config "" ldapHost "$ldap_server"
sudo -u "$htuser" php occ ldap:set-config "" ldapPort "$ldap_port"
sudo -u "$htuser" php occ ldap:set-config "" ldapBase "$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapAgentName "uid=admin,ou=People,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapAgentPassword "$dbpass"
sudo -u "$htuser" php occ ldap:set-config "" ldapBaseGroups "ou=Groups,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapBaseUsers "ou=People,$ldap_base_dn"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupDisplayName "cn"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilter "(&(|(objectclass=top))(|(cn=Profs)(cn=admins)))"
sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilterGroups 'Administratifs;Profs;admins'
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

# Inutile en principe vu que owncloud est installé sur le même serveur que l'annuaire ldap 
#sudo -u "$htuser" php occ ldap:set-config "" turnOffCertCheck "1"
#sudo -u "$htuser" php occ ldap:set-config "" ldapTLS "0"

# L'annuaire ldap du se3 ne dispose pas l'attribut MemberOf pour déterminer le groupe auquel appartient l'utilisateur
sudo -u "$htuser" php occ ldap:set-config "" useMemberOfToDetectMembership "0"
sudo -u "$htuser" php occ ldap:set-config "" ldapConfigurationActive "1"

# Quota par défaut des utilisateurs de l'annuaire ldap (en octets) : 1Mo par défaut
sudo -u "$htuser" php occ ldap:set-config "" ldapQuotaDefault "1000000"

# Choisir uid comme nom de répertoire des utilisateurs d'Owncloud afin qu'il soit identique à celui d'un utilisateur du se3 présent dans /home
sudo -u "$htuser" php occ ldap:set-config "" homeFolderNamingRule "attr:uid"

echo "Etape 8.3 Configuration du module Stockage Externe pour rendre accessible les partages Samba du se3"

# Configuration du module external storage
# Pour un bon fonctionnement de ce module, la documentation recommande d'installer  php5-libsmbclient
#echo 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/Debian_7.0/ /' >> /etc/apt/sources.list.d/php5-libsmbclient.list  
#wget http://download.opensuse.org/repositories/isv:ownCloud:community/Debian_7.0/Release.key >> "$SORTIE" 2>&1
#apt-key add - < Release.key
#rm -f Release.key
#apt-get update >> "$SORTIE" 2>&1
#apt-get install -y smbclient php5-libsmbclient >> "$SORTIE" 2>&1 

# Activation du module de stockage externe 
#sudo -u "$htuser" php occ app:enable files_external

# Par défaut, la local est 'en' pour le module stockage externe, ce qui pose des problèmes 
# avec les répertoires ou fichiers qui contiennent des caractères spéciaux : on la met en fr
#sed -i -e "s/const LOCALE = 'en_US.UTF-8'/const LOCALE ='fr_FR.UTF-8'/g" "$ocpath/apps/files_external/3rdparty/icewind/smb/src/Server.php"  >> "$SORTIE" 2>&1 


# Par défaut, on ne va partager que deux partages Samba du se3 via Owncloud : 
# - le répertoire Docs par défaut
# - le répertoire Classes
# Ces répertoires ne seront accessibles qu'aux enseignants et adminins de l'annuaire ldap du se3
# Libre ensuite à l'administrateur d'Owncloud d' ajouter/personnaliser/adjuster, via l'interface web
# d'administration d'Owncloud le paramétrage proposé ici par défaut, si la configuration de son serveur
# et de son réseau le permet

#-------------------------------------------------------------------------------------------------------
# La création du fichier de configuration des partages externes .json ne fonctionne pas avec la commande cat ... (erreur de parsing ..)
# Pour éviter cette erreur de parsing, on copie la sortie de la commande occ après avoir paramétrée à la 
# main, via l'interface, l'accès aux partages Docs et Classes du se3. Ce fichier .json s'obtient avec la commande :
# sudo -u "$htuser" php occ files_external:export "$ocpath/partage_samba_se3.json"
#cat <<EOF > "$ocpath/partages_samba_se3.json"
#[
#    {
#        "mount_id": 1,
#        "mount_point": "\/Classes (sur le se3)",
#        "storage": "\\OC\\Files\\Storage\\SMB",
#        "authentication_type": "password::sessioncredentials",
#        "configuration": {
#            "host": "$se3ip",
#            "share": "Classes",
#            "root": "",
#            "domain": ""
#        },
#        "options": {
#            "encrypt": true,
#            "previews": true,
#            "enable_sharing": false,
#            "filesystem_check_changes": 1
#        },
#        "applicable_users": [],
#        "applicable_groups": [
#            "Profs",
#            "admin",
#            "admins"
#        ]
#    },
#    {
#        "mount_id": 2,
#        "mount_point": "\/Docs (sur le se3)",
#        "storage": "\\OC\\Files\\Storage\\SMB",
#        "authentication_type": "password::sessioncredentials",
#        "configuration": {
#            "host": "$se3ip",
#            "share": "home",
#            "root": "Docs",
#            "domain": ""
#        },
#        "options": {
#            "encrypt": true,
#            "previews": true,
#            "enable_sharing": false,
#            "filesystem_check_changes": 1
#        },
#        "applicable_users": [],
#        "applicable_groups": [
#            "Profs",
#            "admin",
#            "admins"
#        ]
#    }
#EOF
#
#echo ']' >> "$ocpath/partages_samba_se3.json"

# On copie et on met les droits sur le fichier .json contenant la configuration des partages samba "Docs" # et "Classes" pour le module stockage externe d'Owncloud
#if [ -e "$rep_courant/partages_samba_se3.json" ]
#then
#	cp -f "$rep_courant/partages_samba_se3.json" "$ocpath/partages_samba_se3.json"
#	sed -i -e "s/__IPSE3__/$se3ip/g" "$ocpath/partages_samba_se3.json" >> "$SORTIE" 2>&1 
#    chown "$htuser":"$htgroup" "$ocpath/partages_samba_se3.json"
#	chmod 750 "$ocpath/partages_samba_se3.json"
#	sudo -u "$htuser" php occ files_external:import "$ocpath/partages_samba_se3.json"
#	rm -f "$ocpath/partages_samba_se3.json"
#else
#	echo "le fichier partages_samba_se3.json décrivant les partages se3 n'est pas présent dans le répertoire contenant" 
#	echo "le script d'installation : la configuration du module Stockage Externe sera de ce fait incomplète ..."
#fi

echo "Etape 8.4 Construction d'un skelette vide sur le partage Owncloud : les utilisateurs doivent enregistrer dans les partages Samba"
# Définir le skelette par défaut des utilisateurs
mkdir "$ocpath/core/skeleton_se3"
mkdir "$ocpath/core/skeleton_se3/cloud"
chown -R "$htuser":"$htgroup" "$ocpath/core/skeleton_se3"
sudo -u "$htuser" php occ config:system:set skeletondirectory --value="$ocpath/core/skeleton_se3"

#echo "Etape 8.5 La quota par défaut des utilisateurs est quasiment mis à 0 afin que les utilisateurs ne #puissent pas enregistrer dans la partage owncloud"
# Définir les quota par défaut des utilisateurs (où se trouve le paramètre default quota dans owncloud ?)
# les quotas sont réglés au minimum (1 MB) car l'espace /var/www n'est pas très grand sur un se3 :
# les utilisateurs devront enregistrer sur le stockage externe (c a d les partages Samba du se3 ...)

echo "Etape 8.5 : Définition d'un cache local selon les recommandations d' Owncloud"
apt-get install -y php-apc >> "$SORTIE" 2>&1
sudo -u "$htuser" php occ config:system:set memcache.local --value='\OC\Memcache\APC'
service apache2 restart >> "$SORTIE" 2>&1

echo "Etape 8.6 Mise des droits sur les fichiers et repertoire du dossier owncloud selon les recommandations de la documnetation officielle d'Owncloud"
# Script pour mettre les droits sur le répertoire owncloud (documentation officielle owncloud)
# Attention, ces droits sont très serrés : pour une mise à jour ultérieure d'Owncloud, il sera nécessaire # de les relachế ... (se reporter à la documentation officielle)
 
cat <<EOF > "/root/mettre_droits_owncloud.sh"

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

bash /root/mettre_droits_owncloud.sh  >> "$SORTIE" 2>&1

##############################################################################
# Fin de la 2ème solution pour utiliser /home comme répertoire data d'Owncloud
# Copie des fichiers de configuration de data dans /home
if [ -d "${ocpath}/data" ]
then
	cp -p "$ocpath/data/.htaccess" /home/
	cp -p "$ocpath/data/.ocdata" /home/
	cp -p "$ocpath/data/index.html" /home/
	cp -p "$ocpath/data/owncloud.log" /home/
	cp -Rp "$ocpath/data/admowncloud" /home/
	
	# Sauvegarde du dossier data avant création du lien symbolique
	mv "$ocpath/data" "$ocpath/data_save"

	# Création du lien symbolique
	ln -s /home "$ocpath/data"
fi
##############################################################################

echo "Fin de l'installation : vous devez pouvoir vous connecter à votre serveur owncloud à l'adresse http://IP_SE3/owncloud"
echo "Le compte administrateur de votre serveur Owncloud est :"
echo "Identifiant : admowncloud"
echo "Mot de passe : celui du compte admin de l'interface web de votre se3"
exit 0
