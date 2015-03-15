# Pour les impatients qui veulent tester rapidement

## Installation du paquet `se3-clients-linux` sur le serveur

Il faut que votre réseau local dispose d'une connexion
Internet. Pour commencer, il faut préparer votre serveur
Samba en y installant le paquet `se3-clients-linux`. Pour ce
faire :

1. Si votre serveur est sous Lenny, il faut ouvrir une
console en tant que `root` et lancer :
```sh
apt-get update
apt-get install se3-clients-linux
```
2. Si votre serveur est sous Squeeze, vous pouvez :
* ou bien faire l'installation comme sur un serveur Lenny
(en mode console donc);
* ou bien faire l'installation en passant par l'interface
d'administration Web du serveur via les menus
`Configuration générale` puis `Modules`. Dans le tableau des
modules, le paquet `se3-clients-linux` correspond à la ligne
avec l'intitulé `Support des clients linux`.

**Attention**, dans les versions précédentes du paquet, il fallait
éditer le fichier `/etc/apt/sources.list` mais désormais ce n'est
plus nécessaire. Le paquet est maintenant inclus dans le dépôt
officiel du projet SambaÉdu.


TODO...


