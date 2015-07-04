# Memo Git

## Installation

Installation du minimum pour faire du git en ligne de
commandes :

```sh
apt-get update
apt-get install openssl ca-certificates git
```

## Mise en place de sa clé publique/privé d'accès

Pour ne pas avoir à se connecter/déconnecter à chaque fois,
on peut utiliser un jeu de clés publique/privée. Voici comment
les mettre en place :

Les créer :

```sh
ssh-keygen -t rsa
```

On vous pose des questions : `Entrée` 3 fois

Afficher la clé publique :

```sh
cat ~/.ssh/id_rsa.pub
```

Puis l'ajouter, par un copier/coller, dans son profil sur le
site du Git via son butineur préféré. Tout cela avant de lancer
la commande `git clone git@github.com:flaf/se3-clients-linux.git`
(voir ci-dessous). Ensuite, les différentes commandes de gestion
se font en étant dans le répertoire `se3-clients-linux` (voir
ci-dessous).


## Configuration du fichier `~/.gitconfig`

Quelques paramétrage à effectuer pour avoir de la couleur dans la sortie
des commandes (c'est juste indispensable la couleur) :

```sh
git config --global color.diff auto
git config --global color.status auto
git config --global color.branch auto
```

Les commandes ci-dessus ne sont qu'un moyen de modifier le
fichier (texte) de configuration `~/.gitconfig` (fichier de
configuration dans le home de utilisateur).

Il est important de bien paramétrer les éléments ci-dessous,
notamment l'adresse mail qui doit coïncider avec son adresse
mail sur GitHub :

```sh
git config --global user.name <son-login-github>
git config --global user.email <son-adresse-github>
```



## Commandes de base

### Clonage d'un dépôt distant

En général avec GitHub, on crée un dépôt via l'interface Web de
GitHub et ensuite on clone ce dépôt en local sur sa (ses) machine(s)
personnelle(s). Dans le cas qui nous intéresse, le dépôt
`se3-clients-linux` existe déjà, il ne reste plus qu'à le cloner sur
sa machine. On se rend quelque part dans son home où on va créer un
répertoire, qui contiendra le dépôt, à l'aide de la commande suivante :

```sh
git clone git@github.com:flaf/se3-clients-linux.git
```

À partir de là, on a un répertoire `se3-clients-linux` qui vient de se
créer au niveau du répertoire courant et qui contient tout le projet (en
local donc). Le jour où on veut tout abandonner, on supprime le dépôt
local comme ceci (ça n'aura absolument aucune incidence sur le dépôt
distant, ie le dépôt sur GitHub) :

```sh
rm -rf se3-clients-linux/
```

### Update dépôt local

À faire régulièrement. Avec cette commande, on récupère toutes les
modifications (on appelle ça des commits) que les autres membres du
projet ont éventuellement poussées sur le dépôt distant. Bref, cela
permet d'avoir un dépôt local à jour par rapport au dépôt distant
(pull = tirer en anglais) :

```sh
git pull
```

**NB :** cette commande de gestion, ainsi que les autres, ne
fonctionnera que si on la lance quand on se trouve dans le
répertoire local `se3-clients-linux`. Ne pas oublier de s'y
placer. En supposant que le répertoire `se3-clients-linux`
est dans le votre répertoire personnel, cela donnerait :

```sh
cd ~/se3-clients-linux/
```

### Vérification des modifications locales et commit

Imaginons qu'on ait **modifié** un fichier ou plusieurs fichiers
du projet. « Modifié » signifie qu'on a édité (avec son éditeur
favori, par exemple vim) un fichier ou plusieurs fichiers déjà
existants dans le projet. La commande :

```sh
git status
```

affichera la liste des fichiers modifiés sur le dépôt local et
qui n'ont pas encore été commités, ie validés en quelques sortes.
Pour commiter (ie valider) la liste des modifications inventoriées
par la commande `git status`, faire :

```sh
git commit -av
```

L'éditeur par défaut va s'ouvrir et il faudra indiquer un message
court expliquant nos modifications. Cela va commiter, ie valider
les modifications sur notre dépôt **local** et sur **lui seulement**
(à ce stade les modifications sont validées sur notre dépôt local mais
pas sur le dépôt distant).

**Remarque :** on peut parfaitement faire plusieurs modifications sur
N fichiers et regrouper tout cela en un seul commit. Il est toutefois
recommandé de faire des commits les plus atomiques possibles (ie une
modification, un commit, une modification un commit etc). En revanche,
on n'est pas obligé de pusher chaque commit les uns après les autres.
On peut parfaitement faire N commits (en local donc) et pusher nos N
commits en une fois.

### Remonter les modifications sur le dépôt distant

Imaginons qu'on ait effectué N commits. Comme on a vu ci-dessus, ces
N commits ne sont toujours pas remontés sur le dépôt distant, ie le
dépôt GitHub (et donc concrètement vous n'avez toujours pas partagé
vos commits avec les autres membres du projet). Pour pousser ces N
commits sur le site distant, on lance la commande :

```sh
# push = pousser.
git push
```

Pas de bonnes pratiques particulières au niveau des pushs. On peut très
bien faire un push après chaque commit mais ce n'est pas obligatoire.
On peut très bien faire 20 commits et pusher ensuite, peu importe. En
revanche, les commits, eux, doivent être le plus atomiques possibles :

```sh
# Une modification.
vim ./un/fichier

# Un commit.
git commit -av


# Une autre modification.
vim ./un/autre/fichier

# Un autre commit.
git commit -av

# Etc.

# Et à la fin, on pushe nos commits.
# On pourrait tout aussi bien pusher après chaque commit (personnellement,
# c'est ce que je fais).
git push
```

### Ajout de fichiers/répertoires au projet

Enfin, tout ce qui touche à la structure du projet doit passer
par des commandes git dédiées. Par exemple, pour **ajouter** un
nouveau fichier au projet :

```sh
# On crée le fichier dans notre dépôt local.
touch le-nouveau-fichier
```
ce qui crée localement un nouveau fichier mais pour l'instant ce
fichier ne fait pas encore parti du projet. D'ailleurs, la
commande :

```sh
git status
```

va indiquer que le nouveau fichier est `untracked`, ie qu'il ne
fait pas partie (encore) du projet. Pour l'intégrer au projet :

```sh
git add le-nouveau-fichier
```

Voici un autre exemple :

```sh
# Ajout d'un nouveau répertoire contenant un fichier.
mkdir ltsp
vim ltsp/le-fichier.ext
```

Là aussi, à ce stade, le fichier ne fait pas partie du projet. On
aura beau commiter ce qu'on veux, le fichier ne sera pas mis sur
GitHub. Il faut d'abord l'intégrer au projet avec :

```sh
git add ltsp/le-fichier.ext
```

On vient alors d'ajouter le fichier au projet.
Git comprendra qu'il faut aussi rajouter le répertoire `ltsp` du coup.
On peut à nouveau éditer le fichier etc. puis :

```sh
vim ltsp/le-fichier.ext
git commit -av
git push
```

### Le renommage d'un fichier/répertoire

Le renommage modifie modifie la structure d'un projet. Il possède lui
aussi une commande dédiée :

```sh
# Renomme le fichier1 en fichier2
git mv ./fichier1 ./fichier2
git commit -av
git push
```

### Manipulation de branches

```sh
# Ces commandes supposent que les branches existent déjà soit en local
# soit sur le dépôt distant (ie GitHub) :
git checkout master    # bascule dans la branche master
git checkout test-truc # bascule dans la branche test-truc
```

Lorsqu'on change de branche, l'arborescence locale va se modifier
automatiquement afin de coller à la branche choisie. Il n'y aura pas
2 arborescences différentes, juste une seule qui collera automatiquement
à la branche choisie (la « magie » est dans le répertoire `.git/` qui se
trouve à la racine du dépôt local et qui contient toutes les informations
nécessaires afin que git se débrouille pour que l'arborescence locale soit
en phase avec la branche sur laquelle on se trouve).




## Voir les pushs des autres avec Git et Gihub

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




# Memo sur le formatage markdown (fichiers `.md`)

En fait, tout est parfaitement résumé
[ici](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet).
Voici quelques syntaxes fondamentales ci-dessous.

## Mise en forme de base

* Pour faire un titre : `# Titre` (en début de ligne)
* Pour faire un sous-titre : `## Sous titre` (en début de ligne)
* Pour faire un sous-sous-titre : `### Sous sous titre` (en début de ligne)
* Pour mettre en gras  : `**du gras**`
* Pour faire une liste à puce : ̀`*`
* Pour faire un lien : `Consultez [cette page](<url relative ou absolue>)`

## Insérer du code

Pour insérer du code sur une ligne de texte ou dans un bloc,
tout est expliqué
[ici](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet#code-and-syntax-highlighting).
Voici un exemple simple ci-dessous dans le cas d'un code shell
dans un bloc :

````
```sh
# Du code en shell
find /dir -type f -name '*.sh'
```
````

Le `sh` juste après les 3 backquotes est optionnel mais il
permet d'avoir une coloration syntaxique du code adapté au
langage (le langage shell ici) ce qui rend les extraits de
codes nettement plus jolis.

## Insérer une image

Pour insérer une image centrée, on doit insérer un petit
bout de code html au sein du fichier markdown comme ceci :

```
Blabla blabla Blabla blabla Blabla blabla Blabla blabla
Blabla blabla Blabla blabla Blabla blabla Blabla blabla

<p align="center">
  <img src="images/bidul.png" width="50%" alt="Texte alternatif" title="Info lors du survol ">
</p>

Blabla blabla Blabla blabla Blabla blabla Blabla blabla
Blabla blabla Blabla blabla Blabla blabla Blabla blabla
```

Dans l'exemple ci-dessus :

* `src="images/bidul.png"` correspond au chemin relatif du
fichier image par rapport au fichier markdown qu'on est en
train d'éditer.
* Pour être respectueux de la norme html, il faut bien mettre
les attributs d'une balise sous la forme `name="value" comme
dans `width="50%"` avec la valeur entre doubles quotes.
* Dans la balise `img`, l'attribut `alt` est obligatoire (si on
veut être respectueux de la norme html). Il s'agit d'un texte
affiché à la place de l'image si celle-ci n'est pas trouvée par
le serveur.
* L'attribut `title` définit du texte (court) qui sera affiché
lors du survol de la souris au niveau de l'image. Cet attribut
est optionnel.
* L'attribut `width="50%"` permet de redimensionner la taille
de l'image. Dans le cas présent, l'image occupera la moitié
(ie 50%) de la largeur du texte des paragraphes.


