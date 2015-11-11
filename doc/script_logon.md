#Le script de logon

##Phases d’exécution du script de logon

Le script de logon est un script bash qui est exécuté par les clients GNU/Linux lors de trois phases différentes. Pour plus de commodité dans les explications, nous allons donner un nom à chacune de ces trois phases une bonne fois pour toutes :

1. **L’initialisation :** cette phase se produit juste avant l’affichage de la fenêtre de connexion. Attention, cela correspond en particulier au démarrage du système, certes, mais pas seulement. L’initialisation se produit aussi juste après la fermeture de session d’un utilisateur, avant que la fenêtre de connexion n’apparaisse à nouveau (sauf si, bien sûr, l’utilisateur a choisi d’éteindre ou de redémarrer la machine).

    **Description rapide des tâches exécutées par le script lors de cette phase :** le script efface les homes (s’il en existe) de tous utilisateurs qui ne correspondent pas à des comptes locaux , vérifie si le partage CIFS `//SERVEUR/netlgon-linux` du serveur est bien monté sur le répertoire `/mnt/netlogon/` du client GNU/Linux et, si ce n’est pas le cas, le script exécute ce montage. Ensuite, le cas écheant, le script procède à la synchronisation du profil par défaut local sur le profil par défaut distant et lance les exécutions des `*.unefois` si l’initialisation correspond en fait à un redémarrage du système.

    **Note :** Un compte local est un compte figurant dans le fichier /etc/passwd du client GNU/Linux.

2. **L’ouverture :** cette phase se produit à l’ouverture de session d’un utilisateur juste après que celui-ci ait saisi ses identifiants.

    **Description rapide des tâches exécutées par le script lors de cette phase :** le script procède à la création du home de l’utilisateur qui se connecte (via une copie du profil par défaut local), exécute le montage de certains partages du serveur auxquels l’utilisateur peut prétendre (comme par exemple le partage correspondant aux données personnelles de l’utilisateur).

3. **La fermeture :** cette phase se produit à la fermeture de session d’un utilisateur.

    **Description rapide des tâches exécutées par le script lors de cette phase :** le script ne fait rien qui mérite d’être signalé dans cette documentation.

Comme vous pouvez le constater, le script de logon est un peu le « chef d’orchestre » de chacun des clients GNU/Linux.

##Emplacement du script de logon

À la base, le script de logon se trouve localement à l’adresse `/etc/se3/bin/logon` de chaque client GNU/Linux. Mais il existe une version centralisée de ce script sur le serveur à l’adresse :

1. `/home/netlogon/clients-linux/bin/logon` si on est sur le serveur
2. `/mnt/netlogon/bin/logon` si on est sur un client GNU/Linux

Nous avons donc, comme pour le profil par défaut, des versions locales du script de logon (sur chaque client GNU/Linux) et une unique version distante (sur le serveur). Et au niveau de la synchronisation, les choses fonctionnent de manière très similaire aux profils par défaut. **Lors de l’initialisation d’un client GNU/Linux :**

* Si le contenu du script de logon local est identique au contenu du script de logon distant, alors c’est le script de logon local qui est exécuté par le client GNU/Linux.
* Si en revanche les contenus diffèrent (ne serait-ce que d’un seul caractère), alors c’est le script de logon distant qui est exécuté. Mais dans la foulée, le script de logon local est écrasé puis remplacé par une copie de la version distante. Du coup, il est très probable qu’à la prochaine initialisation du client GNU/Linux ce soit à nouveau le script de logon local qui soit exécuté parce que identique à la version distante (on retombe dans le cas précédent).

À priori, cela signifie donc que, pour peu que vous sachiez parler (et écrire) le langage du script de logon (il s’agit du Bash), vous pouvez modifier uniquement le script de logon distant (celui du serveur donc) afin de l’adapter à vos besoins. Vos modifications seraient alors impactées sur tous les clients GNU/Linux dès la prochaine phase d’initialisation. Seulement, il ne faudra pas procéder ainsi et cela pour une raison simple : après la moindre mise à jour du paquet `se3-clients-linux` ou éventuellement après une réinstallation, toutes vos modifications sur le script de logon seront effacées. Pour pouvoir modifier le comportement du script de logon de manière pérenne, il faudra utiliser le fichier `logon_perso` qui se trouve dans le même répertoire que le script de logon.

##Personnaliser le script de logon


Le fichier `logon_perso` va vous permettre d’affiner le comportement du script de logon afin de l’adapter à vos besoins, et cela de manière pérenne dans le temps (les modifications persisteront notamment après une mise à jour du paquet `se3-clients-linux`). À la base, le fichier `logon_perso` est un fichier texte encodé en UTF-8 avec des fins de ligne de type Unix . Il contient du code bash et possède, par défaut, la structure suivante :

```sh
function initialisation_perso ()
{
    # ...
}

function ouverture_perso ()
{
    # ...
}

function fermeture_perso ()
{
    # ...
}
```
**Note :** Attention d’utiliser un éditeur de texte respectueux de l’encodage et des fins de ligne lorsque vous modifierez le fichier logon_perso.

Revenons au contenu du fichier `logon_perso` pour comprendre de quelle manière il permet de modifier le comportement du script `logon`. Dans le fichier `logon_perso`, on peut distinguer trois fonctions :

1. Tout le code que vous mettrez dans la fonction initialisation_perso sera exécuté lors de la phase d’initialisation des clients, en dernier, c’est-à-dire après que le script de logon ait effectué toutes les tâches liées à la phase d’initialisation qui sont décrites brièvement au point 1 de la section 9.1 [TODO].

2. Tout le code que vous mettrez dans la fonction `ouverture_perso` sera exécuté lors de la phase d’ouverture des clients uniquement lorsqu’un utilisateur du domaine se connecte. Le code est exécuté **juste après** la création du « home » de l’utilisateur qui se connecte. Typiquement, c’est dans cette fonction que vous allez gérer les montages de partages réseau en fonction du type de compte qui se connecte (son appartenance à tel ou tel groupe etc).

    Pour la gestion des montages de partages réseau à l’ouverture de session, tout se trouve à la section 9.5 page 31 [TODO].

3. Tout le code que vous mettrez dans la fonction `fermeture_perso` sera exécuté lors de la phase de fermeture des clients, en dernier, c’est-à-dire après que le script de logon ait effectué toutes les tâches liées à la phase de fermeture qui sont décrites brièvement au point 3 de la section 9.1 [TODO].

Vous pouvez bien sûr définir dans le fichier `logon_perso` des fonctions supplémentaires, mais, pour que celles-ci soient au bout du compte exécutées par le script de logon, il faudra les appeler dans le corps d’une des trois fonctions `initialisation_perso`, `ouverture_perso` ou `fermeture_perso`.

Il faut bien avoir en tête que le contenu de `logon_perso` est ni plus ni moins inséré dans le script `logon` et donc, après modification de `logon_perso`, il faut toujours mettre à jour le fichier `logon` via la commande « `dpkg-reconfigure se3-clients-linux` ».

