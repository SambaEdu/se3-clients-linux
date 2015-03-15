#!/bin/bash

rm -f /home/netlogon/clients-linux/bin/logon_param_fond_ecran
if [ -e "/etc/se3/fonds_ecran/actif.txt" -a "$(cat /etc/se3/fonds_ecran/actif.txt)" = "1" ]; then
    echo "function parametres_generation_fonds() {" > /home/netlogon/clients-linux/bin/logon_param_fond_ecran
    # Pour etre sur de ne pas avoir un fichier vide.
    echo "recup_parametres_generation_fonds=faite" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
    # On effectue des egrep pour virer les commentaires dont les accents peuvent poser probleme.
    # On ne cree pas le dossier /var/se3/Docs/media/fonds_ecran sur les clients et on ne modifier pas la variable dossier_base_fond initialisee ailleurs.
    egrep -v "(^#|^$|^mkdir|^dossier_base_fond=)" /etc/se3/fonds_ecran/parametres_generation_fonds.sh >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
    # On insere une ligne vide pour eviter des problemes en cas de cat avec un fichier sans retour a la ligne en fin de fichier
    echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
    echo "}" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
    echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran

    mkdir -p /home/netlogon/clients-linux/fond_ecran

    ls /etc/se3/fonds_ecran/fond_*|while read fich
    do
        groupe=$(echo "$fich"|sed -e "s|/etc/se3/fonds_ecran/fond_||"|sed -e "s|\.txt$||")

        nom_fonction=parametres_fond_ecran_$groupe
        echo "function $nom_fonction() {" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "generation_fonds_ecran=$(cat $fich)" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        egrep -v "(^#|^$)" /etc/se3/fonds_ecran/parametres_$groupe.sh >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "}" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran

        nom_fonction=annotation_fond_ecran_$groupe
        echo "function $nom_fonction() {" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        pref_fich_annotation=/etc/se3/fonds_ecran/annotations_$groupe
        if [ -e "$pref_fich_annotation.txt" -a "$(cat $pref_fich_annotation.txt)" = "actif" ]; then
            echo "annotation_fonds_ecran=y" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
            egrep -v "(^#|^$)" $pref_fich_annotation.sh >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        else
            echo "annotation_fonds_ecran=n" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        fi
        echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "}" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran
        echo "" >> /home/netlogon/clients-linux/bin/logon_param_fond_ecran

        if [ -e "/var/se3/Docs/media/fonds_ecran/$groupe.jpg" ]; then
            cp /var/se3/Docs/media/fonds_ecran/$groupe.jpg /home/netlogon/clients-linux/fond_ecran
        fi
    done
    chmod -R 755 /home/netlogon/clients-linux/fond_ecran
fi

