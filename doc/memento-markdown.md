Memento Git


## Installation 
```
apt-get update
apt-get install openssl ca-certificates git
```
## Configuration du fichier ~/.gitconfig :

Ça c'est pour afficher de la couleur dans la sortie des commandes,
c'est juste indispensable la couleur, tout prof sait cela. 
```
git config --global color.diff auto
git config --global color.status auto
git config --global color.branch auto
```

Il est important de bien paramétrer les éléments ci-dessous
notamment l'adresse mail doit coïncider avec son mail sur github.
```
git config --global user.name <son-login-github>
git config --global user.email <son-adresse-github>
```
## Commande utiles 


### Clonage d'un dépot distant

on se rend quelque part dans son home où on va placer un répertoire qui contiendra le dépôt puis :
```
git clone git@github.com:flaf/se3-clients-linux.git
```
À partir de là, tu as un répertoire "se3-clients-linux" qui vient de se créer au niveau du répertoire courant et qui contient tout le projet (en local donc). Le jour où tu veuxtout abandonner, tu supprimes le dépôt local (aucune incidence sur le dépôt distant, celui sur github) :
```
rm -rf se3-clients-linux/
```

### Update dépot
```
git pull 
```

tu récupères toutes les modifs que les autres ont éventuellement poussées sur le dépôt distant. Bref, ton dépôt local est à jour par rapport au dépôt distant après cette commande (pull = tirer).


### Vérification modif locales et commit  

Imaginons tu modifies un fichier

```
git status 
```

affichera les modifications sur ton dépôt local qui n'ont pas encore été commitées.


```
git commit -av 
```

tu vas commiter, ie valider tes modifs sur ton dépôt *local* et sur *lui* *seulement* (à ce stade les modifs sont validées sur ton dépôt local mais pas sur le dépôt distant). Pour chaque commit, il faut un commentaire qui explique (de manière très courte) tes modifs.


### Rémontée les modifications sur le dépots distant 

```
git push 
```
là tu pousses ton commit sur le site distant (push = pousser). Tu peux très bien modifier N fichiers (ci-dessus N=2), puis faire un commit et pusher. Mais « la bonne pratique », c'est en général de faire des commits « atomiques » du genre :

```
vim ...  une modif
git commit -av  un commit


vim ... # une autre modif
git commit -av # un autre commit
```

Et seulement à la fin, tu pousses :

```
git push 
```
on pousse sur le site distant tous les précédents commits.

###Modification du projet en local 

Enfin, tout ce qui touche à la structure du projet doit passer par des des commandes git dédiées. Par exemple, pour *ajouter* un nouveau fichier au projet :
```
touch le-nouveau-fichier 
```
on crée localement un nouveau fichier mais pour l'instant ce fichier ne fait pas parti du projet.

```
git status ```
va indiquer que le nouveau fichier est "untracked", ie il ne fait pas partie (encore) du projet.

```
git add le-nouveau-fichier 


### Ajout nouveau fichier 
mkdir ltsp
vim ltsp/le-fichier.ext

Mais à ce stade, le fichier ne fait pas partie du dépôt, il
ne fait pas partie du projet. On aura beau commiter ce qu'on
veux, le fichier ne sera pas mis sur github. Il faut faire :
```
git add ltsp/le-fichier.ext 
```
signifie qu'on ajoute le fichier au dépôt. git comprendra qu'il faut aussi rajouter le répertoire ltsp du coup.

On peut à nouveau éditer le fichier etc. puis :
```
git commit -av ``` là tu commites sur ton dépôt local, tu mets un commentaire etc.
``` git push   ```     là le tout part sur le site distant (github)



### Manipulation de branches 

```git checkout master  ```  bascule dans la branche master
```git checkout test-truc``` bascule dans la branche test-truc

Lorsque tu changeras de branche, ton arborescence locale va se modifier
pour coller à la branche que tu as choisie mais il n'y aura pas 2 arborescences
différentes, juste une seule qui collera automatiquement à la branche que
tu auras choisie (toutes les infos sont dans ton .git/ et git se débrouille
avec ça pour que ton arborescence locale soit en phase avec la branche sur
laquelle tu te trouves).


## Quelques exemples de formatage MD

* Pour faire un titre : # titre
* un sous titre : ## sous titre
* Mettre du gras  : **du gras**
* du code sur une ligne : `code`
* du code shell dans un bloc : ```rm -rf /*```
* Une liste : *
* Un lien vers [cette page](<url relative ou absolue>)

