#! /bin/bash

# Pour avoir des sorties les plus simples possibles, c'est-à-dire
# en anglais avec des caractères 100% ASCII ! Ce changement de locales
# est temporaire et ne durera que le temps de l'exécution du script.
export LC_ALL="C"

# Pour faire des installations via apt-get non interactives.
export DEBIAN_FRONTEND=noninteractive



NOM_DU_SCRIPT=${0##*/}
NOM_DE_CODE=$(lsb_release --codename | cut -f 2)
REP_SE3_LOCAL="/etc/se3"
REP_SAVE_LOCAL="$REP_SE3_LOCAL/save"
REP_TMP_LOCAL="$REP_SE3_LOCAL/tmp"
REP_MONTAGE="/mnt"
REP_NETLOGON="$REP_MONTAGE/netlogon"
PAM_SCRIPT_AUTH="/usr/share/libpam-script/pam_script_auth"


# Fonction pour afficher des messages.
function afficher ()
{
    echo ""
    # On écrira des lignes de 65 caractères maximum.
    echo "$@" | fmt -w 65
    sleep 0.5
}

function restaurer_via_save ()
{
    # Si la cible existe déjà, elle sera écrasée.
    cp -a "${REP_SAVE_LOCAL}$1" "$1"
}





LISTE_OPTIONS=$(getopt --options h --longoptions "help,redemarrer-client,rc" -n "$NOM_DU_SCRIPT" -- "$@")

# Si l'appel est syntaxiquement incorrect on arrête le script.
if [ $? != 0 ] ; then echo "Arrêt du script $NOM_DU_SCRIPT." >&2; exit 1; fi

# Évaluation de la chaîne $LISTE_OPTIONS afin de positionner 
# $1, $2 comme étant la succession des mots de $LISTE_OPTIONS.
eval set -- "$LISTE_OPTIONS"

# On peut détruire la variable LISTE_OPTIONS.
unset -v LISTE_OPTIONS 

# On définit des variables indiquant si les options ont été
# appelées. Par défaut, elles ont la valeur "false", c'est-à-dire
# qu'il n'y a pas eu appel des options.
OPTION_REDEMARRER="false"


# La commande shift décale les paramètres $1, $2 etc.
# Par exemple après "shift 2" $3 devient accessible via $1 etc.
# On sortira forcément de la boucle car (et c'est entre autres le
# travail de getopt), la chaîne LISTE_OPTIONS évaluée précédemment 
# contient forcément un "--" qui séparent les options (à gauche) et les
# arguments du script et qui ne sont pas des options (à droite de --).
while true ; do
	case "$1" in
	
		-h|--help)
		    echo "Aide : voir la documentation (au format pdf) associée." 
            exit 0
        ;;

        --redemarrer-client|--rc) 
            OPTION_REDEMARRER="true"
		    shift 1
		    ;;

		--) 
		    shift
		    break
		    ;;
		    
		*) 
		    echo "Erreur: «$1» est une option non implémentée."
		    exit 1
		    ;;
		    
	esac
done









# On vérifie que l'utilisateur a bien les droits de root.
# Tester « "$USER" == "root" » est possible mais la variable
# $USER peut être modifiée par n'importe quel utilisateur,
# tandis que la variable $UID est en lecture seule.
if [ "$UID" != "0" ]; then
    afficher "Désolé, vous devez avoir les droits « root » pour lancer" \
             "le script. Fin du script."
    exit 1
fi

# On vérifie que le système est bien Precise Pangolin.
if [ "$NOM_DE_CODE" != "precise" ]; then
    afficher "Désolé, le script doit être exécuté sur Ubuntu Precise Pangolin." \
             "Fin du script."
    exit 1
fi

# Vérification du bon fonctionnement de « apt-get update ».
# Cette commande semble renvoyer la valeur 0 à chaque fois,
# même quand les dépôts ne sont pas accessibles par exemple.
# Du coup, je ne vois rien de mieux que de compter le nombre 
# de lignes écrites sur la sortie standard des erreurs.
if [ $(apt-get update 2>&1 >/dev/null | wc -l) -gt 0 ]; then
    afficher "Désolé, la commande « apt-get update » ne fonctionne pas" \
             "correctement. Il y des erreurs que vous devez rectifier." \
             "Relancez le script ensuite. Fin du script."
    exit 1
fi







# On démonte les deux montages potentiels dûs à l'intégration
# et on supprime les répertoires.
mountpoint -q "$REP_NETLOGON" && umount "$REP_NETLOGON"
[ -e "$REP_NETLOGON" ] && rm -fr "$REP_NETLOGON"
mountpoint -q "$REP_TMP_LOCAL" && umount "$REP_TMP_LOCAL"
[ -e "$REP_TMP_LOCAL" ] && rm -fr "$REP_TMP_LOCAL"




# Désinstallation des paquets.
afficher "Désinstallation des paquets ayant servi à l'intégration du client."
PAQUETS="cifs-utils ldap-utils rng-tools libnss-ldapd libpam-ldapd nscd nslcd libpam-script rsync ntpdate samba"
apt-get purge --yes $PAQUETS >/dev/null 2>&1


# Réinstallation de network-manager.
afficher "Réinstallation de network-manager."
apt-get install --yes network-manager network-manager-gnome > /dev/null 2>&1


afficher "Restauration des certains fichiers de configuration."

# Fichiers PAM.
for f in "/etc/pam.d/common-"*".AVEC-LDAP"; do
    [ "$f" = "/etc/pam.d/common-*.AVEC-LDAP" ] && continue
    rm -f "$f"
done
[ -f "$PAM_SCRIPT_AUTH" ] && rm -f "$PAM_SCRIPT_AUTH"
restaurer_via_save "/etc/pam.d/lightdm"
if [ -f "/etc/pam.d/gnome-screensaver" ]; then
    restaurer_via_save "/etc/pam.d/gnome-screensaver"
fi
if [ -f "/etc/pam.d/xscreensaver" ]; then
    restaurer_via_save "/etc/pam.d/xscreensaver"
fi

# Le fichier lightdm.
restaurer_via_save "/etc/lightdm/lightdm.conf"

# Divers
restaurer_via_save "/etc/xdg/user-dirs.defaults"
restaurer_via_save "/usr/share/polkit-1/actions/org.freedesktop.upower.policy"

# Restauration par défaut du daemon avahi-daemon.
update-rc.d avahi-daemon defaults >/dev/null 2>&1





afficher "Fin de la désintégration. Il reste encore le répertoire $REP_SE3_LOCAL" \
         "sur la machine que vous pourrez supprimer en tant que root avec la" \
         "commande « rm -fr \"$REP_SE3_LOCAL\" ». De plus, sur le serveur," \
         "pensez à supprimer toute trace de la machine cliente (notamment dans" \
         "l'annuaire du serveur)."

if "$OPTION_REDEMARRER"; then
    afficher "La machine va redémarrer dans 10 secondes."
    echo ""            
    for i in 1 2 3 4 5 6 7 8 9 10; do 
        sleep 1
        echo -n "$i... "
    done
    printf "\n"
    reboot
    exit 0
else
    afficher "Pour pour que le système soit opérationnel, vous devez le redémarrer."
    exit 0
fi



