#!/bin/sh

#chroot /target
#Téléchargement du service de premier redémarrage
#wget -O /etc/systemd/system/post-install.service http://192.168.98.5/install/post-install.service
#Téléchargement du script de post-install
mkdir /target/root/post-install
wget -O /target/root/post-install/post-install_debian_jessie.sh http://192.168.98.5/install/post-install_debian_jessie.sh
chmod u+x /target/root/post-install/post-install_debian_jessie.sh

#Désactivation des DM
gdm="$(cat /target/etc/X11/default-display-manager | cut -d / -f 4)"
mv /target/usr/sbin/$gdm /target/usr/sbin/$gdm.save                        
printf '#!/bin/sh\nwhile true; do sleep 10; done\n' >/target/usr/sbin/$gdm; 
chmod 755 /target/usr/sbin/$gdm;

#systemctl disable gdm3.service
#systemctl disable lightdm.service
#Activation du service de post-installation
#systemctl enable post-installation.service
#set-default multi-user.target
mkdir -p /target/etc/systemd/system/getty@tty1.service.d/
wget -O /target/etc/systemd/system/getty@tty1.service.d/autologin.conf http://192.168.98.5/install/autologin.conf

#touch /target/etc/systemd/system/getty@tty1.service.d/autologin.conf
#echo "[Service]
#ExecStart=
#ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux -l /root/post-install/post-install_debian_jessie.sh" > /etc/systemd/system/getty@tty1.service.d/autologin.conf


