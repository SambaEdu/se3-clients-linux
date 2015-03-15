#! /bin/bash

#--%<----%<----%<----%<----%<----%<----%<----%<----%<----%<----%<--
SE3="__SE3__"
BASE_DN="__BASE_DN__"
SERVEUR_NTP="__SERVEUR_NTP__"
#--%<----%<----%<----%<----%<----%<----%<----%<----%<----%<----%<--

# Pour avoir des sorties les plus simples possibles, c'est-à-dire
# en anglais avec des caractères 100% ASCII ! Ce changement de locales
# est temporaire et ne durera que le temps de l'exécution du script.
export LC_ALL="C"

# Pour faire des installations via apt-get non interactives.
export DEBIAN_FRONTEND=noninteractive




#######################################
#######################################
### Quelques variables importantes. ###
#######################################
#######################################

# Le nom de ce script.
NOM_DU_SCRIPT=${0##*/}

# Nom actuel de la machine cliente.
NOM_CLIENT_ANCIEN=$(cat "/etc/hostname")

# Le nom de code de la distribution (par exemple "squeeze").
NOM_DE_CODE=$(lsb_release --codename | cut -f 2)
#NOM_DE_CODE="wheezy"

# Le partage du Se3.
NOM_PARTAGE_NETLOGON="netlogon-linux"
CHEMIN_PARTAGE_NETLOGON="//$SE3/$NOM_PARTAGE_NETLOGON"

# Les répertoires/fichiers importants suite au montage du partage.
REP_MONTAGE="/mnt"
REP_NETLOGON="$REP_MONTAGE/netlogon"
REP_SAVE="$REP_NETLOGON/distribs/$NOM_DE_CODE/save"
REP_SKEL="$REP_NETLOGON/distribs/$NOM_DE_CODE/skel"
REP_BIN="$REP_NETLOGON/bin"
REP_INTEGRATION="$REP_NETLOGON/distribs/$NOM_DE_CODE/integration"

# Les répertoires/fichiers importants locaux au client.
REP_SE3_LOCAL="/etc/se3"
REP_SAVE_LOCAL="$REP_SE3_LOCAL/save"
REP_BIN_LOCAL="$REP_SE3_LOCAL/bin"
REP_SKEL_LOCAL="$REP_SE3_LOCAL/skel"
REP_UNEFOIS_LOCAL="$REP_SE3_LOCAL/unefois"
REP_LOG_LOCAL="$REP_SE3_LOCAL/log"
REP_TMP_LOCAL="$REP_SE3_LOCAL/tmp"
LOGON_SCRIPT_LOCAL="$REP_BIN_LOCAL/logon"
PAM_SCRIPT_AUTH="/usr/share/libpam-script/pam_script_auth"
CREDENTIALS="$REP_TMP_LOCAL/credentials"

# Les options de base pour un montage CIFS.
OPTIONS_MOUNT_CIFS_BASE="nobrl,serverino,iocharset=utf8,sec=ntlmv2"

# Variable de sortie en cas de debuggage
SORTIE="/dev/null"

########################
########################
### Fonctions utiles ###
########################
########################

# Fonction pour afficher des messages.
function afficher ()
{
    echo ""
    # On écrira des lignes de 65 caractères maximum.
    echo "$@" | fmt -w 65
    sleep 0.5
}

# Fonction qui teste si le nom du client est un nom valide.
# Elle prend un argument qui est le nom à tester bien sûr. 
# Elle renvoie 0 si tout est Ok, 1 sinon (et dans ce cas un
# message d'erreur est envoyé).
function tester_nom_client ()
{
    # $1 représente le nom du client
    # La classe [a-z] dépend de la locale : sur mon système (Debian Squeeze)
    # et avec la locale fr_FR.utf8 la classe [a-z] attrape les caractères
    # accentués ce que je ne souhaite pas. Mais avec la locale C, 
    # la classe [a-z] n'attrape pas les caractères accentués. 
    # Devant ce comportement un peu versatile, je préfère mettre explicitement 
    # la locale "C", même si en principe elle est déjà définie au début
    # du script.
    if echo "$1" | LC_ALL=C grep -Eiq '^[-a-z0-9]{1,15}$'; then
        return 0
    else
        return 1
    fi
}

# Affiche un message d'erreur concernant le nom du client à intégrer.
function afficher_erreur_nom_client ()
{
    afficher "Désolé, le client ne peut pas être intégré au" \
             "domaine car son nom doit être uniquement constitué" \
             "des caractères « -A-Za-z0-9 » avec 15 caractères maximum."
}

# Fonction qui Demande un mot de passe à l'utilisateur avec confirmation
# et définit ensuite la variable « mot_de_passe » qui contient alors 
# la saisie de l'utilisateur.
function demander_mot_de_passe ()
{
    local mdp1
    local mdp2
    
    printf "Saissez le mot de passe : "
    read -s -r mdp1
    printf "\n"

    printf "Saissez le mot de passe à nouveau : "
    read -s -r mdp2
    printf "\n"
 
    while [ "$mdp1" != "$mdp2" ]; do
        printf "Désolé, mais vos deux saisies ne sont pas identiques. Recommencez.\n"

        printf "Saissez le mot de passe : "
        read -s -r mdp1
        printf "\n"

        printf "Saissez le mot de passe à nouveau : "
        read -s -r mdp2
        printf "\n"
    done
    
    mot_de_passe="$mdp1" 
}

# Fonction qui permet d'obtenir le hachage version Grub2 d'un mot 
# de passe donné. La fonction prend un argument qui est le mot de 
# passe en question.
function hacher_mot_de_passe_grub ()
{
    { echo "$1"; echo "$1"; } \
        | grub-mkpasswd-pbkdf2 -c 30 -l 30 -s 30 2>$SORTIE \
        | grep -v 'password' \
        | sed -r 's/Your PBKDF2 is (.+)$/\1/'  
}

# Fonction qui permet de changer le mot de passe root. Elle prend
# un argument qui correspond au mot de passe souhaité.
function changer_mot_de_passe_root ()
{
    { echo "$1"; echo "$1"; } | passwd root > $SORTIE 2>&1
}

# Fonction qui restaure, en préservant les droits, un fichier
# à partir de sa version dans REP_SAVE_LOCAL. Le nom du fichier est donné 
# en unique paramètre. 1) Le fichier doit exister dans REP_SAVE_LOCAL et 
# 2) son nom doit être exprimé sous la forme d'un chemin absolu, correspondant
# à son emplacement dans le système. Par exemple "/etc/machin" comme paramètre
# implique que "$REP_SAVE_LOCAL"/etc/machin" doit exister.
function restaurer_via_save ()
{
    # Si la cible existe déjà, elle sera écrasée.
    cp -a "${REP_SAVE_LOCAL}$1" "$1"
}

# Fonction qui permettra de supprimer le montage REP_NETLOGON
# (entre autres) si le script se termine incorrectement.
function nettoyer_avant_de_sortir ()
{
    case "$?" in

        "0")
            # Tout va bien, on ne fait rien.
            true
            ;;

        "1")
            # Là, il y a eu un problème. Il faut démonter REP_NETLOGON
            # et supprimer le répertoire.
            
            afficher "Nettoyage du système avant de quitter."
            
            if mountpoint -q "$REP_NETLOGON"; then
                umount "$REP_NETLOGON" && rmdir "$REP_NETLOGON"
            else
                if [ -d "$REP_NETLOGON" ]; then
                    rmdir "$REP_NETLOGON"
                fi
            fi
            
            if [ -e "$REP_SE3_LOCAL" ]; then
                if mountpoint -q  "$REP_TMP_LOCAL"; then
                    umount "$REP_TMP_LOCAL"
                fi
                rm -fR "$REP_SE3_LOCAL"
            fi
            
            # On supprime les paquets installés.
            apt-get purge --yes $PAQUETS_TOUS >$SORTIE 2>&1
            ;;
            
        *)
            # On ne fait rien.
            true
            ;;

    esac
}

function configurer_gdm3 ()
{
    #############################
    #############################
    ### Configuration de gdm3 ###
    #############################
    #############################

    afficher "Configuration de gdm3 afin que le script de logon soit" \
         "exécuté au démarrage de gdm3, à l'ouverture et à la" \
         "fermeture de session"
       
    ######################################################
    ### Modification du fichier /etc/gdm3/Init/Default ###
    ######################################################

    # Ce fichier est exécuté à chaque fois que la fenêtre de connexion
    # gdm3 est affichée, à savoir à chaque démarrage du système et après 
    # chaque fermeture de session d'un utilisateur. C'est dans l'exécution
    # de ce script, entre autres, que le partage NOM_PARTAGE_NETLOGON va
    # être monté.

    # Modification du fichier en partant de la version sauvegardée.
    # On supprime le « exit 0 » à la fin.
    grep -v '^exit 0' "$REP_SAVE_LOCAL/etc/gdm3/Init/Default" > "/etc/gdm3/Init/Default"
    # Puis on y ajoute ceci :
    echo "

###########################################################################
###         Modification pour l'intégration au domaine                  ###
###########################################################################

if [ -x '$LOGON_SCRIPT_LOCAL' ]; then
    '$LOGON_SCRIPT_LOCAL' 'initialisation'
fi

#######################FIN DE LA MODIFICATION##############################

exit 0

" >> "/etc/gdm3/Init/Default"

    # Modifications des droits (les droits par défaut me semblent trop
    # permissifs.
    chown "root:root" "/etc/gdm3/Init/Default"
    chmod "700" "/etc/gdm3/Init/Default"

    #########################################################
    #### Création du fichier /etc/gdm3/PostLogin/Default ####
    #########################################################

    # Ce script sera lancé à l'ouverture de session, juste après avoir 
    # entré le mot de passe.
    touch "/etc/gdm3/PostLogin/Default"
    chown "root:root" "/etc/gdm3/PostLogin/Default"
    chmod "700" "/etc/gdm3/PostLogin/Default"

    # On édite le fichier /etc/gdm3/PostLogin/Default de A à Z.
    echo "#! /bin/bash

###########################################################################
###         Création du fichier pour l'intégration au domaine           ###
###########################################################################

if [ -x '$LOGON_SCRIPT_LOCAL' ]; then
    '$LOGON_SCRIPT_LOCAL' 'ouverture'
fi

#######################FIN DE LA MODIFICATION##############################

exit 0

" > "/etc/gdm3/PostLogin/Default"

    #############################################################
    ### Modification du fichier /etc/gdm3/PostSession/Default ###
    #############################################################

    # Ce script sera lancé à la fermeture de session.

    # On édite carrément ce fichier de A à Z.
    echo "#! /bin/bash

###########################################################################
###         Modification pour l'intégration au domaine                  ###
###########################################################################

if [ -x '$LOGON_SCRIPT_LOCAL' ]; then
    '$LOGON_SCRIPT_LOCAL' 'fermeture'
fi

#######################FIN DE LA MODIFICATION##############################

exit 0

" > "/etc/gdm3/PostSession/Default"

    # Modifications des droits.
    chown "root:" "/etc/gdm3/PostSession/Default"
    chmod "700" "/etc/gdm3/PostSession/Default"

    ########################################################
    ### Modification de /etc/gdm3/greeter.gsettings ###
    ########################################################

    # Ce fichier permet de gérer quelques options de la fenêtre de
    # connexion qui s'affiche après le démarrage du système.

    # Modification du fichier en partant de la version sauvegardée
    # toujours pour être sûr de partir d'un fichier « clean ».
    restaurer_via_save "/etc/gdm3/greeter.gsettings"
    echo "

###########################################################################
###         Modification pour l'intégration au domaine                  ###
###########################################################################"

    sed -r -i -e 's/^\# disable-user-list=true.*$/disable-user-list=true/g' /etc/gdm3/greeter.gsettings

}    

function configurer_lightdm ()
{
    restaurer_via_save "/etc/lightdm/lightdm.conf"
    sed -r -i "s|#greeter-setup-script.*$|greeter-setup-script=\"${LOGON_SCRIPT_LOCAL}\" initialisation|g" /etc/lightdm/lightdm.conf
    sed -r -i "s|#session-setup-script.*$|session-setup-script=\"${LOGON_SCRIPT_LOCAL}\" ouverture|g" /etc/lightdm/lightdm.conf
    sed -r -i "s|#session-cleanup-script.*$|session-cleanup-script=\"${LOGON_SCRIPT_LOCAL}\" fermeture|g" /etc/lightdm/lightdm.conf
}

# Avec de se terminer la fonction nettoyer_avant_de_sortir sera appelée.
trap 'nettoyer_avant_de_sortir' EXIT




###################
###################
### Les options ###
###################
###################

# Une options longue avec les « :: » signifie que le paramètre est optionnel
# (par exemple « --nom-client » ou « --nom-client="S121-HPS-04" »).
# getopt réorganise les chaînes de caractères de "$@" pour que si par
# exemple "$@" vaut « --nom-client=TOTO arg1 arg2 », alors LISTE_OPTIONS  
# vaut « --nom-client 'TOTO' -- 'arg1' 'arg2' ».

suite_options="help"
suite_options="$suite_options,nom-client::,nc::"
suite_options="$suite_options,mdp-grub::,mg::"
suite_options="$suite_options,mdp-root::,mr::"
suite_options="$suite_options,ignorer-verification-ldap,ivl"
suite_options="$suite_options,redemarrer-client,rc"
suite_options="$suite_options,installer-samba,is"
suite_options="$suite_options,debug,d"

LISTE_OPTIONS=$(getopt --options h --longoptions "$suite_options" -n "$NOM_DU_SCRIPT" -- "$@")
# Si l'appel est syntaxiquement incorrect on arrête le script.
if [ $? != 0 ] ; then echo "Arrêt du script $NOM_DU_SCRIPT." >&2; exit 1; fi

unset -v suite_options

# Évaluation de la chaîne $LISTE_OPTIONS afin de positionner 
# $1, $2 comme étant la succession des mots de $LISTE_OPTIONS.
eval set -- "$LISTE_OPTIONS"

# On peut détruire la variable LISTE_OPTIONS.
unset -v LISTE_OPTIONS 

# On définit des variables indiquant si les options ont été
# appelées. Par défaut, elles ont la valeur "false", c'est-à-dire
# qu'il n'y a pas eu appel des options.
OPTION_NOM_CLIENT="false"
OPTION_MDP_GRUB="false"
OPTION_MDP_ROOT="false"
OPTION_IV_LDAP="false"
OPTION_REDEMARRER="false"
OPTION_INSTALLER_SAMBA="false"

# La commande shift décale les paramètres $1, $2 etc.
# Par exemple après "shift 2" $3 devient accessible via $1 etc.
# On sortira forcément de la boucle car (et c'est entre autres le
# travail de getopt), la chaîne LISTE_OPTIONS évaluée précédemment 
# contient forcément un "--" qui séparent les options (à gauche) et les
# arguments du script et qui ne sont pas des options (à droite de --).
while true ; do
	case "$1" in
	
		-h|--help)
		    afficher "Aide : voir la documentation (au format pdf) associée." 
            exit 0
        ;;

        --nom-client|--nc)
            OPTION_NOM_CLIENT="true"
            NOM_CLIENT="$2"
            shift 2
            ;;
            
        --mdp-grub|--mg) 
            OPTION_MDP_GRUB="true"
            MDP_GRUB="$2"
		    shift 2
		    ;;

        --mdp-root|--mr) 
            OPTION_MDP_ROOT="true"
            MDP_ROOT="$2"
		    shift 2
		    ;;

        --ignorer-verification-ldap|--ivl) 
            OPTION_IV_LDAP="true"
		    shift 1
		    ;;

        --redemarrer-client|--rc) 
            OPTION_REDEMARRER="true"
		    shift 1
		    ;;

        --installer-samba|--is) 
            OPTION_INSTALLER_SAMBA="true"
            shift 1
		    ;;

        --debug|--d) 
            SORTIE=">&1"
            shift 1
		    ;;
		    
		--) 
		    shift
		    break
		    ;;
		    
		*) 
		    afficher "Erreur: «$1» est une option non implémentée."
		    exit 1
		    ;;
		    
	esac
done

if [ -n "$1" ]; then
    afficher "Désolé le script ne prend aucun argument à part des" \
             "options de la forme « --xxx ». Fin du script."
    exit 1
fi



# Les paquets nécessaires à l'intégration. Ne peuvent être définis qu'après
# avoir connaissance de l'activation éventuelle de l'option --installer-samba.
PAQUETS_MONTAGE_CIFS="cifs-utils"
PAQUETS_CLIENT_LDAP="ldap-utils"
PAQUETS_RANDOM="rng-tools"
PAQUETS_AUTRES="libnss-ldapd libpam-ldapd nscd nslcd libpam-script rsync ntpdate xterm imagemagick"
if "$OPTION_INSTALLER_SAMBA"; then
    PAQUETS_AUTRES="$PAQUETS_AUTRES samba"
fi
PAQUETS_TOUS="$PAQUETS_MONTAGE_CIFS $PAQUETS_CLIENT_LDAP $PAQUETS_RANDOM $PAQUETS_AUTRES"



###################################
###################################
### Vérifications sur le client ###
###################################
###################################

afficher "Vérifications sur le système client..."

# On vérifie que l'utilisateur a bien les droits de root.
# Tester « "$USER" == "root" » est possible mais la variable
# $USER peut être modifiée par n'importe quel utilisateur,
# tandis que la variable $UID est en lecture seule.
if [ "$UID" != "0" ]; then
    afficher "Désolé, vous devez avoir les droits « root » pour lancer" \
             "le script. Fin du script."
    exit 1
fi

# On vérifie que le système est bien Debian Wheezy.
if [ "$NOM_DE_CODE" != "wheezy" ]; then
    afficher "Désolé, le script doit être exécuté sur Debian Wheezy." \
             "Fin du script."
    exit 1
fi

# Vérification du nom du client à intégrer.
if "$OPTION_NOM_CLIENT"; then
    # L'option a été spécifiée.
    if [ -n "$NOM_CLIENT" ]; then
        # Si $NOM_CLIENT n'est pas vide, c'est que l'option a
        # été spécifiée avec paramètre.
        if ! tester_nom_client "$NOM_CLIENT"; then
            afficher_erreur_nom_client
            exit 1
        fi
    else
        # $NOM_CLIENT est vide et l'utilisateur va choisir
        # manuellement le nom du client plus loin. Pas de test.
        true
    fi
else
    # L'option n'a pas été spécifiée, il faut vérifier le nom
    # actuel du client.
    if ! tester_nom_client "$NOM_CLIENT_ANCIEN"; then
        afficher_erreur_nom_client
        exit 1
    fi
fi

# On vérifie que le répertoire de montage existe bien.
if [ ! -d "$REP_MONTAGE" ]; then
    afficher "Désolé, le répertoire $REP_MONTAGE n'existe pas." \
             "Sa présence est nécessaire pour le script." \
             "Fin du script."
    exit 1
fi

# On vérifie l'absence de montage dans le répertoire de montage.
if df | grep -q "$REP_MONTAGE"; then
    afficher "Désolé, le répertoire $REP_MONTAGE ne doit contenir aucun" \
             "montage de système de fichiers. Charge à vous d'enlever" \
             "le ou les montages et de supprimer le ou les répertoires" \
             "associés. Relancez le script d'intégration ensuite." \
             "Fin du script."
    exit 1
fi

# On vérifie alors qu'il n'existe pas de fichier ou répertoire REP_NETLOGON.
if [ -e "$REP_NETLOGON" ]; then
    afficher "Désolé, un répertoire ou fichier $REP_NETLOGON existe déjà" \
             "dans $REP_MONTAGE. Charge à vous de le supprimer." \
             "Relancez le script d'intégration ensuite. Fin du script."
    exit 1
fi

# Vérification du bon fonctionnement de « apt-get update ».
# Cette commande semble renvoyer la valeur 0 à chaque fois,
# même quand les dépôts ne sont pas accessibles par exemple.
# Du coup, je ne vois rien de mieux que de compter le nombre 
# de lignes écrites sur la sortie standard des erreurs.
if [ $(apt-get update 2>&1 >$SORTIE | wc -l) -gt 0 ]; then
    afficher "Désolé, la commande « apt-get update » ne fonctionne pas" \
             "correctement. Il y des erreurs que vous devez rectifier." \
             "Relancez le script d'intégration ensuite. Fin du script."
    exit 1
fi

# Vérification de la disponibilité des paquets nécessaires à l'intégration.
for paquet in $PAQUETS_TOUS; do
    if ! apt-get install "$paquet" --yes --simulate >$SORTIE 2>&1; then
        afficher "Désolé, le paquet $paquet n'est pas disponible dans" \
                 "les dépôts alors que celui-ci est nécessaire pour" \
                 "effectuer l'intégration de la machine cliente." \
                 "La liste des dépôts dans le fichier /etc/apt/sources.list" \
                 "est sans doute incomplète. Fin du script."
        exit 1
    fi
done

# On teste la variable SE3 pour savoir si son contenu est une IP ou non.
# Si ce n'est pas une IP (et donc un nom), on teste sa résolution
# en adresse IP.
octet="[0-9]{1,3}"
if ! echo "$SE3" | grep -qE "^$octet\.$octet\.$octet\.$octet$"; then
    if ! host "$SE3" >$SORTIE; then
        afficher "Désolé, le nom d'hôte du SambaÉdu ($SE3) n'est pas résolu" \
                 "par la machine cliente. Fin du script."
        exit 1
    fi   
fi
unset -v octet

# Pas de client mDNS (le paquet tout seul est désinstallé).
# En effet, lors de la résolution d'un nom, ce protocole est
# utilisé avant DNS si et seulement si le nom d'hôte se termine
# par ".local". Et comme sur un réseau pédagogique il n'y a pas
# serveur mDNS, la résolution ne fonctionne pas. Et par défaut,
# quand la résolution mDNS n'aboutit pas, le protocole DNS n'est
# pas utilisé ensuite si bien que le nom d'hôte n'est pas résolu.
# Ça provient de la ligne
# « hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4 »
# dans le fichier /etc/nsswitch.conf. Bref, ce protocole ne sert
# à rien dans un réseau pédagogique et il peut même entraîner
# des erreurs (par exemple un simple « ping se3.intranet.local »
# ne fonctionnera pas alors que « ping se3 » fonctionnera).
apt-get remove --purge --yes libnss-mdns >$SORTIE 2>&1

# Arrêt définitif du service avahi-daemon. C'est la partie serveur
# du protocole mDNS dont on n'a que faire. Désintaller le paquet
# avahi-daemon ne doit pas être tenté car, par le jeu des dépendances,
# le paquet gnome-desktop-environment a besoin de avahi-daemon
# et du coup, si on désintalle avahi-daemon, gnome-desktop-environment
# se désinstalle et avec lui de très nombreuses dépendances ce qui
# ampute le système de plein de fonctionnalités. Le mieux, c'est donc
# de stopper ce daemon et d'empêcher son lancement lors du démarrage
# du système.
invoke-rc.d avahi-daemon stop >$SORTIE 2>&1
update-rc.d -f avahi-daemon remove >$SORTIE 2>&1

# On vérifie que le Se3 est bien accessible via un ping.
if ! ping -c 5 -W 2 "$SE3" >$SORTIE 2>&1; then
    afficher "Désolé, le SambaÉdu est inaccessible via la commande ping." \
             "Fin du script."
    exit 1    
fi

afficher "Vérifications OK."

# Purge des paquets pour repartir sur une base saine et pouvoir
# enchaîner deux intégrations de suite sur le même client.
# Peut-être que l'option --installer-samba n'est pas activée
# et dans ce cas $PAQUETS_TOUS ne contient pas samba.
# Donc on l'ajoute dans la liste pour être sûr qu'il soit
# désintallé.
apt-get purge --yes $PAQUETS_TOUS samba >$SORTIE 2>&1

# On stoppe définitivement le daemon exim4 qui ne sert pas dans le
# cas d'une station cliente et qui peut bloquer pendant quelques secondes
# (voire quelques minutes) l'arrivée du prompt de login sur tty[1-6].
invoke-rc.d exim4 stop >$SORTIE 2>&1
update-rc.d -f exim4 remove >$SORTIE 2>&1




###############################################
###############################################
### Montage du partage NOM_PARTAGE_NETLOGON ###
###############################################
###############################################

afficher "Montage du partage « $NOM_PARTAGE_NETLOGON » du serveur."

# Nous allons installer PAQUETS_MONTAGE_CIFS nécessaire pour les montages CIFS,
# mais ce paquet nécessite l'installation du paquet samba-common
# qui lui-même pose des questions à l'utilisateur au moment de
# l'installation. D'où la nécessité de renseigner la configuration
# de ce paquet via debconf.
debconf_parametres=$(mktemp)
echo "
samba-common	samba-common/encrypt_passwords	boolean	true
samba-common	samba-common/dhcp	boolean	false
samba-common	samba-common/workgroup	string	WORKGROUP
samba-common	samba-common/do_debconf	boolean	true
" > "$debconf_parametres"
debconf-set-selections < "$debconf_parametres"
rm -f "$debconf_parametres"
unset -v debconf_parametres

# On installe le paquet qui contient la commande « mount.cifs ». L'option
# --no-install-recommends permet d'éviter l'installation du paquet
# samba-common-bin qui ferait du client un serveur Samba ce qui serait
# inutile ici.
apt-get install --no-install-recommends --reinstall --yes $PAQUETS_MONTAGE_CIFS >$SORTIE 2>&1

# Montage du partage NOM_PARTAGE_NETLOGON.
mkdir "$REP_NETLOGON"
chown "root:root" "$REP_NETLOGON"
chmod 700 "$REP_NETLOGON"
mount -t cifs "$CHEMIN_PARTAGE_NETLOGON" "$REP_NETLOGON" -o ro,guest,"$OPTIONS_MOUNT_CIFS_BASE" >$SORTIE 2>&1
if [ "$?" != "0" ]; then
    rmdir "$REP_NETLOGON"
    afficher "Échec du montage du partage $NOM_PARTAGE_NETLOGON du SambaÉdu." \
             "Fin du script."
    exit 1
fi




#######################################################
#######################################################
### Mise en place du répertoire local REP_SE3_LOCAL ###
#######################################################
#######################################################

afficher "Mise en place du répertoire local $REP_SE3_LOCAL."

# On efface le fichier ou répertoire REP_SE3_LOCAL s'il existe
# pour créer un répertoire vide qui sera rempli ensuite.
if [ -e "$REP_SE3_LOCAL" ]; then
    if mountpoint -q  "$REP_TMP_LOCAL"; then
        umount "$REP_TMP_LOCAL"
    fi
    rm -fR "$REP_SE3_LOCAL"
fi
mkdir -p "$REP_SE3_LOCAL"
chown "root:" "$REP_SE3_LOCAL"
chmod "700" "$REP_SE3_LOCAL"

# Copie du répertoire REP_BIN.
cp -r "$REP_BIN" "$REP_BIN_LOCAL"
rm -fr "$REP_BIN_LOCAL/logon_perso" # En revanche le fichier logon_perso est inutile.
# On y ajoute les scripts d'intégration et de désintégration.
cp "$REP_INTEGRATION/"*"$NOM_DE_CODE"* "$REP_BIN_LOCAL"
chown -R "root:" "$REP_BIN_LOCAL"
chmod -R "700" "$REP_BIN_LOCAL"

# Copie du répertoire REP_SKEL et mise en place de droits cohérents.
cp -r "$REP_SKEL" "$REP_SKEL_LOCAL"
chown -R "root:" "$REP_SKEL_LOCAL"
chmod "700" "$REP_SKEL_LOCAL"
# Pour le premier find, il y a l'option « -mindepth 1 » car sinon
# les droits du répertoire « racine » REP_SKEL_LOCAL vont être
# redéfinis par find.
find "$REP_SKEL_LOCAL" -mindepth 1 -type d -exec chmod u=rwx,g=rwx,o='',u-s,g-s,o-t '{}' \;
find "$REP_SKEL_LOCAL" -type f -exec chmod u=rw,g=rw,o='',u-s,g-s,o-t '{}' \;

# Copie du répertoire REP_SAVE
cp -r "$REP_SAVE" "$REP_SAVE_LOCAL"
chown -R "root:" "$REP_SAVE_LOCAL"
chmod "700" "$REP_SAVE_LOCAL"

# Mise en place des droits sur les fichiers tels qu'ils sont
# sur un système « clean ». Pour ce faire, on utilise le fichier
# "droits" qui contient, sous un certain format, toutes les
# informations nécessaires.
cat "$REP_SAVE_LOCAL/droits" | while read; do
    nom="$REP_SAVE_LOCAL$(echo "$REPLY" | cut -d ':' -f 1)"
    proprietaire="$(echo "$REPLY" | cut -d ':' -f 2)"
    groupe_proprietaire="$(echo "$REPLY" | cut -d ':' -f 3)"
    droits="$(echo "$REPLY" | cut -d ':' -f 4)"
    chown "$proprietaire:$groupe_proprietaire" "$nom"
    chmod "$droits" "$nom"
done
unset -v nom proprietaire groupe_proprietaire droits

# Création du répertoire REP_UNEFOIS_LOCAL
mkdir -p "$REP_UNEFOIS_LOCAL"
chown "root:" "$REP_UNEFOIS_LOCAL"
chmod 700 "$REP_UNEFOIS_LOCAL"

# Création du répertoire REP_LOG_LOCAL
mkdir -p "$REP_LOG_LOCAL"
chown "root:" "$REP_LOG_LOCAL"
chmod 700 "$REP_LOG_LOCAL"

# Création du répertoire REP_TMP_LOCAL
mkdir -p "$REP_TMP_LOCAL"
chown "root:" "$REP_TMP_LOCAL"
chmod 700 "$REP_TMP_LOCAL"




######################################
######################################
### Renommage (éventuel) du client ###
######################################
######################################

# On récupère le nom du client dans la variable NOM_CLIENT.
if "$OPTION_NOM_CLIENT"; then
    # L'option a été spécifiée.
    if [ -z "$NOM_CLIENT" ]; then
        # Si $NOM_CLIENT est vide, c'est que l'option a été spécifié
        # sans paramètre et il faut demander à l'utilisateur le nom
        # qu'il souhaite pour le client.
        afficher "Saisissez le nom de la machine cliente :"
        read -r NOM_CLIENT
        if ! tester_nom_client "$NOM_CLIENT"; then
            afficher_erreur_nom_client
            exit 1
        fi
    else
        # $NOM_CLIENT n'est pas vide et l'utilisateur a déjà
        # spécifié la valeur de ce paramètre. La vérification
        # sur les caractères a déjà été effectuée dans la partie
        # « Vérifications sur le client ».
        true
    fi
else
    # L'option n'a pas été spécifiée et le nom (ancien) a déjà été
    # vérifié au niveau des caractères dans la partie
    # « Vérifications sur le client ».
    NOM_CLIENT="$NOM_CLIENT_ANCIEN"
fi

afficher "Installation de l'exécutable ldapsearch et vérification de la" \
         "connexion avec l'annuaire LDAP du serveur à travers une" \
         "recherche d'enregistrements en rapport avec le client (au niveau" \
         "du nom de machine ou de l'adresse MAC ou de l'adresse IP)."

# Installation du ou des paquets contenant un client LDAP (pour
# faire des recherches.
apt-get install --no-install-recommends --reinstall --yes "$PAQUETS_CLIENT_LDAP" >$SORTIE 2>&1

# Vérification de la connexion LDAP avec le Se3.
ldapsearch -xLLL -h "$SE3" -b "ou=Computers,$BASE_DN" "(|(uid=$NOM_CLIENT$)(cn=$NOM_CLIENT))" "dn" > $SORTIE 2>&1
if [ "$?" != 0 ]; then
    afficher "Désolé, le serveur LDAP n'est pas joignable." \
             "Fin du script."
    exit 1
fi

# On passe à la recherche LDAP proprement dite. On va cherche dans l'annuaire
# toute entrée de machine dont le nom, l'adresse MAC ou l'adresse IP seraient
# identique à la machine cliente.

# Liste des cartes réseau (eth0, lo etc).
cartes_reseau=$(ifconfig | grep -i '^[a-z]' | cut -d' ' -f 1)

# Variable contenant les lignes de la forme 
# nom-de-carte;adresse-mac;adresse-ip.
carte_mac_ip=$(for carte in $cartes_reseau; do
                   # On passe le cas où la carte est lo.
                   [ "$carte" = "lo" ] && continue
                   ifconfig "$carte" | awk 'BEGIN { v="rien"} 
                                            /^'"$carte"' / { printf $1 ";" $NF ";" }
                                            /inet addr/ {v=$2; gsub("addr:", "", v); print v }
                                            END { if (v == "rien") print "SANS-IP" }'   
               done)

# Construction du filtrer de recherche LDAP, par rapport au nom du client,
# à l'adresse MAC des cartes réseau ou à l'adresse IP des cartes réseau.
filtre_recherche="(|(uid=$NOM_CLIENT$)(cn=$NOM_CLIENT)"
for i in $carte_mac_ip; do
    carte=$(echo "$i" | cut -d";" -f 1)
    adresse_mac=$(echo "$i" | cut -d";" -f 2)
    adresse_ip=$(echo "$i" | cut -d";" -f 3)
    # Si jamais "$adresse_ip" = "SANS-IP", on ajoute simplement un critère inutile
    # dans la recherche mais ce n'est pas un problème.
    filtre_recherche="$filtre_recherche(ipHostNumber=$adresse_ip)(macAddress=$adresse_mac)"
done
# On ferme la parenthèse.
filtre_recherche="$filtre_recherche)"

# On effectue enfin la recherche LDAP qu'on affiche.
resultat=$(ldapsearch -xLLL -h "$SE3" -b "ou=Computers,$BASE_DN" "$filtre_recherche" dn ipHostNumber macAddress)
if [ "$resultat" = "" ]; then
    resultat="AUCUNE ENTRÉE CORRESPONDANT DANS L'ANNUAIRE."
fi
afficher "Résultat de la recherche LDAP :"
echo "-------------------------------------------------"
echo "$resultat"
echo "-------------------------------------------------"

# On affiche quelques informations sur les cartes réseau de la
# machine cliente.
afficher "Pour information, voici l'adresse MAC et l'adresse IP des cartes" \
         "réseau de la machine cliente ($NOM_CLIENT) :"
for i in $carte_mac_ip; do
    carte=$(echo "$i" | cut -d";" -f 1)
    adresse_mac=$(echo "$i" | cut -d";" -f 2)
    adresse_ip=$(echo "$i" | cut -d";" -f 3)
    # On ne saute pas de ligne ici, alors on utilise echo.
    echo "* $carte <--> $adresse_mac (IP: $adresse_ip)"
done

if  "$OPTION_IV_LDAP"; then
    afficher "Vous avez choisi d'ignorer la vérification LDAP, le script" \
             "d'intégration continue son exécution."
else
    afficher "D'après les informations ci-dessus, voulez-vous continuer" \
             "l'exécution du script d'intégration ? Si oui, alors répondez" \
             "« oui » (en minuscules), sinon répondez autre chose :"
    read -r reponse
    if [ "$reponse" != "oui" ]; then
        afficher "Fin du script."
        exit 1
    fi
fi

# Après les vérifications, on procède au renommage proprement
# dit. Renommage qui n'a lieu que si l'option --nom-client a été
# spécifié.
if "$OPTION_NOM_CLIENT"; then
    afficher "Changement de nom du système."
    echo "$NOM_CLIENT" > "/etc/hostname"
    invoke-rc.d hostname.sh stop > $SORTIE 2>&1
    invoke-rc.d hostname.sh start > $SORTIE 2>&1
fi

unset -v cartes_reseau carte_mac_ip carte adresse_mac adresse_ip 
unset -v filtre_recherche resultat reponse




#######################################################
#######################################################
### Mise en place (éventuelle) du mot de passe Grub ###
#######################################################
#######################################################

# Si l'option --mdp-grub n'a pas été spécifiée, alors on passe
# à la suite sans rien faire. Sinon, il faut mettre en place
# un mot de passe Grub.
if "$OPTION_MDP_GRUB"; then

    afficher "Mise en place du mot de passe Grub (le login sera « admin »)."

    # Installation temporaire qui permet de rendre le fichier
    # /dev/random plus loquace ce qui permet ainsi de rectifier
    # un bug de la commande grub-mkpasswd-pbkdf2. Ces installations
    # seront supprimées ensuite, une fois la mise en place du
    # mot de passe Grub terminée.
    apt-get install --reinstall --yes --force-yes $PAQUETS_RANDOM > $SORTIE 2>&1
    echo "HRNGDEVICE=/dev/urandom" >> "/etc/default/rng-tools"
    invoke-rc.d rng-tools stop > $SORTIE 2>&1
    invoke-rc.d rng-tools start > $SORTIE 2>&1
    
    if [ -z "$MDP_GRUB" ]; then
        # MDP_GRUB est vide (l'option --mdp-grub a été spécifiée
        # sans paramètre), il faut donc demander à l'utilisateur
        # le mot de passe.
        demander_mot_de_passe # La variable mot_de_passe est alors définie.
        MDP_GRUB=$mot_de_passe
    else
        # MDP_GRUB a été spécifié via le paramètre de l'option
        # --mdp-grub. Il n'y a rien à faire dans ce cas.
        true
    fi
    
    # On hache le mot de passe Grub.
    mdp_grub_hache=$(hacher_mot_de_passe_grub "$MDP_GRUB")
    
    # On édite le fichier /etc/grub.d/40_custom.
    fichier_grub_custom="/etc/grub.d/40_custom"
    restaurer_via_save "$fichier_grub_custom"
    echo 'set superusers="admin"' >> "$fichier_grub_custom"
    echo "password_pbkdf2 admin $mdp_grub_hache" >> "$fichier_grub_custom"
    
    # On met à jour la configuration de Grub.
    update-grub > $SORTIE 2>&1
    if [ "$?" != "0" ]; then
        afficher "Attention, la commande « update_grub » ne s'est pas" \
                 "effectuée correctement, a priori Grub n'est pas" \
                 "opérationnel. Il faut rectifier la configuration de" \
                 "Grub jusqu'à ce que la commande se déroule sans erreur."
        exit 1
    fi
    
    unset -v mot_de_passe mdp_grub_hache fichier_grub_custom

    # Désinstallation de PAQUETS_RANDOM.
    apt-get remove --purge --yes $PAQUETS_RANDOM > $SORTIE 2>&1
    
fi

######################################################
# Annulation du timeout de démarrage
######################################################
sed -r -i -e 's/^\GRUB_TIMEOUT=5.*$/GRUB_TIMEOUT=-1/g' /etc/default/grub
update-grub > $SORTIE 2>&1


#######################################################
#######################################################
### Mise en place (éventuelle) du mot de passe root ###
#######################################################
#######################################################

# Si l'option --mdp-root n'a pas été spécifiée, alors on passe
# à la suite sans rien faire. Sinon, il faut modifier le
# mot de passe root.
if "$OPTION_MDP_ROOT"; then

    afficher "Changement du mot de passe root."
        
    if [ -z "$MDP_ROOT" ]; then
        # MDP_ROOT est vide (l'option --mdp-root a été spécifiée
        # sans paramètre), il faut donc demander à l'utilisateur
        # le mot de passe.
        demander_mot_de_passe # La variable mot_de_passe est alors définie.
        MDP_ROOT=$mot_de_passe
    else
        # MDP_ROOT a été spécifié via le paramètre de l'option
        # --mdp-root. Il n'y a rien à faire dans ce cas.
        true
    fi

    # On peut alors changer le mot de passe de root.    
    changer_mot_de_passe_root "$MDP_ROOT"

    unset -v mot_de_passe
    
fi




#########################################################################
#########################################################################
### Désinstallation des paquets network-manager network-manager-gnome ###
#########################################################################
#########################################################################

# Avant de désinstaller network-manager*, on énumère les cartes
# réseau présentes sur le système, sachant que ça inclut « lo ».
cartes_reseau=$(ifconfig | grep -i '^[a-z]' | cut -d' ' -f 1)

config_cartes="/etc/network/interfaces"

afficher "Les paquets network-manager et network-manager-gnome vont être" \
         "désinstallés. C'est le fichier $config_cartes qui permettra" \
         "désormais de paramétrer la configuration IP des cartes réseau." \
         "Par défaut, toutes les cartes réseau vont être configurées" \
         "via le DHCP."

apt-get remove --purge --yes network-manager network-manager-gnome > $SORTIE 2>&1

echo "
# Fichier édité lors de l'intégration de la machine au domaine SE3.
# NetworkManager a été désinstallé du système et c'est maintenant ce
# fichier qui gère la configuration des cartes réseau de la machines.

auto lo
iface lo inet loopback
" > "$config_cartes"

for carte in $cartes_reseau; do
    [ "$carte" = "lo" ] && continue
	echo "auto $carte" >> "$config_cartes"
	echo "iface $carte inet dhcp" >> "$config_cartes"
	echo "" >> "$config_cartes"
done

invoke-rc.d networking stop > $SORTIE 2>&1
invoke-rc.d networking start > $SORTIE 2>&1

# On vérifie à nouveau que le Se3 est bien accessible via un ping.
if ! ping -c 5 -W 2 "$SE3" >$SORTIE 2>&1; then
    afficher "Désolé, le Se3 est inaccessible via la commande ping." \
             "Fin du script."
    exit 1    
fi

unset -v cartes_reseau config_cartes




################################
################################
### Installation des paquets ###
################################
################################

afficher "Installation des paquets nécessaires à l'intégration."

# Utilisation de debconf pour rendre l'installation non-interactive
# mais adaptée à la situation présente.
debconf_parametres=$(mktemp)
echo "
libnss-ldapd	libnss-ldapd/nsswitch	multiselect	group, passwd, shadow
libnss-ldapd	libnss-ldapd/clean_nsswitch	boolean	false
libpam-ldapd	libpam-ldapd/enable_shadow	boolean	true
nslcd	nslcd/ldap-bindpw	password	
nslcd	nslcd/ldap-starttls	boolean	false
nslcd	nslcd/ldap-base	string	$BASE_DN
nslcd	nslcd/ldap-reqcert	select	
nslcd	nslcd/ldap-uris	string	ldap://$SE3/
nslcd	nslcd/ldap-binddn	string	
samba-common	samba-common/encrypt_passwords	boolean	true
samba-common	samba-common/dhcp	boolean	false
samba-common	samba-common/workgroup	string	WORKGROUP
samba-common	samba-common/do_debconf	boolean	true
" > "$debconf_parametres"
debconf-set-selections < "$debconf_parametres"
rm -f "$debconf_parametres"
unset -v debconf_parametres

apt-get install --no-install-recommends --yes --reinstall $PAQUETS_AUTRES > $SORTIE 2>&1

# Cas particulier. Sur Squeeze, on a besoin du paquet sudo.
apt-get install --yes  sudo > $SORTIE 2>&1
    
# On désinstalle le gestionnaire de fenêtres TWM pour qu'au moment
# de l'ouverture de session l'utilisateur ne puisse choisir que Gnome
# et seulement Gnome.
apt-get remove --purge --yes twm >$SORTIE 2>&1
afficher "Installation des paquets terminée."




afficher "Configuration post-installation du système."




############################
############################
### Configuration de PAM ###
############################
############################

afficher "Configuration de PAM afin que seul gdm3 (la fenêtre de login)" \
         "consulte l'annuaire LDAP du serveur pour l'authentification. Une" \
         "authentification via ssh (par exemple) ne sera possible qu'avec" \
         "un compte local."

# L'installation des paquets a eu lieu et maintenant les fichiers
# "/etc/pam.d/common-*" tiennent compte de LDAP. On va les renommer
# de manière explicite, avec l'extension « .AVEC-LDAP », et on va
# remettre les fichiers "/etc/pam.d/common-*" d'origine.
# Ensuite, dans le fichier "/etc/pam.d/gdm3" et lui seul, on va
# changer les instructions « @include » pour importer les fichiers
# "/etc/pam.d/common-*.AVEC-LDAP". Ainsi, gdm3 sera la seule application
# utilisant PAM qui tiendra compte de LDAP. Par exemple, les comptes
# LDAP ne pourront pas se connecter au système via la console ou via
# ssh.

# Si des fichiers ayant pour nom "common-*.AVEC-LDAP", c'est sans
# doute qu'il y a déjà eu tentative d'intégration, alors on supprime
# ces fichiers.
for f in "/etc/pam.d/common-"*".AVEC-LDAP"; do
    [ "$f" = "/etc/pam.d/common-*.AVEC-LDAP" ] && continue
    rm -f "$f"
done

# On renomme les fichiers "common-*" en ajoutant l'extension « .AVEC-LDAP »
# et on restaure sa version d'origine.
for f in "/etc/pam.d/common-"*; do
    [ "$f" = "/etc/pam.d/common-*" ] && continue
    mv -f "$f" "$f.AVEC-LDAP"
    restaurer_via_save "$f"    
done

# Dans les trois fichiers common-(auth|account|session).AVEC-LDAP, on 
# remplace, au niveau de la ligne faisant appel à pam_unix.so,
# l'instruction de contrôle par « sufficient ». Le but est que,
# en cas de panne du serveur, la connexion avec les comptes locaux
# ne soit pas ralentie pour autant (ce qui est le cas si on laisse
# en l'état la configuration.
sed -i -r -e 's/^.*pam_unix\.so.*$/account    sufficient    pam_unix.so/g' "/etc/pam.d/common-account.AVEC-LDAP"
sed -i -r -e 's/^.*pam_unix\.so.*$/auth    sufficient    pam_unix.so/g' "/etc/pam.d/common-auth.AVEC-LDAP"
sed -i -r -e 's/^.*pam_unix\.so.*$/session    sufficient    pam_unix.so/g' "/etc/pam.d/common-session.AVEC-LDAP"

# On modifie le fichier /etc/pam.d/gdm3  ou /etc/pam.d/lightdm afin que :
# 1) Il fasse appel à la bibliothèque pam_script.so.
# 2) Il y ait des « includes » des fichiers "/etc/pam.d/common-*.AVEC-LDAP".

gdm="$(cat /etc/X11/default-display-manager | cut -d / -f 4)"
echo "Gestionnaire graphique installé $gdm"
restaurer_via_save "/etc/pam.d/${gdm}"
# Insertion de la ligne « auth    optional    pam_script.so ».
awk '{ print $0 } /^auth.*pam_gnome_keyring\.so/ { print "auth\toptional\tpam_script.so" }' \
"${REP_SAVE_LOCAL}/etc/pam.d/${gdm}" > "/etc/pam.d/${gdm}"
# Inclusion des fichiers "/etc/pam.d/common-*.AVEC-LDAP".
sed -i -r 's/@include\s+(common\-[a-z]+)\s*$/@include \1\.AVEC-LDAP/' "/etc/pam.d/${gdm}"

# Création du fichier PAM_SCRIPT_AUTH.
echo '#! /bin/bash

function est_utilisateur_local ()
{
    if grep -q "^$1:" "/etc/passwd"; then
        return 0
    else
        return 1
    fi
}

if est_utilisateur_local "$PAM_USER"; then
    # On ne fait rien.
    exit 0
fi

# Sinon, on écrit les identifiants.

echo "username=$PAM_USER
password=$PAM_AUTHTOK" > "__CREDENTIALS__"

exit 0
' > "$PAM_SCRIPT_AUTH"

# Attention, il faut prendre « : » comme délimiteur car « / »
# est présent dans le chemin du fichier CREDENTIALS.
sed -r -i -e "s:__CREDENTIALS__:$CREDENTIALS:g" "$PAM_SCRIPT_AUTH"
chown "root:root" "$PAM_SCRIPT_AUTH"
chmod "555" "$PAM_SCRIPT_AUTH"


# Paramétrage de gnome-screensaver utiliser quand une session
# doit être déverrouillée.
restaurer_via_save "/etc/pam.d/gnome-screensaver"
sed -i -r 's/@include\s+(common\-[a-z]+)\s*$/@include \1\.AVEC-LDAP/' "/etc/pam.d/gnome-screensaver"




######################################################################
######################################################################
### Réécriture des fichiers /etc/hosts et /etc/dhcp/dhclient.conf ####
######################################################################
######################################################################

# Peu importe que l'option --nom-client ait été spécifiée ou non,
# nous allons réécriture le fichier /etc/hosts.

afficher "Réécriture complète du fichier /etc/hosts."

echo "
127.0.0.1    localhost
127.0.1.1    $NOM_CLIENT

# The following lines are desirable for IPv6 capable hosts
::1      ip6-localhost ip6-loopback
fe00::0  ip6-localnet
ff00::0  ip6-mcastprefix
ff02::1  ip6-allnodes
ff02::2  ip6-allrouters
" > "/etc/hosts"

#Modification inutile sur Wheezy
#afficher "Modification du fichier /etc/dhcp/chclient.conf afin que le" \
#         "nom de la machine soit envoyé au serveur DHCP par le client DHCP."

# Et nous allons également modifier le fichier
# /etc/dhcp/chclient.conf afin que le nom de machine soit
# envoyé au serveur DHCP.
#restaurer_via_save "/etc/dhcp/dhclient.conf"
#sed -i -r -e "s/^.*send host-name.*$/send host-name \"$NOM_CLIENT\";/g" "/etc/dhcp/dhclient.conf"




#############################################
#############################################
### Réécriture du fichier /etc/nslcd.conf ###
#############################################
#############################################

afficher "Réécriture complète du fichier /etc/nslcd.conf afin que la" \
         "communication LDAP entre le client et le serveur (notamment" \
         "au moment de l'authentification) soit cryptée."

echo "
# /etc/nslcd.conf
# nslcd configuration file. See nslcd.conf(5) for details.

# The user and group nslcd should run as.
uid nslcd
gid nslcd

# The location at which the LDAP server(s) should be reachable.
uri ldap://$SE3/

# The search base that will be used for all queries.
base $BASE_DN

# SSL options
ssl start_tls
tls_reqcert never

" > "/etc/nslcd.conf"

invoke-rc.d nslcd stop > $SORTIE 2>&1
invoke-rc.d nslcd start > $SORTIE 2>&1



##############################################################################
##############################################################################
### Modification du fichier smb.conf (s'il s'avère qu'on a installé Samba) ###
##############################################################################
##############################################################################

# À faire seulement si le fichier existe bien sûr.
if [ -f "/etc/samba/smb.conf" ]; then
    afficher "Modification du fichier /etc/samba/smb.conf afin d'indiquer" \
             "à la machine cliente que le serveur SambaÉdu est le" \
             "serveur WINS du domaine."
    sed -i -r -e "s/^.*wins +server +=.*$/wins server = $SE3/" "/etc/samba/smb.conf"
    invoke-rc.d samba restart > $SORTIE 2>&1
fi



#######################################
#######################################
### Configuration de ntpdate-debian ###
#######################################
#######################################


afficher "Réécriture complète du fichier /etc/default/ntpdate" \
         "afin que l'heure du système soit mise à jour via le" \
         "serveur NTP indiqué dans le script d'intégration."

# On réécrit simplement le fichier de configuration
# associé (/etc/default/ntpdate). Ensuite, tout se passe comme si,
# à chaque démarrage, la commande « ntpdate-debian » était lancée
# en tant que root.
echo "
# The settings in this file are used by the program ntpdate-debian, but not
# by the upstream program ntpdate.

# Set to \"yes\" to take the server list from /etc/ntp.conf, from package ntp,
# so you only have to keep it in one place.
NTPDATE_USE_NTP_CONF=no

# List of NTP servers to use  (Separate multiple servers with spaces.)
# Not used if NTPDATE_USE_NTP_CONF is yes.
NTPSERVERS=\"$SERVEUR_NTP\"

# Additional options to pass to ntpdate
NTPOPTIONS=\"\"
" > "/etc/default/ntpdate"


#########################################
#########################################
### Configurations des gestionnaires  ###
### graphiques d'ouverture de session ###
#########################################
#########################################


if [ "$gdm" = "gdm3" ]; then
    configurer_gdm3
fi

if [ "$gdm" = "lightdm" ]; then
    configurer_lightdm
fi

###############################
###############################
### Configurations diverses ###
###############################
###############################

###########################################################
### Modification du fichier /etc/xdg/user-dirs.defaults ###
###########################################################

afficher "Modification du fichier /etc/xdg/user-dirs.defaults afin" \
         "que « Bureau » soit le seul répertoire créé automatiquement" \
         "dans le home d'un utilisateur."

# Ce fichier permet de gérer les répertoires créés par défaut dans
# le /home de l'utilisateur (comme le répertoire Bureau ou Images etc).
restaurer_via_save "/etc/xdg/user-dirs.defaults"

# On édite carrément le fichier de A à Z.
echo "
# Le bureau sera le seul répertoire créé par défaut
# dans le /home de l'utilisateur.

DESKTOP=Desktop

" > "/etc/xdg/user-dirs.defaults"




#########################################################################################
### Modification du fichier /usr/share/polkit-1/actions/org.freedesktop.upower.policy ###
#########################################################################################

afficher "Modification du fichier /usr/share/polkit-1/actions/org.freedesktop.upower.policy" \
         "afin de désactiver l'hibernation et la mise en veille du système."

# Ce fichier permet de désactiver l'hibernation et la mise en veille
# qui mettent souvent la pagaille sous Linux.

# On crée le fichier en partant de sa version sauvegardée dont on
# est sûr qu'elle est non bidouillée.
restaurer_via_save "/usr/share/polkit-1/actions/org.freedesktop.upower.policy"
sed -i -r \
 -e 's:<allow_inactive>no</allow_inactive>:<allow_inactive>yes</allow_inactive>:g' \
 -e 's:<allow_active>yes</allow_active>:<allow_active>no</allow_active>:g' \
 "/usr/share/polkit-1/actions/org.freedesktop.upower.policy"




############################
############################
### FIN DE L'INTÉGRATION ###
############################
############################


afficher "Fin de l'intégration." \
         "Si ce n'est pas déjà fait, pensez à effectuer une réservation" \
         "d'adresse IP du client via" \
         "le serveur DHCP du SambaÉdu, afin d'inscrire le nom" \
         "de la machine cliente dans l'annuaire."

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




