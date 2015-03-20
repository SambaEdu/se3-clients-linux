#!/bin/bash

# Script lancé en fin d'installation preseed Debian wheezy
# pour finaliser de la config .
#
# 
# lastupdate 5-06-2014
. /root/bin/params.sh

# quelques couleurs ;-)
rouge='\e[0;31m'
rose='\e[1;31m'
COLTITRE='\e[0;33m'
jaune='\e[1;33m'
vert='\e[0;32m'
bleu='\e[1;34m'
neutre='\e[0;m'


DEBIAN_PRIORITY="critical"
DEBIAN_FRONTEND="noninteractive"
export  DEBIAN_PRIORITY
export  DEBIAN_FRONTEND


ladate=$(date +%Y%m%d%H%M%S)


TEST_CLIENT=$(ifconfig | grep ":$ip_se3 ")
if [ -e /var/www/se3 ]; then
	echo "Malheureux... Ce script est a executer sur les clients Linux, pas sur le serveur."
	exit 1
fi

compte_rendu=/root/compte_rendu_post-install_${ladate}.txt

echo "Compte-rendu de post-installation: $ladate" > $compte_rendu





echo -e "$COLTITRE"
echo "--------------------------------------------------------------------------------"
echo "Post Configuration du poste"
echo "--------------------------------------------------------------------------------"
echo -e "$neutre"
echo "Appuyez sur Entree pour continuer"
read -t 20 dummy




# Debug:
#echo "++++++++"
#cat /root/bin/params.sh >> $compte_rendu 2>&1
#echo "ip_se3=$ip_se3"|tee -a $compte_rendu
#echo "++++++++"

echo "Mise en place des cles publiques SSH" | tee -a $compte_rendu
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cd /root/.ssh
if [ -n "${ip_se3}" ]; then
	wget http://${ip_se3}/paquet_cles_pub_ssh.tar.gz >/dev/null 2>&1
	if [ "$?" = "0" ]; then
		tar -xzf paquet_cles_pub_ssh.tar.gz && \
		cat *.pub > authorized_keys && \
		rm paquet_cles_pub_ssh.tar.gz
	else
		echo "Echec de la recuperation des cles pub." | tee -a $compte_rendu
	fi
# 	echo "Config proxy apt..." | tee -a $compte_rendu
# 	echo 'Acquire::http { Proxy "http://'$ip_se3':'9999'"; };' > /etc/apt/apt.conf.d/02apt-proxy
# 	cat /etc/apt/apt.conf.d/02apt-proxy | tee -a $compte_rendu
else
	echo "IP SE3 non trouvee???" | tee -a $compte_rendu
fi
sleep 5

if [ -n "$ip_proxy" -a -n "$port_proxy" ]; then
	echo "Config proxy..." | tee -a $compte_rendu
	echo "
export https_proxy=\"http://$ip_proxy:$port_proxy\"
" > /etc/proxy.sh
	chmod +x /etc/proxy.sh

	echo '
if [ -e /etc/proxy.sh ]; then
. /etc/proxy.sh
fi
' >> /etc/profile

fi

echo "Config vim..." | tee -a $compte_rendu
echo 'filetype plugin indent on
set autoindent
set ruler
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif' > /root/.vimrc

cp /root/.vimrc /etc/skel/.vimrc

if [ -n "${ip_ldap}" -a -n "${ldap_base_dn}" ]; then
	echo "Config LDAP..." | tee -a $compte_rendu
echo "HOST $ip_ldap
BASE $ldap_base_dn
# TLS_REQCERT never
# TLS_CACERTDIR /etc/ldap/
# TLS_CACERT /etc/ldap/slapd.pem
" > /etc/ldap/ldap.conf
else
	echo "IP LDAP ou ldap_base_dn et/non trouves..." | tee -a $compte_rendu
fi



if [ "$ocs" = "1" ]; then
	echo "Installation et configuration du client OCS" | tee -a $compte_rendu 
	aptitude -y install ocsinventory-agent
	echo "server=$ip_se3:909" > /etc/ocsinventory/ocsinventory-agent.cfg 
fi




if [ -n "${ip_se3}" ]; then
	echo "Telechargement de integration_wheezy.bash..." | tee -a $compte_rendu
	mkdir -p /root/bin
	cd /root/bin
	wget http://${ip_se3}/install/integration_wheezy.bash >/dev/null 2>&1
	if [ "$?" = "0" ]; then
		echo "Telechargement reussi." | tee -a $compte_rendu
		chmod +x integration_wheezy.bash
	else
		echo "Echec du telechargement." | tee -a $compte_rendu
		echo "Le poste ne pourra pas être intégré au domaine" | tee -a $compte_rendu 
		ISCRIPT="erreur"
	fi
fi


t=$(ifconfig |grep "HWaddr"|sed -e "s|.*HWaddr ||"|wc -l)
if [ "${t}" = "1" ]; then
	# Il semble qu on n entre pas ici en post-inst exécuté en fin d install
	mac=$(ifconfig |grep HWaddr|sed -e "s|.*HWaddr ||")
	echo "Une adresse mac trouvee : $mac"
	if [ -n "$mac" ]; then
		#nom_machine=$(ldapsearch -xLLL macAddress=$mac cn|grep "^cn: "|sed -e "s|^cn: ||")

		t=$(ldapsearch -xLLL macAddress=$mac cn|grep "^cn: "|sed -e "s|^cn: ||"|head -n1)
		if [ -z "$t" ]; then
			echo "Nom de machine non trouvé dans l annuaire LDAP"
		else
			tab_nom_machine=($(ldapsearch -xLLL macAddress=$mac cn|grep "^cn: "|sed -e "s|^cn: ||"))
			if [ "${#tab_nom_machine[*]}" = "1" ]; then
				t=$(echo "${tab_nom_machine[0]}"|sed -e "s|[^A-Za-z0-9_\-]||g")
				t2=$(echo "${tab_nom_machine[0]}"|sed -e "s|_|-|g")
				if [ "$t" != "${tab_nom_machine[0]}" ]; then
					echo "Le nom de machine ${tab_nom_machine[0]} contient des caracteres invalides."
				elif [ "$t2" != "${tab_nom_machine[0]}" ]; then
					echo "Le nom de machine ${tab_nom_machine[0]} contient des _ qui seront remplaces par des -"
					nom_machine="$t2"
					echo "nouveau nom : $nom_machine"
					sleep 2
				else
					nom_machine=${tab_nom_machine[0]}

					echo "Nom de machine trouve dans l annuaire LDAP : $nom_machine"
					
				fi
			else
				echo "Attention : adresse MAC $mac est associee a plusieurs machines:"
				ldapsearch -xLLL macAddress=$mac cn|grep "^cn: "|sed -e "s|^cn: ||"
			fi
		fi	
	else
		echo "Attention : adresse MAC illisible !!"
				
	fi
fi

	
	
while [ -z "$nom_machine" ]
	do
		echo "Machine non connue de l'annuare, Veuillez saisir un nom"
		echo "Attention espaces et _ sont interdits et 15 car maxi" 
		read nom_machine
		echo "Nom de machine: $nom_machine"
		if [ -n "${nom_machine}" ]; then
			t=$(echo "${nom_machine:0:1}"|grep "[A-Za-z]")
			if [ -z "$t" ]; then
				echo "Le nom doit commencer par une lettre."
				nom_machine=""
			else
				t=$(echo "${nom_machine}"|sed -e "s/[A-Za-z0-9\-]//g")
				if [ -n "$t" ]; then
					echo "Le nom $nom_machine contient des caracteres invalides: '$t'"
					nom_machine=""
				fi
			fi
		fi
	done
	sleep 2


echo ""
echo "Config SSMTP..."
cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.${ladate}
echo "
root=$email
#mailhub=mail
mailhub=$mailhub
rewriteDomain=$rewriteDomain
hostname=$nom_machine.$nom_domaine
" > /etc/ssmtp/ssmtp.conf
sleep 2


if [ $ISCRIPT != "erreur" ]; then
	echo -e "${jaune}"
	echo -e "==========================================="
	echo -e "Intégration au domaine SE3"
	echo -e "===========================================${neutre}"

	echo "Voulez-vous intégrer la machine au domaine SE3 (o)"
	read -t 10 rep
else
	echo "Script d'intégration non présent" | tee -a $compte_rendu 
fi


[ "$rep" != "n" ] && echo "La machine sera mise au domaine" && sleep 1



echo -e "${jaune}"
echo -e "==========================================="
echo -e "Début de l'installation des paquets de base"
echo -e "===========================================${neutre}"

echo "Installation des paquets définis dans mesapplis-debian.txt"
sleep 2
if [ -e /etc/proxy.sh ] ; then
	. /etc/proxy.sh
fi

apt-get -q update
# aptitude -y full-upgrade
apt-get install -y tofrodos
fromdos /root/bin/mesapplis-debian.txt
for i in $(cat /root/bin/mesapplis-debian.txt)
do
	#installation des paquets
	echo -e "${vert}=========================="
	echo -e "on installe $i"
	echo -e "==========================${neutre}"
	sleep 2
	
	aptitude -y install $i
	
done
fromdos /root/bin/mesapplis-debian-eb.txt
for i in $(cat /root/bin/mesapplis-debian-eb.txt)
do
	#installation des paquets
	echo -e "${vert}=========================="
	echo -e "on installe $i"
	echo -e "==========================${neutre}"
	sleep 2
	
	aptitude -y install $i
	
done
echo -e "${jaune}"
echo -e "==========================================="
echo -e "Fin de l'installation des paquets mesapplis-debian"
echo -e "===========================================${neutre}"


if [ "$rep" != "n" ]; then
	./integration_wheezy.bash --nom-client="$nom_machine" --is --ivl | tee -a $compte_rendu 
	
else
	
	echo "on intègre pas au domaine....Renommage du poste pour $nom_machine"| tee -a $compte_rendu 
	echo "$nom_machine" > "/etc/hostname"  
	invoke-rc.d hostname.sh stop > $SORTIE 2>&1
	invoke-rc.d hostname.sh start > $SORTIE 2>&1

	echo "
	127.0.0.1    localhost
	127.0.1.1    $nom_machine

	# The following lines are desirable for IPv6 capable hosts
	::1      ip6-localhost ip6-loopback
	fe00::0  ip6-localnet
	ff00::0  ip6-mcastprefix
	ff02::1  ip6-allnodes
	ff02::2  ip6-allrouters
	" > "/etc/hosts"

	echo "Renommage termine."| tee -a $compte_rendu 
	echo "pour intégrer le poste plus tard : 
	cd /root/bin/
	./integration_wheezy.bash --nom-client=\"$nom_machine\" --is --ivl" | tee -a $compte_rendu 
fi


# if [ -n "$nom_machine" -a -n "$email" ]; then
# 	cat /root/firstboot.txt|mail -s "[$nom_se3.$nom_domaine]: Post-install $nom_machine" $email
# fi

gdm="$(cat /etc/X11/default-display-manager | cut -d / -f 4)"
if [ "$gdm" = "gdm3" ]; then
    update-rc.d gdm3 defaults
fi
if [ "$gdm" = "lightdm" ]; then
    update-rc.d lightdm defaults
fi

mv /root/bin/post-install_debian_wheezy.sh /root/bin/post-install_debian_wheezy.sh.$ladate


echo "Reconfig grub..." | tee -a $compte_rendu
sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=saved|" /etc/default/grub
sed -i "/^GRUB_SAVEDEFAULT=.*/d" /etc/default/grub
echo "
# Pour rebooter sur le dernier OS choisi
GRUB_SAVEDEFAULT=true" >> /etc/default/grub

# Virer l'entree (mode de dépannage)
echo '
# Pour ne pas generer l entree mode de depannage (sans mot de passe root)
GRUB_DISABLE_LINUX_RECOVERY="true"' >> /etc/default/grub
egrep -v "(^$|^#)" /etc/default/grub | tee -a $compte_rendu
sed -r -i -e 's/^\GRUB_TIMEOUT=-1.*$/GRUB_TIMEOUT=3/g' /etc/default/grub
os-prober
update-grub

apt-get remove -y xscreensaver



# modif inittab
sed 's|1:2345:respawn:/bin/login -f root tty1 </dev/tty1 >/dev/tty1 2>\&1|1:2345:respawn:/sbin/getty 38400 tty1|' -i /etc/inittab

# Remise en place gdm3
update-rc.d gdm3 defaults


echo -e "$COLTITRE"
echo "--------------------------------------------------------------------------------"
echo "Fin du script -reboot dans 10s pour finaliser l'installation"
echo "--------------------------------------------------------------------------------"
echo -e "$COLTXT"
read -t 10 dummy
reboot

exit 0
