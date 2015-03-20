#!/bin/bash

# Script destine a recuperer l'archive PlayOnLinux et mettre en place le necessaire sur SE3.
#
# Auteur: Stephane Boireau
# Derniere modification: 25/01/2014

url_archive="http://wawadeb.crdp.ac-caen.fr/iso/tmp/multiboot/PlayOnLinux.tar.gz"
url_md5="http://wawadeb.crdp.ac-caen.fr/iso/tmp/multiboot/PlayOnLinux.tar.gz.md5"

dir_client_linux="/home/netlogon/clients-linux"
dest_prog=${dir_client_linux}/Progs
logon_perso=${dir_client_linux}/bin/logon_perso

#Couleurs
COLTITRE="\033[1;35m"   # Rose
COLPARTIE="\033[1;34m"  # Bleu

COLTXT="\033[0;37m"     # Gris
COLCHOIX="\033[1;33m"   # Jaune
COLDEFAUT="\033[0;33m"  # Brun-jaune
COLSAISIE="\033[1;32m"  # Vert

COLCMD="\033[1;37m"     # Blanc

COLERREUR="\033[1;31m"  # Rouge
COLINFO="\033[0;36m"    # Cyan

DEBUG="yes"


function add_fonc_logon_perso() {

echo -e "$COLTXT"
echo "Ajout d une fonction tester_et_mettre_a_jour_PlayOnLinux_sur_le_client()
dans le logon_perso..."
echo -e "$COLCMD\c"
echo '
function tester_et_mettre_a_jour_PlayOnLinux_sur_le_client() {
    PlayOnLinux_dir=/opt/PlayOnLinux
    PlayOnLinux_parent_dir=$(dirname ${PlayOnLinux_dir})

    if appartient_au_parc "PlayOnLinux" "$NOM_HOTE"; then
        mkdir -p ${PlayOnLinux_parent_dir}

        mise_a_jour_requise="n"
        if [ ! -e "${PlayOnLinux_dir}/.VERSION" ]; then
            mise_a_jour_requise="y"
        else
            t=$(diff -abB /mnt/netlogon/Progs/PlayOnLinux.VERSION ${PlayOnLinux_dir}/.VERSION)
            if [ -n "$t" ]; then
                mise_a_jour_requise="y"
            fi
        fi

        if [ "$mise_a_jour_requise" = "y" ]; then
            echo "La mise a jour de PlayOnLinux est requise."
            cd ${PlayOnLinux_parent_dir}

            # Mise en reserve d une ancienne version si elle existe
            suffixe_tmp="_tmp_$(date +%Y%m%d%H%M%S)"
            if [ -e ${PlayOnLinux_dir} ]; then 
                echo "Mise en reserve de la version anterieure de PlayOnLinux."
                mv ${PlayOnLinux_dir} ${PlayOnLinux_dir}.${suffixe_tmp}
            fi

            # Copie et desarchivage
            echo "Copie et desarchivage de PlayOnLinux."
            cp -fr /mnt/netlogon/Progs/PlayOnLinux.tar.gz ${PlayOnLinux_parent_dir}/ && tar -xzf PlayOnLinux.tar.gz
            if [ "$?" = "0" ]; then
                # Menage sur l ancienne version
                if [ -e ${PlayOnLinux_dir}.${suffixe_tmp} ]; then
                    echo "Suppression de la version anterieure de PlayOnLinux..."
                    rm -fr ${PlayOnLinux_dir}.${suffixe_tmp}
                fi

                echo "Correction des droits et proprios..."
                chown -R root:root ${PlayOnLinux_dir}
                chmod +x ${PlayOnLinux_dir}/bin/adapter_le_modele_a_l_utilisateur_courant.sh

                # Mise en place du fichier de version
                echo "Mise en place du fichier de version..."
                cp -f /mnt/netlogon/Progs/PlayOnLinux.VERSION ${PlayOnLinux_dir}/.VERSION
            else
                # Menage
                rm -fr ${PlayOnLinux_dir}

                # Retablissement de la version precedente:
                echo "Retablissement de la version precedente..."
                if [ -e ${PlayOnLinux_dir}.${suffixe_tmp} ]; then
                    mv ${PlayOnLinux_dir}.${suffixe_tmp} ${PlayOnLinux_dir}
                fi
            fi

            # Menage
            rm -f PlayOnLinux.tar.gz
        fi
    fi
}
' >> $logon_perso

}

function patch1_logon_perso() {
echo "Patch 1 de $logon_perso "
sed -i 's#\(monter_partage "//$SE3/homes/Docs".*\)#\1\n        "$REP_HOME/Docs" \\\n        "$REP_HOME/Documents" \\\n#' $logon_perso 

}

function patch2_logon_perso() {
 echo "Patch 2 de $logon_perso "
 sed -i 's|\(# Montage du partage « admhomes.*\)|if [ -e /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh ]; then\n    chmod +x /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh\n    /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh $LOGIN\n    fi\n    tester_et_mettre_a_jour_PlayOnLinux_sur_le_client\n\1|' $logon_perso

}


cd ${dir_client_linux}
tmp="tmp_$(date +%Y%m%d%H%M%S)"
mkdir -p ${tmp}

if [ "$DEBUG" != "yes" ]; then
	cd ${tmp}
fi

echo -e "$COLTXT"
echo "Telechargement de PlayOnLinux..."
echo -e "$COLCMD\c"
if [ ! -e PlayOnLinux.tar.gz ]; then
	wget $url_archive
else 
echo archive presente en local
fi

if [ "$?" != "0" ]; then
    echo -e "$COLERREUR"
    echo "ERREUR lors du telechargement de $url_archive"
    sleep 2
    echo -e "$COLTXT"
    exit
fi

echo -e "$COLTXT"
echo "Telechargement de la somme MD5 associee..."
echo -e "$COLCMD\c"
wget $url_md5
if [ "$?" != "0" ]; then
    echo -e "$COLERREUR"
    echo "ERREUR lors du telechargement de $url_md5"
    sleep 2
    echo -e "$COLTXT"
    exit
fi

t=$(md5sum PlayOnLinux.tar.gz)
t2=$(cat PlayOnLinux.tar.gz.md5)
if [ "$t" != "$t" ]; then
    echo -e "$COLERREUR"
    echo "ERREUR La somme MD5 ne correspond pas."
    rm -fr ${tmp}
    sleep 2
    echo -e "$COLTXT"
    exit
else
    echo -e "$COLTXT"
    echo "Mise en place de l archive..."
    echo -e "$COLCMD\c"
    mkdir -p $dest_prog
    cp PlayOnLinux.tar.gz $dest_prog/
    cp PlayOnLinux.tar.gz.md5 $dest_prog/PlayOnLinux.VERSION
    cd ${dir_client_linux}
    rm -fr ${tmp}
fi


echo "sauvegarde de la version actulle de $logon_perso"
cp $logon_perso $logon_perso-$(date +%Y%m%d%H%M%S)



if [ -z "$(grep "\$REP_HOME/Docs" $logon_perso)"  ]; then
	patch1_logon_perso
fi

if [ -z "$(grep "/opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh"  $logon_perso)"  ]; then
	patch2_logon_perso
fi

if [ -z "$(grep "function tester_et_mettre_a_jour_PlayOnLinux_sur_le_client" $logon_perso)"  ]; then
	add_fonc_logon_perso
fi

bash /home/netlogon/clients-linux/.defaut/reconfigure.bash 

echo "Creation du script d'installation automatique de PlayOnLinux sur les clients"
UNEFOISDIR="/home/netlogon/clients-linux/unefois"


if [ -e $UNEFOISDIR/PAUSE ]; then
	mv $UNEFOISDIR/PAUSE $UNEFOISDIR/NO-PAUSE
fi

mkdir -p "$UNEFOISDIR/^*"
echo "
#!/bin/bash
wget -q http://deb.playonlinux.com/public.gpg -O- | apt-key add -
wget http://deb.playonlinux.com/playonlinux_wheezy.list -O /etc/apt/sources.list.d/playonlinux.list
apt-get update 
apt-get install playonlinux -y
" > "$UNEFOISDIR/^*/install-playonlinux.unefois"

echo -e "$COLTXT"
 echo -e "Ce qu il reste a faire:
 - Creer un parc 'PlayOnLinux' sur le SE3 et y ajouter la machine cliente Linux."
# - Completer la fonction ouverture_perso() dans le
#      ${COLINFO}$logon_perso${COLTXT}
#   pour y ajouter dans le montage de Mes documents les dossiers
#   Docs et Documents.
#   Le premier (${COLINFO}Docs${COLTXT}) est explicitement utilise dans le script
#      ${COLINFO}adapter_le_modele_a_l_utilisateur_courant.sh${COLTXT}
#   execute cote client lors du login.
#   Il faut donc quelque chose comme:${COLINFO}"
# echo '
#     monter_partage "//$SE3/homes/Docs" "Docs" \
#         "$REP_HOME/Docs" \
#         "$REP_HOME/Documents" \
#         "$REP_HOME/Documents de $LOGIN sur le réseau" \
#         "$REP_HOME/Bureau/Documents de $LOGIN sur le réseau"
# '
# echo -e "${COLTXT}
# - Ajouter en fin de fonction ouverture_perso() du logon_perso
# ${COLINFO}
# tester_et_mettre_a_jour_PlayOnLinux_sur_le_client
# 
# if [ -e /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh ]; then
# chmod +x /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh
# /opt/PlayOnLinux/bin/adapter_le_modele_a_l_utilisateur_courant.sh \$LOGIN
# fi
# ${COLTXT}
# - Et enfin lancer
# ${COLINFO}     dpkg-reconfigure se3-clients-linux${COLINFO}"


