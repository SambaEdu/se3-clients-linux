# Intégration de stations de travail Debian ou Ubuntu dans un domaine SambaÉdu avec le paquet se3-clients-linux

## Résumé et avertissement

Le but de cette documentation est de décrire un mode opératoire
d'intégration de stations clientes Debian ou Ubuntu dans un domaine
SambaÉdu (avec un serveur en version Lenny ou Squeeze) par
l'intermédiaire du paquet `se3-clients-linux`. Les distributions
GNU/Linux qui ont été testées sont :

* Debian Squeeze (version 6)
* Debian Wheezy (version 7)
* Ubuntu Precise Pangolin (version 12.04)
* Xubuntu Precise Pangolin (version 12.04)

En pratique, l'objectif est de pouvoir ouvrir une session
sur un client Linux avec un compte du domaine et d'avoir
accès à l'essentiel des partages offerts par le serveur
SambaÉdu en fonction du compte.

Le fonctionnement de l'ensemble du paquet a été écrit de
manière à tenter de minimiser le trafic réseau entre un
client Linux et le serveur, notamment au moment de
l'ouverture de session où la gestion des profils est très
différente de celle mise en place pour les clients Windows
(voir la documentation pour plus de précisions).

**Avertissement :** l'intégration est censée fonctionner
avec les distributions ci-desssus **dans leur configuration
proposée par défaut**, notamment au niveau du « display
manager », c'est-à-dire le programme qui se lance au
démarrage et qui affiche une fenêtre de connexion permettant
d'ouvrir une session après authentification via un
identifiant et un mot de passe. Sous Squeeze par exemple, le
programme par défaut remplissant cette fonction s'appelle
Gdm3 et sous Precise il s'agit de Lightdm etc..
Tout au long de la documentation, il est supposé que c'est
bien le cas.

Si jamais vous tenez à changer de « display manager » sur
votre distribution, il est quasiment certain que vous devrez
modifier le script d'intégration de la distribution parce
que celui-ci ne fonctionnera pas en l'état. Si vous tenez à
changer uniquement l'environnement de bureau, il est
possible que le script d'intégration fonctionne en l'état
malgré tout mais nous ne pouvons en rien vous garantir le
résultat final. L'apparition de régressions ici ou là par
rapport à ce qui est annoncé dans ce document n'est pas à
exclure.

## Table des matières

* [Pour les impatients qui veulent tester rapidement](impatients.md)
* [Transformer votre client Debian Wheezy en serveur LTSP](ltsp.mpd)


