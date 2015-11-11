#`SE3`

Cette variable stocke l’adresse IP du serveur récupérée automatiquement lors de l’installation du paquet `se3-clients-linux`.

#`NOM_DE_CODE`

Cette variable stocke ce qu’on appelle le « nom de code » de la distribution (`squeeze` dans le cas d’une Debian Squeeze, `precise` dans le cas d’une Ubuntu Precise Pangolin etc).

#`ARCHITECTURE`

Cette variable stocke l’architecture du système. Par exemple, si le système repose sur une architecture 64 bits, alors la variable stockera la chaîne de caractères `x86_64`.

#`BASE_DN`

Cette variable contient le suffixe de base LDAP de l’annuaire du serveur. Elle pourra vous être utile si vous souhaitez faire vous-même des requêtes LDAP particulières sur les clients à l’aide de la commande `ldapsearch`.

#`NOM_HOTE`

Cette variable stocke le nom du client GNU/Linux (celui qui se trouve dans le fichier de configuration `/etc/hostname`). Par exemple, si vous avez pris l’ha-
bitude de choisir des noms de machines de la forme `<salle>-xxx` (comme dans `S121-PC04` ou même comme dans `S18-DELL-02`), alors vous pourrez récupérer le nom de la salle où se trouve le client GNU/Linux par l’intermédiaire de la variable `NOM_HOTE` comme ceci :

```sh
SALLE=$(echo "$NOM_HOTE" | cut -d’-’ -f1)

if [ "$SALLE" = "S121" ]; then
    # Les trucs à faire si on est dans la salle 121.
fi

if [ "$SALLE" = "S18" ]; then
    # Les trucs à faire si on est dans la salle 18.
fi
# etc.
```

#appartient_au_parc

Cette fonction permet de savoir si une machine appartient à un parc donné. Pour ce faire, la fonction appartient_au_parc interroge l’annuaire du serveur via une requête LDAP. Voici un exemple d’utilisation :

```sh
if appartient_au_parc "S121" "$NOM_HOTE"; then
    # La machine appartient au parc S121
else
    # La machine n’appartient pas au parc S121
fi
```
