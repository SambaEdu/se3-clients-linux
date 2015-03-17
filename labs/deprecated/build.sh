#!/bin/bash


# 1) Sans option, ce script envoie le paquet en cours dans
# http://francois-lafont.ac-versailles.fr/debian-test et c'est tout.
#
# 2) Avec l'option --doc, ce script envoie la documentation dans
# http://francois-lafont.ac-versailles.fr/sedu-linux et c'est tout.
#
# 3) Avec l'option --prod, ce script envoie la documentation dans
# http://francois-lafont.ac-versailles.fr/sedu-linux et la version
# courante du paquet dans http://francois-lafont.ac-versailles.fr/debian.


# Pour info, le svn du Se3 est ici :
# https://svn.tice.ac-caen.fr/svn/SambaEdu3/trunk/

# Pour info, le svn de la documentation est ici :
# https://svn.ac-versailles.fr/svn/formation/trunk/Reseau/SE3/Documentation/se3-clients-linux/

# Pour déboguer.
#set -x
#set -e


HOTE='xxx'
UTILISATEUR='yyy'
MOTDEPASSE='zzz'

RACINE=$(cd $(dirname "$0"); pwd)
VERSION_PAQUET=$(grep '^Version' "se3-clients-linux/DEBIAN/control" | cut -d":" -f 2 | tr -d ' ')
NOM_PAQUET="se3-clients-linux"
REP_DOC="$RACINE/doc"

n=$(cd "$REP_DOC"; \ls doc_v*.pdf | wc -l)
if [ "$n" != "1" ]; then
    echo "Désolé mais le répertoire de documentation, doit contenir " \
         "exactement un et un seul fichier de la forme " \
         "doc_v*.pdf, ce qui n'est pas le cas en ce moment. " \
         "Fin du script".
    exit 1
fi
FICHIER_DOC_PDF=$(cd "$REP_DOC"; \ls doc_v*.pdf)
FICHIER_DOC="${FICHIER_DOC_PDF%.pdf}" # Nom du fichier sans l'extension.
REP_DOC_TEMP="$FICHIER_DOC"
FICHIER_PAQUET="se3-clients-linux_${VERSION_PAQUET}_all.deb"
URL_DOC="http://francois-lafont.ac-versailles.fr/sedu-linux"




#####################
#### Les options ####
#####################

if ! TEMP=$(getopt -o "" -l prod,doc -n "$nom_du_script" -- "$@"); then
    echo "Arrêt..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

PROD=false # Par défaut on passe par le dépôt de test.
DOC=false # Par défaut la doc n'est pas envoyée.

while true ; do

    case "$1" in

        --prod)
            echo "Êtes-vous sûr(e) de vouloir envoyer la version $VERSION_PAQUET" \
                 "du paquet dans le dépôt de production ?" \
                 "Répondre OUI si vous êtes sûr(e) ou n'importe quoi d'autre sinon."
            read reponse
            if [ "$reponse" != "OUI" ]; then
                # Si la réponse n'est pas OUI, on arrête.
                echo "Dans ce cas, on arrête tout."
                exit 0
            else
                echo "Ok, on continue."
            fi
            PROD=true
            shift 1
        ;;

        --doc)
            DOC=true
            shift 1
        ;;

        --)
            shift 1
            break
        ;;

        *)
            echo "Option inexistante dans l'appel."
            exit 1
        ;;

    esac

done




#######################
#### Mise en place ####
#######################

cd "$RACINE" || exit 1

# Nettoyage au niveau de la racine.
for f in se3-clients-linux_*_all.deb; do
    [ "$f" = "se3-clients-linux_*_all.deb" ] && continue
    rm "$f"
done




##################################
#### Envoi éventuel de la doc ####
##################################

if "$DOC" || "$PROD"; then

    echo "Envoi de la documentation."

    if "$PROD"; then
        # On teste l'existence de la documentation sous le même numéro
        # de version que le paquet car avec --prod on envoie le paquet
        # avec la doc et il faut que ce soit la même version.
        if [ "$FICHIER_DOC_PDF" != "doc_v$VERSION_PAQUET.pdf" ]; then
            echo "Désolé, mais le paquet et la documentation n'indiquent " \
                 "pas le même numéro de version. Fin du script."
            exit 1
        fi
    fi

    cd "$RACINE" || exit 1

    # On va zipper les sources de la doc.
    [ -e "$REP_DOC_TEMP" ] && rm -rf "$REP_DOC_TEMP"
    mkdir "$REP_DOC_TEMP"
    cp "$REP_DOC/"*".tex" "$REP_DOC_TEMP/"
    cp -r "$REP_DOC/images" "$REP_DOC_TEMP/"
    find "$REP_DOC_TEMP/" -name '.svn' -prune -exec rm -fr '{}' \; # on enlève les ".svn"
    zip -q -r "$FICHIER_DOC.zip" "$REP_DOC_TEMP/"


    ftp -n "$HOTE" <<END_SCRIPT
quote USER "$UTILISATEUR"
quote PASS "$MOTDEPASSE"
binary

put "$REP_DOC/$FICHIER_DOC.pdf" "/sedu-linux/$FICHIER_DOC.pdf"
put "$REP_DOC/$FICHIER_DOC.pdf" "/sedu-linux/doc.pdf"
put "$RACINE/$FICHIER_DOC.zip" "/sedu-linux/$FICHIER_DOC.zip"

quit
END_SCRIPT

    # On nettoie.
    rm "$FICHIER_DOC.zip" # suppression du .zip.
    rm -rf "$REP_DOC_TEMP" # suppression du dossier qui a servi à construire le zip.

fi


if "$DOC"; then
    # On s'arrête là si l'option --doc a été utilisée.
    exit 0
fi




################################
#### Construction du paquet ####
################################

echo "Construction du paquet."

cd "$RACINE" || exit 1

rep_temp=$(mktemp -d)

cp -r "$NOM_PAQUET" "$rep_temp/"

# Sans l'option -prune, find va trouver un répertoire .svn/ et voudra
# aller à l'intérieur mais comme -exec l'aura supprimé, cela provoquera
# une erreur.
find "$rep_temp/$NOM_PAQUET" -name '.svn' -prune -exec rm -fr '{}' \;

# Nettoyage de pool en local. Ici on enlève seulement la version actuelle du paquet.
f="depot/debian/dists/lenny/pool/$FICHIER_PAQUET"
test -e "$f" && rm "$f"
f="depot/debian/dists/squeeze/pool/$FICHIER_PAQUET"
test -e "$f" && rm "$f"

dpkg --build "$rep_temp/$NOM_PAQUET" . >/dev/null

# Déplacement du paquet dans le pool/ de Squeeze.
mv "$FICHIER_PAQUET" depot/debian/dists/squeeze/pool/

# Création des fichiers Packages.gz toujours en local pour Squeeze.
cd depot/debian/ || exit 1
{ dpkg-scanpackages dists/squeeze/pool 2>/dev/null; } | gzip -f9 > dists/squeeze/se3/binary-i386/Packages.gz
{ dpkg-scanpackages dists/squeeze/pool 2>/dev/null; } | gzip -f9 > dists/squeeze/se3/binary-amd64/Packages.gz


cd "$RACINE" || exit 1

# On crée le paquet pour Lenny aussi. Déjà, dans le fichier control, on
# enlève le numéro de version nécessaire pour se3-logonpy dans Squeeze.
sed -r -i -e 's/^Depends:.*$/Depends: se3-domain, se3-logonpy/g' "$rep_temp/$NOM_PAQUET/DEBIAN/control"

dpkg --build "$rep_temp/$NOM_PAQUET" . >/dev/null

# Déplacement du paquet dans le pool/ de Lenny.
mv "$FICHIER_PAQUET" depot/debian/dists/lenny/pool/

# Création des fichiers Packages.gz toujours en local pour Lenny.
cd depot/debian/ || exit 1
{ dpkg-scanpackages dists/lenny/pool 2>/dev/null; } | gzip -f9 > dists/lenny/se3/binary-i386/Packages.gz
{ dpkg-scanpackages dists/lenny/pool 2>/dev/null; } | gzip -f9 > dists/lenny/se3/binary-amd64/Packages.gz


# On nettoie ensuite.
rm -r "$rep_temp"



##############################################
#### Envoie du paquet sur le site distant ####
##############################################


cd "$RACINE" || exit 1

# Le choix du dépôt.
if "$PROD"; then
    DEPOT="debian"
    echo "Envoi du paquet sur le dépôt de production."
else
    DEPOT="debian-test"
    echo "Envoi du paquet sur le dépôt de test."
fi



# On envoie le tout sur le site distant via ftp.
ftp -n "$HOTE" <<EOF
quote USER "$UTILISATEUR"
quote PASS "$MOTDEPASSE"
binary

put "$RACINE/depot/debian/dists/squeeze/pool/$FICHIER_PAQUET" "/$DEPOT/dists/squeeze/pool/$FICHIER_PAQUET"
put "$RACINE/depot/debian/dists/lenny/pool/$FICHIER_PAQUET" "/$DEPOT/dists/lenny/pool/$FICHIER_PAQUET"

put "$RACINE/depot/debian/dists/lenny/se3/binary-amd64/Packages.gz" "/$DEPOT/dists/lenny/se3/binary-amd64/Packages.gz"
put "$RACINE/depot/debian/dists/lenny/se3/binary-i386/Packages.gz" "/$DEPOT/dists/lenny/se3/binary-i386/Packages.gz"
put "$RACINE/depot/debian/dists/squeeze/se3/binary-amd64/Packages.gz" "/$DEPOT/dists/squeeze/se3/binary-amd64/Packages.gz"
put "$RACINE/depot/debian/dists/squeeze/se3/binary-i386/Packages.gz" "/$DEPOT/dists/squeeze/se3/binary-i386/Packages.gz"

quit
EOF








