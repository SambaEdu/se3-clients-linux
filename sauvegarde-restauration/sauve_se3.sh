#!/bin/bash
#
#
#####################################################################################
##### Script permettant de sauvegarder les données importantes
##### pour une restauration du serveur SE3
##### version du 16/04/2014
##### modifiée le 18/06/2016
#
# Auteurs :      Louis-Maurice De Sousa louis.de.sousa@crdp.ac-versailles.fr
#                François-Xavier Vial Francois.Xavier.Vial@crdp.ac-versailles.fr
#                Rémy Barroso remy.barroso@crdp.ac-versailles.fr
#
# Modifié par :  Michel Suquet Michel-Emi.Suquet@ac-versailles.fr
# 
# Ce programme est un logiciel libre : vous pouvez le redistribuer ou
#    le modifier selon les termes de la GNU General Public Licence tels
#    que publiés par la Free Software Foundation : à votre choix, soit la
#    version 3 de la licence, soit une version ultérieure quelle qu'elle
#    soit.
#
# Ce programme est distribué dans l'espoir qu'il sera utile, mais SANS
#    AUCUNE GARANTIE ; sans même la garantie implicite de QUALITÉ
#    MARCHANDE ou D'ADÉQUATION À UNE UTILISATION PARTICULIÈRE. Pour
#    plus de détails, reportez-vous à la GNU General Public License.
#
# Vous devez avoir reçu une copie de la GNU General Public License
#    avec ce programme. Si ce n'est pas le cas, consultez
#    <http://www.gnu.org/licenses/>] 
#
# Fonctionnalités : ce script fonctionne dans 3 modes (verbeux, silencieux et test)
#                    -v → verbeux pour un lancement manuel
#                    -s → silencieux pour un lancement par crontab
#                    -t → permet de tester que tout est en place sans lancer la sauvegarde
# 
#####################################################################################

#####
# Définition des variables
# Elles sont modifiables pour adaptation à la situation locale
# Ces paramètres sont à faire correspondre avec ce qui a été choisi dans le 
# le script de restauration

#MAIL="votre_adresse_mel"       # Adresse mel d'envoi du compte-rendu
# cette variable MAIL est récupérée directement sur le se3
# voir la fonction recuperer_mail ci-dessous
COURRIEL="CR_sauvegarde.txt"            # compte-rendu de la sauvegarde
##### #####
# à la place de /sauvese3, on peut utiliser le répertoire /var/lib/backuppc (voir la doc)
# sur ce répertoire devra être monté le disque dur externe avant de lancer le script
MONTAGE="/sauvese3"                 # Chemin vers les répertoires de sauvegarde
SAV="SauveGarde"                        # Nom du répertoire de sauvegarde de /var/se3/save
SAVHOME="SauveGardeHome"                # Nom du répertoire de sauvegarde de /home et de /var/se3
##### #####
script_nom="$(basename ${0})"           # nom du script, sans le chemin
DESTINATION=$MONTAGE/$SAV               # Destination de sauvegarde de /var/se3/save
DESTINATIONHOME=$MONTAGE/$SAVHOME       # Destination de sauvegarde de /home et de /var/se3
DATESAUVEGARDE=$(date +%F+%0kh%0Mmin)   # Date et heure de la sauvegarde
DATEDEBUT=$(date +%s)                   # Début de la sauvegarde en secondes
DATEJOUR=$(date +%A)                    # Jour de la sauvegarde
TEXTE="texte.txt"                       # texte temporaire

#----- -----
# les fonctions
#----- -----

mode_texte()
{
    echo "Utilisation : $0 [-paramétre]"
    echo "paramètres possibles :"
    echo "   -h : afficher cet aide-mémoire"
    echo "   -s : script silencieux, utilisation avec crontab"
    echo "   -v : script verbeux, utilisation en manuel"
    echo "   -t : permet de tester que tout est en place, sans lancer la sauvegarde"
}

mode_script()
{
    # le canal 3 est dirigé vers le compte-rendu
    exec 3> $COURRIEL
    if [ ! "$#" = "0" ]
    then
        case $1 in
            -v)
                # mode verbeux
                # le canal 4 est dirigé vers l'affichage écran
                mode="verbeux"
                test="0"
                exec 4>&1
            ;;
            -t)
                # mode verbeux et de test
                # le canal 4 est dirigé vers l'affichage écran
                # on ne lance pas la sauvegarde : tester uniquement la mise en place
                mode="test"
                test="1"
                exec 4>&1
            ;;
            -s)
                # mode silencieux pour une utilisation via la crontab
                # le canal 4 est dirigé vers le canal 3
                mode="silence"
                test="0"
                exec 4>&3
            ;;
            -h)
                # on affiche l'aide
                mode_texte
                exit 0
            ;;
            *)
                echo "paramètre $1 incorrect"
                # on affiche l'aide
                mode_texte
                exit 2
            ;;
        esac
    else
        echo "la commande doit avoir un paramètre"
        mode_texte
        exit 3
    fi
}

tester_script_actif()
{
    # on teste si une sauvegarde est en cours
    # pour cela, on a besoin de la disponibilité de la commande pgrep
    # qui devrait être disponible sur les versions squeeze, wheezy et jessie de debian.
    
    n=$(pgrep -c "^${script_nom}$")
    if [ "$n" != "1" ]
    then
        echo "Une sauvegarde est déjà en cours."
        return 1
    else
        # pas de sauvegarde en cours
        return 0
    fi
}

gestion_texte()
{
    # on envoie le texte sur le canal 4,
    # le canal 4 est redirigé, selon les modes, vers :
    #    le canal 1 (sortie standard, affichage écran)
    # ou le canal 3 (courriel)
    cat "$TEXTE" >&4
    # en mode test, il faut aussi utiliser la messagerie
    [ "$mode" = "test" ] && cat "$TEXTE" >&3
}

tester_tree()
{
    # bien que non indispensable,
    # tree est nécessaire pour une partie du compte-rendu
    # on l'installe si besoin
    if ! which tree >/dev/null
    then
        echo "La commande tree n'est pas disponible" > $TEXTE
        echo "on installe tree" >> $TEXTE
        echo "" >> $TEXTE
        gestion_texte
        aptitude update >/dev/null
        aptitude -y install tree >/dev/null
        return 0
    else
        # tree est présent
        return 0
    fi
}

tester_pgrep()
{
    # tester si la commande pgrep est disponible
    # ce qui est normalement le cas car elle fait partie du paquet procps
    # cette commande est indispensable pour vérifier si une sauvegarde est encore en cours
    if ! which pgrep >/dev/null
    then
        echo "La commande pgrep n'est pas disponible :"
        echo "le paquet procps est-il installé ?"
        echo "Situation à rétablir avant de relancer le script"
        # il faut arrêter le script : situation anormale
        return 1
    else
        # pgrep est présent
        return 0
    fi
}

message_debut()
{
    # message de début de la sauvegarde
    echo "Début de la sauvegarde du $DATESAUVEGARDE" > $TEXTE
    echo "" >> $TEXTE
    gestion_texte
}

recuperer_mail()
{
    # on récupère l'adresse mel de l'administrateur
    # que se passe-t-il si l'administrateur ne l'a pas paramétré ? [TODO]
    MAIL=$(cat /etc/ssmtp/ssmtp.conf | grep ^root | cut -d "=" -f 2)
}

presence_repertoire_se3()
{
    # tester s'il exite le répertoire de sauvegarde à la racine du se3
    if [ -d $MONTAGE ]
    then
        # le répertoire $MONTAGE existe, on peut continuer
        echo "Le répertoire $MONTAGE est présent" > $TEXTE
        gestion_texte
        return 0
    else
        # le répertoire $MONTAGE n'existe pas, on envoie un courriel
        OBJET="Sauvegarde Se3 : pas de répertoire $MONTAGE"
        echo "La sauvegarde a échoué car il n'y a pas de répertoire $MONTAGE" > $TEXTE
        gestion_texte
        # et on ne lance pas la sauvegarde
        return 1
    fi
}

trouver_disque()
{
    # Le disque devrait être monté sur le répertoire de sauvegarde
    DISQUE=$(mount | grep $MONTAGE | gawk -F" " '/[^:]/ {print $1", de "$4" "$5}'| sed 's:/dev/::')
    if [ -z "$DISQUE" ]
    then
        # le disque n'étant pas monté correctement, on envoie un courriel
        OBJET="Sauvegarde Se3 : disque non monté dans $MONTAGE"
        echo "mais la sauvegarde a échoué car aucun disque n'est monté sur $MONTAGE" > $TEXTE
        gestion_texte
        # et on ne lance pas la sauvegarde
        return 1
    else
        # le disque étant monté, infos à garder et on peut continuer
        echo "Le disque est $DISQUE, monté sur $MONTAGE" > $TEXTE
        # doit-on tester le format ? Que se passe-t-il si on a un NAS ? [TODO]
        test_format=$(echo "$disque" | gawk -F" " '{print $4}')
        gestion_texte
        return 0
    fi
}

test_repertoire()
{
    # on teste la présence, dans $MONTAGE du répertoire $1
    # s'il est absent, on le crée
    REP=$(ls $MONTAGE | grep $1$)
    if [ -z "$REP" ]
    then
        echo "Création du répertoire $MONTAGE/$1" > $TEXTE
        gestion_texte
        mkdir $MONTAGE/$1
    else
        echo "Le répertoire $MONTAGE/$1 est présent" > $TEXTE
        gestion_texte
    fi
}

deux_repertoires()
{
    # Destination de sauvegarde de /var/se3/save → tester sa présence, sinon le créer
    test_repertoire $SAV
    
    # Destination de sauvegarde de /home et de /var/se3 → tester sa présence, sinon le créer
    test_repertoire $SAVHOME
}

gestion_temps()
{
    # calcul du temps passé
    DATEFIN=$(date +%s)                 # Fin de la sauvegarde en secondes
    TEMPS=$(($DATEFIN-$DATEDEBUT))      # durée de la sauvegarde, en secondes
    # conversion en heure-minute
    HEURES=$(( TEMPS/3600 ))
    MINUTES=$(( (TEMPS-HEURES*3600)/60 ))
    # gestion de l'accord pour les heures ; pour les minutes, elles seront souvent plusieurs ;-)
    case $HEURES in
        0)
            echo "Sauvegarde exécutée en $MINUTES minutes" >&3
        ;;
        1)
            echo "Sauvegarde exécutée en $HEURES heure et $MINUTES minutes" >&3
        ;;
        *)
            echo "Sauvegarde exécutée en $HEURES heures et $MINUTES minutes" >&3
        ;;
    esac
    echo "" >&3
    echo "Le fichier de log $COURRIEL est disponible dans /root si nécessaire" >&3
}

rediger_compte_rendu()
{
    # on complète le compte-rendu
    echo "" >&3
    echo "La sauvegarde du $DATESAUVEGARDE a réussi" >&3
    echo "--------------------" >&3
    echo "Rsync de /var/se3/save" >&3
    cat /root/logrsyncvarse3save.txt >&3
    echo "--------------------" >&3
    echo "Copie de /root/.my.cnf" >&3
    cat /root/logcpcnf.txt >&3
    echo "--------------------" >&3
    echo "Rsync de /etc/samba" >&3
    cat /root/logrsyncsamba.txt >&3
    echo "--------------------" >&3
    echo "Rsync de /home" >&3
    cat /root/logrsynchome.txt >&3
    echo "--------------------" >&3
    echo "Rsync de /var/se3" >&3
    cat /root/logrsyncvarse3.txt >&3
    echo "--------------------" >&3
    echo "Rsync de /var/lib/samba/printers" >&3
    cat /root/logrsyncprinters.txt >&3
    echo "--------------------" >&3
    tree -a $DESTINATION >&3
    echo "--------------------" >&3
    echo "Fin de la sauvegarde" >&3
    OBJET="Sauvegarde Se3 : compte-rendu"
}

envoi_courriel()
{
    # on envoie le compte-rendu
    echo "" >&4
    echo "Sauvegarde du $DATESAUVEGARDE : envoi du compte-rendu vers $MAIL" > $TEXTE
    cat "$TEXTE" >&4
    cat $COURRIEL | mail $MAIL -s "$OBJET" -a "Content-type: text/plain; charset=UTF-8"
}

sauver_droits()
{
    # droits pour /home (pour mémoire)
    # non nécessaire pour /home car le restore_droits suffit
    #echo "sauvegarde des droits sur les fichiers de /home dans $DESTINATIONHOME" >&4
    #getfacl -R --absolute-names /home > $DESTINATIONHOME/home.acl
    
    # droits pour /var/se3
    echo "sauvegarde des droits sur les fichiers de /var/se3 dans $DESTINATIONHOME" >&4
    getfacl -R --absolute-names /var/se3 > $DESTINATIONHOME/varse3.acl
}

sauver_imprimantes()
{
    # synchro des drivers imprimantes
    echo "synchronisation des pilotes d'imprimantes dans $DESTINATIONHOME" >&4
    rsync -a --del --ignore-errors --force /var/lib/samba/printers $DESTINATIONHOME/ > /root/logrsyncprinters.txt
    # archivage des fichiers de configuration des imprimantes
    IMPR=`ls /etc/cups/ | grep printers.`
    if [ -z "$IMPR" ]
    then
        echo "" >&4
        echo "Attention : il n'y a pas de fichier /etc/cups/printers.*" >&4
        echo "" >&4
    else
        echo "archivage de fichiers de configuration des imprimantes dans $DESTINATION" >&4
        cd /etc/cups > /dev/null
        tar -cz printers.* > $DESTINATION/printers.tgz
        cd - > /dev/null
    fi
}

synchro_archivage()
{
    echo "" >&4
    echo "Début de la synchronisation/archivage" >&4
    # synchro du répertoire /var/se3/save
    echo "synchronisation de /var/se3/save dans $DESTINATION" >&4
    rsync -rltgo --del --ignore-errors --force /var/se3/save/ $DESTINATION > /root/logrsyncvarse3save.txt
    # copie de /root/.my.cnf
    echo "copie du fichier /root/.my.cnf dans $DESTINATIONHOME" >&4
    cp /root/.my.cnf $DESTINATIONHOME > /root/logcpcnf.txt
    # synchro du répertoire /etc/samba
    echo "synchronisation de /etc/samba dans $DESTINATIONHOME" >&4
    rsync -a --del --ignore-errors --force /etc/samba $DESTINATIONHOME/ > /root/logrsyncsamba.txt
    # synchro du répertoire /home
    echo "synchronisation de /home dans $DESTINATIONHOME" >&4
    rsync -a --del --ignore-errors --force /home $DESTINATIONHOME/ > /root/logrsynchome.txt
    # synchro du répertoire /var/se3
    echo "synchronisation de /var/se3 dans $DESTINATIONHOME" >&4
    rsync -a --del --ignore-errors --force /var/se3 $DESTINATIONHOME/ > /root/logrsyncvarse3.txt
}

efface_log()
{
    rm $COURRIEL
    rm /root/logrsyncvarse3save.txt
    rm /root/logcpcnf.txt
    rm /root/logrsyncsamba.txt
    rm /root/logrsynchome.txt
    rm /root/logrsyncvarse3.txt
    rm /root/logrsyncprinters.txt
}

#----- -----
# fin des fonctions
#----- -----

#####
# Début du programme
#
recuperer_mail              # récupération de l'adresse mel de l'admnistrateur
tester_pgrep                # commande indispensable pour détecter une sauvegarde en cours
[ "$?" != "0" ] && exit 1
tester_script_actif         # déterminer présence d'une sauvegarde en cours
[ "$?" != "0" ] && exit 1
mode_script $1              # déterminer mode silencieux, verbeux ou test
message_debut
# on vérifie si tout est en place pour lancer la sauvegarde
tester_tree                                 # commande nécessaire pour le compte-rendu
presence_repertoire_se3                     # présence d'un répertoire de sauvegarde
[ "$?" != "0" ] && test="2"
[ "$test" != "2" ] && trouver_disque        # présence d'un disque externe monté dans le répertoire de sauvegarde
[ "$?" != "0" ] && test="2"
[ "$test" != "2" ] && deux_repertoires      # présence des sous-répertoires de sauvegarde (création si nécessaire)

case $test in
    0)
        # on lance la sauvegarde
        synchro_archivage            # Synchronisation des fichiers
        sauver_droits                # Sauvegarde des droits sur les fichiers
        sauver_imprimantes           # Les fichiers concernant les imprimantes
        rediger_compte_rendu         # Rédaction du compte-rendu de la sauvegarde
    ;;
    1)
        # on ne lance pas la sauvegarde (mode test)
        echo "" > $TEXTE
        echo "Test de la mise en place du système : pas de sauvegarde effectuée" >> $TEXTE
        echo "Tout semble en place." >> $TEXTE
        gestion_texte
        OBJET="Test pour la sauvegarde"
    ;;
    2)
        # on ne lance pas la sauvegarde : système non en place pour la sauvegarde
        echo "" > $TEXTE
        echo "Système non en place : on ne lance pas la sauvegarde du $DATESAUVEGARDE" >> $TEXTE
        echo "Tenez-compte des indications données ci-dessus" >> $TEXTE
        echo "puis effectuez un test avant de relancer la sauvegarde" >> $TEXTE
        gestion_texte
        OBJET="Sauvegarde non en place"
    ;;
    *)
        # autres cas à prévoir ?
        OBJET="Cas inattendu"
    ;;
esac
gestion_temps       # calculer la durée de la sauvegarde
envoi_courriel      # envoi du compte-rendu par la messagerie à l'aide de la variable $MAIL
#efface_log         # possibilité de garder ou de supprimer le fichier de log (on garde si ligne commentée)

#####
# Fin du programme
exit 0
