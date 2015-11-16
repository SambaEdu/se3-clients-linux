#Un mot sur les imprimantes

Ne disposant personnellement d'aucune imprimante réseau, je n'ai jamais pu tester ce qui suit . Je suis donc loin de maîtriser l'aspect « gestion des imprimantes » sur les clients GNU/Linux. Ceci étant, il faut bien évoquer ce point très important.

**Note :** Si vous avez du code bash à me proposer pour automatiser l'installation des imprimantes sur les clients GNU/Linux via par exemple la fonction initialisation_perso, je suis preneur (francois.lafont@crdp.ac-versailles.fr).

* [Le répertoire `/mnt/netlogon/divers/imprimantes/`](#le-répertoire-mntnetlogondiversimprimantes)
* [Installation d'une imprimante réseau](#installation-dune-imprimante-réseau)
* [Imprimante par défaut](#imprimante-par-défaut)
* [Suppression d'une imprimante](#suppression-dune-imprimante)
* [CUPS](#cups)
* [Références](#références)


## Le répertoire `/mnt/netlogon/divers/imprimantes/`

Sur un client GNU/Linux, le répertoire `/mnt/netlogon/divers/` contient un sous-répertoire nommé `imprimantes/`.

Ce répertoire vous permettra de stocker de manière centralisée des fichiers `.ppd` (pour « PostScript Printer Description ») qui sont des sortes de drivers permettant d'installer des imprimantes sur les clients GNU/Linux.

Vous pouvez télécharger de tels fichiers (qui dépendent du modèle de l'imprimante) sur ce site par exemple :  
[http://www.openprinting.org/printers](http://www.openprinting.org/printers)


Certains constructeurs proposent des fichiers `.ppd` sur leurs sites.


## Installation d'une imprimante réseau

Supposons que, dans le répertoire `/mnt/netlogon/divers/imprimantes/`, se trouve le fichier `.ppd` d'un modèle d'imprimante réseau donné.

Vous pouvez alors lancer l'installation de cette imprimante sur un client GNU/Linux via la commande suivante (en tant que `root`) :

```sh
lpadmin -p NOM-IMPRIMANTE -v socket://IP-IMPRIMANTE:9100 \<Touche ENTRÉE>
    -E -P /mnt/netlogon/divers/imprimantes/fichier.ppd
```

Cette commande doit être, en principe, exécutée une seule fois sur le client GNU/Linux.

Si tout va bien, vous devriez ensuite (même après redémarrage du système) être en mesure d'imprimer tout ce que vous souhaitez à travers vos applications favorites (navigateur Web, traitement de texte, lecteur de PDF etc).


## Imprimante par défaut

Si plusieurs imprimantes sont installées sur un client, pour faire en sorte que l'imprimante NOM-IMPRIMANTE soit l'imprimante par défaut, il faut exécuter, en console `root` sur le client :

```sh
lpadmin -d NOM-IMPRIMANTE
```

Par précaution, s'il y a une seule imprimante d'installée sur un client, déclarez-la par défaut.


## Suppression d'une imprimante

Et pour supprimer l'imprimante :
```sh
lpadmin -x NOM-IMPRIMANTE
```


## CUPS

Une autre méthode est d'utiliser `CUPS` via un butineur.

Dans le butineur `Iceweasel`, utilisez cette url :
```sh
http://localhost:631/
```

Pour plus de précisions, voir les références ci-dessous.


## Références

Quelques référence pouvant être utiles :

* [le wiki debian : le système d'impression](https://wiki.debian.org/fr/SystemPrinting)
* [le wiki debian : CUPS](https://wiki.debian.org/fr/CUPS)

