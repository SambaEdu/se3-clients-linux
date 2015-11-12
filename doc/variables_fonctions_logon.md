#Quelques variables et fonctions prêtes à l’emploi

Voici la liste des variables et des fonctions que vous pourrez utiliser dans le fichier `logon_perso` et qui seront susceptibles de vous aider à affiner le comportement du script de logon :

Pour commencer, [toutes les variables et les fonctions présentées ici](variables_fonctions.md) sont utilisables.

##`LOGIN`
Cette variable stocke le login de l’utilisateur qui a ouvert une session.
Cette variable n’a de sens que lors de la phase d’ouverture et de ferme-
ture (c’est-à-dire uniquement à l’intérieur des fonctions `ouverture_perso` et
`fermeture_perso`), pas lors de la phase d’initialisation (c’est-à-dire à l’in-
térieur de la fonction `initialisation_perso`) puisque personne n’a encore
ouvert de session à ce moment là.

##`NOM_COMPLET_LOGIN`
Cette variable stocke le nom complet (sous la forme « prénom nom ») de
l’utilisateur qui a ouvert une session. Cette variable n’a de sens que lors de
la phase d’ouverture et de fermeture.

##`REP_HOME`
Cette variable stocke le chemin absolu du répertoire home de l’utilisateur qui
se connecte. Par exemple, si le compte `toto` ouvre une session, la variable
contiendra la chaîne `/home/toto`. Remarquez que cette variable est un simple
raccourci pour écrire `"/home/$LOGIN"`. Cette variable n’a de sens que lors de
la phase d’ouverture et de fermeture.
