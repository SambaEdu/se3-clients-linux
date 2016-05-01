#! /bin/bash

##### #####
# script d'intégration des clients Jessie à un domaine géré par un se3
#
#
# version : 20160429
#
#
#
##### #####

#####
# les variables du serveur
#--%<----%<----%<----%<----%<----%<----%<----%<----%<----%<----%<--
SE3="__SE3__"
BASE_DN="__BASE_DN__"
SERVEUR_NTP="__SERVEUR_NTP__"
#--%<----%<----%<----%<----%<----%<----%<----%<----%<----%<----%<--

#####
# la distribution GNU/Linux
version_debian="jessie"

#####
# Pour avoir des sorties les plus simples possibles, c'est-à-dire
# en anglais avec des caractères 100% ASCII ! Ce changement de locales
# est temporaire et ne durera que le temps de l'exécution du script.
export LC_ALL="C"

#####
# Pour faire des installations via apt-get non interactives.
export DEBIAN_FRONTEND=noninteractive


#=====
# Quelques variables importantes
#=====

# Le nom de ce script.
NOM_DU_SCRIPT=${0##*/}

# Nom actuel de la machine cliente.
NOM_CLIENT_ANCIEN=$(cat "/etc/hostname")

# Le nom de code de la distribution (par exemple "squeeze").
NOM_DE_CODE=$(lsb_release --codename | cut -f 2)

# Le gestionnaire de connexion
gdm="$(cat /etc/X11/default-display-manager | cut -d / -f 4)"

# Le partage du Se3.
NOM_PARTAGE_NETLOGON="netlogon-linux"
CHEMIN_PARTAGE_NETLOGON="//$SE3/$NOM_PARTAGE_NETLOGON"

# Les répertoires/fichiers importants suite au montage du partage.
REP_MONTAGE="/mnt"
REP_NETLOGON="$REP_MONTAGE/netlogon"
REP_SKEL="$REP_NETLOGON/distribs/$NOM_DE_CODE/skel"
REP_BIN="$REP_NETLOGON/bin"
REP_INTEGRATION="$REP_NETLOGON/distribs/$NOM_DE_CODE/integration"

# Les répertoires/fichiers importants locaux au client.
REP_SE3_LOCAL="/etc/se3"
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

# date et compte-rendu du script
ladate=$(date +%Y%m%d%H%M%S)
compte_rendu=/root/compte_rendu_integration_client_${ladate}.txt


#=====
# Fonctions du programme
# début
#=====


afficher()
{
    # Fonction pour afficher des messages.
    #
    echo ""
    # On écrira des lignes de 65 caractères maximum.
    echo "$@" | fmt -w 65
    sleep 0.5
}

tester_nom_client()
{
    # Fonction qui teste si le nom du client est un nom valide.
    # Elle prend un argument qui est le nom à tester bien sûr.
    # Elle renvoie 0 si tout est Ok, 1 sinon (et dans ce cas un
    # message d'erreur est envoyé).
    #
    # 1 argument : $1 représente le nom du client
    #
    # La classe [a-z] dépend de la locale : sur mon système (Debian Squeeze)
    # et avec la locale fr_FR.utf8 la classe [a-z] attrape les caractères
    # accentués ce que je ne souhaite pas. Mais avec la locale C,
    # la classe [a-z] n'attrape pas les caractères accentués.
    # Devant ce comportement un peu versatile, je préfère mettre explicitement 
    # la locale "C", même si en principe elle est déjà définie au début
    # du script.
    if echo "$1" | LC_ALL=C grep -Eiq '^[-a-z0-9]{1,15}$'
    then
        return 0
    else
        return 1
    fi
}


afficher_erreur_nom_client()
{
    # Affiche un message d'erreur concernant le nom du client à intégrer.
    #
    afficher "Désolé, le client ne peut pas être intégré au" \
             "domaine car son nom doit être uniquement constitué" \
             "des caractères « -A-Za-z0-9 » avec 15 caractères maximum."
}


demander_mot_de_passe()
{
    # Fonction qui Demande un mot de passe à l'utilisateur avec confirmation
    # et définit ensuite la variable « mot_de_passe » qui contient alors 
    # la saisie de l'utilisateur.
    #
    local mdp1
    local mdp2
    
    printf "saissez le mot de passe : "
    read -s -r mdp1
    printf "\n"
    
    printf "saissez le mot de passe à nouveau : "
    read -s -r mdp2
    printf "\n"
    
    while [ "$mdp1" != "$mdp2" ]
    do
        printf "Désolé, mais vos deux saisies ne sont pas identiques. Recommencez.\n"
        
        printf "saissez le mot de passe : "
        read -s -r mdp1
        printf "\n"
        
        printf "saissez le mot de passe à nouveau : "
        read -s -r mdp2
        printf "\n"
    done
    
    mot_de_passe="$mdp1" 
}


hash_grub_pwd()
{
    # Fonction qui permet d'obtenir le hachage version Grub2 d'un mot 
    # de passe donné. La fonction prend un argument qui est le mot de 
    # passe en question.
    #
    { echo "$1"; echo "$1"; }                                          \
        | LC_ALL=C grub-mkpasswd-pbkdf2 -c 30 -l 30 -s 30 2>>"$SORTIE" \
        | grep 'PBKDF2'                                                \
        | sed 's/^.* is //'
}


changer_mot_de_passe_root()
{
    # Fonction qui permet de changer le mot de passe root.
    #
    # 1 argument qui correspond au mot de passe souhaité.
    #
    { echo "$1"; echo "$1"; } | passwd root >> $SORTIE 2>&1
}


nettoyer_avant_de_sortir()
{
    # Fonction qui permettra de supprimer le montage REP_NETLOGON
    # (entre autres) si le script se termine incorrectement.
    #
    case "$?" in
        
        "0")
            # Tout va bien, on ne fait rien
            true
        ;;
        
        "1")
            # Là, il y a eu un problème. Il faut démonter REP_NETLOGON
            # et supprimer le répertoire.
            
            afficher "nettoyage du système avant de quitter."
            
            if mountpoint -q "$REP_NETLOGON"
            then
                umount "$REP_NETLOGON" && rmdir "$REP_NETLOGON"
            else
                if [ -d "$REP_NETLOGON" ]
                then
                    rmdir "$REP_NETLOGON"
                fi
            fi
            
            if [ -e "$REP_SE3_LOCAL" ]
            then
                if mountpoint -q  "$REP_TMP_LOCAL"
                then
                    umount "$REP_TMP_LOCAL"
                fi
                rm -fR "$REP_SE3_LOCAL"
            fi
            
            # On supprime les paquets installés.
            apt-get purge --yes $PAQUETS_TOUS >> $SORTIE 2>&1
        ;;
        
        *)
            # On ne fait rien
            true
        ;;
        
    esac
}


# En cas de sortie impromptue du script,
# la fonction nettoyer_avant_de_sortir sera appelée.
trap 'nettoyer_avant_de_sortir' EXIT


message_debut()
{
    echo "Compte-rendu de l'intégration du client-linux : $ladate" > $compte_rendu
}


recuperer_options()
{
    # la récupération des options se fait en début du programme (voir ci-dessous)
    # cette fonction analyse les différentes options transmises au script.
    
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
    if [ "$?" != "0" ]
    then
        echo "Arrêt du script $NOM_DU_SCRIPT." >&2
        exit 1
    fi
    
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
    while true
    do
        case "$1" in
        
            -h|--help)
                afficher "Aide : voir la documentation (https://github.com/SambaEdu/se3-docs/blob/master/se3-clients-linux/options_scripts.md) associée." 
                exit 0
            ;;
            
            --nom-client|--nc)
                OPTION_NOM_CLIENT="true"
                NOM_CLIENT="$2"
                echo "le nom du client : $NOM_CLIENT" >> $compte_rendu
                shift 2
            ;;
            
            --mdp-grub|--mg) 
                OPTION_MDP_GRUB="true"
                MDP_GRUB="$2"
                echo "le mot de passe grub : $MDP_GRUB" >> $compte_rendu
                shift 2
            ;;
            
            --mdp-root|--mr) 
                OPTION_MDP_ROOT="true"
                MDP_ROOT="$2"
                echo "le mot de passe root : $MDP_ROOT" >> $compte_rendu
                shift 2
            ;;
            
            --ignorer-verification-ldap|--ivl) 
                OPTION_IV_LDAP="true"
                echo "on ignore la vérification ldap" >> $compte_rendu
                shift 1
            ;;
            
            --redemarrer-client|--rc) 
                OPTION_REDEMARRER="true"
                echo "on redémarre le client à la fin" >> $compte_rendu
                shift 1
            ;;
            
            --installer-samba|--is) 
                OPTION_INSTALLER_SAMBA="true"
                echo "on installe samba" >> $compte_rendu
                shift 1
            ;;
            
            --debug|--d) 
                SORTIE="$compte_rendu"
                echo "mode debuggage demandé" >> $compte_rendu
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
    
    if [ -n "$1" ]
    then
        afficher "Désolé, le script ne prend aucun argument à part des" \
                 "options de la forme « --xxx ». Fin du script."
        exit 1
    fi
}


definir_paquets_a_installer()
{
    # Les paquets nécessaires à l'intégration.
    #
    # Ils ne peuvent être définis qu'après avoir connaissance
    # de l'activation éventuelle de l'option --installer-samba.
    #
    PAQUETS_MONTAGE_CIFS="cifs-utils"
    PAQUETS_CLIENT_LDAP="ldap-utils"
    #PAQUETS_AUTRES="libnss-ldapd libpam-ldapd nscd nslcd libpam-script rsync ntpdate xterm imagemagick"
    PAQUETS_AUTRES="libnss-ldapd libpam-ldapd nscd nslcd libpam-script rsync ntpdate"
    if "$OPTION_INSTALLER_SAMBA"
    then
        PAQUETS_AUTRES="$PAQUETS_AUTRES samba"
    fi
    PAQUETS_TOUS="$PAQUETS_MONTAGE_CIFS $PAQUETS_CLIENT_LDAP $PAQUETS_AUTRES"
}


verifier_droits_root()
{
    # On vérifie que l'utilisateur a bien les droits de root.
    #
    # Tester « "$USER" == "root" » est possible mais la variable
    # $USER peut être modifiée par n'importe quel utilisateur,
    # tandis que la variable $UID est en lecture seule.
    #
    if [ "$UID" != "0" ]
    then
        afficher "Désolé, vous devez avoir les droits « root » pour lancer" \
                 "le script. Fin du script."
        exit 1
    fi
}


verifier_version_debian()
{
    # On vérifie que la version Debian est bien celle correspondant au script.
    #
    if [ "$NOM_DE_CODE" != "$version_debian" ]
    then
        afficher "Désolé, le script doit être exécuté sur Debian $version_debian." \
                 "là, vous êtes en $NOM_DE_CODE"
                 "Fin du script."
        exit 1
    fi
}


verifier_gdm()
{
    # On vérifie que le système utilise un gestionnaire de connexion testé
    # Actuellement : gdm3 et lightdm
    #
    case "$gdm" in
        gdm3)
            # test réussi pour gdm3
            true
        ;;
    
        lightdm)
            # test réussi pour lightdm
            true
        ;;
    
        *)
            afficher "Désolé, le script doit être exécuté avec gdm3 ou lightdm" \
                     "et non ${gdm}, qui n'a pas encore été testé et validé."
                     "Fin du script."
            exit 1
        ;;
    
    esac
}


verifier_nom_client()
{
    # Vérification du nom du client à intégrer.
    #
    if "$OPTION_NOM_CLIENT"
    then
        # L'option a été spécifiée.
        if [ -n "$NOM_CLIENT" ]
        then
            # Si $NOM_CLIENT n'est pas vide,
            # c'est que l'option aété spécifiée avec paramètre.
            if ! tester_nom_client "$NOM_CLIENT"
            then
                afficher_erreur_nom_client
                exit 1
            fi
        else
            # $NOM_CLIENT est vide et l'utilisateur va choisir
            # manuellement le nom du client plus loin. Pas de test.
            true
        fi
    else
        # L'option n'a pas été spécifiée,
        # il faut vérifier le nom actuel du client.
        if ! tester_nom_client "$NOM_CLIENT_ANCIEN"
        then
            afficher_erreur_nom_client
            exit 1
        fi
    fi
}


verifier_repertoire_montage()
{
    # On vérifie que le répertoire de montage existe bien.
    #
    if [ ! -d "$REP_MONTAGE" ]
    then
        afficher "Désolé, le répertoire $REP_MONTAGE n'existe pas." \
                 "Sa présence est nécessaire pour le script." \
                 "Fin du script."
        exit 1
    fi
    
    # On vérifie l'absence de montage dans le répertoire de montage.
    if df | grep -q "$REP_MONTAGE"
    then
        afficher "Désolé, le répertoire $REP_MONTAGE ne doit contenir aucun" \
                 "montage de système de fichiers. Charge à vous d'enlever" \
                 "le ou les montages et de supprimer le ou les répertoires" \
                 "associés. Relancez le script d'intégration ensuite." \
                 "Fin du script."
        exit 1
    fi
    
    # On vérifie alors qu'il n'existe pas de fichier ou répertoire REP_NETLOGON.
    if [ -e "$REP_NETLOGON" ]
    then
        afficher "Désolé, un répertoire ou fichier $REP_NETLOGON existe déjà" \
                 "dans $REP_MONTAGE. Charge à vous de le supprimer." \
                 "Relancez le script d'intégration ensuite. Fin du script."
        exit 1
    fi
}


verifier_apt_get()
{
    # Vérification du bon fonctionnement de « apt-get update ».
    #
    # Cette commande semble renvoyer la valeur 0 à chaque fois,
    # même quand les dépôts ne sont pas accessibles par exemple.
    # Du coup, je ne vois rien de mieux que de compter le nombre 
    # de lignes écrites sur la sortie standard des erreurs.
    #
    if [ $(apt-get update 2>&1 >> $SORTIE | wc -l) -gt 0 ]
    then
        afficher "Désolé, la commande « apt-get update » ne fonctionne pas" \
                 "correctement. Il y des erreurs que vous devez rectifier." \
                 "Relancez le script d'intégration ensuite. Fin du script."
        exit 1
    fi
}


verifier_disponibilite_paquets()
{
    # Vérification de la disponibilité des paquets nécessaires à l'intégration.
    #
    for paquet in $PAQUETS_TOUS
    do
        if ! apt-get install "$paquet" --yes --simulate >> $SORTIE 2>&1
        then
            afficher "Désolé, le paquet $paquet n'est pas disponible dans" \
                     "les dépôts alors que celui-ci est nécessaire pour" \
                     "effectuer l'intégration de la machine cliente." \
                     "La liste des dépôts dans le fichier /etc/apt/sources.list" \
                     "est sans doute incomplète. Fin du script."
            exit 1
        fi
    done
}


verifier_ip_se3()
{
    # On teste la variable SE3 pour savoir si son contenu est une IP ou non.
    #
    # Si ce n'est pas une IP (et donc un nom), on teste sa résolution
    # en adresse IP.
    #
    octet="[0-9]{1,3}"
    if ! echo "$SE3" | grep -qE "^$octet\.$octet\.$octet\.$octet$"
    then
        if ! host "$SE3" >> $SORTIE
        then
            afficher "Désolé, le nom d'hôte du SambaÉdu ($SE3) n'est pas résolu" \
                     "par la machine cliente. Fin du script."
            exit 1
        fi
    fi
    unset -v octet
}


verifier_acces_ping_se3()
{
    # On vérifie que le Se3 est bien accessible via un ping.
    # mais certains vlans bloquent les pings…
    # il vaut donc mieux utiliser nmap
    # on conserve cette fonction pour mémoire…
    #
    if ! ping -c 5 -W 2 "$SE3" >> $SORTIE 2>&1
    then
        afficher "Désolé, le SambaÉdu est inaccessible via la commande ping." \
                 "Fin du script."
        exit 1
    fi
}


verifier_acces_nmap_se3()
{
    # Certains réseaux comportent des vlans bloquant les pings
    # on utilise nmap, avec l'option -sP pour scan Ping (plus rapide !)
    test_se3=$(nmap -sP $SE3 | grep "1 host up")
    if [ -z "$test_se3" ]
    then
        afficher "Désolé, le SambaÉdu est inaccessible via la commande nmap." \
                 "Fin du script."
        exit 1
    fi
    
}


installer_paquets_cifs()
{
    # Nous allons installer PAQUETS_MONTAGE_CIFS nécessaire pour les montages CIFS.
    #
    # Ce paquet nécessite l'installation du paquet samba-common
    # qui ne pose plus de questions à l'utilisateur au moment de
    # l'installation ; cependant, on maintient les paramètres.
    # dpkg-reconfigure samba-common permet la configuration (2 questions pour Jessie)
    # pour le praramètre dhcp, par défaut c'est false
    # mais ici on met true pour le service WINS si OPTION_INSTALLER_SAMBA est à true
    debconf_parametres=$(mktemp)
    cat > "$debconf_parametres" << END
samba-common	samba-common/dhcp	boolean	$OPTION_INSTALLER_SAMBA
samba-common	samba-common/workgroup	string	WORKGROUP
samba-common	samba-common/do_debconf	boolean	true
END
    debconf-set-selections < "$debconf_parametres"
    rm -f "$debconf_parametres"
    unset -v debconf_parametres
    
    # On installe le paquet qui contient la commande « mount.cifs ».
    # L'option --no-install-recommends permet d'éviter l'installation du paquet
    # samba-common-bin qui ferait du client un serveur Samba ce qui serait inutile ici.
    apt-get install --no-install-recommends --reinstall --yes $PAQUETS_MONTAGE_CIFS >> $SORTIE 2>&1
}


montage_partage_netlogon()
{
    # Montage du partage NOM_PARTAGE_NETLOGON.
    #
    mkdir "$REP_NETLOGON"
    chown "root:root" "$REP_NETLOGON"
    chmod 700 "$REP_NETLOGON"
    mount -t cifs "$CHEMIN_PARTAGE_NETLOGON" "$REP_NETLOGON" -o ro,guest,"$OPTIONS_MOUNT_CIFS_BASE" >> $SORTIE 2>&1
    if [ "$?" != "0" ]
    then
        rmdir "$REP_NETLOGON"
        afficher "Échec du montage du partage $NOM_PARTAGE_NETLOGON du SambaÉdu." \
                 "Fin du script."
        exit 1
    fi
}


effacer_repertoire_rep_se3_local()
{
    # est-ce utile ? par précaution ?
    # On efface le fichier ou répertoire REP_SE3_LOCAL s'il existe
    #
    if [ -e "$REP_SE3_LOCAL" ]
    then
        if mountpoint -q  "$REP_TMP_LOCAL"
        then
            umount "$REP_TMP_LOCAL"
        fi
        rm -fR "$REP_SE3_LOCAL"
    fi
}


creer_repertoire_rep_se3_local()
{
    mkdir -p "$REP_SE3_LOCAL"
    chown "root:" "$REP_SE3_LOCAL"
    chmod "700" "$REP_SE3_LOCAL"
}


copier_repertoire_rep_bin()
{
    # création d'un répertoire vide qui sera rempli ensuite.
    # Copie du répertoire REP_BIN.
    #
    cp -r "$REP_BIN" "$REP_BIN_LOCAL"
    rm -fr "$REP_BIN_LOCAL/logon_perso" # En revanche le fichier logon_perso est inutile.
    # On y ajoute les scripts d'intégration et de désintégration.
    cp "$REP_INTEGRATION/"*"$NOM_DE_CODE"* "$REP_BIN_LOCAL"
    chown -R "root:" "$REP_BIN_LOCAL"
    chmod -R "700" "$REP_BIN_LOCAL"
}


copier_repertoire_rep_skel()
{
    # Copie du répertoire REP_SKEL et mise en place de droits cohérents.
    #
    cp -r "$REP_SKEL" "$REP_SKEL_LOCAL"
    chown -R "root:" "$REP_SKEL_LOCAL"
    chmod "700" "$REP_SKEL_LOCAL"
    # Pour le premier find, il y a l'option « -mindepth 1 » car sinon
    # les droits du répertoire « racine » REP_SKEL_LOCAL vont être
    # redéfinis par find.
    find "$REP_SKEL_LOCAL" -mindepth 1 -type d -exec chmod u=rwx,g=rwx,o='',u-s,g-s,o-t '{}' \;
    find "$REP_SKEL_LOCAL" -type f -exec chmod u=rw,g=rw,o='',u-s,g-s,o-t '{}' \;
}


creation_repertoire_unefois_local()
{
    # Création du répertoire REP_UNEFOIS_LOCAL
    #
    mkdir -p "$REP_UNEFOIS_LOCAL"
    chown "root:" "$REP_UNEFOIS_LOCAL"
    chmod 700 "$REP_UNEFOIS_LOCAL"
}


creation_repertoire_rep_log_local()
{
    # Création du répertoire REP_LOG_LOCAL
    #
    mkdir -p "$REP_LOG_LOCAL"
    chown "root:" "$REP_LOG_LOCAL"
    chmod 700 "$REP_LOG_LOCAL"
}


creation_repertoire_rep_tmp_local()
{
    # Création du répertoire REP_TMP_LOCAL
    #
    mkdir -p "$REP_TMP_LOCAL"
    chown "root:" "$REP_TMP_LOCAL"
    chmod 700 "$REP_TMP_LOCAL"
}


recuperer_nom_client()
{
    # On récupère le nom du client dans la variable NOM_CLIENT.
    #
    if "$OPTION_NOM_CLIENT"
    then
        # L'option a été spécifiée.
        if [ -z "$NOM_CLIENT" ]
        then
            # Si $NOM_CLIENT est vide, c'est que l'option a été spécifié
            # sans paramètre et il faut demander à l'utilisateur le nom
            # qu'il souhaite pour le client.
            afficher "saisissez le nom de la machine cliente :"
            read -r NOM_CLIENT
            if ! tester_nom_client "$NOM_CLIENT"
            then
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
}


installer_paquets_client_ldap()
{
    # Installation du ou des paquets contenant un client LDAP
    # pour faire des recherches dans l'annuaire ldap du se3.
    #
    apt-get install --no-install-recommends --reinstall --yes "$PAQUETS_CLIENT_LDAP" >> $SORTIE 2>&1
}


verifier_connexion_ldap_se3()
{
    # Vérification de la connexion LDAP avec le Se3.
    #
    ldapsearch -xLLL -h "$SE3" -b "ou=Computers,$BASE_DN" "(|(uid=$NOM_CLIENT$)(cn=$NOM_CLIENT))" "dn" >> $SORTIE 2>&1
    if [ "$?" != 0 ]
    then
        afficher "Désolé, le serveur LDAP n'est pas joignable." \
                 "Fin du script."
        exit 1
    fi
}


rechercher_ldap_client()
{
    # On passe à la recherche LDAP proprement dite.
    #
    # On va cherche dans l'annuaire toute entrée de machine
    # dont le nom, l'adresse MAC ou l'adresse IP seraient
    # identique à la machine cliente.
    
    # Liste des cartes réseau (eth0, lo etc)
    cartes_reseau=$(ifconfig | grep -i '^[a-z]' | cut -d' ' -f 1)
    
    # Variable contenant les lignes de la forme 
    # nom-de-carte;adresse-mac;adresse-ip.
    carte_mac_ip=$(for carte in $cartes_reseau; do
                       # On passe le cas où la carte est lo
                       [ "$carte" = "lo" ] && continue
                       ifconfig "$carte" | awk 'BEGIN { v="rien"} 
                                                /^'"$carte"' / { printf $1 ";" $NF ";" }
                                                /inet addr/ {v=$2; gsub("addr:", "", v); print v }
                                                END { if (v == "rien") print "SANS-IP" }'
                   done)
    
    # Construction du filtre de recherche LDAP, par rapport au nom du client,
    # à l'adresse MAC des cartes réseau ou à l'adresse IP des cartes réseau.
    filtre_recherche="(|(uid=$NOM_CLIENT$)(cn=$NOM_CLIENT)"
    for i in $carte_mac_ip
    do
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
    if [ "$resultat" = "" ]
    then
        resultat="AUCUNE ENTRÉE CORRESPONDANT DANS L'ANNUAIRE."
    fi
}


afficher_info_carte_reseau_client()
{
    # On affiche quelques informations sur les cartes réseau
    # de la machine cliente.
    #
    afficher "pour information, voici l'adresse MAC et l'adresse IP des cartes" \
             "réseau de la machine cliente ($NOM_CLIENT) :" | tee -a $compte_rendu
    for i in $carte_mac_ip
    do
        carte=$(echo "$i" | cut -d";" -f 1)
        adresse_mac=$(echo "$i" | cut -d";" -f 2)
        adresse_ip=$(echo "$i" | cut -d";" -f 3)
        # On ne saute pas de ligne ici, alors on utilise echo.
        echo "* $carte <--> $adresse_mac (IP: $adresse_ip)" | tee -a $compte_rendu
    done
    
    if "$OPTION_IV_LDAP"
    then
        afficher "vous avez choisi d'ignorer la vérification LDAP, le script" \
                 "d'intégration continue son exécution" | tee -a $compte_rendu
    else
        afficher "d'après les informations ci-dessus, voulez-vous continuer" \
                 "l'exécution du script d'intégration ? Si oui, alors répondez" \
                 "« oui » (en minuscules), sinon répondez autre chose :" | tee -a $compte_rendu
        read -r reponse
        if [ "$reponse" != "oui" ]
        then
            afficher "Fin du script."
            exit 1
        fi
    fi
}


renommer_nom_client()
{
    # Après les vérifications, on procède au renommage proprement dit.
    #
    # Renommage qui n'a lieu que si l'option --nom-client
    # a été spécifié.
    #
    if "$OPTION_NOM_CLIENT"
    then
        afficher "changement de nom du système" | tee -a $compte_rendu
        echo "$NOM_CLIENT" > "/etc/hostname"
        # prise en compte du changement dans la fonction reecrire_fichier_hosts
    fi
    
    unset -v cartes_reseau carte_mac_ip carte adresse_mac adresse_ip 
    unset -v filtre_recherche resultat reponse
}


reecrire_fichier_hosts()
{
    # On ré-écris de A à Z le fichier /etc/hosts
    cat > "/etc/hosts" << END

127.0.0.1    localhost
127.0.1.1    $NOM_CLIENT

# The following lines are desirable for IPv6 capable hosts
::1      ip6-localhost ip6-loopback
fe00::0  ip6-localnet
ff00::0  ip6-mcastprefix
ff02::1  ip6-allnodes
ff02::2  ip6-allrouters
END
    # on prend en compte le changement de nom et le fichier /etc/hosts
    /etc/init.d/hostname.sh start
}


set_grub_pwd ()
{
    # Si l'option --mdp-grub n'a pas été spécifiée, alors on passe
    # à la suite sans rien faire. Sinon, il faut mettre en place
    # un mot de passe Grub.
    if "$OPTION_MDP_GRUB"
    then
        afficher "mise en place du mot de passe Grub (le login sera « admin »)." | tee -a $compte_rendu
        
        if [ -z "$MDP_GRUB" ]
        then
            # MDP_GRUB est vide (l'option --mdp-grub a été spécifiée
            # sans paramètre), il faut donc demander à l'utilisateur
            # le mot de passe.
            demander_mot_de_passe # La variable mot_de_passe est alors définie.
            MDP_GRUB="$mot_de_passe"
        else
            # MDP_GRUB a été spécifié via le paramètre de l'option
            # --mdp-grub. Il n'y a rien à faire dans ce cas.
            true
        fi
        
        # On hache le mot de passe Grub.
        local hached_grub_pwd
        hached_grub_pwd=$(hash_grub_pwd "$MDP_GRUB")
        
        # Le fichier /etc/grub.d/40_custom existe déjà. Il faut le rééditer
        # en partant de zéro.
        printf '#!/bin/sh\n'                                    >/etc/grub.d/40_custom
        printf 'exec tail -n +3 $0\n'                          >>/etc/grub.d/40_custom
        printf 'set superusers="admin"\n'                      >>/etc/grub.d/40_custom
        printf 'password_pbkdf2 admin %s\n' "$hached_grub_pwd" >>/etc/grub.d/40_custom
        
        # Dans le fichier /etc/grub.d/10_linux, il faut chercher une ligne
        # spécifique qui va générer les entrées de boot Grub dite "simples"
        # (typiquement l'entrée de boot par défaut qui va lancer Jessie).
        # Au niveau de cette ligne, il faudra ajouter « --unrestricted ».
        # En effet, sans cela, par défaut avec seulement le compte "admin"
        # créé, aucun boot ne sera possible sans les identifiants du compte
        # admin (par exemple si on laisse le compteur de temps défiler, Grub
        # lancera le boot par défaut mais il demandera des identifiants pour
        # autoriser le boot ce qui n'est franchement pas pratique).
        
        local pattern="'gnulinux-simple-\$boot_device_id'"
        
        # Si, au niveau de la ligne, l'option est déjà présente alors
        # on ne modifie pas le fichier. Sinon on le modifie.
        if ! grep -- "$pattern" /etc/grub.d/10_linux | grep -q -- '--unrestricted'
        then
            # Ajout de l'option « --unrestricted ».
            sed -i "s/$pattern/& --unrestricted/" /etc/grub.d/10_linux
        fi
        
        # On met à jour la configuration de Grub.
        if ! update-grub >> $SORTIE 2>&1
        then
            afficher "Attention, la commande « update_grub » ne s'est pas" \
                     "effectuée correctement, a priori Grub n'est pas"     \
                     "opérationnel. Il faut rectifier la configuration de" \
                     "Grub jusqu'à ce que la commande se déroule sans erreur." | tee -a $compte_rendu
            exit 1
        fi
        
        unset -v mot_de_passe
    fi
}


mise_en_place_mot_de_passe_root()
{
    # Si l'option  --mdp-root n'a pas été spécifiée,
    # alors on passe à la suite sans rien faire.
    #
    # Sinon, il faut modifier le mot de passe root.
    #
    if "$OPTION_MDP_ROOT"
    then
        afficher "changement du mot de passe root" | tee -a $compte_rendu
        
        if [ -z "$MDP_ROOT" ]
        then
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
}


installer_paquets_integration()
{
    # Utilisation de debconf pour rendre l'installation non-interactive
    # Avec Jessie, 3 questions sont posées.
    #
    debconf_parametres=$(mktemp)
    cat > "$debconf_parametres" << END
libnss-ldapd	libnss-ldapd/nsswitch	multiselect	group, passwd, shadow
libnss-ldapd	libnss-ldapd/clean_nsswitch	boolean	false
libpam-ldapd	libpam-ldapd/enable_shadow	boolean	true
nslcd	nslcd/ldap-uris	string	ldap://$SE3/
nslcd	nslcd/ldap-base	string	$BASE_DN
nslcd	nslcd/ldap-bindpw	password	
nslcd	nslcd/ldap-auth-type	select	simple
nslcd	nslcd/ldap-starttls	boolean	true
nslcd	nslcd/ldap-sasl-authcid	string	
nslcd	nslcd/ldap-sasl-mech	select
nslcd	nslcd/ldap-sasl-secprops	string	
nslcd	nslcd/ldap-sasl-krb5-ccname	string	/var/run/nslcd/nslcd.tkt
nslcd	nslcd/ldap-sasl-realm	string	
nslcd	nslcd/ldap-sasl-authzid	string	
nslcd	nslcd/ldap-cacertfile	string	/etc/ssl/certs/ca-certificates.crt
nslcd	nslcd/ldap-reqcert	select	never
nslcd	libraries/restart-without-asking	boolean	false
nslcd	nslcd/restart-services	string	
END
    debconf-set-selections < "$debconf_parametres"
    rm -f "$debconf_parametres"
    unset -v debconf_parametres
    
    apt-get install --no-install-recommends --yes --reinstall $PAQUETS_AUTRES >> $SORTIE 2>&1
}


installer_paquet_sudo()
{
    # Pour le script logon, l'installation du paquet sudo est nécessaire
    #
    apt-get install --yes  sudo >> $SORTIE 2>&1
}


modifier_fichiers_pam()
{
    # À partir de Jessie - Modification pour "ldapiser" tous les processus utilisant les common-*
    # On modifie le fichier /etc/pam.d/gdm-password ou /etc/pam.d/lightdm
    # pour faire appel à la bibliothèque pam_script.so.
    #
    case "$gdm" in
        gdm3)
            # le nom du fichier gdm3 a changé avec Jessie
            # Ensuite (cas gdm3), dans le fichier "/etc/pam.d/gdm-password" et lui seul, on va
            # incorporer le script pam_script.so. Ainsi, gdm3 sera la seule application
            # utilisant PAM qui tiendra compte de LDAP. Par exemple, les comptes
            # LDAP ne pourront pas se connecter au système via la console ou via ssh.
            fichier_gdm="gdm-password"
        ;;
        lightdm)
            # cas lightdm : même explication
            fichier_gdm="lightdm"
        ;;
    esac
    # Insertion de la ligne « auth    optional    pam_script.so ».
    # ligne issue du script pour Xenial
    sed -i '/@include common-account/i \auth optional pam_script.so' /etc/pam.d/${fichier_gdm}
    
    # L'installation de libpam-script a ajouté des appels à pam_script.so
    # → est-ce un bug ou est-ce voulu par les concepteurs de libpam-script ?
    # Or cet appel ne doit se faire que dans le fichier /etc/pam.d/gdm-password ou /etc/pam.d/lightdm
    # dans tous les fichiers common-*, on les met donc en commentaire
    sed -i '/pam_script/ s/^/#/g' /etc/pam.d/common-session \
                                  /etc/pam.d/common-session-noninteractive \
                                  /etc/pam.d/common-account \
                                  /etc/pam.d/common-auth \
                                  /etc/pam.d/common-password
} 

creation_fichier_pam()
{
    # Création du fichier PAM_SCRIPT_AUTH.
    # but de cette création à expliquer…
    #
    cat > "$PAM_SCRIPT_AUTH" << END
#! /bin/bash

function est_utilisateur_local ()
{
    if grep -q "^$1:" "/etc/passwd"
    then
        return 0
    else
        return 1
    fi
}

if est_utilisateur_local "$PAM_USER"
then
    # On ne fait rien.
    exit 0
fi

# Sinon, on écrit les identifiants.

echo "username=$PAM_USER
password=$PAM_AUTHTOK" > "__CREDENTIALS__"

chown root:root "__CREDENTIALS__"
chmod 700 "__CREDENTIALS__"

exit 0
END
    
    # Attention, il faut prendre « : » comme délimiteur car « / »
    # est présent dans le chemin du fichier CREDENTIALS.
    sed -r -i -e "s:__CREDENTIALS__:$CREDENTIALS:g" "$PAM_SCRIPT_AUTH"
    chown "root:root" "$PAM_SCRIPT_AUTH"
    chmod "555" "$PAM_SCRIPT_AUTH"
}

parametrer_gnome_screensaver()
{
    # fonction plus utilisée : à supprimer
    
    # Paramétrage de gnome-screensaver,
    # utiliser quand une session doit être déverrouillée.
    #
    # NB : à modifier pour Jessie ! (20151026)
    # → passer par une modification de dconf ?
    #
    restaurer_via_save "/etc/pam.d/gnome-screensaver"
    sed -i -r 's/@include\s+(common\-[a-z]+)\s*$/@include \1\.AVEC-LDAP/' "/etc/pam.d/gnome-screensaver"
}


relancer_service_nslcd()
{
    # suite aux modifications de configuration de nslcd,
    # on relance le service
    service nslcd stop >> $SORTIE 2>&1
    service nslcd start >> $SORTIE 2>&1
}


modifier_fichier_smb()
{
    # commentaires ?
    #
    # À faire seulement si le fichier /etc/samba/smb.conf existe bien sûr
    # ce qui doit être le cas si on a installé le paquet samba
    #
    if [ -f "/etc/samba/smb.conf" ]
    then
        afficher "modification du fichier /etc/samba/smb.conf afin d'indiquer" \
                 "à la machine cliente que le serveur SambaÉdu est le" \
                 "serveur WINS du domaine" | tee -a $compte_rendu
        sed -i -r -e "s/^.*wins +server +=.*$/wins server = $SE3/" "/etc/samba/smb.conf"
        # on relance les services smbd et nmbd
        service smbd restart >> $SORTIE 2>&1
        service nmbd restart >> $SORTIE 2>&1
    fi
}


reecrire_fichier_ntpdate()
{
    # On réécrit simplement le fichier de configuration
    # associé (/etc/default/ntpdate).
    # Ensuite, tout se passe comme si, à chaque démarrage,
    # la commande « ntpdate-debian » était lancée en tant que root.
    #
    cat > "/etc/default/ntpdate" << END
# The settings in this file are used by the program ntpdate-debian, but not
# by the upstream program ntpdate.

# Set to "yes" to take the server list from /etc/ntp.conf, from package ntp,
# so you only have to keep it in one place.
NTPDATE_USE_NTP_CONF=no

# List of NTP servers to use  (Separate multiple servers with spaces.)
# Not used if NTPDATE_USE_NTP_CONF is yes.
NTPSERVERS="$SERVEUR_NTP"

# Additional options to pass to ntpdate
NTPOPTIONS=""
END
}


configurer_gdm3 ()
{
    # Configuration de gdm3
    #
    afficher "configuration du gestionnaire de connexion : ${gdm} "\
             "afin que le script de logon soit exécuté au démarrage de ${gdm}," \
             "à l'ouverture et à la fermeture de session." | tee -a $compte_rendu
    
    #####
    # Modification du fichier /etc/gdm3/Init/Default
    #
    # Ce fichier est exécuté à chaque fois que la fenêtre de connexion
    # gdm3 est affichée, à savoir à chaque démarrage du système et après
    # chaque fermeture de session d'un utilisateur. C'est dans l'exécution
    # de ce script, entre autres, que le partage NOM_PARTAGE_NETLOGON va
    # être monté.
    
    # On supprime le « exit 0 » à la fin.
    sed -i "s/^exit 0//" "/etc/gdm3/Init/Default"
    # Puis on y ajoute ceci :
    cat >> "/etc/gdm3/Init/Default" << END

#####
# Modification pour l'intégration au domaine
#

if [ -x '$LOGON_SCRIPT_LOCAL' ]
then
    '$LOGON_SCRIPT_LOCAL' 'initialisation'
fi

# Fin de la modification
#####

exit 0
END
    # Modifications des droits
    # les droits par défaut me semblent trop permissifs
    chown "root:root" "/etc/gdm3/Init/Default"
    chmod "700" "/etc/gdm3/Init/Default"
    
    #####
    # Création du fichier /etc/gdm3/PostLogin/Default
    #
    # Ce script sera lancé à l'ouverture de session,
    # juste après avoir entré le mot de passe.
    touch "/etc/gdm3/PostLogin/Default"
    # Modifications des droits
    chown "root:root" "/etc/gdm3/PostLogin/Default"
    chmod "700" "/etc/gdm3/PostLogin/Default"
    # On édite le fichier /etc/gdm3/PostLogin/Default de A à Z.
    cat > "/etc/gdm3/PostLogin/Default" << END
#! /bin/bash

#####
# Création du fichier pour l'intégration au domaine

if [ -x '$LOGON_SCRIPT_LOCAL' ]
then
    '$LOGON_SCRIPT_LOCAL' 'ouverture'
fi

# Fin de la modification
#####

exit 0
END
    
    #####
    # Modification du fichier /etc/gdm3/PostSession/Default
    # Ce script sera lancé à la fermeture de session.
    # On édite carrément ce fichier de A à Z.
    cat > "/etc/gdm3/PostSession/Default" << END
#! /bin/bash

#####
# Modification pour l'intégration au domaine
#

if [ -x '$LOGON_SCRIPT_LOCAL' ]
then
    '$LOGON_SCRIPT_LOCAL' 'fermeture'
fi

# Fin de la modification
#####

exit 0
END
    # Modifications des droits.
    chown "root:" "/etc/gdm3/PostSession/Default"
    chmod "700" "/etc/gdm3/PostSession/Default"
    
    #####
    # Modification de /etc/gdm3/greeter.dconf-defaults
    # Ce fichier permet de gérer quelques options de la fenêtre de
    # connexion qui s'affiche après le démarrage du système.
    # Ici, on fait en sorte que la liste des utilisateurs ne soit pas proposée
    sed -r -i -e 's/^\# disable-user-list=true.*$/disable-user-list=true/g' /etc/gdm3/greeter.dconf-defaults
}


configurer_lightdm ()
{
    # Configuration de lightdm
    #
    afficher "configuration du gestionnaire de connexion ${gdm} "\
             "afin que le script de logon soit exécuté au démarrage de ${gdm}," \
             "à l'ouverture et à la fermeture de session." | tee -a $compte_rendu
    
    #####
    # Modification du fichier /etc/lightdm/lightdm.conf
    sed -r -i "s|#greeter-setup-script.*$|greeter-setup-script=\"${LOGON_SCRIPT_LOCAL}\" initialisation|g" /etc/lightdm/lightdm.conf
    sed -r -i "s|#session-setup-script.*$|session-setup-script=\"${LOGON_SCRIPT_LOCAL}\" ouverture|g" /etc/lightdm/lightdm.conf
    sed -r -i "s|#session-cleanup-script.*$|session-cleanup-script=\"${LOGON_SCRIPT_LOCAL}\" fermeture|g" /etc/lightdm/lightdm.conf
}


configurer_gestionnaire_connexion()
{
    case "$gdm" in
        gdm3)
            configurer_gdm3
        ;;
        lightdm)
            configurer_lightdm
        ;;
    esac
}


desactiver_hibernation_mise_en_veille()
{
    # À partir de Jessie, on utilise le skel pour ces fonctions.
    
    case "$gdm" in
        gdm3)
            # Sous Gnome, ce n'est pas xsreensaver
            # le problème est géré par le skel et dconf
            true
        ;;
        lightdm)
            # Sous Xfce, on désinstalle l'économiseur d'écran "xscreensaver"
            # (l'onglet "Verrouillage de l'écran" devient de ce fait caduque…) 
            # afin d'éviter qu'un PC soit vérouillé par un utilisateur et ne nécessite, de ce fait,
            # un redémarrage pour être déverrouiller…
            # 
            # Et sous Lxde, est-ce xscreensaver ?
            afficher "purge du paquet xscreensaver" \
                     "pour rendre caduque l'onglet « vérouillage de l'écran »"
            apt-get purge -y xscreensaver
        ;;
    esac
}


preconfigurer_libpam_runtime()
{
    # le paquet libpam-runtime a besoin d'être préconfiguré
    # afin d'éviter des questions de la commande pam-auth-update
    # lors de l'exécution d'un "apt-get upgrade" ultérieurement
    
    debconf-set-selections <<EOF
libpam-runtime	libpam-runtime/override	boolean	false
libpam-runtime	libpam-runtime/profiles	multiselect	pam_script, unix, ldap, systemd, gnome-keyring
EOF
}


preconfigurer_ocsinventory()
{
    # L'installation du client ocsinventory nécessite
    # de préconfigurer des réponses sous peine de "casser" dpkg
    # NB : port 909 pour se3 en squeeze et port 80 à partir d'un se3 en wheezy
    port_ocs="80"
    debconf-set-selections <<EOF
ocsinventory-agent	ocsinventory-agent/method	select	http
ocsinventory-agent	ocsinventory-agent/server	string	$SE3:$port_ocs
ocsinventory-agent	ocsinventory-agent/tag	string
EOF
}

configurer_polkit()
{
cat << 'EOF' > /usr/share/polkit-1/actions/org.freedesktop.login1.policy
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
        "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>

        <vendor>The systemd Project</vendor>
        <vendor_url>http://www.freedesktop.org/wiki/Software/systemd</vendor_url>

        <action id="org.freedesktop.login1.inhibit-block-shutdown">
                <description>Allow applications to inhibit system shutdown</description>
                <description xml:lang="de">Anwendungen dürfen das Herunterfahren des Systems unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν τον τερματισμό του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher l'arrêt du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire lo spegnimento del sistema</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymywanie wyłączenia systemu</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку на выключение системы</description>
                <message>Authentication is required to allow an application to inhibit system shutdown.</message>
                <message xml:lang="de">Legitimierung ist notwendig, um Anwendungen das Herunterfahren des Systems zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει τον τερματισμό του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher l'arrêt du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazione di inibire lo spegnimento del sistema</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie wyłączenia systemu.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку на выключение системы, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.inhibit-delay-shutdown org.freedesktop.login1.inhibit-block-sleep org.freedesktop.login1.inhibit-delay-sleep org.freedesktop.login1.inhibit-block-idle</annotate>
        </action>

        <action id="org.freedesktop.login1.inhibit-delay-shutdown">
                <description>Allow applications to delay system shutdown</description>
                <description xml:lang="de">Anwendungen dürfen das Herunterfahren des Systems verzögern</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να καθυστερούν τον τερματισμό του συστήματος</description>
                <description xml:lang="fr">Permet aux applications de retarder l'arrêt du système</description>
                <description xml:lang="it">Consenti alle applicazioni di ritardare lo spegnimento del sistema</description>
                <description xml:lang="pl">Zezwolenie programom na opóźnienie wyłączenia systemu</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать задержку на выключение системы</description>
                <message>Authentication is required to allow an application to delay system shutdown.</message>
                <message xml:lang="de">Legitimierung ist notwendig, um Anwendungen das Verzögern des Herunterfahren des Systems zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να καθυστερήσει τον τερματισμό του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application de retarder l'arrêt du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazione di ritardare lo spegnimento del sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na opóźnienie wyłączenia systemu.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать задержку на выключение системы, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>yes</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.inhibit-delay-sleep</annotate>
        </action>

        <action id="org.freedesktop.login1.inhibit-block-sleep">
                <description>Allow applications to inhibit system sleep</description>
                <description xml:lang="de">Anwendungen dürfen den Bereitschaftsmodus unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν την ύπνωση του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher la mise en veille du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire il sistema in pausa</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie uśpienia systemu</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку на засыпание системы</description>
                <message>Authentication is required to allow an application to inhibit system sleep.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, um Anwendungen das Unterbinden des Bereitschaftsmodus zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την ύπνωση του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher la mise en veille du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazioni di inibire il sistema in pausa.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie uśpienia systemu.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку на засыпание системы, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.inhibit-delay-sleep org.freedesktop.login1.inhibit-block-idle</annotate>
        </action>

        <action id="org.freedesktop.login1.inhibit-delay-sleep">
                <description>Allow applications to delay system sleep</description>
                <description xml:lang="de">Anwendungen dürfen den Bereitschaftsmodus verzögern</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να καθυστερούν την ύπνωση του συστήματος</description>
                <description xml:lang="fr">Permet aux applications de retarder la mise en veille du système</description>
                <description xml:lang="it">Consenti alle applicazioni di ritardare il sistema in pausa</description>
                <description xml:lang="pl">Zezwolenie programom na opóźnienie uśpienia systemu</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать задержку на засыпание системы</description>
                <message>Authentication is required to allow an application to delay system sleep.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, um Anwendungen das Verzögern des Bereitschaftsmodus zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να καθυστερήσει την ύπνωση του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application de retarder la mise en veille du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazioni di ritardare il sistema in pausa.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na opóźnienie uśpienia systemu.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать задержку на засыпание системы, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>yes</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.inhibit-block-idle">
                <description>Allow applications to inhibit automatic system suspend</description>
                <description xml:lang="de">Anwendungen dürfen den automatischen Bereitschaftsmodus unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν την αυτόματη αναστολή του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher l'hibernation automatique du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire la sospesione automatica del sistema</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie automatycznego uśpienia systemu</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку на автоматический переход системы в ждущий режим</description>
                <message>Authentication is required to allow an application to inhibit automatic system suspend.</message>
                <message xml:lang="de">Legitimierung ist notwendig, um Anwendungen das Unterbinden des automatischen Bereitschaftsmodus zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την αυτόματη αναστολή του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher l'hibernation automatique du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazioni di inibire la sospensione automatica del sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie automatycznego uśpienia systemu.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку на автоматический переход системы в ждущий режим, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>yes</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.inhibit-handle-power-key">
                <description>Allow applications to inhibit system handling of the power key</description>
                <description xml:lang="de">Anwendungen dürfen das Auswerten des Ein-/Ausschaltknopfs des Systems unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν τη διαχείριση του πλήκτρου ενεργοποίησης του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher la gestion du bouton d'alimentation  du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire al sistema la gestione del tasto di accensione</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie obsługi klawisza zasilania przez system</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку обработки нажатий на кнопку выключения</description>
                <message>Authentication is required to allow an application to inhibit system handling of the power key.</message>
                <message xml:lang="de">Legitmierung ist erforderlich, um Anwendungen das Unterbinden der Auswertung der Ein-/Ausschaltknopfs des Systems zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την διαχείριση του πλήκτρου ενεργοποίησης του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher la gestion du bouton d'alimentation du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazioni di inibire al sistema la gestione del tasto di accensione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie obsługi klawisza zasilania przez system.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку обработки нажатий на кнопку выключения, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.inhibit-handle-suspend-key org.freedesktop.login1.inhibit-handle-hibernate-key org.freedesktop.login1.inhibit-handle-lid-switch</annotate>
        </action>

        <action id="org.freedesktop.login1.inhibit-handle-suspend-key">
                <description>Allow applications to inhibit system handling of the suspend key</description>
                <description xml:lang="de">Anwendungen dürfen das Auswerten des Bereitschaftsknopfs des Systems unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν τη διαχείριση του πλήκτρου αναστολής του συστήματος.</description>
                <description xml:lang="fr">Permet aux applications d'empêcher la gestion du bouton de mise en veille du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire al sistema la gestione del tasto di sospensione</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie obsługi klawisza uśpienia przez system</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку обработки нажатий на кнопку перехода в ждущий режим</description>
                <message>Authentication is required to allow an application to inhibit system handling of the suspend key.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, um Anwendungen das Unterbinden der Auswertung des Bereitschaftsknopfes des Systems zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την διαχείριση του πλήκτρου αναστολής του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher la gestion du bouton de mise en veille du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire ad un'applicazione di inibire al sistema la gestione del tasto di sospensione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie obsługi klawisza uśpienia przez system.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку обработки нажатий на кнопку перехода в ждущий режим, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.inhibit-handle-hibernate-key org.freedesktop.login1.inhibit-handle-lid-switch</annotate>
        </action>

        <action id="org.freedesktop.login1.inhibit-handle-hibernate-key">
                <description>Allow applications to inhibit system handling of the hibernate key</description>
                <description xml:lang="de">Anwendungen dürfen das Auswerten des Knopfs für den Ruhezustand unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν τη διαχείριση του πλήκτρου αδρανοποίησης του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher la gestion du bouton d'hibernation du système</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire al sistema la gestione del tasto di ibernazione</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie obsługi klawisza hibernacji przez system</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку обработки нажатий на кнопку перехода в спящий режим</description>
                <message>Authentication is required to allow an application to inhibit system handling of the hibernate key.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, um Anwendungen das Unterbinden der Auswertung des Knopfs für den Ruhezustand zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την διαχείριση του πλήκτρου αδρανοποίησης του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher la gestion du bouton d'hibernation du système.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire ad un'applicazione di inibire al sistema la gestione del tasto di ibernazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie obsługi klawisza hibernacji przez system.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку обработки нажатий на кнопку перехода в спящий режим, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.inhibit-handle-lid-switch">
                <description>Allow applications to inhibit system handling of the lid switch</description>
                <description xml:lang="de">Anwendungen dürfen das Auswerten des Notebookdeckelschalters unterbinden</description>
                <description xml:lang="el">Να επιτρέπεται στις εφαρμογές να αποτρέπουν τη διαχείριση του διακόπτη καλύμματος του συστήματος</description>
                <description xml:lang="fr">Permet aux applications d'empêcher la gestion par le système du rabat de l'écran</description>
                <description xml:lang="it">Consenti alle applicazioni di inibire al sistema la gestione degli eventi relativi alla chiusura del portatile</description>
                <description xml:lang="pl">Zezwolenie programom na wstrzymanie obsługi przełącznika pokrywy przez system</description>
                <description xml:lang="ru">Разрешить приложениям устанавливать блокировку на обработку закрытия крышки ноутбука</description>
                <message>Authentication is required to allow an application to inhibit system handling of the lid switch.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, um Anwendungen das Unterbinden der Auswertung des Notebookdeckelschalters des Systems zu erlauben.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μια εφαρμογή να αποτρέψει την διαχείριση του διακόπτη καλύμματος του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour permettre à une application d'empêcher la gestion par le système du rabat de l'écran.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire alle applicazioni di inibire al sistema la gestione degli eventi relativi alla chiusura del portatile.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić programowi na wstrzymanie obsługi przełącznika pokrywy przez system.</message>
                <message xml:lang="ru">Чтобы разрешить приложениям устанавливать блокировку на обработку закрытия крышки ноутбука, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>no</allow_any>
                        <allow_inactive>yes</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.set-user-linger">
                <description>Allow non-logged-in users to run programs</description>
                <description xml:lang="de">Nicht angemeldete Benutzer dürfen Programme ausführen</description>
                <description xml:lang="el">Να επιτρέπεται σε μη συνδεμένους χρήστες να εκτελούν προγράμματα</description>
                <description xml:lang="fr">Permet aux utilisateurs non connectés d'exécuter des programmes</description>
                <description xml:lang="it">Consenti agli utenti non connessi di eseguire programmi</description>
                <description xml:lang="pl">Zezwolenie niezalogowanym użytkownikom na uruchamianie programów</description>
                <description xml:lang="ru">Разрешить пользователям оставлять программы в фоновом режиме после завершения сеанса</description>
                <message>Authentication is required to allow a non-logged-in user to run programs.</message>
                <message xml:lang="de">Legitimierung ist erforderlich, damit nicht angemeldete Benutzer Programme ausführen dürfen.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για να επιτρέπεται σε μη συνδεμένους χρήστες να εκτελούν προγράμματα.</message>
                <message xml:lang="fr">Authentification requise pour permettre aux utilisateurs non connectés d'exécuter des programmes.</message>
                <message xml:lang="it">Autenticazione richiesta per consentire agli utenti non connessi di eseguire programmi.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zezwolić niezalogowanemu użytkownikowi na uruchamianie programów.</message>
                <message xml:lang="ru">Чтобы разрешить пользователям оставлять программы в фоновом режиме после завершения сеанса, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.attach-device">
                <description>Allow attaching devices to seats</description>
                <description xml:lang="de">Das Anschließen von Geräten an Arbeitsstationen erlauben</description>
                <description xml:lang="el">Να επιτρέπεται η προσάρτηση συσκευών στους σταθμούς εργασίας</description>
                <description xml:lang="fr">Permet d'associer des périphériques à des postes (seats)</description>
                <description xml:lang="it">Consenti di collegare dispositivi alle postazioni</description>
                <description xml:lang="pl">Zezwolenie na podłączanie urządzeń do stanowisk</description>
                <description xml:lang="ru">Разрешить подключение устройств к рабочим местам</description>
                <message>Authentication is required for attaching a device to a seat.</message>
                <message xml:lang="de">Legitimierung ist zum Anschließen eines Geräts an eine Arbeitsstation notwendig.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για προσάρτηση μιας συσκευής σε έναν σταθμό εργασίας.</message>
                <message xml:lang="fr">Authentification requise pour associer un périphérique à un poste (seat).</message>
                <message xml:lang="it">Autenticazione richiesta per collegare un dispositivo alla postazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby podłączyć urządzenie do stanowiska.</message>
                <message xml:lang="ru">Чтобы разрешить подключение устройств к рабочим местам, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.flush-devices</annotate>
        </action>

        <action id="org.freedesktop.login1.flush-devices">
                <description>Flush device to seat attachments</description>
                <description xml:lang="de">Zurücksetzen der an eine Arbeitsstation angeschlossenen Geräte</description>
                <description xml:lang="el">Αφαίρεση συσκευής από προσαρτήσεις σταθμού εργασίας</description>
                <description xml:lang="fr">Révoquer les associations de périphériques aux postes (seats)</description>
                <description xml:lang="it">Scollega i dispositivi dalla postazione</description>
                <description xml:lang="pl">Usunięcie podłączenia urządzeń do stanowisk</description>
                <description xml:lang="ru">Сбросить привязки устройств к рабочим местам</description>
                <message>Authentication is required for resetting how devices are attached to seats.</message>
                <message xml:lang="de">Legitimierung ist zum Zurücksetzen notwendig, wie Geräte an eine Arbeitsstation angeschlossen werden.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για επαναφορά του τρόπου που οι συσκευές προσαρτώνται στους σταθμούς εργασίας.</message>
                <message xml:lang="fr">Authentification requise pour révoquer les associations de périphériques aux postes (seats).</message>
                <message xml:lang="it">Autenticazione richiesta per scollegare i dispositivi dalla postazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby ponownie ustawić sposób podłączenia urządzeń do stanowisk.</message>
                <message xml:lang="ru">Чтобы сбросить привязки устройств к рабочим местам, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.power-off">
                <description>Power off the system</description>
                <description xml:lang="de">Das System ausschalten</description>
                <description xml:lang="el">Σβήσιμο του συστήματος</description>
                <description xml:lang="fr">Éteindre le système</description>
                <description xml:lang="it">Spegnere il sistema</description>
                <description xml:lang="pl">Wyłączenie systemu</description>
                <description xml:lang="ru">Выключить систему</description>
                <message>Authentication is required for powering off the system.</message>
                <message xml:lang="de">Legitimierung ist zum Ausschalten des Systems notwendig.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για την σβήσιμο του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour éteindre le système.</message>
                <message xml:lang="it">Autenticazione richiesta per spegnere il sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby wyłączyć system.</message>
                <message xml:lang="ru">Чтобы выключить систему, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.power-off-multiple-sessions">
                <description>Power off the system while other users are logged in</description>
                <description xml:lang="de">Das System herunter fahren, während andere Benutzer angemeldet sind</description>
                <description xml:lang="el">Σβήσιμο του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι</description>
                <description xml:lang="fr">Éteindre le système alors que d'autres utilisateurs sont connectés</description>
                <description xml:lang="it">Spegnere il sistema mentre altri utenti sono connessi</description>
                <description xml:lang="pl">Wyłączenie systemu, kiedy są zalogowani inni użytkownicy</description>
                <description xml:lang="ru">Выключить систему, несмотря на то, что в ней работают другие пользователи</description>
                <message>Authentication is required for powering off the system while other users are logged in.</message>
                <message xml:lang="de">Legitimierung ist zum Herunterfahren des Systems notwendig, während andere Benutzer angemeldet sind.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για σβήσιμο του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι.</message>
                <message xml:lang="fr">Authentification requise pour éteindre le système alors que d'autres utilisateurs sont connectés.</message>
                <message xml:lang="it">Autenticazione richiesta per spegnere il sistema mentre altri utenti sono connessi.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby wyłączyć system, kiedy są zalogowani inni użytkownicy.</message>
                <message xml:lang="ru">Чтобы выключить систему, несмотря на то, что в ней работают другие пользователи, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.power-off</annotate>
        </action>

        <action id="org.freedesktop.login1.power-off-ignore-inhibit">
                <description>Power off the system while an application asked to inhibit it</description>
                <description xml:lang="de">Das System ausschalten, während eine Anwendung anfordert es zu unterbinden</description>
                <description xml:lang="el">Απενεργοποίηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί.</description>
                <description xml:lang="fr">Éteindre le système alors qu'une application a demandé de l'empêcher</description>
                <description xml:lang="it">Spegnere il sistema nonostante l'inibizione di una applicazione</description>
                <description xml:lang="pl">Wyłączenie systemu, kiedy program zażądał jego wstrzymania</description>
                <description xml:lang="ru">Выключить систему, несмотря на то, что приложение запросило блокировку выключения</description>
                <message>Authentication is required for powering off the system while an application asked to inhibit it.</message>
                <message xml:lang="de">Legitimierung ist zum Ausschalten des Systems notwendig, während eine Anwendung anfordert es zu unterbinden.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για απενεργοποίηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί.</message>
                <message xml:lang="fr">Authentification requise pour éteindre le système alors qu'une application a demandé de l'empêcher.</message>
                <message xml:lang="it">Autenticazione richiesta per spegnere il sistema nonostante l'inibizione di una applicazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby wyłączyć system, kiedy program zażądał jego wstrzymania.</message>
                <message xml:lang="ru">Чтобы выключить систему, несмотря на то, что приложение запросило блокировку выключения, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.power-off</annotate>
        </action>

        <action id="org.freedesktop.login1.reboot">
                <description>Reboot the system</description>
                <description xml:lang="de">Das System neu starten</description>
                <description xml:lang="el">Επανεκκίνηση του συστήματος</description>
                <description xml:lang="fr">Redémarrer le système</description>
                <description xml:lang="it">Riavviare il sistema</description>
                <description xml:lang="pl">Ponowne uruchomienie systemu</description>
                <description xml:lang="ru">Перезагрузить систему</description>
                <message>Authentication is required for rebooting the system.</message>
                <message xml:lang="de">Legitimierung ist zum Neustart des Systems notwendig.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για επανεκκίνηση του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour redémarrer le système.</message>
                <message xml:lang="it">Autenticazione richiesta per riavviare il sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby ponownie uruchomić system.</message>
                <message xml:lang="ru">Чтобы перезагрузить систему, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
        </action>

        <action id="org.freedesktop.login1.reboot-multiple-sessions">
                <description>Reboot the system while other users are logged in</description>
                <description xml:lang="de">Das Systems neu starten, während andere Benutzer angemeldet sind</description>
                <description xml:lang="el">Επανεκκίνηση του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι</description>
                <description xml:lang="fr">Redémarrer le système alors que d'autres utilisateurs sont connectés</description>
                <description xml:lang="it">Riavviare il sistema mentre altri utenti sono connessi</description>
                <description xml:lang="pl">Ponowne uruchomienie systemu, kiedy są zalogowani inni użytkownicy</description>
                <description xml:lang="ru">Перезагрузить систему, несмотря на то, что в ней работают другие пользователи</description>
                <message>Authentication is required for rebooting the system while other users are logged in.</message>
                <message xml:lang="de">Legitimierung ist zum Neustart des Systems notwendig, während andere Benutzer angemeldet sind.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για επανεκκίνηση του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι.</message>
                <message xml:lang="fr">Authentification requise pour redémarrer le système alors que d'autres utilisateurs sont connectés.</message>
                <message xml:lang="it">Autenticazione richiesta per riavviare il sistema mentre altri utenti sono connessi.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby ponownie uruchomić system, kiedy są zalogowani inni użytkownicy.</message>
                <message xml:lang="ru">Чтобы перезагрузить систему, несмотря на то, что в ней работают другие пользователи, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>yes</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.reboot</annotate>
        </action>

        <action id="org.freedesktop.login1.reboot-ignore-inhibit">
                <description>Reboot the system while an application asked to inhibit it</description>
                <description xml:lang="de">Das System neu starten, während eine Anwendung anfordert es zu unterbinden</description>
                <description xml:lang="el">Επανεκκίνηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί</description>
                <description xml:lang="fr">Redémarrer le système alors qu'une application a demandé de l'empêcher</description>
                <description xml:lang="it">Riavviare il sistema nonostante l'inibizione di una applicazione</description>
                <description xml:lang="pl">Ponowne uruchomienie systemu, kiedy program poprosił o jego wstrzymanie</description>
                <description xml:lang="ru">Перезагрузить систему, несмотря на то, что приложение запросило блокировку выключения</description>
                <message>Authentication is required for rebooting the system while an application asked to inhibit it.</message>
                <message xml:lang="de">Legitimierung ist zum Neustart des Systems notwendig, während eine Anwendung anforderte es zu unterbinden.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για επανεκκίνηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί.</message>
                <message xml:lang="fr">Authentification requise pour redémarrer le système alors qu'une application  a demandé de l'empêcher.</message>
                <message xml:lang="it">Autenticazione richiesta per riavviare il sistema nonostante l'inibizione di una applicazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby ponownie uruchomić system, kiedy program zażądał jego wstrzymania.</message>
                <message xml:lang="ru">Чтобы перезагрузить систему, несмотря на то, что приложение запросило блокировку выключения, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.reboot</annotate>
        </action>

        <action id="org.freedesktop.login1.suspend">
                <description>Suspend the system</description>
                <description xml:lang="de">Das System in Bereitschaft versetzen</description>
                <description xml:lang="el">Αναστολή του συστήματος</description>
                <description xml:lang="fr">Mettre le système en veille</description>
                <description xml:lang="it">Sospendere il sistema</description>
                <description xml:lang="pl">Uśpienie systemu</description>
                <description xml:lang="ru">Перевести систему в ждущий режим</description>
                <message>Authentication is required for suspending the system.</message>
                <message xml:lang="de">Legitimierung ist zum Versetzen des Systems in Bereitschaft notwendig.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για την αναστολή του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en veille.</message>
                <message xml:lang="it">Autenticazione richiesta per sospendere il sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby uśpić system.</message>
                <message xml:lang="ru">Чтобы перевести систему в ждущий режим, необходимо пройти аутентификацию.</message>
                <defaults>
#                        <allow_any>auth_admin_keep</allow_any>
#                        <allow_inactive>auth_admin_keep</allow_inactive>
#                        <allow_active>yes</allow_active>
						 <allow_any>no</allow_any>
                         <allow_inactive>yes</allow_inactive>
                         <allow_active>no</allow_active
                </defaults>
        </action>

        <action id="org.freedesktop.login1.suspend-multiple-sessions">
                <description>Suspend the system while other users are logged in</description>
                <description xml:lang="de">Das System in Bereitschaft versetzen, während andere Benutzer angemeldet sind.</description>
                <description xml:lang="el">Αναστολή του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι</description>
                <description xml:lang="fr">Mettre le système en veille alors que d'autres utilisateurs sont connectés</description>
                <description xml:lang="it">Sospendere il sistema mentre altri utenti sono connessi</description>
                <description xml:lang="pl">Uśpienie systemu, kiedy są zalogowani inni użytkownicy</description>
                <description xml:lang="ru">Перевести систему в ждущий режим, несмотря на то, что в ней работают другие пользователи</description>
                <message>Authentication is required for suspending the system while other users are logged in.</message>
                <message xml:lang="de">Legitimierung ist zum Versetzen des Systems in Bereitschaft notwendig, während andere Benutzer angemeldet sind.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για αναστολή του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en veille alors que d'autres utilisateurs sont connectés.</message>
                <message xml:lang="it">Autenticazione richiesta per sospendere il sistema mentre altri utenti sono connessi.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby uśpić system, kiedy są zalogowani inni użytkownicy.</message>
                <message xml:lang="ru">Чтобы перевести систему в ждущий режим, несмотря на то, что в ней работают другие пользователи, необходимо пройти аутентификацию.</message>
                <defaults>
#                        <allow_any>auth_admin_keep</allow_any>
#                        <allow_inactive>auth_admin_keep</allow_inactive>
#                        <allow_active>yes</allow_active>
                         <allow_any>no</allow_any>
                         <allow_inactive>yes</allow_inactive>
                         <allow_active>no</allow_active

                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.suspend</annotate>
        </action>

        <action id="org.freedesktop.login1.suspend-ignore-inhibit">
                <description>Suspend the system while an application asked to inhibit it</description>
                <description xml:lang="de">Das System in Bereitschaft versetzen, während eine Anwendung anfordert dies zu unterbinden</description>
                <description xml:lang="el">Αναστολή του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί</description>
                <description xml:lang="fr">Mettre le système en veille alors qu'une application a demandé de l'empêcher</description>
                <description xml:lang="it">Sospendere il sistema nonostante l'inibizione di una applicazione</description>
                <description xml:lang="pl">Uśpienie systemu, kiedy program poprosił o jego wstrzymanie</description>
                <description xml:lang="ru">Перевести систему в ждущий режим, несмотря на то, что приложение запросило блокировку</description>
                <message>Authentication is required for suspending the system while an application asked to inhibit it.</message>
                <message xml:lang="de">Legitimierung ist zum Versetzen des Systems in Bereitschaft notwendig, während eine Anwendung anfordert dies zu unterbinden.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για αναστολή του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en veille alors qu'une application a demandé de l'empêcher.</message>
                <message xml:lang="it">Autenticazione richiesta per sospendere il sistema nonostante l'inibizione di una applicazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby uśpić system, kiedy program zażądał jego wstrzymania.</message>
                <message xml:lang="ru">Чтобы перевести систему в ждущий режим, несмотря на то, что приложение запросило блокировку, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.suspend</annotate>
        </action>

        <action id="org.freedesktop.login1.hibernate">
                <description>Hibernate the system</description>
                <description xml:lang="de">Den Ruhezustand des Systems aktivieren</description>
                <description xml:lang="el">Αδρανοποίηση του συτήματος</description>
                <description xml:lang="fr">Mettre le système en hibernation</description>
                <description xml:lang="it">Ibernare il sistema</description>
                <description xml:lang="pl">Hibernacja systemu</description>
                <description xml:lang="ru">Перевести систему в спящий режим</description>
                <message>Authentication is required for hibernating the system.</message>
                <message xml:lang="de">Legitimierung ist zum Aktivieren des Ruhezustands des Systems notwendig.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για αδρανοποίηση του συστήματος.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en hibernation.</message>
                <message xml:lang="it">Autenticazione richiesta per ibernare il sistema.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zahibernować system.</message>
                <message xml:lang="ru">Чтобы перевести систему в спящий режим, необходимо пройти аутентификацию.</message>
                <defaults>
#                        <allow_any>auth_admin_keep</allow_any>
#                        <allow_inactive>auth_admin_keep</allow_inactive>
#                        <allow_active>yes</allow_active>
                         <allow_any>no</allow_any>
                         <allow_inactive>yes</allow_inactive>
                         <allow_active>no</allow_active

                </defaults>
        </action>

        <action id="org.freedesktop.login1.hibernate-multiple-sessions">
                <description>Hibernate the system while other users are logged in</description>
                <description xml:lang="de">Den Ruhezustand des Systems aktivieren, während andere Benutzer angemeldet sind</description>
                <description xml:lang="el">Αδρανοποίηση του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι</description>
                <description xml:lang="fr">Mettre le système en hibernation alors que d'autres utilisateurs sont connectés</description>
                <description xml:lang="it">Ibernare il sistema mentre altri utenti sono connessi</description>
                <description xml:lang="pl">Hibernacja systemu, kiedy są zalogowani inni użytkownicy</description>
                <description xml:lang="ru">Перевести систему в спящий режим, несмотря на то, что в ней работают другие пользователи</description>
                <message>Authentication is required for hibernating the system while other users are logged in.</message>
                <message xml:lang="de">Legitimierung ist zum Aktivieren des Ruhezustands des Systems notwendig, während andere Benutzer angemeldet sind.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για αδρανοποίηση του συστήματος ενώ άλλοι χρήστες είναι συνδεμένοι.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en hibernation alors que d'autres utilisateurs sont connectés.</message>
                <message xml:lang="it">Autenticazione richiesta per ibernare il sistema mentre altri utenti sono connessi.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zahibernować system, kiedy są zalogowani inni użytkownicy.</message>
                <message xml:lang="ru">Чтобы перевести систему в спящий режим, несмотря на то, что в ней работают другие пользователи, необходимо пройти аутентификацию.</message>
                <defaults>
#                        <allow_any>auth_admin_keep</allow_any>
#                        <allow_inactive>auth_admin_keep</allow_inactive>
#                        <allow_active>yes</allow_active>
                         <allow_any>no</allow_any>
                         <allow_inactive>yes</allow_inactive>
                         <allow_active>no</allow_active

                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.hibernate</annotate>
        </action>

        <action id="org.freedesktop.login1.hibernate-ignore-inhibit">
                <description>Hibernate the system while an application asked to inhibit it</description>
                <description xml:lang="de">Das System in den Ruhezustand versetzen, während eine Anwendung wünscht dies zu verhindern</description>
                <description xml:lang="el">Αδρανοποίηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί</description>
                <description xml:lang="fr">Mettre le système en hibernation alors qu'une application a demandé de l'empêcher</description>
                <description xml:lang="it">Ibernare il sistema nonostante l'inibizione di una applicazione</description>
                <description xml:lang="pl">Hibernacja systemu, kiedy program zażądał jej wstrzymania</description>
                <description xml:lang="ru">Перевести систему в спящий режим, несмотря на то, что приложение запросило блокировку</description>
                <message>Authentication is required for hibernating the system while an application asked to inhibit it.</message>
                <message xml:lang="de">Legitimierung ist zum Versetzen des System in den Ruhezustand notwendig, während eine Anwendung wünscht dies zu verhindern.</message>
                <message xml:lang="el">Απαιτείται πιστοποίηση για αδρανοποίηση του συστήματος ενώ μια εφαρμογή ζήτησε να αποτραπεί.</message>
                <message xml:lang="fr">Authentification requise pour mettre le système en hibernation alors qu'une application a demandé de l'empêcher.</message>
                <message xml:lang="it">Autenticazione richiesta per ibernare il sistema nonostante l'inibizione di una applicazione.</message>
                <message xml:lang="pl">Wymagane jest uwierzytelnienie, aby zahibernować system, kiedy program zażądał jej wstrzymania.</message>
                <message xml:lang="ru">Чтобы перевести систему в спящий режим, несмотря на то, что приложение запросило блокировку, необходимо пройти аутентификацию.</message>
                <defaults>
                        <allow_any>auth_admin_keep</allow_any>
                        <allow_inactive>auth_admin_keep</allow_inactive>
                        <allow_active>auth_admin_keep</allow_active>
                </defaults>
                <annotate key="org.freedesktop.policykit.imply">org.freedesktop.login1.hibernate</annotate>
        </action>

</policyconfig>
EOF
}

decompte_10s()
{
    if "$OPTION_REDEMARRER"
    then
        afficher "La machine va redémarrer dans 10 secondes." | tee -a $compte_rendu
        echo ""
        for i in 1 2 3 4 5 6 7 8 9 10
        do
            sleep 1
            echo -n "$i... " | tee -a $compte_rendu
        done
        printf "\n"
        reboot
        exit 0
    else
        afficher "pour que le système soit opérationnel, vous devez le redémarrer." | tee -a $compte_rendu
        exit 0
    fi
}

#=====
# Fonctions du programme
# fin
#=====

#####
# début du programme
# le compte-rendu : mise en place
message_debut

#=====
# Les options
#=====
# on récupère les options du script
recuperer_options "$@"

#=====
# selon les options choisies, on rajoute certains paquets
# → il s'agit du paquet samba
#=====
definir_paquets_a_installer

#=====
# Vérifications sur le client
#=====
afficher "vérifications sur le système client..." | tee -a $compte_rendu
echo -n " 8..." | tee -a $compte_rendu
verifier_droits_root
echo -n " 7..." | tee -a $compte_rendu
verifier_version_debian
echo -n " 6..." | tee -a $compte_rendu
verifier_gdm
echo -n " 5..." | tee -a $compte_rendu
verifier_nom_client
echo -n " 4..." | tee -a $compte_rendu
verifier_repertoire_montage
echo -n " 3..." | tee -a $compte_rendu
verifier_apt_get
echo -n " 2..." | tee -a $compte_rendu
verifier_disponibilite_paquets
echo -n " 1..." | tee -a $compte_rendu
verifier_ip_se3
echo " 0..." | tee -a $compte_rendu
afficher "gestionnaire de connexion installé : $gdm" | tee -a $compte_rendu
afficher "vérification accès se3" | tee -a $compte_rendu
#verifier_acces_ping_se3
verifier_acces_nmap_se3     # meilleure vérification pour l'instant
afficher "vérifications terminées" | tee -a $compte_rendu

#=====
# Montage du partage NOM_PARTAGE_NETLOGON
#=====
afficher "installation du paquet $PAQUETS_MONTAGE_CIFS" | tee -a $compte_rendu
installer_paquets_cifs
afficher "montage du partage « $NOM_PARTAGE_NETLOGON » du serveur" | tee -a $compte_rendu
montage_partage_netlogon

#=====
# Mise en place du répertoire local REP_SE3_LOCAL
#=====
afficher "mise en place du répertoire local $REP_SE3_LOCAL" | tee -a $compte_rendu
echo -n " 5..." | tee -a $compte_rendu
effacer_repertoire_rep_se3_local
creer_repertoire_rep_se3_local
echo -n " 4..." | tee -a $compte_rendu
copier_repertoire_rep_bin
echo -n " 3..." | tee -a $compte_rendu
copier_repertoire_rep_skel
echo -n " 2..." | tee -a $compte_rendu
creation_repertoire_unefois_local
echo -n " 1..." | tee -a $compte_rendu
creation_repertoire_rep_log_local
echo " 0..." | tee -a $compte_rendu
creation_repertoire_rep_tmp_local

#=====
# Configuration accès réseau et Ldap
# renommage éventuel du client-linux
#=====
recuperer_nom_client
afficher "installation de l'exécutable ldapsearch et vérification de la" \
         "connexion avec l'annuaire LDAP du serveur à travers une" \
         "recherche d'enregistrements en rapport avec le client (au niveau" \
         "du nom de machine ou de l'adresse MAC ou de l'adresse IP)" | tee -a $compte_rendu
afficher "installation du paquet $PAQUETS_CLIENT_LDAP" | tee -a $compte_rendu
installer_paquets_client_ldap
afficher "vérification de la connexion à l'annuaire ldap du se3" | tee -a $compte_rendu
verifier_connexion_ldap_se3
rechercher_ldap_client
afficher "résultat de la recherche LDAP :" | tee -a $compte_rendu
echo "-------------------------------------------------" | tee -a $compte_rendu
echo "$resultat" | tee -a $compte_rendu
echo "-------------------------------------------------" | tee -a $compte_rendu
afficher_info_carte_reseau_client
# On renomme le client (dépend de l'option --nom-client)
renommer_nom_client
# Peu importe que l'option --nom-client ait été spécifiée ou non,
# nous allons réécriture le fichier /etc/hosts.
afficher "réécriture complète du fichier /etc/hosts" | tee -a $compte_rendu
reecrire_fichier_hosts

#=====
# Mise en place (éventuelle) du mot de passe Grub
#=====
# dépend de l'option --mdp-grub
set_grub_pwd

#=====
# Mise en place (éventuelle) du mot de passe root
#=====
# dépend de l'option --mdp-root
mise_en_place_mot_de_passe_root

#=====
# Installation des paquets
#=====
afficher "installation des paquets nécessaires à l'intégration : $PAQUETS_AUTRES" | tee -a $compte_rendu
installer_paquets_integration
# Cas particulier : sur Debian, on a besoin du paquet sudo
# Cela sert dans le fichier logon plusieurs fois.
installer_paquet_sudo
afficher "installation des paquets terminée" | tee -a $compte_rendu

#=====
# Configuration de PAM
#=====
afficher "configuration de PAM afin que seul le gestionnaire de connexion" \
         "consulte l'annuaire LDAP du serveur pour l'authentification." \
         "Une authentification via ssh (par exemple) ne sera possible" \
         "qu'avec un compte local" | tee -a $compte_rendu
modifier_fichiers_pam
creation_fichier_pam

#=====
# Configuration du service nslcd
#=====
# la préconfiguration du paquet nslcd a permis de configurer directement le cryptage
# pendant son installation, il devient de ce fait inutile de réécrire le fichier nslcd.conf
# On relance le service nslcd
relancer_service_nslcd

#=====
# Configuration pour le serveur WINS (s'il s'avère qu'on a installé Samba)
#=====
# dépend de l'option --installer-samba
modifier_fichier_smb

#=====
# Configuration de ntpdate-debian
#=====
afficher "réécriture complète du fichier /etc/default/ntpdate" \
         "afin que l'heure du système soit mise à jour via le" \
         "serveur NTP indiqué dans le script d'intégration" | tee -a $compte_rendu
reecrire_fichier_ntpdate

#=====
# Configurations des gestionnaires graphiques d'ouverture de session
#=====
# configuration lié au script de logon
configurer_gestionnaire_connexion

#=====
# Configurations de paquets
#=====
preconfigurer_libpam_runtime
# pour ocs, cela est fait au niveau de la post-install
#preconfigurer_ocsinventory

#=====
# Gestion hibernation et mise en veille
#=====
# est-ce utile pour lightdm ? gestion via le skel ? -> oui, je pense que xscreensaver est encore l'économiseur d'écran de xfce
desactiver_hibernation_mise_en_veille

#=====
# Pour les bureaux xfce et lxde, désactivation du "suspendre, hibernation, changer d'utilisateur" avec polkit-1
#=====
if [ "$gdm"="lightdm" ]
then
	configurer_polkit
fi

#=====
# Fin de l'intégration
#=====
# suppression de la liste des paquets inutilisés
apt-get autoremove -y >> $SORTIE 2>&1
afficher "intégration terminée" | tee -a $compte_rendu
afficher "si ce n'est pas déjà fait, pensez à effectuer" \
         "une réservation d'adresse IP du client via" \
         "le serveur DHCP du SambaÉdu, afin d'inscrire" \
         "le nom de la machine cliente dans l'annuaire" | tee -a $compte_rendu
decompte_10s

# Fin du programme
#####
