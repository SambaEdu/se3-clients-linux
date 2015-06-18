# Construire le package

Une fois que vous avez cloné ce dépôt, pour construire le
package, il suffit de lancer le script `./build/build.sh`
où que vous soyez. Typiquement, si vous vous trouvez à la
racine de ce dépôt git, il vous suffit de lancer la commande :

```sh
./build/build.sh
```

Le package `.deb` se trouvera dans le réportoire `./build/`
du dépôt. Vous pourrez le visualiser avec :

```sh
# Toujours en supposant que vous vous trouvez à la racine du dépôt.
ls -l ./build
```

Si vous relancez une nouvelle fois la construction du package,
« l'ancien » fichier `.deb` sera tout simplement écrasé et
remplacé par sa nouvelle version.


# Utiliser une branche git puis tester le package

Vous pouvez créer une branche git afin de tester des modifications.
Un package sera automatiquement créé afin que vous puissiez tester
vos changements, sans que cela impacte la branche `master` ie la
branche git par défaut.

Voici un exemple. On suppose que vous vous trouvez dans un répertoire
local de votre dépôt git. Déjà, vous mettez à jour votre dépôt :

```sh
git pull
```

Ensuite, vous allez créer localement une nouvelle branche. Pour
le nom de cette nouvelle branche, utilisez uniquement les caractères
`abc...z01...9` ainsi que le tiret (`-`), c'est tout.

```sh
git branch my-new-feature      # La branche `my-new-feature` est créée en local.
git checkout my-new-feature    # On bascule dans la nouvelle branche en local.
git push origin my-new-feature # On crée la nouvelle branche sur le dépôt distant aussi (ie sur Github)
```

À ce stade une nouvelle branche a été créée sur votre dépôt local
et sur le dépôt distant (ie GitHub). Attention, maintenant il faudra
bien commiter sur la nouvelle branche. N'hésitez pas à lancer les
commandes suivantes pour vous assurer que vous vous trouvez bien sur
la bonne branche :

```sh
git branch # la branche sur laquelle on se trouve actuellement est précédée d'un `*`

# Si jamais vous n'êtes pas sur la branche my-new-feature, vous pouvez
# y basculer via cette commande.
git checkout my-new-feature
```

Ensuite, une fois que vous êtes sur la bonne branche, vous pouvez
modifier les fichiers, commiter, pusher etc. comme vous le souhaitez.
Si jamais vous avez pushé un commit sur la nouvelle branche, le
package sera buildé sur le serveur `repository.flaf.fr`.

Par exemple, imaginons que vous venez de pusher un commit d'id
`656c693a71...` (pour voir l'id de son dernier commit, faire `git log`
et `q` pour sortir). **Si vous attendez 5 minutes**, la nouvelle version
de votre package sera disponible. Il suffit pour cela d'ajouter
la ligne suivante dans le `sources.list` de votre serveur Se3 de test :

```sh
# La syntaxe est toujours de la forme :
#
#   deb deb http://repository.flaf.fr se3-clients-linux <le-nom-de-ma-branche-git>
#
deb http://repository.flaf.fr se3-clients-linux my-new-feature
```

Il faudra aussi ajouter la clé publique gpg utilisée par le dépôt
pour signer les paquets :

```sh
# Ceci, tout comme la modification du sources.list, ne sera à faire qu'une
# seule fois sur votre serveur Se3 de test.
wget http://repository.flaf.fr/pub-key.gpg -O - | apt-key add -
```

Ensuite, pour installer ou mettre à jour le paquet dans sa
toute nouvelle version (celle correspondant à votre dernier commit) :

```sh
apt-get update && apt-get install se3-clients-linux
```

Penser à vérifier que le paquet installé sur votre serveur de test
correspond bien à la version de votre dernier commit :

```sh
dpkg-query -W se3-clients-linux
```

La version du paquet sera toujours de la forme `<epoch>~<commit-id>`
sachant que :

* `<epoch>` est simplement le nombre de secondes écoulées
entre le 1 janvier 1970 à minuit (UTC) et l'instant où le build
du package a été effectué;
* `<commit-id>` est l'id du commit sur lequel se trouvait le dépôt
git du serveur repository au moment du build du package (l'id est
tronqué aux 10 premiers caractères). Le serveur repository possède
son propre dépôt git de `se3-clients-linux` qu'il met à jour
juste avant chaque build afin de récupérer les commits qui ont été
pushés par les membres du projet.

Il est facile de convertir la date `epoch` en une date au format
classique :

```sh
# Par exemple l'epoch 1433160890 correspond au 1 juin 2015 à 14h14,
# ce qui veut donc dire qu'un package dont l'epoch dans le numéro
# version correspond à 1433160890 est un package qui a été buildé
# le 1 juin 2015 à 14h14 (et 50 secondes).
~$ date -d "@1433160890"
lundi 1 juin 2015, 14:14:50 (UTC+0200)
```

Soyez patient entre le moment où vous avez commité et pushé
une nouvelle modification sur votre branche et le moment où
le package dans sa nouvelle version sera disponible sur le
serveur repository. Il faut patienter au moins 5 minutes, tout
simplement parce qu'il y a une tâche cron qui tourne toutes les
5 minutes sur le serveur repository. Donc, si vous avez commité
puis pushé une modification sur votre branche à 14h46, il faudra
attendre 14h50 (et quelques secondes) avant que votre package
soit disponible dans sa dernière version. Vous pourrez voir la
version du package disponible en visitant la page (`F5` pour
la rafraîchir) :

```sh
branch='my-new-feature' # Mettre ici le nom de votre nouvelle branche.
http://repository.flaf.fr/dists/se3-clients-linux/${branch}/binary-amd64/Packages
```

Après vos tests, si vous êtes satisfait, alors vous pouvez merger
sur la branche `master` comme ceci :

```sh
# On bascule dans la branche master.
git checkout master

# On merge, ie on fusionne nos changements sur la branche master.
git merge my-new-feature

# Pour voir s'il y a des fichiers « unmerged », ie des conflits
# que git ne peut pas résoudre lui-même automatiquement.
git status

# Si le merge n'a rencontré aucun conflit, on peut alors pusher.
# Sinon, voir les quelques commentaires ci-dessous.
git push
```

Si on a de la chance, un merge peut se passer sans problème.
Mais si par exemple il y a eu des modifications sur la branche
`master` (pendant que nous, on avançait sur la branche `my-new-feature`)
et si certaines de ces modifications rentrent en conflit avec
nos modifications alors il y a des étapes supplémentaires pour
aider git à achever le merge (c'est une situation assez courante qui
n'a rien d'anormale lors d'un merge). Si
jamais il y a des conflits non résolus, on peut le voir avec la
commande `git status` : si certains fichiers sont marqués `unmerged`,
cela veut dire que des conflits demeurent au niveau de ces fichiers
et qu'il faudra les éditer à la main. Je ne détaille cela (désolé),
voir sur le Web qui regorge de tutoriels sur le merge avec git.


Une fois que le merge c'est bien passé, ou bien si vous décidez
d'abandonner votre branche (parce que votre idée de départ était
une mauvaise idée etc.), il faut détruire la branche en local
et sur le site distant (GitHub) :

```sh
# On détruit la branche en local, attention on perd toute la branche.
git branch -D my-new-feature

# On détruit la branche sur Github. Le « : » est important.
git push origin :my-new-feature
```




# Voir les pushs des autres avec Git et Gihub

Avec git, il faut absolument utiliser une paire de clés ssh
pour pouvoir pusher les commits de son dépôt local (quand
bien même il existerait un autre moyen, c'est définitivement
la paire de clés ssh qui doit être privilégiée). On peut
commiter puis pusher sans demande de mot de passe. Mais il
faut faire attention de bien paramétrer les éléments
suivants sur toute machine où l'on utilise le dépôt git :

```sh
# Ces commandes ne font rien d'autres qu'éditer votre
# fichier de configuration de votre home `~/.gitconfig`.
# Attention en revanche ce paramétrage n'est valable
# que pour le compte Unix qu'on utilise pour lancer
# les commandes ci-dessous.
git config --global user.name <votre-login-sur-github>
git config --global user.email <votre-adresse-mail-de-contact-sur-github>
```

En effet, Github se base sur la configuration du login et
aussi du mail pour mettre un nom sur un utilisateur qui
pushe. On peut faire sans le paramétrage ci-dessus (si vous
avez votre paire de clé ssh, vous pourrez toujours commiter
et pusher) mais Github ne sera pas capable d'identifier
celui qui a pushé et il mettra le nom du compte unix que
vous utilisez à la place (si vous avez pushé un commit avec
le compte root, Github estimera que le commit provient de
l'utilisateur `root`). Du coup, votre commit ne vous sera
pas comptabilisé dans la page des contributeurs qui se
trouve [ici](https://github.com/flaf/se3-clients-linux/graphs/contributors)
ce qui serait tellement dommage... ;)

Si vous voulez suivre un peu les commits des autres, une
fois dans votre dépôt local, lancez ces commandes :

```sh
# On met à jour le dépôt local :
git pull

# Pour voir les commits des autres (et les siens au passage) :
git log # flèches pour naviguer de haut en bas et `q` pour quitter.
```

Avec la dernière commande ci-dessus, on voit les commits des
autres (et les siens aussi d'ailleurs) mais on ne voit pas
les modifications. On voit juste l'auteur et l'intitulé des
commits. Si jamais on veut une affichage un peu plus bavard :

```sh
git log -p
```

Avec cette commande ci-dessus, on voit le détail des
modifications de chaque commit.

**Remarque :** il est juste inconcevable de lancer `git log`
et `git log -p` sans avoir de la couleur dans l'affichage.
Pour ce faire, lancer une bonne fois pour toutes :

```sh
git config --global color.diff auto
git config --global color.status auto
git config --global color.branch auto
```

Voir les commits est également possible sur Github bien sûr.
Vous allez sur la page du [dépôt](https://github.com/flaf/se3-clients-linux).
Ensuite vous cliquez sur l'onglet `commits` en haut au
dessus de la barre verte. Là, vous avez l'historique des
commits. Au niveau d'un commit, vous pouvez cliquer sur le
commentaire d'un commit et vous aurez le détail des
modifications de ce commit (un peu comme avec `git log -p`
en ligne de commandes).

Un lien qui peut être intéressant également, c'est le bouton
`<>` en face de chaque commit au niveau de la page de
[l'historique des commits](https://github.com/flaf/se3-clients-linux/commits/master).
Ce bouton vous permet de naviguer dans l'arborescence des
fichiers tels qu'ils étaient au moment du commit en
question.

Enfin, si vous utilisez Git en ligne de commandes et si vous
voulez que Git utilise `vim` par défaut à chaque fois que
vous devez indiquer le commentaire d'un commit, vous pouvez
mettre cette ligne `export EDITOR="vim"` dans le fichier
`~/.bashrc` de votre home.




