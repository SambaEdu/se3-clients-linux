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

##Quelques variables et fonctions prêtes à l’emploi

[Voici la liste des variables et des fonctions que vous pourrez utiliser dans le fichier `logon_perso`](variables_fonctions_logon.md) et qui seront susceptibles de vous aider à affiner le comportement du script de logon.

##Gestion du montage des partages réseau
Comme cela a déjà été expliqué, c’est vous qui allez gérer les montages de partages réseau en éditant le contenu de la fonction `ouverture_perso` qui se trouve dans le fichier `logon_perso`. Évidemment, si la gestion par défaut des montages vous convient telle quelle, alors vous n’avez pas besoin de toucher à ce fichier. Commençons par un exemple simple :

```sh
function ouverture_perso ()
{
    monter_partage "//$SE3/Classes" "Classes" "$REP_HOME/Bureau/Répertoire Classes"
}
```

Ici la fonction monter_partage possède trois arguments qui devront être délimités par des
doubles quotes (") :
1. Le premier représente le chemin UNC du partage à monter. Vous reconnaissez sans doute la
variable SE3 qui stocke l’adresse IP du serveur. Par exemple si l’adresse IP du serveur est
172.20.0.2, alors le premier argument sera automatiquement développé en :
//172.20.0.2/Classes.
Cela signifie que c’est le partage Classes du serveur 172.20.0.2 qui va être monté sur le clients
GNU/Linux. Attention, sous GNU/Linux un chemin UNC de partage s’écrit avec des slashs (/)
et non avec des antislashs (\) comme c’est le cas sous Windows.
2. Maintenant, il faut un répertoire local pour monter un partage. C’est le rôle du deuxième argu-
ment. Quoi qu’il arrive (vous n’avez pas le choix sur ce point), le partage sera monté dans un
sous-répertoire du répertoire /mnt/_$LOGIN/. Par exemple si c’est toto qui se connecte sur le
poste client, le montage sera fait dans un sous répertoire de /mnt/_toto/. Le deuxième argu-
ment spécifie le nom de ce sous-répertoire. Ici nous avons décidé assez logiquement de l’appeler
Classes. Par conséquent, en visitant le répertoire /mnt/_toto/Classes/ sur le poste client,
notre cher toto aura accès au contenu du partage Classes du serveur.
Attention, dans le choix du nom de ce sous-répertoire, vous êtes limité(e) aux caractères a-z,
A-Z, 0-9, le tiret (-) et le tiret bas (_). C’est tout. En particulier pas d’espace ni accent. Si
vous ne respectez pas cette consigne le partage ne sera tout simplement pas monté et une fenêtre
d’erreur s’affichera à l’ouverture de session.
31/45Vous serez sans doute amené(e) à monter plusieurs partages réseau pour un même utilisateur (via
plusieurs appels de la fonction monter_partage au sein de la fonction ouverture_perso). Donc
il y aura plusieurs sous-répertoires dans /mnt/_$LOGIN/. Charge à vous d’éviter les doublons dans
les noms des sous-répertoires, sans quoi certains partages ne seront pas montés.
3. À ce stade, notre cher toto pourra accéder au partage Classes du serveur en passant par
/mnt/_toto/Classes/. Mais cela n’est pas très pratique. L’idéal serait d’avoir accès à ce par-
tage directement via un dossier sur le bureau de toto. C’est exactement ce que fait le troisième
argument. Si toto ouvre une session, l’argument "$REP_HOME/Bureau/Répertoire Classes"
va se développer en "/home/toto/Bureau/Répertoire Classes" si bien qu’un raccourci (sous
GNU/Linux on appelle ça un lien symbolique) portant le nom Répertoire Classes sera créé
sur le bureau de toto. Donc en double-cliquant sur ce raccourci (vous pouvez voir à la page 35
via une capture d’écran que ce genre de raccourci ressemble à un simple dossier), sans même le
savoir, toto visitera le répertoire /mnt/_toto/Classes/ qui correspondra au contenu du partage
Classes du serveur. Vous n’êtes pas limité(e) dans le choix du nom de ce raccourci. Les espaces
et les accents sont parfaitement autorisés (évitez par contre le caractère double-quote). En re-
vanche, ce raccourci doit forcément être créé dans le home de l’utilisateur qui se connecte. Donc
ce troisième argument devra toujours commencer par "$REP_HOME/..." sans quoi le lien
ne sera tout simplement pas créé.
Tout n’a pas encore été dévoilé concernant cette fonction monter_partage. En fait, vous pouvez
créer autant de raccourcis que vous voulez. Il suffit pour cela d’ajouter un quatrième argument, puis
un cinquième , puis un sixième etc. Voici un exemple :
function ouverture_perso ()
{
monter_partage "//$SE3/Classes" "Classes" \<Touche ENTRÉE>
"$REP_HOME/Bureau/Lecteur réseau Classes" \<Touche ENTRÉE>
"$REP_HOME/Lecteur réseau Classes"
}
Remarque : normalement il faut mettre une fonction avec ses arguments sur une même ligne car un
saut de ligne signifie la fin d’une instruction aux yeux de l’interpréteur Bash. Mais ici la ligne serait
bien longue à écrire et dépasserait la largeur de la page de ce document. La combinaison antislash
(\) puis ENTRÉE permet simplement de passer à la ligne tout en signifiant à l’interpréteur Bash que
l’instruction entamée n’est pas terminée et qu’elle se prolonge sur la ligne suivante.
Le premier argument correspond toujours au chemin UNC du partage réseau et le deuxième argument
au nom du sous-répertoire dans /mnt/_$LOGIN/ associé à ce partage. Ensuite, nous avons cette fois-ci
un troisième et un quatrième argument qui correspondent aux raccourcis pointant vers le partage :
l’un est créé sur le bureau et l’autre est créé à la racine du home de l’utilisateur qui se connecte. Il est
possible de créer autant de raccourcis que l’on souhaite, il suffit d’empiler les arguments 3, 4, 5 etc.
les uns à la suite des autres.
La syntaxe de la fonction monter_partage est donc la suivante :
monter_partage "<partage>" "<répertoire>" ["<raccourci>"]...
où seuls les deux premiers arguments sont obligatoires :
• <partage> est le chemin UNC du partage à monter. Il est possible de se limiter à un sous-
répertoire du partage, par exemple comme dans //$SE3//administration/docs où l’on montera
uniquement le sous-répertoire docs/ du partage administration du serveur.
• <répertoire> est le nom du sous-répertoire de /mnt/_$LOGIN/ qui sera créé et sur lequel le
partage sera monté. Seuls les caractères -_a-zA-Z0-9 sont autorisés.
32/45• Les arguments <raccourci> sont optionnels. Ils représentent les chemins absolus des raccourcis
qui seront créés et qui pointeront vers le partage. Ils doivent toujours se situer dans le home de
l’utilisateur qui se connecte, donc ils doivent toujours commencer par "$REP_HOME/...". Si ces
arguments ne sont pas présents, alors le partage sera monté mais aucun raccourci ne sera créé.

Attention, le montage du partage réseau se fait avec les droits de l’utilisateur
qui est en train de se connecter. Si l’utilisateur n’a pas les droits suffisants pour
accéder à ce partage, ce dernier ne sera tout simplement pas monté.
Remarque : au final, si vous placez bien vos raccourcis, l’utilisateur n’aura que faire du répertoire
"/mnt/_$LOGIN/". Il utilisera uniquement les raccourcis qui se trouvent dans son home. Peu importe
pour lui de savoir qu’ils pointent en réalité vers un sous-répertoire de "/mnt/_$LOGIN/", il n’a pas à
s’en préoccuper.
Remarque : je vous conseille de toujours créer au moins un raccourci à la racine du home de l’utilisa-
teur qui se connecte. En effet, lorsqu’un utilisateur souhaite enregistrer un fichier via une application
quelconque, très souvent l’explorateur de fichiers s’ouvre au départ à la racine de son home. C’est donc
un endroit privilégié pour placer les raccourcis vers les partages réseau. Il me semble que doubler les
raccourcis à la fois à la racine du home et sur le bureau de l’utilisateur est une bonne chose. Mais bien
sûr, tout cela est une question de goût...
Étant donné que le montage d’un partage se fait avec les droits de l’utilisateur qui se connecte,
certains partages devront être montés uniquement dans certains cas. Prenons l’exemple du partage
netlogon-linux du serveur. Celui-ci n’est accessible qu’au compte admin du domaine. Pour pouvoir
monter ce partage seulement quand c’est le compte admin qui se connecte, il va falloir ajouter ce bout
de code dans la fonction ouverture_perso du fichier logon_perso :
function ouverture_perso ()
{
# Montage du partage "netlogon-linux" seulement dans le cas
# où c’est le compte "admin" qui se connecte.
if [ "$LOGIN" = "admin" ]; then
# Cette partie là ne sera exécutée qui si c’est admin qui se connecte.
monter_partage "//$SE3/netlogon-linux" "clients-linux" \<Touche ENTRÉE>
"$REP_HOME/clients-linux" \<Touche ENTRÉE>
"$REP_HOME/Bureau/clients-linux"
fi
}
Remarque : attention, en Bash, le crochet ouvrant au niveau du if doit absolument être précédé et
suivi d’un espace et le crochet fermant doit absolument être précédé d’un espace.
Autre cas très classique, celui d’un partage accessible uniquement à un groupe. Là aussi, une
structure avec un if s’impose :
function ouverture_perso ()
{
# On décide que le montage du partage "administration" sera seulement effectué si
# c’est un compte qui appartient au groupe "Profs" qui se connecte.
if est_dans_liste "$LISTE_GROUPES_LOGIN" "Profs"; then
monter_partage "//$SE3/administration" "administration" \<Touche ENTRÉE>
"$REP_HOME/administration sur le réseau" \<Touche ENTRÉE>
33/45"$REP_HOME/Bureau/administration sur le réseau"
fi
}
L’instruction « if est_dans_liste "$LISTE_GROUPES_LOGIN" "Profs"; then » doit s’interpréter
ainsi : « si dans la liste des groupes dont est membre le compte qui se connecte actuellement il y a le
groupe Profs, autrement dit si le compte qui se connecte actuellement appartient au groupe Profs,
alors... »

Attention, le test if ci-dessus est sensible à la casse si bien que le résultat ne sera
pas le même si vous mettez "Profs" ou "profs". Par conséquent, prenez bien la
peine de regarder le nom du groupe qui vous intéresse avant de l’insérer dans un
test if comme ci-dessus afin de bien respecter les minuscules et les majuscules.
Si vous voulez savoir le nom des partages disponibles pour un utilisateur donné, par exemple toto,
il vous suffit de lancer la commande suivante sur le serveur en tant que root :
smbclient --list localhost -U toto
# Il faudra alors saisir le mot de passe de toto.
Parmi la liste des partages, l’un d’eux est affiché sous le nom de home. Il correspond au home de toto
sur le serveur. Ce partage est un peu particulier car il pointera vers un répertoire différent en fonction
du compte qui tente d’y accéder. Par exemple, si titi veut accéder à ce partage, alors il sera rédirigé
vers le répertoire /home/titi/ du serveur. Chaque utilisateur a le droit de monter ce partage, mais
attention le chemin UNC est en fait //SERVEUR/homes (avec un « s » à la fin et d’ailleurs dans le
fichier de configuration Samba ce partage est bien défini par la section homes). A priori, on pourra
monter ce partage pour tous les comptes du domaine donc pas besoin de structure if pour ce partage :
function ouverture_perso ()
{
# Montage du sous-répertoire "Docs" du partage "homes" pour tout le monde.
monter_partage "//$SE3/homes/Docs" "Docs" \<Touche ENTRÉE>
"$REP_HOME/Documents de $LOGIN sur le réseau" \<Touche ENTRÉE>
"$REP_HOME/Bureau/Documents de $LOGIN sur le réseau"
}
Dans l’exemple ci-dessus, on ne monte pas le partage homes mais uniquement le sous-répertoire Docs
de ce partage. Comme d’habitude sous GNU/Linux, respectez bien la casse des noms de partages et
de répertoires.
Pour l’instant, de par la manière dont la fonction monter_partage est définie, on peut créer uni-
quement des liens qui pointent vers la racine du partage associé. Mais on peut vouloir par exemple
monter un partage et créer des liens uniquement vers des sous-répertoires de ce partage (et non vers
sa racine). C’est tout à fait possible avec la fonction creer_lien. Voici un exemple :
function ouverture_perso ()
{
# Montage du partage "homes" pour tout le monde, mais ici on ne créé pas de
# lien vers la racine de ce partage (appel de la fonction avec seulement deux
# arguments).
monter_partage "//$SE3/homes" "home"
# Ensuite on crée des liens mais ceux-ci ne pointent pas à la racine du partage.
34/45creer_lien "home/Docs" "$REP_HOME/Documents de $LOGIN sur le réseau"
creer_lien "home/Bureau" "$REP_HOME/Bureau de $LOGIN sous Windows"
}
Le premier argument de la fonction creer_lien est la cible du ou des liens à créer. Cette cible peut
s’écrire sous la forme d’un chemin absolu, c’est-a-dire un chemin qui commence par un antislash (ce
qui n’est pas le cas ci-dessus). Si le chemin ne commence pas par un antislash, alors la fonction part du
principe que c’est un chemin relatif qui part de /mnt/_$LOGIN/ 18 . Ensuite, le deuxième argument et
les suivants (autant qu’on veut) sont les chemins absolus du ou des liens qui seront créés. Ces chemins
doivent impérativement tous commencer par "$REP_HOME/...".
