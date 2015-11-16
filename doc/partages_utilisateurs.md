#Les partages des utilisateurs

Cette liste de partages est une liste proposée **par défaut** par le paquet `se3-clients-linux`.

Vous verrez plus loin, à la section [gestion-montage]() [TODO], que vous pourrez définir vous-même
la liste des partages disponibles en fonction du compte qui se connecte ou en fonction de son appartenance à tel ou tel groupe.

**Cette liste est donc tout à fait modifiable**.

* [Liste par défaut des partages accessibles suivant le type de compte](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#liste-par-d%C3%A9faut-des-partages-accessibles-suivant-le-type-de-compte)
    * [Partages pour un compte `élève`](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#partages-pour-un-compte-%C3%A9l%C3%A8ve)
    * [Partages pour un compte `professeur`](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#partages-pour-un-compte-professeur)
    * [Partages pour le compte `admin`](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#partages-pour-le-compte-admin)
* [Le lien symbolique clients-linux](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#le-lien-symbolique-clients-linux)
* [Reconfiguration des droits du paquet `se3-clients-linux`](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#reconfiguration-des-droits-du-paquet-se3-clients-linux)
* [Cas des paquets dont la version est antérieure à 1.1](https://github.com/flaf/se3-clients-linux/blob/master/doc/partages_utilisateurs.md#cas-des-paquets-dont-la-version-est-ant%C3%A9rieure-%C3%A0-11)



## Liste par défaut des partages accessibles suivant le type de compte

Voici la liste, par défaut, des partages accessibles en fonction du type de compte lors d'une session.

### Partages pour un compte `élève`

Un compte `élève` aura accès :

* Au partage `//SERVEUR/homes/Docs/` via deux liens symboliques. Tous les deux possèdent le même nom : « `Documents de <login> sur le réseau` ». L'un se trouve dans le répertoire `/home/<login>/` et l'autre dans le répertoire `/home/<login>/Bureau/`.
* Au partage `//SERVEUR/Classes/` via deux liens symboliques. Tous les deux possèdent le même nom : « `Classes sur le réseau` ». L'un se trouve dans le répertoire `/home/<login>/` et l'autre dans le répertoire `/home/<login>/Bureau/`.

### Partages pour un compte `professeur`

Un compte `professeur` aura accès :

* Aux mêmes partages qu'un compte `élève`.
* Mais il aura accès en plus au partage `//SERVEUR/Docs/` via deux liens symboliques. Tous les deux possèdent le même nom : « `Public sur le réseau` ». L'un se trouve dans le répertoire `/home/<login>/` et l'autre dans le répertoire `/home/<login>/Bureau/`.

**Recommandation :** À la place de `Public sur le réseau`, il sera plus judicieux de mettre `Ressources sur le réseau`

**Remarque :** Ce partage`//SERVEUR/Docs/` pourra aussi être accessible aux élèves en supprimant ses conditions d'acès dans le fichier `logon_perso` mais il faudra alors paramétrer en conséquence les droits sur les fichiers et répertoires de ce partage.

### Partages pour le compte `admin`

Le compte `admin` aura accès :

* Aux mêmes partages qu'un compte `professeur`.
* Mais il aura accès en plus au partage `//SERVEUR/admhomes/` via deux liens symboliques. Tous les deux possèdent le même nom : « `admhomes` ». L'un se trouve dans le répertoire `/home/admin/` et l'autre dans le répertoire `/home/admin/Bureau/`.
* Et il aura accès en plus au partage `//SERVEUR/netlogon-linux/` via deux liens symboliques. Tous les deux possèdent le même nom : « `clients-linux` ». L'un se trouve dans le répertoire `/home/admin/` et l'autre dans le répertoire `/home/admin/Bureau/`.


## Le lien symbolique clients-linux

Rien de nouveau donc au niveau des partages disponibles, à part le partage `netlogon-linux` accessible via le compte `admin` du domaine à travers le lien symbolique `clients-linux` situé sur le bureau.

Ce lien symbolique vous permet d'avoir accès, **en lecture et en écriture**, au répertoire `/home/netlogon/clients-linux/` du serveur.

Techniquement, une modification de ce répertoire est aussi possible via le lien symbolique `admhomes` puisque celui-ci donne accès à tout le répertoire `/home/` du serveur.

**Avertissement : toujours reconfigurer les droits après modifications du contenu du répertoire clients-linux/**

Lors de certains paramétrages du paquet `se3-clients-linux`, vous serez parfois amené(e) à modifier le contenu du répertoire `/home/netlogon/clients-linux/` du serveur :

* soit via une console sur le serveur si vous êtes un(e) adepte de la ligne de commandes ;
* soit via le lien symbolique `clients-linux` situé sur le bureau du compte `admin`  
lorsque vous êtes connecté(e) sur un client GNU/Linux intégré au domaine.  

Dans un cas comme dans l'autre, une fois vos modifications terminées, il faudra **TOUJOURS reconfigurer les droits du paquet** sans quoi vous risquez ensuite de rencontrer des erreurs incompréhensibles.


## Reconfiguration des droits du paquet `se3-clients-linux`

Pour reconfigurer les droits du paquet `se3-clients-linux` il faudra :

* **si vous êtes connecté(e) en mode console sur le serveur se3**

Dans ce cas, exécutez en tant que `root` la commande suivante:

    `dpkg-reconfigure se3-clients-linux`

* **si vous êtes connecté(e) en tant qu'`admin` sur un client GNU/Linux**

Dans ce cas, double-cliquer sur le fichier `reconfigure.bash` accessible en passant par le lien symbolique `clients-linux` sur le bureau puis par le répertoire `bin/`(le mot de passe `root` du serveur se3 sera demandé).

**Remarque :** en réalité, ces deux procédures ne font pas que reconfigurer les droits sur les fichiers, elles permettent aussi d'injecter le contenu du fichier `logon_perso` dans le fichier `logon`. Ce point est abordé dans la section [personnalisation](https://github.com/flaf/se3-clients-linux/blob/master/doc/script_logon.md#personnaliser-le-script-de-logon).


## Cas des paquets dont la version est antérieure à 1.1

**Avertissement valable uniquement pour ceux qui ont déjà installé une version n du paquet avec n < 1.1**

**Attention**, **depuis la version 1.1 du paquet**, la gestion des partages accessibles se fait exclusivement dans le fichier `logon_perso`.

Cela a une conséquence importante si une version antérieure à la version $1.1$ du paquet est déjà installée sur votre serveur se3.

En effet, lors de la mise à jour du paquet vers une version $\geq 1.1$, plus aucun partage réseau ne devrait être monté à l'ouverture de session sur vos clients GNU/Linux et cela pour tout utilisateur du domaine.

C'est parfaitement normal car, lors de la mise à jour du paquet, votre fichier `logon_perso` a été conservé et c'est désormais dans ce fichier que les commandes de montage des partages sont effectuées. Or, a priori, votre fichier `logon_perso` ne contient pas encore ces commandes de montage.

Il est cependant très facile de retrouver le comportement par défaut (comme décrit ci-dessous) au niveau du montage des partages réseau à l'ouverture de session. Sur une console du serveur, en tant que `root`, il vous suffit de faire :

```sh
# On se place dans le répertoire `bin/`.
cd /home/netlogon/clients-linux/bin/

# On met dans un coin votre fichier `logon_perso` en le renommant
# `logon_perso.SAVE` (si jamais vous n'avez jamais touché à ce fichier
# alors vous pouvez même le supprimer avec la commande `rm logon_perso`).
mv logon_perso logon_perso.SAVE

# On reconfigure le paquet. L'absence du fichier `logon_perso` sera
# détectée et vous retrouverez ainsi la version par défaut de ce 
# fichier.
dpkg-reconfigure se3-clients-linux
```

Vous retrouverez un comportement par défaut dès que les clients GNU/Linux auront mis à jour leur script de logon local, c'est-à-dire au plus tard après un redémarrage des clients (en fait, après une simple fermeture de session, la mise à jour devrait se produire).

