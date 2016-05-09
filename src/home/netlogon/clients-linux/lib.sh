###########################################
###                                     ###
###            The lib.sh               ###
### (should be filled little by little) ###
###                                     ###
###########################################

############################################################################################################################
# This function downloads amd64 et i386 ubuntu Precise packages to install Open-Sankore in Jessie et Xenial
# (Open-Sankore are no more updated but still works quite well on Jessie and Xenial clients with old Ubuntu Precise packages)
# deb package are moved to /var/www/install in order to be download in local by Jessie et Xenial clients
############################################################################################################################

download_open_sankore_deb()
{
url_open_sankore='http://www.cndp.fr/open-sankore/OpenSankore/Releases/v2.5.1'
wget -q "$url_open_sankore/Open-Sankore_Ubuntu_12.04_2.5.1_amd64.zip"
if [ "$?" = "0" ] 
then 
	"Download Open-Sankore_Ubuntu_12.04_2.5.1_amd64.zip"
fi

wget -q "$url_open_sankore/Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip"
if [ "$?" = "0" ] 
then 
	"Download Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip"
fi

chmod 755 Open-Sankore*.zip
mv Open-Sankore*.zip "${rep_lien}/"
}


############################################################################################################################
# This function installs Open-Sankore 2.5.1 on Jessie and Xenial clients durant post-install
# Deb packages are previously being downloaded and stored in Apache Server of se3 
############################################################################################################################

install_open_sankore()
{
echo "Installation d'Open-Sankore" | tee -a $compte_rendu

test_archi=$(uname -r | grep -c amd64)
if [ "$test_arch" = "1" ]
then
	wget -q "http://${ip_se3}/install/Open-Sankore_Ubuntu_12.04_2.5.1_amd64.zip"
	if [ "$?" = "0" ] 
	then
		mkdir open-sankore
		unzip -d open-sankore Open-Sankore_Ubuntu*.zip 
		dpkg -i open-sankore/Open-Sankore*.deb > /dev/null
		apt-get install -f 
		rm -rf Open-Sankore_Ubuntu*.zip open-sankore
	fi
fi

test_archi=$(uname -r | grep -c i386)
if [ "$test_arch" = "1" ]
then
	wget -q "http://${ip_se3}/install/Open-Sankore_Ubuntu_12.04_2.5.1_i386.zip"
	if [ "$?" = "0" ] 
	then
		mkdir open-sankore
		unzip -d open-sankore Open-Sankore_Ubuntu*.zip 
		dpkg -i open-sankore/Open-Sankore*.deb > /dev/null
		apt-get install -f 
		rm -rf Open-Sankore_Ubuntu*.zip open-sankore
	fi
fi

}

###########################################
###                                     ###
###           End of lib.sh             ###
###                                     ###
###########################################

