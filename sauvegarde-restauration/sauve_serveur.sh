#!/bin/bash
#
#
#####################################################################################
##### Script permettant de sauvegarder les données importantes
##### pour une restauration du serveur SE3
##### version du 16/04/2014
##### modifiée le 15/02/2016
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
COURRIEL="CR_sauvegarde.txt"    # compte-rendu de la sauvegarde
##### #####
# à la place de /sauveserveur, on peut utiliser le répertoire /var/lib/backuppc
# sur ce répertoire devra être monté le disque dur externe
MONTAGE="/sauveserveur"     # Chemin vers les répertoires de sauvegarde
SAV="SauveGarde"            # Nom du répertoire de sauvegarde de /var/se3/save
SAVHOME="SauveGardeHome"    # Nom du répertoire de sauvegarde de /home et de /var/se3
##### #####
DESTINATION=$MONTAGE/$SAV                # Destination de sauvegarde de /var/se3/save
DESTINATIONHOME=$MONTAGE/$SAVHOME        # Destination de sauvegarde de /home et de /var/se3
DATESAUVEGARDE=$(date +%F+%0kh%0Mmin)    # Date et heure de la sauvegarde
DATEDEBUT=$(date +%s)                    # Début de la sauvegarde en secondes
DATEJOUR=$(date +%A)                     # Jour de la sauvegarde
TEXTE="texte.txt"                        # texte temporaire

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
                test="0"
                exec 4>&1
            ;;
            -t)
                # mode verbeux et de test
                # le canal 4 est dirigé vers l'affichage écran
                # on ne lance pas la sauvegarde : tester uniquement la mise en place
                test="1"
                exec 4>&1
            ;;
            -s)
                # mode silencieux
                # le canal 4 est dirigé vers le canal 3
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

recuperer_mail()
{
    # on récupère l'adresse mel de l'administrateur
    MAIL=$(cat /etc/ssmtp/ssmtp.conf | grep ^root | cut -d "=" -f 2)
    echo "Début de la sauvegarde du $DATESAUVEGARDE" > $TEXTE
    cat "$TEXTE" >&4  && echo "" >&4
    [ "$test" = "1" ] && cat "$TEXTE" >&3 && echo "" >&3
}

presence_repertoire_se3()
{
    # tester s'il exite le répertoire de sauvegarde à la racine du se3
    if [ -d $MONTAGE ]
    then
        # le répertoire $MONTAGE existe, on peut continuer
        echo "Le répertoire $MONTAGE est présent" > $TEXTE
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
        return 0
    else
        # le répertoire $MONTAGE n'existe pas, on envoie un courriel
        OBJET="Sauvegarde Se3 : pas de répertoire $MONTAGE"
        echo "La sauvegarde a échoué car il n'y a pas de répertoire $MONTAGE" > $TEXTE
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
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
        echo "La sauvegarde a échoué car aucun disque n'est monté sur $MONTAGE" > $TEXTE
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
        # et on ne lance pas la sauvegarde
        return 1
    else
        # le disque étant monté, infos à garder et on peut continuer
        echo "Le disque est $DISQUE, monté sur $MONTAGE" > $TEXTE
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
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
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
        mkdir $MONTAGE/$1
    else
        echo "Le répertoire $MONTAGE/$1 est présent" > $TEXTE
        cat "$TEXTE" >&4
        [ "$test" = "1" ] && cat "$TEXTE" >&3
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
    DATEFIN=$(date +%s)                # Fin de la sauvegarde en secondes
    TEMPS=$(($DATEFIN-$DATEDEBUT))    # durée de la sauvegarde, en secondes
    HEURES=$(( TEMPS/3600 ))
    MINUTES=$(( (TEMPS-HEURES*3600)/60 ))
    echo "" >&3
    # gestion de l'accord pour les heures ; pour les minutes, elles seront souvent plusieurs ;-)
    case $HEURES in
        0)
            echo "Sauvegarde terminée en $MINUTES minutes" >&3
        ;;
        1)
            echo "Sauvegarde terminée en $HEURES heure et $MINUTES minutes" >&3
        ;;
        *)
            echo "Sauvegarde terminée en $HEURES heures et $MINUTES minutes" >&3
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
    OBJET="Sauvegarde Se3 : compte-rendu"
}

envoi_courriel()
{
    # on envoie le compte-rendu
    echo "Fin de la sauvegarde : envoi du compte-rendu vers $MAIL" > $TEXTE
    echo "" >&4 && cat "$TEXTE" >&4
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

mode_script $1                # déterminer mode silencieux, verbeux ou test
recuperer_mail                # récupération de l'adresse mel de l'admnistrateur

# on vérifie si tout est en place pour lancer la sauvegarde
presence_repertoire_se3                 # présence d'un répertoire de sauvegarde
[ "$?" != "0" ] && test="2"
[ "$test" != "2" ] && trouver_disque      # présence d'un disque externe monté dans le répertoire de sauvegarde
[ "$?" != "0" ] && test="2"
[ "$test" != "2" ] && deux_repertoires    # présence des sous-répertoires de sauvegarde (création si nécessaire)

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
        echo "Pas de sauvegarde effectuée : test de la mise en place du système" > $TEXTE
        echo "" >&4 && cat "$TEXTE" >&4
        echo "" >&3 && cat "$TEXTE" >&3
        OBJET="Test pour la sauvegarde"
    ;;
    *)
        # on ne lance pas la sauvegarde : système non en place pour la sauvegarde
        echo "Système non en place : on ne lance pas la sauvegarde" > $TEXTE
        echo "" >&4 && cat "$TEXTE" >&4
    ;;
esac
gestion_temps                # calculer la durée de la sauvegarde
envoi_courriel               # envoi du compte-rendu par la messagerie à l'aide de la variable $MAIL
#efface_log                  # possibilité de garder ou de supprimer le fichier de log (on garde si ligne commentée)

#####
# Fin du programme
exit 0
