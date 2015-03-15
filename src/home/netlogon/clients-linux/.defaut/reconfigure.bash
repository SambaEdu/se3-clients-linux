#!/bin/bash

REPERTOIRE_INSTALLATION="/home/netlogon/clients-linux"
REPERTOIRE_BIN="$REPERTOIRE_INSTALLATION/bin"
SMB_CIFSFS="/etc/samba/smb_CIFSFS.conf"
LOGON="$REPERTOIRE_INSTALLATION/bin/logon"
REPERTOIRE_DEFAUT="$REPERTOIRE_INSTALLATION/.defaut"
LOGON_DEFAUT="$REPERTOIRE_DEFAUT/logon"
LOGON_PERSO="$REPERTOIRE_INSTALLATION/bin/logon_perso"
LOGON_PARAM_FOND_ECRAN="$REPERTOIRE_BIN/logon_param_fond_ecran"
GENERE_PARAM_FOND_ECRAN="$REPERTOIRE_BIN/genere_param_fonds_clients_linux.sh"

# Le programme awk injectera le contenu du fichier LOGON_PERSO
# qui devra exister en amont.
PROG_AWK_INSERTION='{ 
    if ($0 ~ /^### LOGON_PERSO ###/) {
        system("cat \"'"$LOGON_PERSO"'\"")
    }
    else if ($0 ~ /^### LOGON_PARAM_FOND_ECRAN ###/) {
        system("cat \"'"$LOGON_PARAM_FOND_ECRAN"'\"")
    } else { 
        print $0 
    }
}'

# Fonction qui configure correctement les droits sur les
# fichiers du répertoire d'installation.
function restaurer_droits ()
{
    # On met en place des droits cohérents sur les répertoires
    # et sur les fichiers.
    chown -R "admin:admins" "$REPERTOIRE_INSTALLATION"
    chmod -R "u=rwx,g=rx,o=rx,u-s,g-s,o-t" "$REPERTOIRE_INSTALLATION"
    # Pour les fichiers, on enlève le droit x pour tout le monde.
    find "$REPERTOIRE_INSTALLATION" -type f -exec chmod "a-x" "{}" \;
    
    # Le répertoire bin/ contient des exécutables.
    for f in "$REPERTOIRE_BIN/"*; do
        [ "$f" = "$REPERTOIRE_BIN/*" ] && continue
        chmod u+x "$f"
    done
    
    # Pour rendre le contenu du répertoire inaccessible sur les clients
    # sauf par admin et root.
    chmod 750 "$REPERTOIRE_INSTALLATION"
    
    # Le fichier SMB_CIFSFS.
    chown "root:root" "$SMB_CIFSFS"
    chmod 644 "$SMB_CIFSFS"
}


echo ""
if [ -e "$GENERE_PARAM_FOND_ECRAN" ]; then
    echo "Generation de logon_param_fond_ecran..."
    chmod +x "$GENERE_PARAM_FOND_ECRAN"
    $GENERE_PARAM_FOND_ECRAN
    if [ -e "$LOGON_PARAM_FOND_ECRAN" ]; then
        echo "Fichier $LOGON_PARAM_FOND_ECRAN genere."
    else
        echo "Aucun fichier $LOGON_PARAM_FOND_ECRAN n'a ete genere."
            sleep 10
    fi
fi


echo ""
echo "Injection du contenu de logon_perso dans le script de logon..."
if awk "$PROG_AWK_INSERTION" "$LOGON_DEFAUT" > "$LOGON"; then
    echo "Ok!"
    sleep 0.5
else
    echo "Erreur!"
    sleep 20
fi


echo ""
echo "Restauration des droits du répertoire $REPERTOIRE_INSTALLATION"
echo "sur le serveur..."

if restaurer_droits; then
    echo "Ok!"
    sleep 1
else
    echo "Erreur!"
    sleep 20
fi


