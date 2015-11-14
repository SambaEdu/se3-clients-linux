#Un mot sur les imprimantes

Ne disposant personnellement d’aucune imprimante réseau, je n’ai jamais pu tester ce qui suit . Je suis donc loin de maîtriser l’aspect « gestion des imprimantes » sur les clients GNU/Linux. Ceci étant, il faut bien évoquer ce point très important.

**Note :** Si vous avez du code bash à me proposer pour automatiser l’installation des imprimantes sur les clients GNU/Linux via par exemple la fonction initialisation_perso, je suis preneur (francois.lafont@crdp.ac-versailles.fr).

Sur un client GNU/Linux, le répertoire `/mnt/netlogon/divers/` contient un sous-répertoire nommé `imprimantes/` qui vous permettra de stocker de manière centralisée des fichiers .ppd (pour « PostScript Printer Description ») qui sont des sortes de drivers permettant d’installer des imprimantes sur les clients GNU/Linux. Vous pouvez télécharger de tels fichiers (qui dépendent du modèle de l’imprimante) sur ce site par exemple :

[http://www.openprinting.org/printers](http://www.openprinting.org/printers)

Supposons que, dans le répertoire `/mnt/netlogon/divers/imprimantes/`, se trouve le fichier `.ppd` d’un modèle d’imprimante réseau donné, vous pouvez alors lancer son installation sur un client GNU/Linux via la commande suivante (en tant que `root`) :

```sh
lpadmin -p NOM-IMPRIMANTE -v socket://IP-IMPRIMANTE:9100 \<Touche ENTRÉE>
    -E -P /mnt/netlogon/divers/imprimantes/fichier.ppd
```

Cette commande doit être en principe exécutée une seule fois sur le client GNU/Linux. Si tout va bien, vous devriez ensuite (même après redémarrage du système) être en mesure d’imprimer tout ce que vous souhaitez à travers vos applications favorites (navigateur Web, traitement de texte, lecteur de PDF etc). Si plusieurs imprimantes sont installées sur un client, pour faire en sorte que l’imprimante NOM-IMPRIMANTE soit l’imprimante par défaut, il faut exécuter en tant que root :

```sh
lpadmin -d NOM-IMPRIMANTE
```

Et pour supprimer l’imprimante :

```sh
lpadmin -x NOM-IMPRIMANTE
```
