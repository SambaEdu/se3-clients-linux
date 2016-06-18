#!/bin/bash
#
# 
#############################################################################
# Script permettant de restaurer les données importantes
# pour un redémarrage du serveur SE3
# ou pour une migration d'un ancien serveur à un nouveau serveur se3
#
# version du 16/04/2014
# modifiée le 18/06/2016
#
# Auteurs :     Louis-Maurice De Sousa louis.de.sousa@crdp.ac-versailles.fr
#               François-Xavier Vial Francois.Xavier.Vial@crdp.ac-versailles.fr
#               Rémy Barroso remy.barroso@crdp.ac-versailles.fr
#
# Modifié par : Michel Suquet Michel-Emi.Suquet@ac-versailles.fr
#               
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
# Fonctionnalités : à utiliser conjointement au script sauve_serveur.sh
# ce script fonctionne dans 2 modes (restauration et test)
#                    -r → lancement de la restauration
#                    -t → permet de tester que tout est en place sans lancer la restauration
#
#############################################################################


#####
# Définition des variables
#
# Elles sont modifiables pour adaptation à la situation locale
# Elles sont à faire correspondre avec celles du script de sauvegarde si elles ont été modifiées
#
#MAIL="votre_adresse_mel"   # Adresse mel d'envoi du compte-rendu
# cette variable MAIL est récupérée directement sur le se3
# voir la fonction recuperer_mail ci-dessous
##### #####
SAUV="SauveGarde"           # Nom du répertoire de sauvegarde de /var/se3/save
SAUVHOME="SauveGardeHome"   # Nom du répertoire de sauvegarde de /home et de /var/se3
##### #####
DATE_RESTAURATION=$(date +%F+%0kh%0M)                   # Date de la restauration
DATE_JOUR=$(date +%A)                                   # Jour de la restauration
COURRIEL="/root/restauration_${DATE_RESTAURATION}.txt"  # compte-rendu de la restauration
MONTAGE="/restaurese3"                                  # répertoire de montage pour le disque usb ou le NAS
SAUVEGARDE=$MONTAGE/$SAUV
SAUVEGARDEHOME=$MONTAGE/$SAUVHOME

#####
# quelques couleurs ;-)
#
rouge='\e[0;31m'
rose='\e[1;31m'
orange='\e[0;33m'
jaune='\e[1;33m'
vert='\e[0;32m'
bleu='\e[1;34m'
neutre='\e[0;m'

#----- -----
# les fonctions
#----- -----

mode_texte()
{
    echo "Utilisation : $0 [-paramétre]"
    echo "paramètres possibles :"
    echo "   -h : afficher cet aide-mémoire"
    echo "   -r : lancer la restauration"
    echo "   -t : permet de tester que tout est en place, sans lancer la restauration"
}

mode_script()
{
    # on teste s'il y a ou non un paramètre
    if [ ! "$#" = "0" ]
    then
        case $1 in
            -r)
                # mode de restauration
                mode_test="r"
            ;;
            -t)
                # mode de test
                # la restauration ne sera pas lancée
                mode_test="t"
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
    echo -e "${jaune}`date +%R` ${neutre}Récupération de l'adresse de messagerie de l'administrateur${neutre}" 2>&1 | tee -a $COURRIEL
    MAIL=$(cat /etc/ssmtp/ssmtp.conf | grep ^root | cut -d "=" -f 2)
    echo -e "l'adresse de messagerie est $MAIL" 2>&1 | tee -a $COURRIEL
}

mise_a_jour()
{
    # Mise à jour
    echo -e ""
    echo -e "${jaune}`date +%R` ${neutre}Mise à jour du se3${neutre}" 2>&1 | tee -a $COURRIEL
    sleep 1
    aptitude update
    /usr/share/se3/scripts/se3_update_system.sh
    echo -e ""
}

arret_des_serveurs()
{
    echo -e "${jaune}`date +%R` ${neutre}Arrêt du serveur ldap${neutre}" 2>&1 | tee -a $COURRIEL
    /etc/init.d/slapd stop
    echo -e "${jaune}`date +%R` ${neutre}Arrêt du serveur samba" 2>&1 | tee -a $COURRIEL
    /etc/init.d/samba stop
}

lancement_des_serveurs()
{
    echo -e "${jaune}`date +%R` ${neutre}Démarrage du serveur ldap" 2>&1 | tee -a $COURRIEL
    /etc/init.d/slapd start
    echo -e "${jaune}`date +%R` ${neutre}Démarrage du serveur samba" 2>&1 | tee -a $COURRIEL
    /etc/init.d/samba start
}

restaure_varse3home()
{
    SAVHOME=$(ls $MONTAGE | grep $SAUVHOME)
    if [ -n "$SAVHOME" ]    # faut-il faire un test plus subtil ?
    then
        echo -e ""
        echo -e "${neutre}Une sauvegarde de /home et /var/se3 est présente"
        echo -e "${orange}Cette restauration peut durer plusieurs heures"
        echo -e "${bleu}Voulez-vous restaurer ces données ? ${neutre}(oui ou OUI) ${vert}\c"
        read REPONSE
        case $REPONSE in
            oui|OUI)
                echo -e "${jaune}`date +%R` ${neutre}Restauration des homes" 2>&1 | tee -a $COURRIEL
                cd /
                cp -ar $SAUVEGARDEHOME/home/* /home
                echo -e "${jaune}`date +%R` ${neutre}Restauration de /var/se3" 2>&1 | tee -a $COURRIEL
                cd /
                cp -ar $SAUVEGARDEHOME/se3/* /var/se3
                echo -e "${jaune}`date +%R` ${neutre}Restauration des ACL de /var/se3" 2>&1 | tee -a $COURRIEL
                cd /var/se3
                setfacl --restore=$SAUVEGARDEHOME/varse3.acl
                cd /home
                echo -e "${jaune}`date +%R` ${neutre}Restauration des droits" 2>&1 | tee -a $COURRIEL
                /usr/share/se3/scripts/restore_droits.sh
                ;;
            *)
                echo -e "${jaune}`date +%R` ${neutre}Pas de restauration des homes et de /var/se3" 2>&1 | tee -a $COURRIEL
                ;;
        esac
    else
        echo -e ""
        echo -e "${jaune}`date +%R` ${orange}Pas de répertoire $SAVHOME${neutre}" 2>&1 | tee -a $COURRIEL
        echo -e "Pas de restauration possible des homes et de /var/se3"
        sleep 1
    fi
}

restaure_conf_imprimante()
{
    cd /
    [ ! -d /savetc ] && mkdir /savetc
    cd /savetc
    tar zxf $SAUVEGARDE/etc/etc.$JOUR.tar.gz
    test1=$(ls /savetc/etc/cups/ | grep printers.conf)
    test2=$(test -d /savetc/etc/samba/printers_se3/ && ls /savetc/etc/samba/printers_se3/)
    if [ "$test1" != "" ] || [ "$test2" != "" ]
    then
        echo -e "${jaune}`date +%R` ${neutre}Restauration de la conf des imprimantes" 2>&1 | tee -a $COURRIEL
        [ "$test1" != "" ] && cp -ar /savetc/etc/cups/printers.conf* /etc/cups/
        [ "$test2" != "" ] && [ ! -d /etc/samba/printers_se3/ ] && mkdir -p /etc/samba/printers_se3
        [ "$test2" != "" ] && cp -ar /savetc/etc/samba/printers_se3/* /etc/samba/printers_se3
    else
        echo -e "${jaune}`date +%R` ${orange}Pas de conf d'imprimante à restaurer${neutre}" 2>&1 | tee -a $COURRIEL
    fi
}

restaure_ldap()
{
    echo -e "${jaune}`date +%R` ${neutre}Nettoyage ldap" 2>&1 | tee -a $COURRIEL
    cp -r /var/lib/ldap /var/lib/ldapold
    rm -Rf /var/lib/ldap/*
    echo -e "${jaune}`date +%R` ${neutre}Gestion du DB_CONFIG" 2>&1 | tee -a $COURRIEL
    cp /var/lib/ldapold/DB_CONFIG /var/lib/ldap
    echo -e "${jaune}`date +%R` ${neutre}Restauration de la base ldap" 2>&1 | tee -a $COURRIEL
    slapadd  -l $SAUVEGARDE/ldap/ldap.$JOUR.ldif
    chown -R openldap:openldap /var/lib/ldap
}

restaure_mysql()
{
    echo -e "${jaune}`date +%R` ${neutre}Nettoyage mysql" 2>&1 | tee -a $COURRIEL
    cp -r /var/lib/mysql /var/lib/mysql.ori
    rm -Rf /var/lib/mysql/se3db/*
    echo -e "${jaune}`date +%R` ${neutre}Restauration se3db"  2>&1 | tee -a $COURRIEL
    mysql --database se3db < $SAUVEGARDE/mysql/se3db.$JOUR.sql
    echo -e "${jaune}`date +%R` ${neutre}Redémarrage du serveur mysql" 2>&1 | tee -a $COURRIEL
    /etc/init.d/mysql restart
}

restaure_samba()
{
    cd /
    echo -e "${jaune}`date +%R` ${neutre}Restauration de Samba" 2>&1 | tee -a $COURRIEL
    cp -ar $SAUVEGARDEHOME/samba/* /etc/samba
    echo -e "${jaune}`date +%R` ${neutre}Restauration du secrets.tdb" 2>&1 | tee -a $COURRIEL
    cp $SAUVEGARDE/secrets.tdb /var/lib/samba/secrets.tdb
}

restaure_imprimantes()
{
    if [ -f "$SAUVEGARDE/printers.tgz" ]
    then
        echo -e "${jaune}`date +%R` ${neutre}Restauration des imprimantes" 2>&1 | tee -a $COURRIEL
        cp $SAUVEGARDE/printers.tgz /etc/cups
        cd /etc/cups
        tar zxf printers.tgz
        #cd -
    else
        echo -e "${jaune}`date +%R` ${orange}Pas d'imprimante à restaurer${neutre}" 2>&1 | tee -a $COURRIEL
    fi
}

restaure_adminse3()
{
    echo -e "${jaune}`date +%R` ${neutre}Création du compte adminse3" 2>&1 | tee -a $COURRIEL
    /usr/share/se3/sbin/create_adminse3.sh
}

restaure_dhcp()
{
    echo -e "${jaune}`date +%R` ${neutre}Restauration configuration DHCP" 2>&1 | tee -a $COURRIEL
    /usr/share/se3/scripts/makedhcpdconf
}

abandonner()
{
    echo -e "${neutre}"
    echo -e "${orange}Restauration abandonnée," 2>&1 | tee -a $COURRIEL
    echo -e "vous pourrez la relancer en utilisant ${neutre}restaure_serveur.sh" 2>&1 | tee -a $COURRIEL
    echo -e "${neutre}"
    # cas d'un montage préalable au lancement du script
    if [ -z "${test_montage}" ]
    then
        [ -d "$MONTAGE" ] && mount | grep $MONTAGE >/dev/null && umount $MONTAGE
        # cas de l'existence du répertoire préalablement au lancement du script
        [ -z "${test_rep}" ] && [ -d "$MONTAGE" ] && rm -r $MONTAGE
    fi
}

montage_partition()
{
    # 1 argument : la partition à monter éventuellement
    # cas d'un montage préalable au lancement du script
    if [ -z "${test_montage}" ]
    then
        # il n'y a pas de montage préalable
        [ -z "${test_rep}" ] && mkdir $MONTAGE
        mount /dev/$1 $MONTAGE
    else
        # il y a un montage préalable au script
        true
    fi
}

demontage_partition()
{
    # on démonte la partition si elle n'était pas montée préalablement au script
    [ -z "${test_montage}" ] && umount $MONTAGE
    # on supprime le répertoire s'il n'existait pas préalablement au script
    [ -z "${test_rep}" ] && [ -d "$MONTAGE" ] && rm -r $MONTAGE
}

choix_archive_sauvegarde()
{
    # 1 argument : la partition à examiner
    # on la monte éventuellement
    montage_partition $1
    pasbon="true"
    Sauvegardedisponible=$(ls -ltr $SAUVEGARDE/etc/ | awk -- '{ print $9 " " $6 " " $7 }' | grep etc | sed "s/etc//g" | sed "s/tar.gz//g" | sed "s/\.//g")
    echo -e ""
    while $pasbon :
    do
        # affichage des sauvegardes disponibles
        echo -e "${neutre}Sur le disque $1, voici les sauvegardes disponibles :" 2>&1 | tee -a $COURRIEL
        echo "$Sauvegardedisponible" 2>&1 | tee -a $COURRIEL
        echo -e "${neutre}ne saisir que les trois premières lettres du jour : lun, mar,…"
        echo -e "ou bien q pour abandonner"
        [ "$mode_test" = "t" ] && echo -e "${bleu}Vous souhaitez tester la restauration de la sauvegarde de quel jour ?${vert} \c"
        [ "$mode_test" = "r" ] && echo -e "${bleu}Vous souhaitez restaurer la sauvegarde de quel jour ?${vert} \c"
        read JOUR
        # on vérifie que le choix est correct
        case "$JOUR" in
            dim|lun|mar|mer|jeu|ven|sam|Sun|Mon|Tue|Wed|Thu|Fri|Sat)
                if [ -f "$SAUVEGARDE/etc/etc.$JOUR.tar.gz" ]
                then
                    # il y a une archive
                    echo -e "${neutre}Archive choisie : ${vert}${SAUVEGARDE}/etc/etc.$JOUR.tar.gz${neutre}" 2>&1 | tee -a $COURRIEL
                    pasbon="false"
                else
                    echo -e "${orange}Il n'y a pas d'archive pour le jour choisi : $JOUR" 2>&1 | tee -a $COURRIEL
                    echo -e "${neutre}"
                fi
                ;;
            q)
                # abandon en cours possible
                abandonner
                return 1
                ;;
            *)
                echo -e "${rouge}Le choix saisi ${vert}$JOUR${rouge} est incorrect${neutre}"
                echo -e "Exemples de choix corrects : lun, mar, mer, jeu, ven, sam, dim ou Sun, Mon,…"
                echo -e "${orange}Si vous voulez abandonner la restauration, choisir q${neutre}"
                echo -e ""
                ;;
        esac
    done
}

trouver_archive_sauvegarde()
{
    # 1 argument : la partition à examiner
    # on la monte éventuellement
    montage_partition $1
    Sauvegardedisponible=$(ls -l $SAUVEGARDE/etc/ | awk -- '{ print $9 " " $6 " " $7 }'| grep etc | sed "s/etc//g" | sed "s/tar.gz//g" | sed "s/\.//g")
    if [ "$Sauvegardedisponible" = "  " ]
    then
        # Il n'y pas d'archive de sauvegarde
        # on la démonte éventuellement
        demontage_partition
        return 1
    else
        # il y a au moins une archive de sauvegarde
        # on la démonte éventuellement
        demontage_partition
        return 0
    fi
}

trouver_sauvegarde()
{
    # 1 argument : la partition à monter éventuellement
    # on la monte éventuellement
    montage_partition $1
    # Y a-t-il un répertoire SauveGarde, sans que ce soit SauveGardeHome ?
    SAV=$(ls $MONTAGE | grep $SAUV | grep -v $SAUVHOME)
    if [ -n "$SAV" ]
    then
        # il y a un répertoire SauveGarde
        # on la démonte éventuellement
        demontage_partition
        return 0
    else
        # il n'y a pas de répertoire SauveGarde
        # on la démonte éventuellement
        demontage_partition
        return 1
    fi
}

rechercher_montage()
{
    # tester s'il exite le répertoire de sauvegarde à la racine du se3
    if [ -d $MONTAGE ]
    then
        # le répertoire $MONTAGE existe
        test_rep="1"
        # on teste s'il y a un montage sur ce répertoire
        test_montage=$(mount | grep $MONTAGE)
        if [ -z "${test_montage}" ]
        then
            # pas de montage sur le répertoire $MONTAGE
            # on peut abandonner cette piste
            return 1
        else
            # il y a un montage sur ce répertoire
            # reste à savoir s'il contient une sauvegarde
            return 0
        fi
    else
        # le répertoire $MONTAGE n'existe pas, on peut abandonner cette piste
        test_rep=""
        # et regarder si un disque usb est branché
        test=""
        return 1
    fi
}

collecter_candidats()
{
    # on collecte les candidats : sauvegarde ayant au moins une archive quotidienne
    for part in $DISQUES
    do
        trouver_sauvegarde $part
        case $? in
            0)
                # le candidat contient un répertoire SauveGarde
                # reste à savoir s'il contient des archives
                trouver_archive_sauvegarde $part
                if [ "$?" = "0" ]
                then
                    # le candidat contient au moins une archive
                    candidat[${#candidat[*]}]="$part"
                fi
                ;;
            *)
                # ne convient pas pour la restauration
                ;;
        esac
    done
}

examiner_liste_candidats()
{
    # on examine la liste des candidats collectés
    # il ne doit y en avoir qu'un seul
    if [ -z "$candidat" ]
    then
        # aucun candidat : bizarre
        echo -e ""
        echo -e "${rouge}Aucun disque ne contient de répertoire ${orange}$SAUV${rouge} ou d'archive quotidienne${neutre}" 2>&1 | tee -a $COURRIEL
        abandonner
        # arrêt du script
        exit 1
    else
        # tester s'il y a plusieurs disques possédant une sauvegarde
        nombre=$(echo ${#candidat[*]})
        case $nombre in
            1)
                # un seul disque possède une sauvegarde : normal
                PART=$candidat
                ;;
            *)
                # plusieurs disques possèdent des sauvegardes : bizarre
                echo -e ""
                echo -e "${rouge}Plusieurs disques possèdent une sauvegarde :${neutre} \c" 2>&1 | tee -a $COURRIEL
                echo ${candidat[*]} 2>&1 | tee -a $COURRIEL
                echo -e "${neutre}Il ne faut qu'un seul disque possédant une sauvegarde${neutre}" 2>&1 | tee -a $COURRIEL
                abandonner
                # arrêt du script
                exit 1
                ;;
        esac
        # il n'y a qu'un seul candidat,
        # on choisit une archive
        choix_archive_sauvegarde $PART
        if [ "$?" = "0" ]
        then
            # une archive a été choisie,
            # on peut restaurer
            return 0
        else
            # on a abandonné la recherche
            return 1
        fi
        
    fi
}

trouver_disque()
{
    echo -e "${neutre}\c"
    # on repère si un montage est réalisé dans $MONTAGE (disque usb ou NAS)
    rechercher_montage
    if [ "$?" = "0" ]
    then
        # c'est le cas, on recherche la présence d'une sauvegarde
        DISQUES=$(mount | grep $MONTAGE | gawk -F" " '/[^:]/ {print $1}'| sed 's:/dev/::')
    else
        # ce n'est pas le cas, on recherche si un disque usb est branché pour lancer la même recherche
        DISQUES=$(fdisk -l | grep ^/dev | grep -v Extended | grep -v swap | gawk -F" " '/[^:]/ {print $1}'| sed 's:/dev/::')
    fi
    # on regarde si des disques contiennent des candidats
    collecter_candidats
    # parmi les candidats repérés, on regarde s'il y a des sauvegardes contenant des archives
    examiner_liste_candidats
    if [ "$?" = "0" ]
    then
        # une archive a été choisie,
        # on peut restaurer
        return 0
    else
        # on a abandonné la recherche
        return 1
    fi
}

gestion_temps()
{
    TEMPS=$((${DATE_FIN}-${DATE_DEBUT}))    # durée de la restauration, en secondes
    HEURES=$(( TEMPS/3600 ))
    MINUTES=$(( (TEMPS-HEURES*3600)/60 ))
    # gestion de l'accord pour les heures ; pour les minutes, elles seront souvent plusieurs ;-)
    case $HEURES in
        0)
            echo "Restauration effectuée en environ $MINUTES minutes" 2>&1 | tee -a $COURRIEL
        ;;
        1)
            echo "Restauration effectuée en environ $HEURES heure et $MINUTES minutes" 2>&1 | tee -a $COURRIEL
        ;;
        *)
            echo "Restauration effectuée en environ $HEURES heures et $MINUTES minutes" 2>&1 | tee -a $COURRIEL
        ;;
    esac
}

menage()
{
    [ -d /savetc ] && rm -rf /savetc
    echo -e "${jaune}`date +%R` ${neutre}Travail terminé : ${vert}se3 restauré${neutre}" 2>&1 | tee -a $COURRIEL
    gestion_temps
    #echo -e "${neutre}" 2>&1 | tee -a $COURRIEL
    echo -e "Le se3 doit redémarrer pour prendre en compte toutes les modifications" 2>&1 | tee -a $COURRIEL
    # cas d'un montage préalable au lancement du script
    if [ -z "${test_montage}" ]
    then
        [ -d "$MONTAGE" ] && mount | grep $MONTAGE >/dev/null && umount $MONTAGE
        # cas de l'existence du répertoire préalablement au lancement du script
        [ -z "${test_rep}" ] && [ -d "$MONTAGE" ] && rm -r $MONTAGE
    fi
}

courriel()
{
    # Envoi du compte-rendu
    echo "Un fichier récapitulatif est disponible si nécessaire : $COURRIEL" >> $COURRIEL
    echo "" >> $COURRIEL
    OBJET="Restauration Se3 : compte-rendu"
    cat $COURRIEL | mail $MAIL -s "$OBJET" -a "Content-type: text/plain; charset=UTF-8"
}

redemarrer()
{
    echo -e "${neutre}Un compte-rendu de la restauration a été envoyé par la messagerie" 2>&1 | tee -a $COURRIEL
    echo -e "${bleu}Souhaitez-vous redémarrer maintenant ? ${neutre}(oui ou OUI)${vert} \c"
    read REPONSE2
    case $REPONSE2 in
        oui|OUI)
            echo -e "${neutre}"
            [ "$mode_test" = "t" ] && echo "on est en mode test : on ne redémarre pas"
            [ "$mode_test" = "r" ] && reboot
            ;;
        *)
            echo -e ""
            echo -e "${neutre}À bientôt ! N'oubliez pas de redémarrer…${neutre}" 2>&1 | tee -a $COURRIEL
            echo -e ""
            ;;
    esac
}

restaurer_serveur()
{
    # une sauvegarde étant présente, on restaure le serveur
    echo -e "${jaune}`date +%R` ${neutre}Début du travail : ${vert}restauration du serveur${neutre}" 2>&1 | tee -a $COURRIEL
    DATE_DEBUT=$(date +%s)          # Début de la restauration en secondes
    arret_des_serveurs
    restaure_samba
    restaure_conf_imprimante
    restaure_ldap
    restaure_varse3home
    restaure_imprimantes
    lancement_des_serveurs
    restaure_mysql
    restaure_adminse3
    restaure_dhcp
    DATE_FIN=$(date +%s)            # Fin de la restauration en secondes
}

#----- -----
# fin des fonctions
#----- -----

#####
# Début du programme
#
mode_script "$@"
echo -e "" > $COURRIEL
echo -e "${bleu}Restauration du se3 ${neutre}${DATE_RESTAURATION}${neutre}\n" 2>&1 | tee -a $COURRIEL
[ "$mode_test" = "r" ] && echo -e "Ce script va restaurer la configuration de votre SE3 à partir d'une sauvegarde"
[ "$mode_test" = "t" ] && echo -e "Ce script va tester la restauration de votre SE3 à partir d'une sauvegarde"
echo -e ""
[ "$mode_test" = "r" ] && echo -e "${orange}Assurez-vous d'avoir installé tous les modules du se3 préalablement utilisés"
[ "$mode_test" = "r" ] && echo -e "Si vous installez ces modules *après* la restauration,"
[ "$mode_test" = "r" ] && echo -e "les fichiers de configuration seront remis à zéro"
[ "$mode_test" = "r" ] && echo -e "${neutre}"
echo -e "N'oubliez pas de brancher, sur un port usb,"
echo -e "→ le disque comportant une sauvegarde de votre se3"
echo -e "ou bien de monter, dans le répertoire $MONTAGE,"
echo -e "→ le NAS comportant une sauvegarde de votre se3"
echo -e "-------------------"
[ "$mode_test" = "r" ] && echo -e "${bleu}Souhaitez-vous procéder à la restauration maintenant ? ${neutre}(oui ou  OUI)${vert} \c"
[ "$mode_test" = "t" ] && echo -e "${bleu}Souhaitez-vous procéder au test de la restauration maintenant ? ${neutre}(oui ou  OUI)${vert} \c"
read REPONSE1
case $REPONSE1 in
    oui|OUI)
        trouver_disque                  # une sauvegarde est-elle disponible ?
        [ "$?" != "0" ] && exit 1
        # une sauvegarde est disponible,
        # on peut lancer la restauration si le paramètre est -r
        case $mode_test in
            r)
                # on lance la restauration
                mise_a_jour                 # mise à jour du se3 avant la restauration
                restaurer_serveur           # on lance la restauration
                menage                      # on revient dans l'état de départ du script
            ;;
            t)
                # on est en mode test : pas de restauration
                echo "On est en mode de test : on ne lance pas la restauration" | tee -a $COURRIEL
            ;;
            *)
                # cas non prévu
                echo "cas non prévu avec mode_test=$mode_test"
                exit 1
            ;;
        esac
        recuperer_mail      # on récupére l'adresse de messagerie pour l'envoi du compte-rendu
        courriel            # on envoie le compte-rendu de la restauration
        redemarrer          # demande de redémarrage du serveur
        ;;
    *)
        # si un montage existe, on ne doit pas y toucher lors de l'abandon
        rechercher_montage
        abandonner
        ;;
esac
exit 0
#
# Fin du programme
#####
