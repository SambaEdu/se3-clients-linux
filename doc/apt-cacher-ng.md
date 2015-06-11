# Mise en place d'apt-cacher-ng


## installer Debian/Jessie sur une machine

Cette machine sera un serveur distant (alice/192.168.1.4) et un répertoire */var/www/miroir/* sera utilisé pour les paquets du miroir *apt-cacher-ng* géré par le se3.'



## sur alice/192.168.1.4

* installer les paquets apache2 et nfs-cacher-ng
aptitude install apache2 mc nfs-kernel-server

* créer un répertoire /var/www/miroir/
mkdir /var/www/miroir

* pour partager /var/www/miroir/ avec le se3/192.168.1.3, écrire la ligne suivante dans /etc/exports :
/var/www/miroir 192.168.1.3(rw,no_root_squash)

* relancer le service nfs-kernel-server
service nfs-kernel-server restart
ou bien, plus bavard :
/etc/init.d/nfs-kernel-server restart

* vérifications que les services sont bien en place
showmount -e
rpcinfo -p | grep nfs
cat /proc/filesystems | grep nfs
rpcinfo -p | grep portmap


## sur le se3/192.168.1.3 :

-voir les partages distants disponibles :
showmount -e 192.168.1.4

- droit root pour /var/se3/apt-cacher-ng avant le montage
chown -R root:root /var/se3/apt-cacher-ng

- monter le répertoire distant
mount -t nfs 192.168.1.4:/var/www/miroir /var/se3/apt-cacher-ng

- droits apt-cacher-ng après le montages
chown -R apt-cacher-ng:apt-cacher-ng /var/se3/apt-cacher-ng

- relancer le service apt-cacher-ng
service apt-cacher-ng restart

- vérifications du montage
mount

- vérifications des droits
les droits en cas de montage (apt-cacher-ng) ou démontage (root)
ls -l /var/se3/apt-cacher-ng/

- vérification que le service est opérationnel
→ sur un client, changer le sources.list pour mettre 192.168.1.3:9999
→ sur ce client, lancer un aptitude update puis un aptitude safe-upgrade
→ le répertoire /var/www/miroir d'alice/192.168.1.4 doit se remplir


## sur le se3/192.168.1.3, montage au redémarrage du se3 du répertoire distant 192.168.1.4:/var/www/miroir

→ écrire dans le fichier /etc/fstab :
192.168.1.4:/var/www/miroir /var/se3/apt-cacher-ng nfs _netdev,noatime,defaults 0 0

sur le se3/192.168.1.3, tâche cron au démarrage (pour mémoire)
@reboot mount -t nfs 192.168.1.4:/var/www/miroir /var/se3/apt-cacher-ng

*Autre option : utiliser autofs ?*

* test des montages et alertes mail si nécessaire
un script à mettre dans /root du se3 : espion_montage_alice.sh
→ à mettre dans le crontab pour un lancement tous les jours à 8h02
crontab -e
une ligne à rajouter :
02 08 * * * bash espion_montage_alice.sh


## pour les futures installations par pxe/preseed

→ dans l'interface du se3, décocher l'option de l'IP du miroir APT et supprimer les contenus des deux champs
→ modifier les fichier preseed


## Les clients linux

- sur les clients-linux, il faudra modifier les sources.list
en remplaçant IP_miroir/miroir par IP_serveur_se3:9999
→ un script unefois


## divers

- arrêt du service sur le se3/192.168.1.3 :
service apt-cacher-ng stop

- pour démonter le partage sur le se3/192.168.1.3 :
umount /var/se3/apt-cacher-ng


