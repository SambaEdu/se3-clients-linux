#!/bin/sh
# Rédigé par Nicolas Aldegheri le 22/04/2016
# Sous licence GNU/Linux
# Ce script intégre Owncloud sur un serveur SE3 wheezy. L'intégration consiste à :
# - installer la partie "Owncloud" uniquement : c'est possible avec un dépôt depuis la version 9 d'Owncloud.
# - configurer le module ldap d'Owncloud pour qu'il consulte l'annuaire ldap du se3
# - installer et configurer le module "Stockage Externe" d' Owncloud afin de pouvoir accéder aux partages Samba "Docs" et "Classes" du se3 depuis l'extérieur de l'établissement
# - créer un partage Samba sur le cloud afin d'y accéder da façon efficace en interne.
# Par défaut : 
# - seul les groupes "Profs" et "admins" ont accés à la fonctionnalité "Stockage Externe" du se3.
# - le compte administrateur d'Owncloud est identique au compte admin de l'interface web du se3
# - les quotas par défaut des utilisateurs sont réglés par défaut à 100 Mo : ils pourront être ajustés ensuite
# Une fois l'installation terminée, il est possible de personnaliser le cloud en se connectant à http://IP_SE3/owncloud avec le compte admowncloud

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

# Récupération du fichier .json décrivant les partages Samba du module Stockage externe
wget https://raw.githubusercontent.com/SambaEdu/se3-clients-linux/master/src/home/netlogon/clients-linux/owncloud/partages_samba_se3.json > "$SORTIE" 2>&1

echo "Etape 2 : Installation des paquets nécessaires à Owncloud"
#  Cette installation suivie ici est celle décrite pour un serveur Ubuntu Trusty dans la documentation officielle d'Owncloud
apt-get install -y apache2 libapache2-mod-php5 >> "$SORTIE" 2>&1
apt-get install -y php5-gd php5-json php5-mysql php5-curl >> "$SORTIE" 2>&1
apt-get install -y php5-intl php5-mcrypt php5-imagick >> "$SORTIE" 2>&1

echo "Etape 3 : Ajout du dépot owncloud aux sources du se3 puis installation du paquet owncloud-files"
# L'installation est réalisé à partir du dépot de la version stable d'Owncloud.
# Sous Wheezy, depuis Owncloud 9, il est alors possible de n'installer que la partie Owncloud
# Cela permet d'utiliser le serveur Web et la base de donnée MySQL du serveur se3

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
# Installation "wizard"
sudo -u "$htuser" php occ maintenance:install --database "mysql" --database-name "owncloud" --database-user "root" --database-pass "$MYSQLPW" --admin-user "admin" --admin-pass "$dbpass" --data-dir "$ocpath/data"

# Configurer la langue par défaut de l'interface web en français
sudo -u "$htuser" php occ config:system:set default_language --value="fr"

# Configuration de config/config.php pour configurer les trusted domain et éventuellement le proxy
#sudo -u "$htuser" php occ config:system:set trusted_domains 1 --value="$se3ip"
#sudo -u "$htuser" php occ config:system:set trusted_domains 2 --value="$domain"
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
sudo -u "$htuser" php occ config:app:set files default_quota --value="100 MB"

echo "Etape 8.2 Configuration pour consulter l'annuaire du se3"
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

sudo -u "$htuser" php occ ldap:set-config "" ldapAttributesForUserSearch "givenname"

# Inutile en principe vu que owncloud est installé sur le même serveur que l'annuaire ldap 
#sudo -u "$htuser" php occ ldap:set-config "" turnOffCertCheck "1"
#sudo -u "$htuser" php occ ldap:set-config "" ldapTLS "0"

# L'annuaire ldap du se3 ne dispose pas l'attribut MemberOf pour déterminer le groupe auquel appartient l'utilisateur
sudo -u "$htuser" php occ ldap:set-config "" useMemberOfToDetectMembership "0"
sudo -u "$htuser" php occ ldap:set-config "" ldapConfigurationActive "1"


# Quota par défaut des utilisateurs de l'annuaire ldap (en octets) : 1Mo par défaut
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
filtre_groupes='(&(|(objectclass=top))(|(cn=Profs)(cn=admins)'

resultats="$(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Equipe_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"
resultats="$resultat $(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Matiere_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"
resultats="$resultat $(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" cn=Cours_* | grep "^cn:" | cut -d":" -f2 | sed -e "s/^ //")"

for groupese3 in "$resultats"
do
	filtre_groupes="$filtre_groupes(cn=$groupese3)"
done

# On ferme les parenthèses du filtre
filtre_groupes="$filtre_groupes))"

sudo -u "$htuser" php occ ldap:set-config "" ldapGroupFilter "$filtre_groupes"

echo "Etape 8.3 Configuration du module Stockage Externe pour rendre accessible les partages Samba du se3"

# Configuration du module external storage
# Pour un bon fonctionnement de ce module, la documentation recommande d'installer  php5-libsmbclient
echo 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/Debian_7.0/ /' >> /etc/apt/sources.list.d/php5-libsmbclient.list  
wget http://download.opensuse.org/repositories/isv:ownCloud:community/Debian_7.0/Release.key >> "$SORTIE" 2>&1
apt-key add - < Release.key
rm -f Release.key
apt-get update >> "$SORTIE" 2>&1
apt-get install -y smbclient php5-libsmbclient >> "$SORTIE" 2>&1 

# Activation du module de stockage externe 
sudo -u "$htuser" php occ app:enable files_external

# Par défaut, la local est 'en' pour le module stockage externe, ce qui pose des problèmes 
# avec les répertoires ou fichiers qui contiennent des caractères spéciaux : on la met en fr
sed -i -e "s/const LOCALE = 'en_US.UTF-8'/const LOCALE ='fr_FR.UTF-8'/g" "$ocpath/apps/files_external/3rdparty/icewind/smb/src/Server.php"  >> "$SORTIE" 2>&1 

# On copie et on met les droits sur le fichier .json contenant la configuration des partages samba "Docs" # et "Classes" pour le module stockage externe d'Owncloud
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

echo "Etape 8.4 Construction d'un skelette vide sur le partage Owncloud : les utilisateurs doivent enregistrer dans les partages Samba"
# Définir le skelette par défaut des utilisateurs
mkdir -p "$ocpath/core/skeleton_se3/cloud"
chown -R "$htuser":"$htgroup" "$ocpath/core/skeleton_se3"
sudo -u "$htuser" php occ config:system:set skeletondirectory --value="$ocpath/core/skeleton_se3"

echo "Etape 8.5 : Définition d'un cache local selon les recommandations d' Owncloud"
apt-get install -y php-apc >> "$SORTIE" 2>&1
sudo -u "$htuser" php occ config:system:set memcache.local --value='\OC\Memcache\APC'
service apache2 restart >> "$SORTIE" 2>&1

echo "Etape 8.6 Mise des droits sur les fichiers et repertoire du dossier owncloud selon les recommendations de la doc officielle d'OC"
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

bash /root/mettre_droits_owncloud.sh >> "$SORTIE" 2>&1

rm -f /root/mettre_droits_owncloud.sh >> "$SORTIE" 2>&1	

#######################################################################################################################################
# Essayer de se passer du module stockage externe et utiliser les répertoires Docs et Classes du se3 comme espace de stockage d'OC
# Le but étant de :
# - éviter d'avoir deux espaces de stockages disctincts (celui du se3 et celui d'OC)
# - utiliser les partages Samba "en interne" pour leur efficacité et disposer des fonctionnalités d'OC pour partager 
#   et accéder de l'extérieur aux partages Samba du se3

# Création des liens symboliques du répertoire data vers le partage Docs du se3
#find /home -mindepth 1 -maxdepth 1 ! -path /home/netlogon ! -path /home/profiles ! -path /home/_templates ! -path /home/templates ! -path /home/_netlogon \
#-exec setfacl -m u:www-data:x,g:www-data:x {} \; \
#-exec setfacl -Rm d:u:www-data:rwx,d:g:www-data:rx,u:www-data:rwx,g:www-data:rx {}/Docs \; \
#-exec mkdir -p "$ocpath"/data{}/cache "$ocpath"/data{}/files \; \
#-exec ln -s {}/Docs "$ocpath"/data{}/files/Docs \;

#chown -R www-data:www-data "$ocpath"/data/home
#chmod -R 750 "$ocpath"/data/home
#cp -rnpP "$ocpath"/data/home/* "$ocpath"/data/
#rm -rf "$ocpath"/data/home

# Fin 
# Cette solution pose des soucis au niveau des quotas : le quota défini sur OW est prioritaire sur celui définit sur le /home du se3
#######################################################################################################################################

#######################################################################################################################################
# Solution alternative : on déplace le répertoire data d'OC dans /var/se3/owncloud_data afin d'avoir plus de place
# On crée un partage Samba owncloud sur le se3 pour rendre accessible via smb, en interne, leur répertoire owncloud
# On crée un groupe owncloud sur le se3 afin que les utilisateurs du se3 puissent y accéder
# On créer et ajouter chaque utilisateur au groupe owncloud

# On déplace le répertoire data d'OC dans /var/se3 car il y a plus de place que dans /var/www/owncloud
sudo -u "$htuser" php occ config:system:set datadirectory --value="/var/se3/dataOC"
mv "$ocpath/data" /var/se3/dataOC

# On crée le groupe owncloud s'il n'existe pas ...
resultat=$(ldapsearch -xLLL -b "ou=Groups,$ldap_base_dn" "cn=owncloud" "dn")

if [ "$resultat" = "" ]
then
	perl /usr/share/se3/sbin/groupAdd.pl "1" "owncloud" "Partage owncloud"
fi

# On met les droits sur le répertoire data d'OW afin de pouvoir y accéder par un partage Samba
setfacl -m g:owncloud:x /var/se3/dataOC  

# On crée le script qui va permettre de créer le skelette d'owncloud à la 1ère connexion de l'utilisateur
# et de mettre les droits pour que le partage Samba puissent être accessible à l'utilisateur se3

cat <<EOF > "/usr/share/se3/scripts/donner_acces_partage_owncloud.sh"
#!/bin/sh

user="\$1"

# On ajoute l'utilisateur au groupe owncloud s'il n'y fait pas parti déjà

resultat="\$(ldapsearch -xLLL -b "cn=owncloud,ou=Groups,$ldap_base_dn" "memberUid=\$user" "dn")"

if [ "\$resultat" = "" ]
then
	perl /usr/share/se3/sbin/groupAddUser.pl "\$user" "owncloud" > /dev/null 2>&1
fi

# On crée éventuellement le répertoire owncloud de l'utilisateur, s'il n'existe pas déjà
if [ ! -d "/var/se3/dataOC/\$user" ]
then
	mkdir -p "/var/se3/dataOC/\$user/cache" "/var/se3/dataOC/\$user/files"
	cp -r "$ocpath/core/skeleton_se3/*" "/var/se3/dataOC/\$user/files/"
fi

# On met les droits sur le répertoire owncloud
setfacl -Rm d:u:"\$user":rwx,u:"\$user":rwx "/var/se3/dataOC/\$user"
EOF


# On crée le partage owncloud
cat <<EOF > "/etc/samba/smb_owncloud.conf"
[owncloud]
	comment= Cloud de %u
	path = /var/se3/dataOC/%u/files
	read only = No
	browseable = Yes
	valid users = @owncloud
	root preexec = /usr/share/se3/scripts/donner_acces_partage_owncloud.sh %u
	root preexec close = Yes
EOF

# S'il n'existe pas déjà, on rajoute le fichier de configuration du partage Owncloud à la conf de Samba
resultat=$(grep "smb_owncloud.conf" "/etc/samba/smb.conf")

if [ "$resultat" = "" ]
then
cat <<EOF >> "/etc/samba/smb.conf"
include = /etc/samba/smb_owncloud.conf
EOF
fi

service samba restart

echo " Etape 9 : Suppression d'Owncloud de la liste des dépôts du se3 afin d'éviter une maj automatique d'OC lors d'un apt-get upgrade sur le se3"
echo " Pour réaliser une maj d'OC, il faudra lancer le script /usr/share/se3/sbin/upgrade_owncloud.sh "

rm -f /etc/apt/sources.list.d/owncloud.list /etc/apt/sources.list.d/php5-libsmbclient.list

echo " Fin de l'installation : vous devez pouvoir vous connecter à votre serveur owncloud à l'adresse http://IP_SE3/owncloud"
echo " Le compte administrateur de votre serveur Owncloud est identique à celui du compte admin de l'interface web de votre se3"
exit 0
