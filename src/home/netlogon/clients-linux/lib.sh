###########################################
###                                     ###
###            The lib.sh               ###
### (should be filled little by little) ###
###                                     ###
###########################################


# 1. Funtions used in install_clients_linux_mise_en_place.sh script

############################################################################################################################
# This function downloads amd64 et i386 ubuntu Precise packages to install Open-Sankore in Jessie et Xenial
# (Open-Sankore are no more updated but still works quite well on Jessie and Xenial clients with old Ubuntu Precise packages)
# deb package are moved to /var/www/install in order to be download in local by Jessie et Xenial clients
############################################################################################################################

download_open_sankore_deb()
{
    local repertoire_install="$1"
    local url_open_sankore='http://www.cndp.fr/open-sankore/OpenSankore/Releases/v2.5.1'
    local version_open_sankore='Open-Sankore_Ubuntu_12.04_2.5.1'

    if [ ! -d "/home/netlogon/clients-linux/divers/open-sankore" ]
    then
        mkdir -p /home/netlogon/clients-linux/divers/open-sankore
    fi

    if [ ! -e "/home/netlogon/clients-linux/divers/open-sankore/${version_open_sankore}_amd64.zip" ] 
    then
        wget "${url_open_sankore}/${version_open_sankore}_amd64.zip"
        chmod 755 "${version_open_sankore}_amd64.zip"
        mv "${version_open_sankore}_amd64.zip" "/home/netlogon/clients-linux/divers/open-sankore"
    fi

    if [ ! -e "/home/netlogon/clients-linux/divers/open-sankore/${version_open_sankore}_i386.zip" ]
    then
        wget "${url_open_sankore}/${version_open_sankore}_i386.zip"
        chmod 755 "${version_open_sankore}_i386.zip"
        mv "${version_open_sankore}_i386.zip" "/home/netlogon/clients-linux/divers/open-sankore"
    fi

    cp "/home/netlogon/clients-linux/divers/open-sankore/${version_open_sankore}_"*".zip" "$repertoire_install"
}


# 2. Funtions used in post-install*.sh scripts

############################################################################################################################
# Use in post-install scripts
# This function installs Open-Sankore 2.5.1 on Jessie and Xenial clients durant post-install
# Deb packages are previously being downloaded and stored in Apache Server of se3 
############################################################################################################################

install_open_sankore()
{
    local compte_rendu="$1"
    local IP_SE3="$2"
    local test_arch="$(arch)"
    local version_open_sankore='Open-Sankore_Ubuntu_12.04_2.5.1'

    echo "Installation d'Open-Sankore" | tee -a "$compte_rendu"

    if [ "$test_arch" = "x86_64" ]
    then
        if wget -q "http://${IP_SE3}/install/${version_open_sankore}_amd64.zip"
        then
            mkdir open-sankore
            unzip -d open-sankore "${version_open_sankore}_amd64.zip"
            dpkg -i open-sankore/Open-Sankore*_amd64.deb > /dev/null 2>&1
            apt-get install -f -y
            find . -maxdepth 1 -type f -name 'Open-Sankore_Ubuntu*.zip' -delete
            rm --one-file-system -r  open-sankore
        fi
    fi

    if [ "$test_arch" = "i686" ]
    then
        if wget -q "http://${IP_SE3}/install/${version_open_sankore}_i386.zip"
        then
            mkdir open-sankore
            unzip -d open-sankore "${version_open_sankore}_i386.zip"
            dpkg -i open-sankore/Open-Sankore*_i386.deb > /dev/null 2>&1
            apt-get install -f -y
            find . -maxdepth 1 -type f -name 'Open-Sankore_Ubuntu*.zip' -delete
            rm --one-file-system -r open-sankore
        fi
    fi

    return 0
}

install_wine()
{
    echo "Installation de wine-development" | tee -a "$compte_rendu"
    dpkg --add-architecture i386 && apt update -q2  > /dev/null 2>&1
    apt-get install -y wine wine-development
    return 0
}

# 3. Funtions used by ltsp 

############################################################################################################################
# 3.1 This function mounts owncloud folder on user's desktop with webdav (if owncloud has been installed on se3)
# It can be executed on se3 as root
############################################################################################################################

mount_owncloud_on_fat_client_desktop()
{	
local ENVIRONNEMENT="$1"			# Name of chroot
local IP_SE3="$2"
local CLOUD_NAME="$3"				# the name of owncloud share on the fat client desktop

if [ -z "$ENVIRONNEMENT" ] || [ -z "$IP_SE3" ] || [ -z "$CLOUD_NAME" ] 
then
	printf 'One of the three paramaters (ENVIRONNEMENT, IP_SE3 or CLOUD_NAME) is missing \n'
	printf 'The function is aborded \n'
	return 1
fi

if [ -e /etc/apache2/sites-available/owncloud.conf ] && [ -e "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml" ]
then
	ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
	ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y davfs2
	sed -i "/^.*pam_mount parameters: General tunables.*$/ i\
<volume\n\
		fstype=\"davfs\"\n\
		path=\"http://$IP_SE3/owncloud/remote.php/webdav/\"\n\
		mountpoint=\"~/$CLOUD_NAME\"\n\
		options=\"username=%(USER),uid=%(USER),nosuid,nodev\"\n\
/>\n\
" "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml"
fi
return 0
}

############################################################################################################################
# 3.2 This function mounts user home on fat client with sshfs (don't work)
# It can be executed on se3 as root
############################################################################################################################

#mount_fat_client_home_with_sshfs()
#{
#local ENVIRONNEMENT="$1"				# Name of chroot
#local IP_SE3="$2"
#local PROFIL_LINUX_NAME="profil-linux"  # Name of folder that contains user's linux profil, in /home/$USER/

#if [ -z "$ENVIRONNEMENT" ] || [ -z "$IP_SE3" ]
#then
	#printf 'One of the two paramaters (ENVIRONNEMENT or IP_SE3) is missing \n'
	#printf 'The function is aborded \n'
	#return 1
#fi

#if [ -e "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml" ]
#then
	## Use sshpass instead of fs0ssh to realize sshfs mounting
	#ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get update
	#ltsp-chroot -m --arch "$ENVIRONNEMENT" apt-get install -y sshpass

	## User's home must be created before se3 Samba mounts
	#sed -i "/^.*Volume definitions.*$/ a\
#<fd0ssh>sshpass</fd0ssh>\n\
#<volume\n\
		#user=\"*\"\n\
		#fstype=\"fuse\"\n\
		#path=\"sshfs#%(USER)@$IP_SE3:/home/%(USER)/$PROFIL_LINUX_NAME\"\n\
		#mountpoint=\"~\"\n\
		#ssh=\"1\"\n\
		#options=\"password_stdin,reconnect,nonempty\"\n\
#/>\n\
#" "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml"
#fi
#return 0
#}

############################################################################################################################
# 3.3 This function mounts user home on fat client with cifs
# It can be executed on se3 as root
############################################################################################################################

mount_fat_client_home_with_cifs()
{
local ENVIRONNEMENT="$1"			# Name of chroot
local IP_SE3="$2"					
local PROFIL_LINUX_NAME="profil-linux"  # Name of folder that contains user's linux profil, in /home/$USER/

if [ -z "$ENVIRONNEMENT" ] || [ -z "$IP_SE3" ]
then
	printf 'One of the two paramaters (ENVIRONNEMENT or IP_SE3) is missing \n'
	printf 'The function is aborded \n'
	return 1
fi

if [ -e "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml" ]
then
	# User's home must be created before se3 Samba mounts because the last one are mounted on ~ 
	sed -i "/^.*Volume definitions.*$/ a\
<volume\n\
		user=\"*\"\n\
		fstype=\"cifs\"\n\
		server=\"$IP_SE3\"\n\
		path=\"homes/$PROFIL_LINUX_NAME\"\n\
		mountpoint=\"~\"\n\
		options=\"nobrl,serverino,iocharset=utf8,sec=ntlmv2\"\n\
/>\n\
" "/opt/ltsp/$ENVIRONNEMENT/etc/security/pam_mount.conf.xml"
fi
return 0
}

############################################################################################################################
# 3.4 This function create a linux profil folder in the home directory of each user on the se3
# It can be executed on se3 as root
# The linux-profil will be created in /home/$USER/profil-linux only if it doesn't exist
# This linux-profil could be used by ltsp fat clients as "home" after login with pam-mount (mounted by sshfs or by cifs)
# The goal is to make user's preferences persistent
############################################################################################################################

create_profil_linux()
{
find /home -mindepth 1 -maxdepth 1 -type d ! -name netlogon ! -name templates ! -name profiles \
-exec mkdir -p {}/profil-linux \; \
-exec cp -r /home/netlogon/clients-linux/ltsp/skel/. {}/profil-linux/ \; \
-exec chown -R --reference={} {}/profil-linux \; \
-exec chmod -R 700 {}/profil-linux \;

return 0
}

############################################################################################################################
# 3.5 This function regenerate the linux profil of all se3 users according to /home/netlogon/clients-linux/ltsp/skel model
# It can be executed on se3 as root
# This will delete all user's preference and user's data stored in /home/$USER/profil-linux
############################################################################################################################

regenerate_all_profil_linux()
{
find /home -mindepth 1 -maxdepth 1 -type d ! -name netlogon ! -name templates ! -name profiles \
-exec rm -Rf {}/profil-linux \; \
-exec cp -r /home/netlogon/clients-linux/ltsp/skel {}/profil-linux \; \
-exec chown -R --reference={} {}/profil-linux \; \
-exec chmod -R 700 {}/profil-linux \;

return 0
}

############################################################################################################################
# 3.6 This function deploy a particular folder in profil-linux of all se3 users and preserve user's preferences
# It can be executed on se3 as root
############################################################################################################################

deploy_one_particular_folder_in_profil_linux()
{
FOLDER_TO_DEPLOY="$1"		# file or folder to deploy in profil-linux

# Verify that variable is not empty
if [ -z "$FOLDER_TO_DEPLOY" ]
then
	printf 'The parameter FOLDER_TO_DEPLOY of the function is missing \n'
	printf 'The function is aborded \n'
	return 1
fi

# Deploy only if the folder existe in skel/$1
if [ -e "/home/netlogon/clients-linux/ltsp/skel/$FOLDER_TO_DEPLOY" ]
then
	find /home -mindepth 1 -maxdepth 1 -type d ! -name netlogon ! -name templates ! -name profiles \
-exec rm -Rf {}/profil-linux/$FOLDER_TO_DEPLOY \; \
-exec cp -r /home/netlogon/clients-linux/ltsp/skel/$FOLDER_TO_DEPLOY {}/profil-linux/$FOLDER_TO_DEPLOY \; \
-exec chown -R --reference={} {}/profil-linux/$FOLDER_TO_DEPLOY \; \
-exec chmod -R 700 {}/profil-linux/$FOLDER_TO_DEPLOY \;
	return 0
else
	printf 'The folder (or file) to deploy is not present in /home/netlogon/clients-linux/ltps/skel/ \n'
	return 1
fi
}

###########################################
###                                     ###
###           End of lib.sh             ###
###                                     ###
###########################################

