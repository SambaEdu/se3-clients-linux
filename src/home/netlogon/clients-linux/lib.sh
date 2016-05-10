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
	chmod 755 ${version_open_sankore}_amd64.zip
	mv ${version_open_sankore}_amd64.zip "/home/netlogon/clients-linux/divers/open-sankore"
fi


if [ ! -e "/home/netlogon/clients-linux/divers/open-sankore/${version_open_sankore}_i386.zip" ]
then 
	wget "${url_open_sankore}/${version_open_sankore}_i386.zip"
	chmod 755 ${version_open_sankore}_i386.zip
	mv ${version_open_sankore}_i386.zip "/home/netlogon/clients-linux/divers/open-sankore"
fi

cp /home/netlogon/clients-linux/divers/open-sankore/${version_open_sankore}_*.zip "$repertoire_install"

return 0

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

echo "Installation d'Open-Sankore" | tee -a $compte_rendu


if [ "$test_arch" = "x86_64" ]
then
	wget -q "http://${IP_SE3}/install/${version_open_sankore}_amd64.zip"
	if [ "$?" = "0" ] 
	then
		mkdir open-sankore
		unzip -d open-sankore "${version_open_sankore}_amd64.zip"
		dpkg -i open-sankore/Open-Sankore*_amd64.deb > /dev/null
		apt-get install -f 
		rm -rf Open-Sankore_Ubuntu*.zip open-sankore
	fi
fi

if [ "$test_arch" = "i686" ]
then
	wget -q "http://${IP_SE3}/install/${version_open_sankore}_i386.zip"
	if [ "$?" = "0" ] 
	then
		mkdir open-sankore
		unzip -d open-sankore "${version_open_sankore}_i386.zip"
		dpkg -i open-sankore/Open-Sankore*_i386.deb > /dev/null
		apt-get install -f 
		rm -rf Open-Sankore_Ubuntu*.zip open-sankore
	fi
fi

return 0

}

###########################################
###                                     ###
###           End of lib.sh             ###
###                                     ###
###########################################

