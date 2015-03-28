Pour les impatients qui veulent tester rapidement
=================================================

Installation du paquet se3-clients-linux sur le serveur {#installation}
-------------------------------------------------------

Il faut que votre réseau local dispose d’une connexion Internet. Pour
commencer, il faut préparer votre serveur Samba en y installant le
paquet . Pour ce faire :

-   Si votre serveur est sous Lenny, il faut ouvrir une console en tant
    que et lancer :

        apt-get update
        apt-get install se3-clients-linux

-   Si votre serveur est sous Squeeze, vous pouvez :

    -   ou bien faire l’installation comme sur un serveur Lenny (en mode
        console donc);

    -   ou bien faire l’installation en passant par l’interface
        d’administration Web du serveur via les menus . Dans le tableau
        des modules, le paquet correspond à la ligne avec l’intitulé .

Attention, dans les versions précédentes du paquet, il fallait éditer le
fichier [^1] et ajouter une des deux lignes suivantes :

    # Pour un serveur en version Lenny.
    deb http://francois-lafont.ac-versailles.fr/debian lenny se3

    # Pour un serveur en version Squeeze.
    deb http://francois-lafont.ac-versailles.fr/debian squeeze se3

Désormais ce n’est plus nécessaire. Le paquet est maintenant inclus dans
le dépôt officiel du projet SambaÉdu, il n’est donc plus indispensable
d’ajouter un dépôt supplémentaire.

**Mais si vous souhaitez utiliser la toute dernière version disponible
du paquet**, alors il faudra dans ce cas utiliser le dépôt
<http://francois-lafont.ac-versailles.fr> comme indiqué ci-dessus.

L’installation ne fait rien de bien méchant sur votre serveur. Vous
pouvez parfaitement désinstaller le paquet du serveur afin que celui-ci
retrouve très exactement le même état qu’avant l’installation (voir la
section [desinstallation] page ). L’installation se borne uniquement à
effectuer les tâches suivantes :

-   Création d’un nouveau répertoire : le répertoire .

-   Création d’un partage Samba supplémentaire sur le serveur à travers
    le fichier de configuration : il s’agit du partage CIFS nommé
    correspondant au répertoire du serveur.

-   Lecture de certains paramètres du serveur afin d’adapter certains
    scripts contenus dans le paquet à l’environnement de votre domaine
    local. En fait, ces fameux paramètres récupérés lors de
    l’installation du paquet sont au nombre de trois :

    1.  l’adresse IP du serveur ;

    2.  le suffixe de base de l’annuaire LDAP ;

    3.  l’adresse du serveur de temps NTP.

Lors de l’installation du paquet, si jamais vous obtenez un message vous
indiquant que le serveur NTP ne semble pas fonctionner, avant de passer
à la suite, vous devez vous rendre sur la console d’administration Web
de votre serveur (dans ) afin de spécifier l’adresse d’un serveur de
temps qui fonctionne correctement (chose que l’on peut vérifier ensuite
dans la page de diagnostic du serveur). Une fois le paramétrage effectué
il vous suffit de reconfigurer le paquet en lançant, en tant que sur une
console du serveur, la commande suivante :

    dpkg-reconfigure se3-clients-linux

Si tout se passe bien, vous ne devriez plus obtenir d’avertissement à
propos du serveur NTP.

Votre serveur Samba possède donc un nouveau partage CIFS qui, au
passage, ne sera pas visible par les machines clientes sous Windows.
Attention, le nom du partage CIFS n’est pas le même que le nom du
répertoire correspondant dans l’arborescence locale du serveur :

   Nom du partage   Chemin réseau   Chemin dans l’arborescence locale du serveur
  ---------------- --------------- ----------------------------------------------
                                   

Au niveau de l’installation du paquet proprement dite, côté serveur,
plus aucune manipulation supplémentaire n’est nécessaire désormais.

Sachez enfin que si, pour une raison ou pour une autre, il vous est
nécessaire de reconfigurer le paquet pour restaurer des droits corrects
sur les fichiers, ou bien pour réadapter les scripts à l’environnement
de votre serveur (parce que par exemple son IP a changé), il vous suffit
de lancer la commande suivante en tant que sur une console du serveur :

    dpkg-reconfigure se3-clients-linux

Intégration d’un client GNU/Linux
---------------------------------

Le répertoire de votre serveur contient un script d’intégration par type
de distribution GNU/Linux. Par exemple, le script d’intégration pour des
Debian Squeeze se trouve dans le répertoire :

et il s’appelle . Il faudra exécuter l’un de ces scripts, en tant que ,
**en local** sur le client GNU/Linux que vous souhaitez intégrer.

pour copier en local sur un client GNU/Linux le script d’intégration qui
se trouve sur le serveur, on pourra utiliser la bonne vieille clé USB
des familles, mais on pourra aussi user et abuser de la commande (très
pratique) qui permet d’effectuer très simplement des copies entre deux
machines (sous GNU/Linux) distantes. Par exemple, sur le terminal d’un
client Debian Squeeze, vous pourriez exécuter les commandes suivantes :

    # Chemin du fichier sur le serveur. Le joker * nous permet simplement 
    # d'économiser la saisie de quelques touches sur le clavier (à
    # condition d'en saisir suffisamment pour éviter toute ambiguïté 
    # sur le nom du fichier).
    SOURCE="/home/netlogon/clients-linux/dist*/squ*/int*/int*"

    # Répertoire de destination sur le client GNU/Linux en local. Par
    # exemple le bureau, histoire de voir apparaître le fichier
    # sous nos yeux.
    DESTINATION="/home/toto/Bureau/"

    # Et enfin la copie du fichier du serveur vers le client GNU/Linux en local.
    # Il faudra alors saisir le mot de passe du compte root du serveur.
    scp root@IP-SERVEUR:"$SOURCE" "$DESTINATION"

si jamais vous avez un doute sur le type de distribution de votre client
GNU/Linux, vous pouvez lancer dans un terminal la commande suivante (pas
forcément en tant que ) :

    lsb_release --codename

Le résultat vous affichera le nom de code de la distribution ( ou etc.)
ce qui vous indiquera le script d’intégration à utiliser.

Supposons par exemple que vous avez copié le script d’intégration sur
une Debian Squeeze et que celui-ci se trouve sur votre bureau. Alors,
**en tant que **, vous pouvez lancer l’intégration ainsi :

    # D'abord, on se place sur le bureau (ici, il s'agit du bureau de toto).
    cd /home/toto/Bureau

    # Ensuite, on rend le script exécutable.
    chmod u+x integration_squeeze.bash

    # Enfin, on lance l'intégration.
    ./integration_squeeze.bash --nom-client="toto-04" --is --ivl --rc

Les explications sur les options se trouvent plus loin dans le document
à la section [options-integration] page . Si tout se passe bien, le
client finira par lancer un redémarrage. Une fois celui-ci terminé, vous
devriez être en mesure d’ouvrir une session avec un compte du domaine
(comme le compte ou un compte de type professeur ou de type élève).

Il est préférable qu’aucun compte local du client n’ait le même login
qu’un compte du domaine. Or, lorsqu’on installe un client GNU/Linux, on
est en général amené à créer au moins un compte local (en plus du compte
). Si cela vous arrive, arrangez-vous pour que le login de ce compte ne
risque pas de rentrer en conflit avec le login d’un compte du domaine.
Vous pouvez utiliser comme login par exemple, ou autre chose…

Visite rapide du répertoire clients-linux/ du serveur {#arborescence}
=====================================================

Afin de faire un rapide tour d’horizon du paquet , voici ci-dessous un
schéma du contenu du répertoire du serveur. Les noms des répertoires
possèdent un slash à la fin, sinon il s’agit de fichiers standards.
Certains fichiers ou répertoires, dont vous n’avez pas à vous
préoccuper, ont été omis afin d’alléger le schéma et les explications
qui vont avec. Les fichiers ou répertoires que vous avez le droit de
modifier pour les adapter à vos besoins sont en ****. À l’inverse, vous
ne devez pas modifier tous les autres fichiers ou répertoires [^2].

    -- clients-linux/
       |-- bin/
       |   |-- connexion_ssh_serveur.bash
       |   |-- logon
       |   |-- logon_perso
       |   `-- reconfigure.bash
       |-- distribs/
       |   |-- precise/
       |   |   |-- integration/
       |   |   |   |-- desintegration_precise.bash
       |   |   |   `-- integration_precise.bash
       |   |   `-- skel/
       |   `-- squeeze/
       |       |-- integration/
       |       |   |-- desintegration_squeeze.bash
       |       |   `-- integration_squeeze.bash
       |       `-- skel/
       |-- divers/
       |-- doc/
       |   `-- LISEZMOI.TXT
       `-- unefois/

Voici quelques commentaires rapides :

-   Le répertoire contient en premier lieu le fichier qui est le script
    de logon. Ce script est véritablement le chef d’orchestre de tous
    les clients GNU/Linux intégrés au domaine. C’est lui qui contient
    les instructions exécutées systématiquement par les clients
    GNU/Linux juste avant l’affichage de la fenêtre de connexion, au
    moment de l’ouverture de session et au moment de la fermeture de
    session. Ce script de logon sera expliqué à la
    section [logon-script] page . En principe, vous ne devez pas
    modifier ce fichier. En revanche, vous pourrez modifier le fichier
    juste à côté. Ce fichier vous permettra d’affiner le comportement du
    script afin de l’adapter à vos besoins. Vous trouverez toutes les
    explications nécessaires dans la section [personnalisation] page .

    Le répertoire contient également le fichier . Il s’agit simplement
    d’un petit script exécutable qui, lorsque sous serez connecté(e)
    avec le compte sur un client GNU/Linux et que vous double-cliquerez
    dessus, vous permettra d’ouvrir une connexion SSH sur le serveur en
    tant que (autrement dit une console à distance sur le serveur en
    tant que ). C’est une simple commodité. Bien sûr, il vous sera
    demandé de fournir le mot de passe du compte sur le serveur. Pour
    fermer proprement la connexion SSH, il vous suffira de taper sur la
    console la commande .

    Enfin, le répertoire contient le fichier . Il s’agit d’un fichier
    exécutable très pratique qui vous permettra de remettre les droits
    par défaut sur l’ensemble des fichiers du paquet se trouvant sur le
    serveur et d’insérer le contenu du fichier (votre fichier personnel
    que vous pouvez modifier afin d’ajuster le comportement des clients
    GNU/Linux selon vos préférences) à l’intérieur du fichier qui est le
    seul fichier lu par les clients GNU/Linux. Vous pourrez lancer cet
    exécutable à partir du compte du domaine sur un client GNU/Linux
    intégré. Cet exécutable utilise une connexion SSH en tant que et à
    chaque fois il faudra donc saisir le mot de passe du serveur.

-   Le répertoire contient un sous-répertoire par distribution GNU/Linux
    prise en charge par le paquet. Par exemple, dans le sous-répertoire
    , il y a les dossiers suivants :

    -   Un dossier qui contient notamment le script d’intégration. C’est
        ce script qu’il faudra exécuter en tant que sur chaque client
        Squeeze que l’on souhaite intégrer au domaine du serveur. Les
        options disponibles dans ce scripts sont décrites dans la
        section [options-integration] à la page . Le script de
        désintégration se trouve également dans ce dossier, mais ce
        script est copié sur chaque client GNU/Linux en local au moment
        de l’intégration. Voir la section [desintegration] page  pour
        plus d’explications sur le script de désintégration .

    -   Un dossier qui contient le profil par défaut (c’est-à-dire le
        home par défaut) de tous les utilisateurs du domaine sur la
        distribution concernée. Si vous voulez modifier la page
        d’accueil du navigateur de tous les utilisateurs du domaine ou
        bien si vous voulez ajouter des icônes sur le bureau, c’est dans
        ce dossier qu’il faudra faire des modifications. Vous trouverez
        toutes les explications nécessaires dans la section [profils] à
        la page .

-   Le répertoire ne contient pas grand chose par défaut et vous pourrez
    a priori y mettre ce que vous voulez. L’intérêt de ce répertoire est
    que, si vous y placez des fichiers (ou des répertoires), ceux-ci
    seront accessibles uniquement par le compte local de chaque client
    GNU/Linux et par le compte du domaine. En particulier, vous aurez
    accès au contenu du répertoire à travers le script de logon et à
    travers les scripts unefois (évoqués ci-dessous) qui sont tous les
    deux exécutés par le compte local de chaque client GNU/Linux. Vous
    trouverez un exemple d’utilisation possible de ce répertoire dans la
    section [imprimante] à la page .

-   Le répertoire contient un fichier texte qui vous indiquera l’adresse
    URL de la documentation en ligne que vous êtes en train de lire
    actuellement (à savoir le fichier ) ainsi que l’adresse URL des
    sources au format LaTeX de cette documentation.

-   Le répertoire sert à exécuter des scripts une seule fois sur toute
    une famille de clients GNU/Linux intégrés au domaine. Ce répertoire
    peut s’avérer utile pour effectuer des tâches administratives sur
    les clients GNU/Linux. Toutes les explications nécessaires sur ce
    répertoire se trouvent dans la section [unefois] page .

Les options des scripts d’intégration {#options-integration}
=====================================

Les deux scripts d’intégration et , qui doivent être exécutés en tant
que en local sur chaque client GNU/Linux à intégrer, utilisent
exactement le même jeu d’options. En voici la liste.

-   L’option ou : cette option vous permet de modifier le nom d’hôte[^3]
    du client. Si l’option n’est pas spécifiée, alors le client gardera
    le nom d’hôte qu’il possède déjà. Si l’option est spécifiée sans
    paramètre, alors le script d’intégration stoppera son exécution pour
    vous demander de saisir le nom de la machine. Si l’option est
    spécifiée avec un paramètre, comme dans :

        ./integration_squeeze.bash --nom-client="toto-04"

    alors le script ne stoppera pas son exécution et effectuera
    directement le changement de nom en prenant comme nom le paramètre
    fourni (ici ). Les caractères autorisés pour le choix du nom sont :

    -   les 26 lettres de l’alphabet en minuscules ou en majuscules,
        **sans accents** ;

    -   les chiffres ;

    -   le tiret du 6 (-) ;

    -   et c’est tout !

    De plus, **le nom de la machine ne soit pas faire plus de 15
    caractères**.

-   L’option ou : cette option vous permet d’ajouter un mot de passe dès
    qu’un utilisateur souhaite éditer un des items du menu Grub au
    démarrage. En effet, en général, sur un système GNU/Linux
    fraîchement installé et utilisant Grub comme chargeur de boot, il
    est possible de sélectionner un des items du menu Grub et de
    l’éditer en appuyant sur la touche sans devoir saisir le moindre mot
    de passe. Cela constitue une faille de sécurité potentielle car,
    dans ce cas, l’utilisateur peut très facilement éditer un des item
    du menu Grub et démarrer ensuite via cet item modifié de manière à
    devenir sur la machine **sans avoir à saisir le moindre mot de
    passe**. Avec l’option , quand l’utilisateur voudra éditer un des
    items du menu Gub, il devra saisir les identifiants suivants :

    -   login : ;

    -   mot de passe : celui spécifié avec l’option .

    Si l’option n’est pas spécifiée, alors la configuration de Grub est
    inchangée et a priori la faille de sécurité sera toujours présente.
    Si l’option est spécifié sans paramètre, alors le script
    d’intégration stoppera son exécution pour vous demander de saisir
    (deux fois) le futur mot de passe Grub (votre saisie ne s’affichera
    pas à l’écran). Si l’option est spécifiée avec un paramètre comme
    dans :

        ./integration_squeeze.bash --mdp-grub="1234"

    alors le script ne stoppera pas son exécution et effectuera
    directement le changement de configuration de Grub en prenant comme
    mot de passe le paramètre fourni (ici ).

-   L’option ou : cette option vous permet de modifier le mot de passe
    du compte . Si vous ne spécifiez pas cette option, le mot de passe
    du compte sera inchangé. Si vous spécifiez cette option sans
    paramètre, alors le script d’intégration stoppera son exécution pour
    vous demander de saisir (deux fois) le futur mot de passe du compte
    (votre saisie ne s’affichera pas sur l’écran). Si l’option est
    spécifiée avec un paramètre comme dans :

        ./integration_squeeze.bash --mdp-root="abcd"

    alors le script ne stoppera pas son exécution et effectuera
    directement le changement de mot de passe en utilisant la valeur
    fournie en paramètre (ici ).

-   L’option ou : cette option, qui ne prend aucun paramètre, vous
    permet de continuer l’intégration sans faire de pause après la
    vérification LDAP. En effet, lors de l’exécution du script
    d’intégration, quel que soit le jeu d’options choisi, une recherche
    dans l’annuaire du serveur est effectuée. Le script lancera une
    recherche de toutes les entrées dans l’annuaire correspondant à des
    machines susceptibles d’avoir un lien avec la machine qui est en
    train d’exécuter le script d’intégration au domaine. Plus
    précisément la recherche porte sur toutes les entrées dans
    l’annuaire correspondant à des machines qui ont :

    -   même nom que la machine exécutant le script ;

    -   **ou** même adresse IP que la carte réseau de la machine
        exécutant le script ;

    -   **ou** même adresse MAC que la carte réseau de la machine
        exécutant le script.

    Dans tous les cas, le résultat de cette recherche sera affiché. Si
    vous n’avez pas spécifié l’option , alors le script s’arrêtera à ce
    moment là et vous demandera si vous voulez continuer l’intégration.
    Si par exemple vous vous apercevez que le nom d’hôte que vous avez
    choisi pour votre client GNU/Linux existe déjà dans l’annuaire du
    serveur, il faudra peut-être arrêter l’intégration (sauf si le
    système GNU/Linux est installé en dual boot avec Windows sur la
    machine et que le système Windows, lui, a déjà été intégré au
    domaine avec ce même nom). Mais si vous avez spécifié l’option ,
    alors après avoir affiché le résultat de la recherche LDAP, le
    script continuera automatiquement l’intégration sans vous demander
    de confirmation.

-   L’option ou : cette option, qui ne prend aucun paramètre, provoquera
    l’installation de Samba sur le client GNU/Linux. Si vous ne
    spécifiez pas cette option, alors Samba ne sera pas installé sur le
    client GNU/Linux. Actuellement, il est conseillé de spécifier cette
    option. En effet, lorsqu’un client GNU/Linux essaye de monter un
    partage Samba du serveur (notamment le partage ), des scripts sont
    exécutés en amont côté serveur et le montage ne sera effectué qu’une
    fois ces scripts terminés. Or, l’un d’entre eux peut mettre un
    certain temps (environ 4 ou 5 secondes) à se terminer si Samba n’est
    pas installé sur la machine cliente. Par conséquent, si vous ne
    spécifiez pas l’option , vous risquez d’avoir des ouvertures de
    sessions un peu lentes (lors du montage des partages Samba). Donc
    pour l’instant, utilisez cette option lors de vos intégrations.

    Pour l’instant, il faut utiliser l’option systématiquement.

-   L’option ou : cette option permet de lancer automatiquement un
    redémarrage du client GNU/Linux à la fin de l’exécution du script
    d’intégration. Si vous ne spécifiez pas cette option, il n’y aura
    pas de redémarrage à la fin de l’exécution du script. Sachez que le
    redémarrage après intégration est nécessaire pour avoir un système
    opérationnel. Si les intégrations se déroulent sans erreur sur vos
    machines Linux, vous aurez donc tout intérêt à spécifier à chaque
    fois l’option .

Précisons enfin que, quel que soit le jeu d’options que vous aurez
choisi, **aucun enregistrement dans l’annuaire du serveur ne sera
effectué par le script d’intégration**. Par conséquent, si vous
souhaitez que votre client GNU/Linux fraîchement intégré figure dans
l’annuaire du serveur, il faudra passer par une réservation d’adresse IP
de la carte réseau du client via le module DHCP du serveur.

Une fois un client intégré au domaine, évitez de monter un disque ou un
partage dans le répertoire . En effet, le répertoire est utilisé
constamment par le client GNU/Linux (une fois que celui-ci est intégré
au domaine) pour y effectuer des montages de partages, notamment au
moment de l’ouverture de session d’un utilisateur du domaine, et ce
répertoire est aussi constamment nettoyé , notamment juste après une
fermeture de session. Afin d’éviter le nettoyage intempestif d’un de vos
disques ou d’un partage réseau de votre cru, utilisez un autre
répertoire pour procéder au montage. Utilisez par exemple le répertoire
à la place. En fait, utilisez ce que vous voulez sauf .

La désintégration  {#desintegration}
==================

Une fois un client GNU/Linux intégré au domaine, celui-ci possédera
**localement** un script permettant de le faire sortir du domaine et de
lui redonner (quasiment) son état avant l’intégration. Il s’agit du
script :

où vous pouvez remplacer par , par etc. Ce script admet une unique
option (qui ne prend pas de paramètre) : il s’agit de l’option ou qui,
comme son nom l’indique, redémarre la machine à la fin du script de
désintégration . Sans cette option, la machine ne redémarrera pas
automatiquement. Tout comme pour les scripts d’intégration, après
désintégration , un redémarrage est nécessaire pour que le système soit
opérationnel. Autre point commun : aucune modification sur l’annuaire du
serveur n’est effectuée lors de l’exécution du script de désintégration
. En particulier, après avoir sorti un client GNU/Linux du domaine, il
faudra effacer vous-même toute trace de ce client dans l’annuaire du
serveur.

Les partages des utilisateurs
=============================

Liste par défaut des partages accessibles suivant le type de compte
-------------------------------------------------------------------

Attention, cette liste (décrite ci-dessous) est une liste proposée **par
défaut** par le paquet. Vous verrez plus loin, à la
section [gestion-montage] page , que vous pourrez définir vous-même la
liste des partages disponibles en fonction du compte qui se connecte, en
fonction de son appartenance à tel ou tel groupe etc. **Cette liste est
donc tout à fait modifiable**.

**Avertissement valable uniquement pour ceux qui ont déjà installé une
version $\bm{n}$ du paquet avec $\bm{n < 1.1}$**

Attention, depuis la version $1.1$ du paquet, la gestion des partages
accessibles se fait exclusivement dans le fichier . Cela a une
conséquence importante si une version antérieure à la version $1.1$ du
paquet est déjà installée sur votre serveur. En effet, lors de la mise à
jour du paquet vers une version $\geq 1.1$, plus aucun partage réseau ne
devrait être monté à l’ouverture de session sur vos clients GNU/Linux et
cela pour tout utilisateur du domaine.

C’est parfaitement normal car, lors de la mise à jour du paquet, votre
fichier a été conservé et c’est désormais dans ce fichier que les
commandes de montage des partages sont effectuées. Or, a priori, votre
fichier ne contient pas encore ces commandes de montage.

Il est cependant très facile de retrouver le comportement par défaut
(comme décrit ci-dessous) au niveau du montage des partages réseau à
l’ouverture de session. Sur une console du serveur, en tant que , il
vous suffit de faire :

    # On se place dans le répertoire bin/.
    cd /home/netlogon/clients-linux/bin/

    # On met dans un coin votre fichier logon_perso en le renommant
    # logon_perso.SAVE (si jamais vous n'avez jamais touché à ce fichier
    # alors vous pouvez même le supprimer avec la commande rm logon_perso).
    mv logon_perso logon_perso.SAVE

    # On reconfigure le paquet. L'absence du fichier logon_perso sera
    # détectée et vous retrouverez ainsi la version par défaut de ce 
    # fichier.
    dpkg-reconfigure se3-clients-linux

Vous retrouverez un comportement par défaut dès que les clients
GNU/Linux auront mis à jour leur script de logon local, c’est-à-dire au
plus tard après un redémarrage des clients (en fait, après une simple
fermeture de session, la mise à jour devrait se produire).

Voici la liste, par défaut, des partages accessibles en fonction du type
de compte lors d’une session.

1.  **Un compte élève** aura accès :

    -   Au partage via deux liens symboliques. Tous les deux possèdent
        le même nom : . L’un se trouve dans le répertoire et l’autre
        dans le répertoire .

    -   Au partage via deux liens symboliques. Tous les deux possèdent
        le même nom : . L’un se trouve dans le répertoire et l’autre
        dans le répertoire .

2.  **Un compte professeur** aura accès :

    -   Aux mêmes partages qu’un compte élève.

    -   Mais il aura accès en plus au partage via deux liens
        symboliques. Tous les deux possèdent le même nom : . L’un se
        trouve dans le répertoire et l’autre dans le répertoire .

3.  **Le compte ** aura accès :

    -   Aux mêmes partages qu’un compte professeur.

    -   Mais il aura accès en plus au partage via deux liens
        symboliques. Tous les deux possèdent le même nom : . L’un se
        trouve dans le répertoire et l’autre dans le répertoire .

    -   Et il aura accès en plus au partage via deux liens symboliques.
        Tous les deux possèdent le même nom : . L’un se trouve dans le
        répertoire et l’autre dans le répertoire .

Le lien symbolique clients-linux
--------------------------------

Rien de nouveau donc au niveau des partages disponibles, à part le
partage accessible via le compte du domaine à travers le lien symbolique
situé sur le bureau. Ce lien symbolique vous permet d’avoir accès, en
lecture et en écriture, au répertoire du serveur. Techniquement, une
modification de ce répertoire est aussi possible via le lien symbolique
puisque celui-ci donne accès à tout le répertoire du serveur.

### Avertissement : toujours reconfigurer les droits après modifications du contenu du répertoire clients-linux/ {#reconfigurer-droits .unnumbered}

Lors de certains paramétrages du paquet , vous serez parfois amené(e) à
modifier le contenu du répertoire du serveur :

-   soit via une console sur le serveur si vous êtes un(e) adepte de la
    ligne de commandes ;

-   soit via le lien symbolique situé sur le bureau du compte lorsque
    vous est connecté(e) sur un client GNU/Linux intégré au domaine.

Dans un cas comme dans l’autre, une fois vos modifications terminées, il
faudra **TOUJOURS** reconfigurer les droits du paquet sans quoi vous
risquez ensuite de rencontrer des erreurs incompréhensibles. Pour ce
faire il faudra :

-   ou bien, **si vous êtes connecté(e) en mode console sur le
    serveur**, exécuter en tant que la commande :

        dpkg-reconfigure se3-clients-linux

-   ou bien, **si vous êtes connecté(e) en tant qu’ sur un client
    GNU/Linux**, double-cliquer sur le fichier accessible en passant par
    le lien symbolique sur le bureau puis par le répertoire (le mot de
    passe du serveur sera demandé).

**Remarque :** en réalité, ces deux procédures ne font pas que
reconfigurer les droits sur les fichiers, elles permettent aussi
d’injecter le contenu du fichier dans le fichier . Ce point sera abordé
dans la section [personnalisation] page .

La gestion des profils {#profils}
======================

Une précision à avoir en tête
-----------------------------

Dans cette documentation, on appellera profil le contenu **ou une copie
du contenu** du home d’un utilisateur (par exemple le profil de est le
contenu du répertoire ). Pour bien comprendre le mécanisme des profils,
il faut avoir en tête ces deux éléments :

1.  Le serveur Samba offre un partage CIFS dont le chemin réseau est et
    qui correspond sur le serveur au répertoire .

2.  Sur chaque client GNU/Linux intégré au domaine, le répertoire est un
    point de montage (en lecture seule) du partage CIFS .

**Conclusion à bien avoir en tête :** sur un client GNU/Linux intégré au
domaine, visiter le répertoire local revient en fin de compte à visiter
le répertoire du serveur Samba. Dans le tableau ci-dessous, les trois
adresses suivantes désignent finalement la même zone de stockage qui se
trouve sur le serveur :

   Chemin réseau   Chemin local sur le serveur   Chemin local sur un client GNU/Linux
  --------------- ----------------------------- --------------------------------------
                                                

Les différentes copies du profil par défaut
-------------------------------------------

Revenons maintenant à nos profils. En fin de compte, pour un client
GNU/Linux donné qui a été intégré au domaine, il existe plusieurs copies
du profil par défaut des utilisateurs. **Dans le cas des clients sur
Debian Squeeze** par exemple, il y a :

1.  Le profil par défaut **distant** qui est unique et centralisé sur le
    serveur. Il est accessible de plusieurs manières. Les trois adresses
    ci-dessous accèdent toutes à ce même profil par défaut **distant** :

    -   à travers le réseau via le partage CIFS :

    -   sur le serveur directement à l’adresse :

    -   sur chaque client Squeeze intégré au domaine via le chemin :

2.  Le profil par défaut **local** qui se trouve sur chaque client
    intégré au domaine dans le **répertoire local** (ce répertoire n’est
    pas un point de montage, c’est un répertoire local au client
    GNU/Linux).

Le mécanisme des profils {#mecanisme-profils}
------------------------

Voici comment fonctionne le mécanisme des profils du point de vue d’un
client GNU/Linux sous Debian Squeeze (sous une autre distribution, c’est
exactement la même chose) :

1.  **Au moment de l’affichage de la fenêtre de connexion** du système
    (c’est-à-dire soit juste après le démarrage du système ou soit juste
    après chaque fermeture de session), le client GNU/Linux va comparer
    le contenu de deux fichiers :

    1.  le fichier de son profil par défaut **local**

    2.  le fichier du profil par défaut **distant**.

    Si ces deux fichiers ont un contenu totalement identique, alors le
    client GNU/Linux ne fait rien car il estime que son profil par
    défaut **local** et le profil par défaut **distant** sont
    identiques. Si en revanche les deux fichiers ont un contenu
    différent, alors le client va modifier son profil par défaut
    **local** afin qu’il soit identique au profil par défaut
    **distant**. Autrement dit, il va synchroniser[^4] son profil par
    défaut **local** par rapport au profil par défaut **distant**.

2.  **Au moment de l’ouverture de session** d’un compte du domaine,
    c’est-à-dire juste après une saisie correcte du login et du mot de
    passe d’un compte du domaine, appelons ce compte , le client
    GNU/Linux va créer le répertoire (local) vide et le remplir en y
    copiant dedans le contenu de son profil par défaut **local**
    (c’est-à-dire le contenu du répertoire ) afin de compléter le home
    de .

3.  **Au moment de la fermeture de session**, tous les liens symboliques
    situés dans qui permettent d’atteindre les différents partages
    auxquels peut prétendre sont supprimés.

4.  **Au moment du prochain affichage de la fenêtre de connexion**,
    c’est-à-dire ou bien juste après la fermeture de session de s’il n’a
    pas choisi d’éteindre le poste client ou bien au prochain démarrage
    du système, **le répertoire est tout simplement effacé**.

Exemple de modification du profil par défaut avec Firefox {#modifier-profil}
---------------------------------------------------------

Du point de vue de l’utilisateur, cette gestion des profils est assez
contraignante : par exemple notre cher aura beau modifier son profil
durant sa session (changer le fond d’écran, ajouter un lanceur sur le
bureau), après une fermeture puis réouverture de session, il retrouvera
inlassablement le même profil par défaut et toutes ses modifications
auront disparu. De plus, tous les comptes du domaine (que ce soit les
comptes professeur ou les comptes élève) possèdent exactement le même
profil par défaut[^5]. Seule la liste des partages réseau accessibles
sera différente d’un compte à l’autre. Mais ceci étant dit, cette
gestion des profils présente tout de même deux avantages importants :

1.  **Ouverture de session rapide :** en effet, au moment de l’ouverture
    de session d’un compte du domaine, la création du home ne sollicite
    pas le réseau puisqu’elle passe par une simple copie locale du
    contenu de qui est copié dans .

2.  **Modification du profil par défaut (pour tous les utilisateurs)
    simple et rapide :** en effet, il devient très facile de modifier le
    profil par défaut des utilisateurs, car, si vous avez bien suivi,
    c’est le profil par défaut **distant** (celui sur le serveur) qui
    sert de modèle à tous les profils par défaut **locaux** des clients
    GNU/Linux. Une modification du profil par défaut **distant**
    accompagnée d’une modification du fichier associé sera impactée sur
    chaque profil par défaut **local** de tous les clients GNU/Linux.

Prenons un exemple avec le navigateur Firefox : vous souhaitez imposer
un profil par défaut particulier au niveau de Firefox pour tous les
utilisateurs du domaine sur les clients GNU/Linux de type Precise
Pangolin. Pour commencer, vous devez ouvrir une session sur un client
GNU/Linux Precise Pangolin et lancer Firefox afin de le configurer
exactement comme vous souhaitez qu’il le soit pour tous les utilisateurs
(page d’accueil, proxy, etc). Une fois le paramétrage effectué, pensez
bien sûr à fermer l’application Firefox. Ensuite, il vous suffit de
suivre la procédure ci-dessous. Pour la suite, on admettra que la
session utilisée pour fabriquer le profil Firefox par défaut est celle
du compte .

1.  Il faut copier le répertoire [^6] (et tout son contenu bien sûr)
    dans le profil par défaut **distant** du serveur, et cela tout en
    veillant à ce que les droits sur la copie soient corrects. Pour ce
    faire, vous avez deux méthodes possibles :

    -   **Méthode graphique :** vous copiez le répertoire sous une clé
        USB puis vous fermez la session de pour en rouvrir une avec le
        compte du domaine. Ensuite, vous double-cliquez sur le lien
        symbolique qui se trouve sur le bureau puis vous vous rendez
        successivement dans pour enfin, via un glisser-déposer, copier
        dans le répertoire qui se trouve dans la clé USB (le dossier
        devra donc contenir un répertoire ).

        Attention, en général, les répertoires dont le nom commence par
        un point sont cachés par défaut et pour qu’ils s’affichent dans
        l’explorateur de fichiers il faudra sans doute activer une
        option du genre .

        Enfin, comme vous avez ajouté des fichiers dans le répertoire du
        serveur, il faut reconfigurer les droits des fichiers. Pour ce
        faire, vous double-cliquez sur le lien symbolique qui se trouve
        sur le bureau puis vous vous rendez dans et vous double-cliquez
        sur le fichier (vous devrez saisir le mot de passe du serveur).

    -   **Méthode via la ligne de commandes :** sur la session de restée
        ouverte, vous ouvrez un terminal et vous lancez les commandes
        suivantes :

            # Répertoire du client GNU/Linux à copier sur le serveur.
            SOURCE="/home/toto/.mozilla/"

            # Destination sur le serveur.
            DESTINATION="/home/netlogon/clients-linux/distribs/precise/skel/"

            # Copie du répertoire local (et de tout son contenu) vers le serveur.
            scp -r "$SOURCE" root@IP-SERVEUR:"$DESTINATION"

        À ce stade, le répertoire a bien été copié sur le serveur mais
        les droits Unix sur la copie ne sont pas encore corrects. Pour
        les reconfigurer, il faut exécuter la commande en tant que sur
        le serveur. Là aussi, cela peut se faire directement du client
        GNU/Linux, sans bouger, via ssh avec la commande :

            # Avec ssh, en étant sur le client GNU/Linux, on peut exécuter notre commande
            # à distance sur le serveur tant que root.
            ssh -t root@IP-SERVEUR "dpkg-reconfigure se3-clients-linux"

2.  Modifiez le fichier [^7] du profil par défaut **distant**. Ce
    fichier est un simple fichier texte, vous pouvez le modifier avec un
    simple éditeur. S’il contient la chaîne 1 par exemple, alors
    éditez-le et écrivez 2 à la place. Si vous préférez, vous pouvez
    très bien indiquer la date du moment comme dans Le  à 15h04 . Le but
    est simplement, qu’une fois modifié, le fichier du serveur possède
    un contenu différent de chacun des fichiers locaux aux machines
    clientes. Dans notre exemple, le fichier se trouve dans le
    répertoire du serveur. Là aussi, deux méthodes s’offrent à vous pour
    le modifier :

    -   **La méthode graphique** : si ce n’est pas déjà fait, vous
        fermez la session de pour vous connecter sur le client GNU/Linux
        avec le compte du domaine. Ensuite, vous double-cliquez sur le
        lien symbolique qui se trouve sur le bureau puis vous vous
        rendez successivement dans . Faites en sorte d’activer l’option
        afin de voir apparaître le fichier qui se trouve à l’intérieur
        du dossier . Éditez ce fichier afin simplement de modifier son
        contenu. Bien sûr, pensez à enregistrer la modification. Pas
        besoin ici de reconfigurer les droits car le fait de modifier le
        contenu du fichier ne change pas les droits sur ce fichier qui,
        a priori, étaient déjà corrects.

    -   **Méthode via la ligne de commandes :** sur la session de restée
        ouverte, vous ouvrez un terminal et vous lancez les commandes
        suivantes :

            # Le fichier sur le serveur qu'il faut modifier.
            CIBLE="/home/netlogon/clients-linux/distribs/precise/skel/.VERSION"

            ssh root@IP-SERVEUR "echo Version du 10 janvier 2012 à 15h04 > $CIBLE"
            # Maintenant le fichier contient "Version du 10 janvier 2012 à 15h04".

Dès le prochain affichage de la fenêtre de connexion, les profils par
défaut **locaux** de tous les clients Precise Pangolin seront modifiés
afin d’être identiques au profil par défaut **distant** du serveur. Dès
lors, les utilisateurs bénéficieront des paramétrages de Firefox que
vous avez effectués.

De la même manière que précédemment, sur le profil par défaut
**distant**, vous pouvez parfaitement définir le contenu du bureau des
utilisateurs : au lieu de copier un répertoire sur le serveur, ce sera
un répertoire , mais le principe reste le même.

D’une distribution à une autre, les versions des logiciels n’étant pas
forcément identiques, chaque distribution prise en charge possède son
propre profil par défaut **distant**. Sur le serveur Samba, on a donc :

-   le répertoire pour les Debian Squeeze.

-   le répertoire pour les Ubuntu Precise Pangolin.

Personnaliser le profil en fonction de l’utilisateur {#personnaliser-profil}
----------------------------------------------------

La rigidité de la gestion du profil telle qu’elle est décrite à la
section [modifier-profil] peut cependant être contournée en modifiant le
script de logon[^8]. Pour comprendre cela, poursuivons avec l’exemple de
la modification du profil par défaut de Mozilla. Imaginons que vous
souhaitiez que les enseignants disposent d’un navigateur dont la
configuration diffère de celle à laquelle accèdent les élèves
(extensions particulières, favoris différents, etc.).

Dans ce cas, vous copierez sur le répertoire du serveur le répertoire
après l’avoir renommé en .

Évidemment, dans ce cas, si un enseignant ouvre une session et lance son
navigateur, la configuration prise en compte par le système sera
toujours celle du répertoire . Il faut donc, pour achever ce processus,
modifier le fichier pour qu’au moment de l’ouverture de session, le
répertoire soit remplacé par si et seulement si c’est un(e)
enseignant(e) qui se connecte.

Pour ce faire, vous utiliserez les variables prêtes à l’emploi (voir
section [fonctions-utiles]), et indiquerez dans la fonction les lignes
suivantes:

         # chargement du profil mozilla pour les profs
        if est_dans_liste "$LISTE_GROUPES_LOGIN" "Profs"; then
            rm -rf "$REP_HOME/.mozilla"
            mv "$REP_HOME/.mozilla-prof" "$REP_HOME/.mozilla"
        fi

Ainsi, à l’ouverture de session, si l’utilisateur qui se connecte est
un(e) enseignant(e), le commencera par supprimer le répertoire , puis
renommera en , permettant ainsi au système de prendre en compte ce
répertoire pour la configuration du navigateur.

Vous imaginez la suite: on peut, avec cette méthode, personnaliser la
configuration de tous les logiciels et de l’environnemnet de bureau pour
chaque profil, voire pour chaque utilisateur.

Le répertoire unefois/ {#unefois}
======================

Principe de base
----------------

Si vous souhaitez faire des interventions ponctuelles sur les clients
GNU/Linux sans vous déplacer devant les postes, alors le répertoire du
serveur Samba peut vous intéresser. En effet, des fichiers exécutables
placés dans ce répertoire seront susceptibles d’être lancés une seule
fois sur les clients GNU/Linux lors du démarrage. En pratique, vous
allez créer un sous-répertoire à la racine du répertoire du serveur. Par
exemple :

-   Si le nom de ce sous-répertoire est , alors les exécutables se
    trouvant dans ce sous-répertoire seront lancés une fois au démarrage
    de tous les clients GNU/Linux dont le nom de machine **contient à la
    casse près** la chaîne de caractères .

-   Si le nom de ce sous-répertoire est [^9], alors les exécutables se
    trouvant dans ce sous-répertoire seront lancés une fois au démarrage
    de tous les clients GNU/Linux dont le nom de machine **commence à la
    casse près par** la chaîne de caractères .

-   Si le nom de ce sous-répertoire est , alors les exécutables se
    trouvant dans ce sous-répertoire seront lancés une fois au démarrage
    de tous les clients GNU/Linux dont le nom de machine **se termine à
    la casse près par** la chaîne de caractères .

-   Si le nom de ce sous-répertoire est , alors les exécutables se
    trouvant dans ce sous-répertoire seront lancés une fois au démarrage
    du client GNU/Linux dont le nom de machine **est identique à la
    casse près à** la chaîne de caractères .

Si jamais cela évoque quelque chose pour vous, sachez qu’en réalité le
nom des sous-répertoires est interprété par le client GNU/Linux comme
une [expression régulière
étendue](http://fr.wikipedia.org/wiki/Expression_rationnelle). Vous
pouvez donc choisir comme nom de sous-répertoire n’importe quelle
expression régulière étendue pour filtrer les noms de machines qui sont
censées exécuter une fois vos scripts ou vos fichiers binaires.

Voici un dernier exemple de nom de sous-répertoire possible (et donc
d’expression régulière possible) : (le nom de ce sous-répertoire est
constitué d’un accent circonflexe puis d’un point). Cette expression
régulière signifie : n’importe quelle chaîne de caractères qui commence
par un caractère quelconque . Autrement dit, les exécutables se trouvant
dans ce sous-répertoire seront lancés une fois au démarrage de **tous
les clients GNU/Linux sans exception**. Bien sûr, le répertoire du
serveur peut parfaitement contenir plusieurs sous-répertoires. Dans ce
cas, si le nom de machine d’un client correspond par exemple avec trois
noms de sous-répertoires , et , alors le client devra lancer une seule
fois au démarrage tous les exécutables contenus dans chacun des
sous-répertoires , et .

Après avoir créé vos sous-répertoires et vos fichiers exécutables dans
le répertoire du serveur, n’oubliez pas de réajuster les droits sur les
fichiers comme expliqué à la section [reconfigurer-droits] page .

Attention, les fichiers exécutables d’un sous-répertoire donné doivent
vérifier certains critères :

-   Le nom d’un exécutable **ne doit pas commencer par un point**.

-   Le nom d’un exécutable **doit se terminer par ** (comme dans ).

-   Si le fichier exécutable est un script (autrement dit si ce n’est
    pas un fichier binaire), **il doit impérativement comporter un
    shebang**[^10] : cela peut-être un script Bash, Perl, Python peu
    importe (du moment que l’interpréteur du langage est installé sur
    les clients GNU/Linux) mais il faut que le shebang soit présent.

**Le critère pour que les clients GNU/Linux se souviennent d’avoir
exécuté un fichier donné (afin de l’exécuter une seule fois) est le nom
de ce fichier** et rien que le nom (pas le contenu). Par exemple, si un
client GNU/Linux a exécuté le script , alors ce client n’exécutera plus
jamais[^11] de fichier s’appellant . Si vous avez un script que vous
souhaitez exécuter non pas une seule fois, mais quelques fois de manière
très ponctuelle (une fois par an par exemple), pensez à insérer la date
du jour dans le nom du script (comme dans ) et le cas échéant, en
modifiant la date dans le nom du fichier (par exemple en le renommant ),
celui-ci sera à nouveau candidat à l’exécution du côté des clients
GNU/Linux.

Le mécanisme en détail
----------------------

Voici le mécanisme effectué par les clients GNU/Linux au niveau du
répertoire **au moment du démarrage du système** uniquement (le
démarrage est le seul instant où les clients GNU/Linux se préoccupent du
répertoire ) :

1.  Le client regarde le contenu de tous les sous-répertoires de [^12]
    dont les noms correspondent à son nom de machine. Par exemple, si le
    client s’appelle , il va regarder le contenu du sous-répertoire mais
    il va ignorer le sous-répertoire . Dans chaque sous-répertoire qu’il
    n’a pas ignoré (s’il en existe), le client va y chercher tous les
    fichiers de la forme , afin d’obtenir toute une liste
    (éventuellement vide) de fichier .

2.  Si, dans cette liste de fichiers , certains noms figurent déjà dans
    le répertoire local , c’est que les fichiers en question ont déjà
    été exécutés par le client GNU/Linux et ils ne le sont donc pas une
    deuxième fois. En revanche, les fichiers de cette liste dont le
    nom[^13] ne figure pas dans sont copiés dans ce répertoire local
    puis les copies locales sont exécutées.

C’est donc le répertoire qui constitue la mémoire du client GNU/Linux :
il contient la liste des noms de fichiers déjà exécutés. Il y a
toutefois deux exceptions au mécanisme décrit ci-dessus :

1.  Au moment du démarrage du système, si le client détecte la présence
    d’un fichier nommé [^14] à la racine du répertoire , alors le client
    ne fait strictement rien au niveau des fichiers et donc il n’exécute
    absolument rien, quoi qu’il arrive.

2.  Au moment du démarrage du système, si le client ne repère pas la
    présence du fichier précédent mais qu’en revanche il détecte la
    présence du fichier [^15], toujours à la racine du répertoire local
    , alors le client GNU/Linux efface le contenu du répertoire . Ainsi,
    au prochain démarrage, si les fichiers et ne sont pas présents, le
    client exécutera tous les exécutables qui le concerne, peu importe
    leur nom étant donné que la mémoire du client GNU/Linux concernant
    tout ce qui a déjà été exécuté a été effacée.

Au moment du démarrage, la recherche par les clients GNU/Linux des
fichiers à exécuter (ainsi que leur copie en local le cas échéant)
entraîne(nt) forcément du trafic réseau. Lorsque vous ne souhaitez pas
faire usage de ce mécanisme (ce qui en principe sera le cas $90\%$ du
temps), n’hésitez pas à placer le fichier à la racine du répertoire du
serveur afin d’éviter ce travail de recherche aux clients GNU/Linux qui
solliciteraient inutilement le réseau.

Là encore, lorsque vous créerez ce fichier , attention de bien
reconfigurer les droits des fichiers comme expliqué à
section [reconfigurer-droits] page .

Les scripts sont tous exécutés, en tant que , **en arrière-plan** et
cela dès l’affichage de la fenêtre de connexion lors du démarrage. Si
vous souhaitez qu’un script se lance un peu après (parce que, par
exemple, vous avez besoin d’attendre que certains services soient
lancés), vous pouvez parfaitement utiliser des instructions comme afin
de forcer le script à attendre pendant $20$ secondes avant de commencer
réellement son travail. Enfin sachez que dans le répertoire local ,
chaque exécutable est accompagné de son homologue nommé qui contient
simplement l’ensemble des messages (d’erreur ou non) du fichier
l’exécutable.

Réglage de la locale durant l’exécution des scripts unefois 
------------------------------------------------------------

Avant de déployer un script bash via le répertoire du serveur, il sera
sans doute nécessaire de le tester sur un client localement. Sachez que
les scripts bash, lorsqu’ils sont exécutés par le client GNU/Linux au
démarrage, ont la variable d’environnement définie comme étant égale à
[^16] et non pas égale à . Cela implique que tous les messages de sortie
des commandes système lancées dans le script seront en anglais avec des
caractères ASCII uniquement. Pour avoir une idée de l’influence de la
locale sur les commandes système, vous pouvez ouvrir un terminal bash et
tester ceci :

    # On paramètre le terminal sur une locale française qui doit être très
    # probablement la locale par défaut déjà définie sur votre système.
    export LC_ALL="fr_FR.utf8"
    # Puis on teste une commande. En principe, l'entête du résultat de la
    # commande est en français.
    df -h

    # Maintenant, on paramètre le terminal sur la locale C.
    export LC_ALL="C"

    # Et on teste à nouveau la même commande. Cette fois-ci, l'entête du
    # résultat de la commande est en anglais.
    df -h

Par conséquent, si jamais vous souhaitez exploiter le résultat de
certaines commandes système dans vos scripts bash , sachez que la locale
peut avoir une incidence sur le comportement du script. Si jamais vous
tenez à avoir une locale française lors de l’exécution de votre script,
alors il vous suffit de placer juste en dessous du shebang l’instruction
:

    export LC_ALL="fr_FR.utf8"

En revanche, si vous ne souhaitez pas forcer le réglage sur une locale
particulière et préférez conserver la valeur par défaut (avec la locale
standard ), alors durant vos tests afin de valider un script bash à
déployer, il faudra le lancer de la manière suivante :

    LC_ALL="C" ./monscript.bash.unefois

De cette manière, le script héritera de la locale et il se comportera de
la même manière que lors d’une exécution via le mécanisme unefois .
Alors que si vous lancez le script ainsi :

    ./monscript.bash.unefois

celui-ci hériterait de la locale du système, qui est très probablement ,
et il se comporterait légèrement différemment que lors d’une exécution
via la mécanisme unefois , si bien que vos tests seraient légèrement
biaisés.

Des variables et des fonctions prêtes à l’emploi
------------------------------------------------

Si jamais vous utilisez le langage Bash pour écrire des script de la
forme , vous pouvez alors utiliser certaines variables ou fonctions
prédéfinies qui pourront peut-être vous faciliter le travail d’écriture
des scripts. Voici tableau listant toutes ces variables et fonctions :

<span>|\>c|\>m<span>0.7</span>|</span> **Nom & **Commentaire ****

[tableau-unefois] & Cette variable stocke l’adresse IP du serveur
récupérée automatiquement lors de l’installation du paquet .\
 & Cette variable stocke ce qu’on appelle le nom de code de la
distribution ( dans le cas d’une Debian Squeeze, dans le cas d’une
Ubuntu Precise Pangolin etc).\
 & Cette variable stocke l’architecture du système. Par exemple, si le
système repose sur une architecture $64$ bits, alors la variable
stockera la chaîne de caractères .\
 & Cette variable contient le suffixe de base LDAP de l’annuaire du
serveur. Elle pourra vous être utile si vous souhaitez faire vous-même
des requêtes LDAP particulières sur les clients à l’aide de la commande
.\
 & Cette variable stocke le nom du client GNU/Linux (celui qui se trouve
dans le fichier de configuration ). Par exemple, si vous avez pris
l’habitude de choisir des noms de machines de la forme (comme dans ou
même comme dans ), alors vous pourrez récupérer le nom de la salle où se
trouve le client GNU/Linux par l’intermédiaire de la variable comme ceci
:

    SALLE=$(echo "$NOM_HOTE" | cut -d'-' -f1)

    if [ "$SALLE" = "S121" ]; then
       # Les trucs à faire si on est dans la salle 121.
    fi

    if [ "$SALLE" = "S18" ]; then
       # Les trucs à faire si on est dans la salle 18.
    fi
    # etc.

\
 & Cette fonction permet de savoir si une machine appartient à un parc
donné. Pour ce faire, la fonction interroge l’annuaire du serveur via
une requête LDAP. Voici un exemple d’utilisation :

    if appartient_au_parc "S121" "$NOM_HOTE"; then
       # La machine appartient au parc S121
    else
       # La machine n'appartient pas au parc S121
    fi

\
 & Un exemple vaudra mieux qu’un long discours :

    liste_parcs=$(afficher_liste_parcs "S121-LS-P")

Dans cet exemple, la fonction effectue une requête LDAP auprès du
serveur afin de connaître le nom de tous les parcs auxquels appartient
la machine . Si la machine appartient aux parcs et , alors la variable
contiendra deux lignes, la première contenant et la deuxième contenant .
L’idée est de stocker tous les parcs d’une machine dans une variable, le
tout en une seule requête LDAP. Enfin, à la place de comme argument de
la fonction, on aurait pu utiliser , comme dans l’exemple ci-dessous qui
sera plus éclairant sur la manière dont on peut exploiter de telles
listes.\
 & Là aussi, illustrons cette fonction par un exemple :

    # On récupère la liste des parcs auxquels 
    # appartient la machine cliente.
    liste_parcs=$(afficher_liste_parcs "$NOM_HOTE")

    if est_dans_liste "$liste_parcs" "PostesProfs"; then
        # Si la machine est dans le parc "PostesProfs"
        # alors faire ceci...
    elif est_dans_liste "$liste_parcs" "CDI"; then
        # Si la machine est dans le parc "CDI" 
        # alors faire ceci...
    else
        # Sinon faire cela...
    fi

L’idée ici est qu’une seule requête LDAP est effectuée (lors de la
première instruction). Ensuite, les tests ne sollicitent pas le réseau
puisque la liste des parcs est déjà stockée dans la variable .\
\
\
\
 & Cette fonction permet de savoir si le login d’un utilisateur
correspond à un compte qui appartient à un groupe donné. Pour ce faire,
la fonction interroge l’annuaire du serveur via une requête LDAP. Voici
un exemple :

    if appartient_au_groupe "Classe_1ES2" "toto"; then
       # Le compte toto appartient à la classe 1ES2.
    else
       # Le compte toto n'appartient pas à la classe 1ES2.
    fi

\
 & Un exemple vaudra mieux qu’un long discours :

    liste_groupes_toto=$(afficher_liste_groupes "toto")
    if est_dans_liste "$liste_groupes_toto" "Eleves"; then
        # toto est un élève alors faire ceci...
    fi

Dans cet exemple, la fonction effectue une requête LDAP auprès du
serveur afin de connaître le nom des groupes auxquels compte utilisateur
appartient. Si par exemple ce compte appartient aux groupes et , alors
la variable contiendra deux lignes, la première contenant et la deuxième
contenant . L’idée est de stocker tous les groupes d’un compte donné
dans une variable, le tout en une seule requête LDAP.\
 & Cette fonction permet de tester si un compte est local (c’est-à-dire
contenu dans le fichier du client GNU/Linux) ou non (c’est-à-dire un
compte du domaine contenu dans l’annuaire du serveur).

    if est_utilisateur_local "toto"; then
        # toto est un compte local, alors faire ceci...
    fi

\
 & Cette fonction permet de tester si un compte est actuellement
connecté au système (c’est-à-dire s’il a ouvert une session).

    if est_connecte "toto"; then
        # toto est actuellement connecté au système,
        # alors faire ceci...
    fi

\
 & Cette fonction, qui ne prend pas d’argument, permet simplement
d’activer le pavé numérique du client GNU/Linux.\

Le script de logon {#logon-script}
==================

Phases d’exécution du script de logon {#phase}
-------------------------------------

Le script de logon est un script bash qui est exécuté par les clients
GNU/Linux lors de trois phases différentes. Pour plus de commodité dans
les explications, nous allons donner un nom à chacune de ces trois
phases une bonne fois pour toutes :

1.  **L’initialisation :** cette phase se produit juste avant
    l’affichage de la fenêtre de connexion. Attention, cela correspond
    en particulier au démarrage du système, certes, mais pas seulement.
    L’initialisation se produit aussi juste après la fermeture de
    session d’un utilisateur, avant que la fenêtre de connexion
    n’apparaisse à nouveau (sauf si, bien sûr, l’utilisateur a choisi
    d’éteindre ou de redémarrer la machine). [initialisation]

    **Description rapide des tâches exécutées par le script lors de
    cette phase :** le script efface les homes (s’il en existe) de tous
    utilisateurs qui ne correspondent pas à des comptes locaux[^17],
    vérifie si le partage CIFS du serveur est bien monté sur le
    répertoire du client GNU/Linux et, si ce n’est pas le cas, le script
    exécute ce montage. Ensuite, le cas écheant, le script procède à la
    synchronisation du profil par défaut local sur le profil par défaut
    distant et lance les exécutions des si l’initialisation correspond
    en fait à un redémarrage du système.

2.  **L’ouverture :** cette phase se produit à l’ouverture de session
    d’un utilisateur juste après que celui-ci ait saisi ses
    identifiants. [ouverture]

    **Description rapide des tâches exécutées par le script lors de
    cette phase :** le script procède à la création du home de
    l’utilisateur qui se connecte (via une copie du profil par défaut
    local), exécute le montage de certains partages du serveur auxquels
    l’utilisateur peut prétendre (comme par exemple le partage
    correspondant aux données personnelles de l’utilisateur).

3.  **La fermeture :** cette phase se produit à la fermeture de session
    d’un utilisateur. [fermeture]

    **Description rapide des tâches exécutées par le script lors de
    cette phase :** le script ne fait rien qui mérite d’être signalé
    dans cette documentation.

Comme vous pouvez le constater, le script de logon est un peu le chef
d’orchestre de chacun des clients GNU/Linux.

Emplacement du script de logon
------------------------------

À la base, le script de logon se trouve localement à l’adresse de chaque
client GNU/Linux. Mais il existe une version centralisée de ce script
sur le serveur à l’adresse :

1.  si on est sur le serveur

2.  si on est sur un client GNU/Linux

Nous avons donc, comme pour le profil par défaut, des versions locales
du script de logon (sur chaque client GNU/Linux) et une unique version
distante (sur le serveur). Et au niveau de la synchronisation, les
choses fonctionnent de manière très similaire aux profils par défaut.
**Lors de l’initialisation d’un client GNU/Linux** :

-   Si le contenu du script de logon local est identique au contenu du
    script de logon distant, alors c’est le script de logon local qui
    est exécuté par le client GNU/Linux.

-   Si en revanche les contenus diffèrent (ne serait-ce que d’un seul
    caractère), alors c’est le script de logon distant qui est exécuté.
    Mais dans la foulée, le script de logon local est écrasé puis
    remplacé par une copie de la version distante. Du coup, il est très
    probable qu’à la prochaine initialisation du client GNU/Linux ce
    soit à nouveau le script de logon local qui soit exécuté parce que
    identique à la version distante (on retombe dans le cas précédent).

A priori, cela signifie donc que, pour peu que vous sachiez parler (et
écrire) le langage du script de logon (il s’agit du Bash), vous pouvez
modifier **uniquement** le script de logon distant (celui du serveur
donc) afin de l’adapter à vos besoins. Vos modifications seraient alors
impactées sur **tous les clients** GNU/Linux dès la prochaine phase
d’initialisation. Seulement, **il ne faudra pas procéder ainsi** et cela
pour une raison simple : après la moindre mise à jour du paquet ou
éventuellement après une réinstallation, toutes vos modifications sur le
script de logon seront effacées. Pour pouvoir modifier le comportement
du script de logon de manière pérenne, il faudra utiliser le fichier qui
se trouve dans le même répertoire que le script de logon.

Personnaliser le script de logon {#personnalisation}
--------------------------------

Le fichier va vous permettre d’affiner le comportement du script de
logon afin de l’adapter à vos besoins, et cela de manière pérenne dans
le temps (les modifications persisteront notamment après une mise à jour
du paquet ). À la base, le fichier est un fichier texte encodé en UTF-8
avec des fins de ligne de type Unix[^18]. Il contient du code bash et
possède, par défaut, la structure suivante :

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

Ce code sera ni plus ni moins inclus, tel quel, dans le script de logon.
En fait, après une modification du fichier , il faudra donc **toujours**
penser à reconfigurer le paquet comme décrit dans la
section [reconfigurer-droits] page  ce qui aura pour effet, entre
autres, d’insérer le contenu de la nouvelle version de dans le fichier .
Si vous oubliez de faire cette manipulation après modification du
fichier , le fichier sera inchangé et vos modifications ne seront tout
simplement pas prises en compte.

**Procédure à suivre quand on modifie le fichier **

Pour modifier le script de logon afin de l’adapter à vos besoins, vous
devez :

1.  Modifier le fichier .

2.  Puis lancer la reconfiguration du paquet en effectuant une des deux
    procédures décrites dans la section [reconfigurer-droits] page ,
    afin que le contenu de la nouvelle version de soit inséré dans le
    fichier .

Revenons au contenu du fichier pour comprendre de quelle manière il
permet de modifier le comportement du script . Dans le fichier , on peut
distinguer trois fonctions :

1.  Tout le code que vous mettrez dans la fonction sera exécuté lors de
    la phase d’initialisation des clients, **en dernier**, c’est-à-dire
    après que le script de logon ait effectué toutes les tâches liées à
    la phase d’initialisation qui sont décrites brièvement au point
    [initialisation] de la section [phase].

2.  Tout le code que vous mettrez dans la fonction sera exécuté lors de
    la phase d’ouverture des clients uniquement lorsqu’un utilisateur du
    domaine se connecte. Le code est exécuté **juste après** la création
    du home de l’utilisateur qui se connecte. Typiquement, c’est dans
    cette fonction que vous allez gérer les montages de partages réseau
    en fonction du type de compte qui se connecte (son appartenance à
    tel ou tel groupe etc).

    Pour la gestion des montages de partages réseau à l’ouverture de
    session, tout se trouve à la section [gestion-montage] page .

3.  Tout le code que vous mettrez dans la fonction sera exécuté lors de
    la phase de fermeture des clients, **en dernier**, c’est-à-dire
    après que le script de logon ait effectué toutes les tâches liées à
    la phase de fermeture qui sont décrites brièvement au point
    [fermeture] de la section [phase].

Vous pouvez bien sûr définir dans le fichier des fonctions
supplémentaires, mais, pour que celles-ci soient au bout du compte
exécutées par le script de logon, il faudra les appeler dans le corps
d’une des trois fonctions , ou .

Il faut bien avoir en tête que le contenu de est ni plus ni moins inséré
dans le script et donc, après modification de , il faut toujours mettre
à jour le fichier via la commande .

Quelques variables et fonctions prêtes à l’emploi {#fonctions-utiles}
-------------------------------------------------

Voici la liste des variables et des fonctions que vous pourrez utiliser
dans le fichier et qui seront susceptibles de vous aider à affiner le
comportement du script de logon :

<span>|\>c|\>m<span>0.7</span>|</span> **Nom & **Commentaire ****

\
\
\
 & Cette variable stocke le login de l’utilisateur qui a ouvert une
session. Cette variable n’a de sens que lors de la phase d’ouverture et
de fermeture (c’est-à-dire uniquement à l’intérieur des fonctions et ),
pas lors de la phase d’initialisation (c’est-à-dire à l’intérieur de la
fonction ) puisque personne n’a encore ouvert de session à ce moment
là.\
 & Cette variable stocke le nom complet (sous la forme prénom nom ) de
l’utilisateur qui a ouvert une session. Cette variable n’a de sens que
lors de la phase d’ouverture et de fermeture.\
 & Cette variable stocke le chemin absolu du répertoire home de
l’utilisateur qui se connecte. Par exemple, si le compte ouvre une
session, la variable contiendra la chaîne . Remarquez que cette variable
est un simple raccourci pour écrire . Cette variable n’a de sens que
lors de la phase d’ouverture et de fermeture.\
 & Cette variable, qui n’a de sens **que lors de la phase d’ouverture**,
stocke la liste des groupes auxquels appartient l’utilisateur qui a
ouvert une session (le format étant un nom de groupe par ligne). Une
utilisation typique de cette variable est :

    if est_dans_liste "$LISTE_GROUPES_LOGIN" "Profs"; then
        # L'utilisateur qui se connecte appartient au
        # groupe Profs, alors faire ceci...
    elif est_dans_liste "$LISTE_GROUPES_LOGIN" "Eleves"; then
        # L'utilisateur qui se connecte appartient au
        # groupe Eleves, alors faire cela...
    fi

Au passage, dans ce code, aucune requête LDAP n’est effectuée puisque la
variable contient déjà la liste des groupes auxquels appartient
l’utilisateur qui vient de se connecter (la requête LDAP permettant de
définir la variable a été faite par le script de logon en amont, une
fois pour toute).\
 & Cette variable stocke toujours la valeur , sauf lorsqu’on se trouve
lors d’une phase d’initialisation qui correspond à un démarrage du
système où elle stocke alors la valeur . Cette variable n’a donc
d’intérêt que lorsqu’elle est utilisée dans la fonction . Voici un
exemple :

    if "$DEMARRAGE"; then
        # On est lors d'une phase de démarrage
        # alors faire ceci...
    fi

\
 & Si vous voulez que les utilisateurs du domaine puissent avoir accès à
des partages réseau sur le serveur, il faudra forcément faire usage de
cette fonction qui est donc très importante. Toutes les explications sur
cette fonction se trouvent à la section [gestion-montage] page . Cette
fonction n’a de sens que lors de la phase d’ouverture.\
 & Cette fonction, qui va de pair avec la précédente, sera détaillée à
la section [gestion-montage] page . Cette fonction n’a de sens que lors
de la phase d’ouverture.\
 & Cette fonction sera détaillée à la section [changer-icone] page .
Cette fonction n’a de sens que lors de la phase d’ouverture.\
 & Cette fonction, utilisable uniquement pendant la phase d’ouverture,
permet de changer le fond d’écran de l’utilisateur qui se connecte. Elle
prend un argument qui correspond au chemin absolu (sur le client) du
fichier image à utiliser en guise de fond d’écran. Un exemple de
l’utilisation de cette fonction sera donné à la section [papier-peint]
page .\
 & Cette fonction, qui fait exactement ce à quoi on pense naturellement,
sera détaillée à la section [pave-num] page .\
 & Parfois certaines commandes nécessitent d’être exécutées un fois le
script de logon terminé (c’est-à-dire une fois l’initialisation,
l’ouverture ou la fermeture terminée). C’est ce que permet cette
fonction. Avec par exemple :

    executer_a_la_fin "5" "commande" "arg1" "arg2"

la commande (avec ses arguments) sera lancée 5 secondes après que le
script de logon ait terminé son exécution. Un exemple de l’usage de
cette fonction sera donné à la section [conky] page . Attention,
l’exécution se faisant une fois le script de logon terminé, il y aura
aucune trace dans les fichiers de log de l’exécution de la commande .\

Gestion du montage des partages réseau {#gestion-montage}
--------------------------------------

Comme cela a déjà été expliqué, c’est vous qui allez gérer les montages
de partages réseau en éditant le contenu de la fonction qui se trouve
dans le fichier . Évidemment, si la gestion par défaut des montages vous
convient telle quelle, alors vous n’avez pas besoin de toucher à ce
fichier. Commençons par un exemple simple :

    function ouverture_perso ()
    {
        monter_partage "//$SE3/Classes" "Classes" "$REP_HOME/Bureau/Répertoire Classes"
    }

Ici la fonction possède trois **arguments qui devront être délimités par
des doubles quotes** () :

1.  Le premier représente le chemin UNC du partage à monter. Vous
    reconnaissez sans doute la variable qui stocke l’adresse IP du
    serveur. Par exemple si l’adresse IP du serveur est , alors le
    premier argument sera automatiquement développé en :

    .

    Cela signifie que c’est le partage du serveur qui va être monté sur
    le clients GNU/Linux. Attention, sous GNU/Linux un chemin UNC de
    partage s’écrit avec des slashs () et non avec des antislashs ()
    comme c’est le cas sous Windows.

2.  Maintenant, il faut un répertoire local pour monter un partage.
    C’est le rôle du deuxième argument. Quoi qu’il arrive (vous n’avez
    pas le choix sur ce point), le partage sera monté dans un
    sous-répertoire du répertoire . Par exemple si c’est qui se connecte
    sur le poste client, le montage sera fait dans un sous répertoire de
    . Le deuxième argument spécifie le nom de ce sous-répertoire. Ici
    nous avons décidé assez logiquement de l’appeler . Par conséquent,
    en visitant le répertoire sur le poste client, notre cher aura accès
    au contenu du partage du serveur.

    Attention, dans le choix du nom de ce sous-répertoire, vous êtes
    limité(e) aux **caractères a-z, A-Z, 0-9, le tiret () et le tiret
    bas ()**. C’est tout. En particulier **pas d’espace ni accent**. Si
    vous ne respectez pas cette consigne le partage ne sera tout
    simplement pas monté et une fenêtre d’erreur s’affichera à
    l’ouverture de session.

    Vous serez sans doute amené(e) à monter plusieurs partages réseau
    pour un même utilisateur (via plusieurs appels de la fonction au
    sein de la fonction ). Donc il y aura plusieurs sous-répertoires
    dans . Charge à vous d’éviter les doublons dans les noms des
    sous-répertoires, sans quoi certains partages ne seront pas montés.

3.  À ce stade, notre cher pourra accéder au partage du serveur en
    passant par . Mais cela n’est pas très pratique. L’idéal serait
    d’avoir accès à ce partage directement via un dossier sur le bureau
    de . C’est exactement ce que fait le troisième argument. Si ouvre
    une session, l’argument va se développer en si bien qu’un raccourci
    (sous GNU/Linux on appelle ça un lien symbolique) portant le nom
    sera créé sur le bureau de . Donc en double-cliquant sur ce
    raccourci (vous pouvez voir à la page  via une capture d’écran que
    ce genre de raccourci ressemble à un simple dossier), sans même le
    savoir, visitera le répertoire qui correspondra au contenu du
    partage du serveur. Vous n’êtes pas limité(e) dans le choix du nom
    de ce raccourci. Les espaces et les accents sont parfaitement
    autorisés (évitez par contre le caractère double-quote). En
    revanche, ce raccourci doit forcément être créé dans le home de
    l’utilisateur qui se connecte. **Donc ce troisième argument devra
    toujours commencer par ** sans quoi le lien ne sera tout simplement
    pas créé.

Tout n’a pas encore été dévoilé concernant cette fonction . En fait,
vous pouvez créer autant de raccourcis que vous voulez. Il suffit pour
cela d’ajouter un quatrième argument, puis un cinquième , puis un
sixième etc. Voici un exemple :

    function ouverture_perso ()
    {
        monter_partage "//$SE3/Classes" "Classes" \ENTREE
            "$REP_HOME/Bureau/Lecteur réseau Classes" \ENTREE
            "$REP_HOME/Lecteur réseau Classes"
    }

normalement il faut mettre une fonction avec ses arguments sur une même
ligne car un saut de ligne signifie la fin d’une instruction aux yeux de
l’interpréteur Bash. Mais ici la ligne serait bien longue à écrire et
dépasserait la largeur de la page de ce document. La combinaison
antislash () puis ENTRÉE permet simplement de passer à la ligne tout en
signifiant à l’interpréteur Bash que l’instruction entamée n’est pas
terminée et qu’elle se prolonge sur la ligne suivante.

Le premier argument correspond toujours au chemin UNC du partage réseau
et le deuxième argument au nom du sous-répertoire dans associé à ce
partage. Ensuite, nous avons cette fois-ci un troisième **et un
quatrième argument** qui correspondent aux raccourcis pointant vers le
partage : l’un est créé sur le bureau et l’autre est créé à la racine du
home de l’utilisateur qui se connecte. Il est possible de créer autant
de raccourcis que l’on souhaite, il suffit d’empiler les arguments $3$,
$4$, $5$ etc. les uns à la suite des autres.

La syntaxe de la fonction est donc la suivante :

    monter_partage "<partage>" "<répertoire>" ["<raccourci>"]...

où seuls les deux premiers arguments sont obligatoires :

-   est le chemin UNC du partage à monter. Il est possible de se limiter
    à un sous-répertoire du partage, par exemple comme dans où l’on
    montera uniquement le sous-répertoire du partage du serveur.

-   est le nom du sous-répertoire de qui sera créé et sur lequel le
    partage sera monté. Seuls les caractères sont autorisés.

-   Les arguments sont optionnels. Ils représentent les chemins absolus
    des raccourcis qui seront créés et qui pointeront vers le partage.
    Ils doivent toujours se situer dans le home de l’utilisateur qui se
    connecte, donc ils doivent toujours commencer par . Si ces arguments
    ne sont pas présents, alors le partage sera monté mais aucun
    raccourci ne sera créé.

Attention, le montage du partage réseau se fait avec les droits de
l’utilisateur qui est en train de se connecter. Si l’utilisateur n’a pas
les droits suffisants pour accéder à ce partage, ce dernier ne sera tout
simplement pas monté.

au final, si vous placez bien vos raccourcis, l’utilisateur n’aura que
faire du répertoire . Il utilisera uniquement les raccourcis qui se
trouvent dans son home. Peu importe pour lui de savoir qu’ils pointent
en réalité vers un sous-répertoire de , il n’a pas à s’en préoccuper.

je vous conseille de toujours créer au moins un raccourci à la racine du
home de l’utilisateur qui se connecte. En effet, lorsqu’un utilisateur
souhaite enregistrer un fichier via une application quelconque, très
souvent l’explorateur de fichiers s’ouvre au départ à la racine de son
home. C’est donc un endroit privilégié pour placer les raccourcis vers
les partages réseau. Il me semble que doubler les raccourcis à la fois à
la racine du home et sur le bureau de l’utilisateur est une bonne chose.
Mais bien sûr, tout cela est une question de goût...

Étant donné que le montage d’un partage se fait avec les droits de
l’utilisateur qui se connecte, certains partages devront être montés
uniquement dans certains cas. Prenons l’exemple du partage du serveur.
Celui-ci n’est accessible qu’au compte du domaine. Pour pouvoir monter
ce partage seulement quand c’est le compte qui se connecte, il va
falloir ajouter ce bout de code dans la fonction du fichier :

    function ouverture_perso ()
    {
        # Montage du partage "netlogon-linux" seulement dans le cas 
        # où c'est le compte "admin" qui se connecte.
        if [ "$LOGIN" = "admin" ]; then
            # Cette partie là ne sera exécutée qui si c'est admin qui se connecte.
            monter_partage "//$SE3/netlogon-linux" "clients-linux" \ENTREE
                "$REP_HOME/clients-linux" \ENTREE
                "$REP_HOME/Bureau/clients-linux"
        fi
    }

attention, en Bash, le crochet ouvrant au niveau du doit absolument être
précédé et suivi d’un espace et le crochet fermant doit absolument être
précédé d’un espace.

Autre cas très classique, celui d’un partage **accessible uniquement à
un groupe**. Là aussi, une structure avec un s’impose :

    function ouverture_perso ()
    {
        # On décide que le montage du partage "administration" sera seulement effectué si
        # c'est un compte qui appartient au groupe "Profs" qui se connecte.
        if est_dans_liste "$LISTE_GROUPES_LOGIN" "Profs"; then
            monter_partage "//$SE3/administration" "administration" \ENTREE
                "$REP_HOME/administration sur le réseau" \ENTREE
                "$REP_HOME/Bureau/administration sur le réseau"
        fi
    }

L’instruction doit s’interpréter ainsi : si dans la liste des groupes
dont est membre le compte qui se connecte actuellement il y a le groupe
, autrement dit si le compte qui se connecte actuellement appartient au
groupe , alors...

Attention, le test ci-dessus est sensible à la casse si bien que le
résultat ne sera pas le même si vous mettez ou . Par conséquent, prenez
bien la peine de regarder le nom du groupe qui vous intéresse avant de
l’insérer dans un test comme ci-dessus afin de bien respecter les
minuscules et les majuscules.

Si vous voulez savoir le nom des partages disponibles pour un
utilisateur donné, par exemple , il vous suffit de lancer la commande
suivante sur le serveur en tant que :

    smbclient --list localhost -U toto
    # Il faudra alors saisir le mot de passe de toto.

Parmi la liste des partages, l’un d’eux est affiché sous le nom de . Il
correspond au home de sur le serveur. Ce partage est un peu particulier
car il pointera vers un répertoire différent en fonction du compte qui
tente d’y accéder. Par exemple, si veut accéder à ce partage, alors il
sera rédirigé vers le répertoire du serveur. Chaque utilisateur a le
droit de monter ce partage, mais attention le chemin UNC est en fait
(avec un s à la fin et d’ailleurs dans le fichier de configuration Samba
ce partage est bien défini par la section ). A priori, on pourra monter
ce partage pour tous les comptes du domaine donc pas besoin de structure
pour ce partage :

    function ouverture_perso ()
    {
        # Montage du sous-répertoire "Docs" du partage "homes" pour tout le monde.
        monter_partage "//$SE3/homes/Docs" "Docs" \ENTREE
            "$REP_HOME/Documents de $LOGIN sur le réseau" \ENTREE
            "$REP_HOME/Bureau/Documents de $LOGIN sur le réseau"
    }

Dans l’exemple ci-dessus, on ne monte pas le partage mais uniquement le
sous-répertoire de ce partage. Comme d’habitude sous GNU/Linux,
respectez bien la casse des noms de partages et de répertoires.

Pour l’instant, de par la manière dont la fonction est définie, on peut
créer uniquement des liens qui pointent vers la racine du partage
associé. Mais on peut vouloir par exemple monter un partage et créer des
liens uniquement vers des sous-répertoires de ce partage (et non vers sa
racine). C’est tout à fait possible avec la fonction . Voici un exemple
:

    function ouverture_perso ()
    {
        # Montage du partage "homes" pour tout le monde, mais ici on ne créé pas de
        # lien vers la racine de ce partage (appel de la fonction avec seulement deux
        # arguments).
        monter_partage "//$SE3/homes" "home"
        
        # Ensuite on crée des liens mais ceux-ci ne pointent pas à la racine du partage.
        creer_lien "home/Docs" "$REP_HOME/Documents de $LOGIN sur le réseau"
        creer_lien "home/Bureau" "$REP_HOME/Bureau de $LOGIN sous Windows"
    }

Le premier argument de la fonction est la cible du ou des liens à créer.
Cette cible peut s’écrire sous la forme d’un chemin absolu, c’est-a-dire
un chemin qui commence par un antislash (ce qui n’est pas le cas
ci-dessus). Si le chemin ne commence pas par un antislash, alors la
fonction part du principe que c’est un chemin relatif qui part de [^19].
Ensuite, le deuxième argument et les suivants (autant qu’on veut) sont
les chemins absolus du ou des liens qui seront créés. Ces chemins
doivent impérativement tous commencer par .

Quelques bricoles pour les perfectionnistes
-------------------------------------------

### Changer les icônes représentants les liens pour faire plus joli {#changer-icone}

C’est quand même plus joli quand on a des icônes évocateurs[^20] comme
ci-dessous pour nos liens vers les partages, non ?

![image](icones_jolis1) [captureic]

Et bien ça tombe bien car c’est facile à faire avec la fonction . Voici
un exemple :

    function ouverture_perso ()
    {
        # On suppose que le partage "Classe" est déjà monté et qu'un
        # lien vers ce partage a déjà été créé sur le bureau...
        changer_icone "$REP_HOME/Bureau/Classes sur le réseau" \ENTREE
                      "$REP_HOME/.mes_icones/classe.jpg"
    }

La fonction prend toujours deux arguments. Le premier est le chemin
absolu du fichier dont on veut changer l’icône. Cela peut être n’importe
quel fichier (ce n’est pas forcément un des raccourcis qu’on a créé),
mais par contre il doit impérativement se trouver dans le home de
l’utilisateur qui se connecte (donc il devra toujours commencer par ).
Ensuite, le deuxième argument est le chemin absolu de n’importe quel
fichier image (du moment que le compte qui se connecte peut y avoir
accès en lecture).

Une idée possible (parmi d’autres) est de modifier le profil par défaut
des d’utilisateurs et d’y placer un répertoire dans lequel vous mettez
tous les icônes dont vous avez besoin pour habiller vos liens. Ensuite,
vous pourrez aller chercher vos icônes dans le home de l’utilisateur qui
se connecte (dans précisément) de manière similaire à ce qui est fait
dans exemple ci-dessus.

Attention, la fonction n’a aucun effet sous la distribution Xubuntu qui
utilise l’environnement de bureau Xfce. Cela vient du fait que
personnellement je ne sais pas changer l’image d’un icône en ligne de
commandes sous Xfce. Si vous savez, n’hésitez pas à me donner
l’information par mail car je pourrais ainsi étendre la fonction à
l’environnement de bureau Xfce.

### Changer le papier peint en fonction des utilisateurs {#papier-peint}

Ça pourrait être sympathique d’avoir un papier différent suivant le type
de compte... Et bien c’est possible avec la fonction . Voici un exemple
:

    function ouverture_perso ()
    {
        if [ "$LOGIN" = "admin" ]; then
            changer_papier_peint "$REP_HOME/.backgrounds/admin.jpg"
        fi
    }

Le seul et unique argument de cette fonction est le chemin absolu (sur
la machine cliente) du fichier image servant pour le fond d’écran. Il
faut bien sûr que ce fichier image soit au moins accessible en lecture
pour l’utilisateur qui se connecte.

Là aussi, comme pour les icônes, l’idée est de placer dans le profil par
défaut distant un répertoire (par exemple) qui contiendra les deux ou
trois fichiers images dont vous avez besoin pour faire vos fonds
d’écran. Voici un exemple dans le cas d’un compte professeur :

![image](bureau-message)

En plus du changement de fond d’écran, il y a un petit message
personnalisé qui s’affiche en haut à droite du bureau. Pour mettre en
place ce genre de message, voir la section [conky] page .

### L’activation du pavé numérique {#pave-num}

Pour activer le pavé numérique du client GNU/Linux au moment de
l’affichage de la fenêtre de connexion du système, en principe ceci
devrait fonctionner :

    function initialisation_perso ()
    {
        # On active le pavé numérique au moment de la phase d'initialisation.
        activer_pave_numerique
    }

Vous pouvez remarquer que, cette fois-ci, c’est le contenu de la
fonction qui a été édité.

En revanche, pour activer le pavé numérique au moment de l’ouverture de
session, procéder exactement de la même façon à l’intérieur de la
fonction risque de ne pas fonctionner, et cela pour une raison de
timing. En effet, au moment où la fonction sera lancée, l’ouverture de
session ne sera pas complètement terminée[^21] et l’activation du pavé
numérique risque d’être annulée lors de la fin de l’ouverture de
session. L’idée est donc de programmer l’appel de la fonction **après**
l’exécution du script de logon, seulement au bout de quelques secondes
(par exemple $5$), afin de lancer l’activation du pavé numérique une
fois l’ouverture de session achevée :

    function ouverture_perso ()
    {
        # On ajoute un argument à l'appel de la fonction activer_pave_numerique.
        # Ici, cela signifie que l'activation du pavé numérique sera lancée 5
        # secondes après que le script de logon soit terminé, ce qui laissera
        # le temps à l'ouverture de session de se terminer.
        activer_pave_numerique "5"
    }

### Incruster un message sur le bureau des utilisateurs pour faire classe {#conky}

Pour incruster un message sur le bureau des utilisateurs, il faudra
d’abord que le paquet soit installé[^22] sur le client GNU/Linux.
Ensuite, tentez de mettre ceci dans la fonction :

    function ouverture_perso ()
    {
        # On crée un fichier de configuration .conkyrc dans le home de l'utilisateur.
        # précisant le contenu du message ainsi que certains paramètres (comme la
        # taille de la police par exemple).
        cat > "$REP_HOME/.conkyrc" <<FIN
    use_xft yes
    xftfont Arial:size=10
    double_buffer yes
    alignment top_right
    update_interval 1
    own_window yes
    own_window_transparent yes
    override_utf8_locale yes
    text_buffer_size 1024
    own_window_hints undecorated,below,sticky,skip_taskbar,skip_pager
    TEXT
    Bonjour $NOM_COMPLET_LOGIN,
    Pensez bien à enregistrer vos données personnelles
    dans le dossier :

         Documents de $LOGIN sur le réseau
         
    qui se trouve sur le bureau, et uniquement dans ce
    dossier, sans quoi vos données seront perdues une
    fois votre session fermée.

       Cordialement.
       Les administrateurs du réseau pédagogique.
    FIN

        # On fait de "$LOGIN" le propriétaire du fichier .conkyrc.
        chown "$LOGIN:" "$REP_HOME/.conkyrc"
        chmod 644 "$REP_HOME/.conkyrc"
        
        # On lancera conky à la fin, une fois l'exécution du script logon terminée.
        # Pour être sûr que l'ouverture de session est achevée, on laisse un délai
        # de 5 secondes entre la fin du script de logon et le lancement de la
        # commande conky (avec ses arguments).
        executer_a_la_fin "5" conky --config "$REP_HOME/.conkyrc"
    }

En principe, vous devriez voir apparaître un message incrusté sur le
bureau des utilisateurs en haut à droite. Ce message sera légèrement
personnalisé puisqu’il contiendra le nom de l’utilisateur connecté.

### Exécuter des commandes au démarrage tous les 30 jours

Toutes les commandes que vous mettrez à l’intérieur de la fonction du
fichier seront exécutées à chaque phase d’initialisation du système ce
qui peut parfois s’avérer un peu trop fréquent à votre goût. Voici un
exemple de fonction qui vous permettra d’exécuter des commandes (peu
importe lesquelles ici) au démarrage du système tous les 30 jours (pour
peu que le système ne reste pas éteint indéfiniment bien sûr) :

    function initialisation_perso ()
    {
        local indicateur
        indicateur="/etc/se3/action_truc"
        # Si le fichier n'existe pas alors il faut le créer.
        [ ! -e "$indicateur" ] && touch "$indicateur"

        # On teste si la phase d'initialisation correspond à un démarrage du système.
        if "$DEMARRAGE"; then
            # On teste si la date de dernière modification du fichier est > 29 jours.
            if find "$indicateur" -mtime +29 | grep -q "^$indicateur$"; then
                echo "Les conditions sont vérifiées, on lance les actions souhaitées."
                action1
                action2
                # etc. 
                
                # Si tout s'est bien déroulé, alors on peut mettre à jour la date
                # de dernière modification du fichier avec la commande touch.
                if [ "$?" = "0"  ]; then
                    touch "$indicateur"
                fi
            fi
        fi
    }

L’idée de ce code est plus simple qu’il n’y paraît. Chaque client
GNU/Linux intégré au domaine possède un répertoire local (accessible en
lecture et en écriture au compte uniquement). Dans ce répertoire, le
script y place un fichier texte vide qui se nomme (c’est un exemple) et
dont le seul but est de fournir une date de dernière modification. Au
départ, cette date de dernière modification coïncide au moment où le
fichier est créé. Si, lors d’un prochain démarrage, cette date de
dernière modification est vieille de 30 jours ou plus, alors les actions
sont exécutées et la date de dernière modification du fichier est
modifiée artificiellement en la date du jour avec la commande .

Les logs pour détecter un problème
==================================

Après modification du script de logon, vous n’obtiendrez peut-être pas
le comportement souhaité. Peut-être parce que vous aurez tout simplement
commis des erreurs. Afin de faire un diagnostic, il vous sera toujours
possible de consulter, **sur un client GNU/Linux**, quelques fichiers
log qui se trouvent tous dans le répertoire . Voici la liste des
fichiers log disponibles :

-   : la mise à jour du script de logon local (via son remplacement par
    une copie de la version distante) est un moment important et ce
    fichier indiquera si cette mise à jour a marché ou non. La date de
    la mise à jour y est indiquée.

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution du script de logon **local** lors de la phase
    d’initialisation.

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution, lors de la phase d’initialisation, du script de logon
    **distant** (celui qui se trouve sur le serveur) et non celui qui se
    trouve en local sur le client GNU/Linux. Rappelez-vous que cela se
    produit quand les deux versions du script de logon (la version
    locale et la version et distante) sont différentes (ce qui est censé
    se produire ponctuellement seulement puisque la version locale est
    ensuite mise à jour).

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution, lors de la phase d’initialisation, de votre fonction .

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution du script de logon local lors de la phase d’ouverture.

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution, lors de la phase d’ouverture, de votre fonction .

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution du script de logon local lors de la phase de fermeture.

-   : ce fichier contiendra tous les messages (d’erreur ou non) suite à
    l’exécution, lors de la phase de fermeture, de votre fonction .

À chaque fois que le script de logon s’exécute, avant d’écrire sur le
fichier adapté à la situation du moment, le fichier , s’il existe déjà,
est d’abord vidé de son contenu. Donc les fichiers log ne seront jamais
très gros. Par exemple, dans le fichier , vous aurez des informations
portant uniquement sur la dernière phase d’initialisation effectuée par
le client GNU/Linux (pas sur les phases d’initialisation précédentes).

Le cas des classes nomades {#classes-nomades}
==========================

Utiliser GNU/Linux sur des ordinateurs portables dans un domaine Se3
présente un atout extraordinaire: le mécanisme des profils (voir
section [mecanisme-profils], page ) limite au maximum les échanges entre
le serveur et le client une fois la session ouverte. Autrement dit, il
n’y a aucun risque de voir la session ouverte « planter » en raison
d’une micro-coupure wifi.

L’intégration au domaine d’un ordinateur issu d’une classe nomade ne
présente qu’une spécificité: le client doit, avant l’ouverture de
session, déjà être connecté au réseau sans fil. Pour ce faire, il
suffira d’indiquer dans le fichier le SSID et le mot de passe du réseau
sans fil auquel le client est censé se connecter.. Il est également
recommandé, par la même occasion, de désactiver l’interface ethernet,
sans quoi le processus de boot se trouvera allongé de plusieurs secondes
voire dizaines de secondes (durant lesquelles le client cherchera à
obtenir une IP du serveur sur toutes les interfaces activées).

Un moyen extrêmement simple et rapide de réaliser cette manipulation est
bien sûr d’utiliser . Ainsi, admettons que les clients de votre classe
nomade soit nommés , , jusqu’à . Avant leur intégration au domaine, vous
pouvez par exemple:

-   déposer dans le répertoire de votre Se3 le fichier configuré par vos
    soins

-   préparer un script intitulé contenant les lignes suivantes[^23] :

        #!/bin/bash
        wget http://IP_DE_VOTRE_SE3/interfaces
        mv /etc/network/interfaces /etc/network/interfaces.old
        mv interfaces /etc/network/
        /etc/init.d networking restart

-   déposer dans le répertoire du serveur ledit script

-   lancer l’intégration au domaine de vos clients

Les ordinateurs de la classe nomade redémarreront une première fois
après l’intégration au domaine: laissez les branchés en filaire. Lors de
leur premier boot en version « intégrés », les clients récupéreront le
fichier de configuration du réseau et se connecteront automatiquement au
réseau wifi adéquat.

Le jour où vous aurez besoin de faire d’importantes mises à jour, vous
pourrez tout aussi facilement refaire momentanément basculer ces postes
en filaire...

Un mot sur les imprimantes {#imprimante}
==========================

Ne disposant personnellement d’aucune imprimante réseau, je n’ai jamais
pu tester ce qui suit[^24]. Je suis donc loin de maîtriser l’aspect
gestion des imprimantes sur les clients GNU/Linux. Ceci étant, il faut
bien évoquer ce point très important.

Sur un client GNU/Linux, le répertoire contient un sous-répertoire nommé
qui vous permettra de stocker de manière centralisée des fichiers (pour
PostScript Printer Description ) qui sont des sortes de drivers
permettant d’installer des imprimantes sur les clients GNU/Linux. Vous
pouvez télécharger de tels fichiers (qui dépendent du modèle de
l’imprimante) sur ce site par exemple :

<http://www.openprinting.org/printers>

Supposons que, dans le répertoire , se trouve le fichier d’un modèle
d’imprimante réseau donné, vous pouvez alors lancer son installation sur
un client GNU/Linux via la commande suivante (en tant que ) :

    lpadmin -p NOM-IMPRIMANTE -v socket://IP-IMPRIMANTE:9100 \ENTREE
        -E -P /mnt/netlogon/divers/imprimantes/fichier.ppd

Cette commande doit être en principe exécutée une seule fois sur le
client GNU/Linux. Si tout va bien, vous devriez ensuite[^25] être en
mesure d’imprimer tout ce que vous souhaitez à travers vos applications
favorites (navigateur Web, traitement de texte, lecteur de PDF etc). Si
plusieurs imprimantes sont installées sur un client, pour faire en sorte
que l’imprimante soit l’imprimante par défaut, il faut exécuter en tant
que :

    lpadmin -d NOM-IMPRIMANTE 

Et pour supprimer l’imprimante :

    lpadmin -x NOM-IMPRIMANTE 

Désinstallation/réinstallation du paquet se3-clients-linux {#desinstallation}
==========================================================

Désinstallation complète
------------------------

Si jamais vous souhaitez désinstaller complètement le paquet de votre
serveur, rien de plus simple. En tant que sur le serveur, il suffit de
lancer la commande suivante :

    apt-get purge se3-clients-linux

Et c’est tout. Une fois la commande ci-dessus exécutée, votre serveur ne
garde **plus la moindre trace** d’installation du paquet .

Attention, en désinstallant le paquet de la sorte (avec ), tout le
répertoire du serveur (et tout ce qu’il contient) sera effacé. Si vous
aviez pris la peine de vous concocter un fichier à votre sauce, d’écrire
de nombreux scripts dans le répertoire etc., tout sera purement et
simplement effacé.

Désinstallation partielle en vue d’une réinstallation {#reinstallation}
-----------------------------------------------------

Avec la commande ci-dessous (où l’instruction est remplacée par ), les
choses se passent un peu différemment :

    apt-get remove se3-clients-linux

Le paquet est bien désinstallé comme dans le cas précédent, sauf que le
répertoire du serveur n’est pas totalement effacé. Tous les
fichiers/répertoires que vous avez le droit de modifier seront
conservés, si bien que l’arborescence du répertoire ressemblera à ceci :

    -- clients-linux/
       |-- bin/
       |   `-- logon_perso
       |-- distribs/
       |   |-- precise/
       |   |   `-- skel/
       |   `-- squeeze/
       |       `-- skel/
       |-- divers/
       `-- unefois/

Ainsi, après réinstallation du paquet, vous retrouverez inchangés :

-   le fichier ;

-   tous les profils distants de chaque distribution prise en charge ;

-   le contenu du répertoire ;

-   le contenu du répertoire .

En résumé, une réinstallation du paquet avec conservation des
fichiers/dossiers modifiables se fait ainsi :

    apt-get remove se3-clients-linux
    apt-get install se3-clients-linux

Une telle réinstallation du paquet peut être utile si jamais, pour une
raison ou pour une autre, vous avez commis un certain nombre de
modifications malheureuses en voulant hacker certains fichiers du paquet
et que vous souhaitez repartir de zéro sans pour autant perdre vos
fichiers personnels[^26] . Autre cas où la réinstallation peut être
utile : lors d’une mise à jour du paquet (auquel cas d’ailleurs il sera
plus naturel d’exécuter la commande ). Dans ce cas aussi, les fichiers
personnels seront conservés en l’état.

ici, la notion de fichiers/répertoires modifiables ou personnels n’est
pas à prendre au pied de la lettre. Dans l’absolu, vous pouvez tenter de
modifier ce que vous voulez dans les fichiers du paquet . Simplement,
sont considérés comme modifiables (ou personnels ) seulement les
fichiers/répertoires **conservés** lors d’une réinstallation ou d’une
mise à jour du paquet.

Signaler un problème, faire une remarque etc.
=============================================

Étant donné que le paquet fait partie du projet SambaÉdu, le mieux à
faire pour signaler un problème, faire une remarque etc. est de passer
par la liste de diffusion SambaÉdu [^27]. N’hésitez pas à me signaler
toute erreur. Si vous envoyez un message sur cette liste avec un objet
assez évocateur (par exemple avec l’expression clients GNU/Linux
dedans), il y a peu de chance que je passe à côté. J’essayerai alors de
vous répondre et, dans la mesure du possible, de rectifier le problème.

Contribuer à améliorer le paquet
================================

Dans votre coin, vous avez réussi à modifier le paquet (un script
d’intégration, le script de logon etc.) afin d’en étendre les
fonctionnalités (par exemple afin de prendre en charge une nouvelle
distribution, un autre gestionnaire de bureau qui a votre faveur et qui
n’est pas actuellement pris en charge par le paquet etc. etc. etc.) ? Si
c’est le cas, n’hésitez surtout pas à nous en faire part sur la liste de
diffusion . Nous serons ravis d’intégrer au paquet vos contributions
pour peu que vous les ayez déjà testées avant[^28].

Les évolutions du paquet
========================

Ci-dessous, vous trouverez le contenu du fichier du paquet. C’est une
sorte de journal qui décrit les modifications du paquet au fur et à
mesure du temps :

[^1]: ou mieux, créer un fichier car le fichier peut être réédité à
    votre insu lors de mises à jour du serveur.

[^2]: En fait, vous pouvez le faire bien sûr car vous êtes sur le
    serveur. Mais les modifications effectuées sur les
    fichiers/répertoires qui ne sont pas en vert sur le schéma ne
    survivront pas à une réinstallation ou à une mise à jour du paquet .

[^3]: Celui qui se trouve dans le fichier . Ce n’est pas un nom DNS
    pleinement qualifié.

[^4]: Le terme de synchronisation est bien adapté car c’est justement la
    commande qui est utilisée pour effectuer cette tâche.

[^5]: Cette restriction pourra, dans une certaine mesure, être levée
    lorsqu’on abordera la personnalisation du script de logon à la
    section [personnalisation] page .

[^6]: Car c’est ce répertoire qui contient tous les réglages concernant
    Firefox que vous avez effectués.

[^7]: Ne pas oublier cette étape, sans quoi les clients GNU/Linux
    estimeront que le profil par défaut **distant** n’a pas été modifié
    et la mise à jour du profil par défaut **local** n’aura pas lieu

[^8]: Le fonctionnement du script de logon est décrit dans la
    section [logon-script], page .

[^9]: Oui, il s’agit bien d’un répertoire dont le nom commence par un
    accent circonflexe.

[^10]: Le shebang est la première ligne d’un script qui commence par
    comme dans ou dans .

[^11]: En fait, comme vous allez le voir juste après, cette règle n’est
    pas complètement immuable.

[^12]: Rappelons à nouveau que le répertoire sur les clients GNU/Linux
    correspond en réalité au répertoire du serveur Samba.

[^13]: Les clients GNU/Linux ne tiennent compte que du nom des fichiers,
    pas de leur contenu. La casse dans le nom des fichiers est prise en
    compte.

[^14]: Le nom du fichier doit être en majuscules uniquement et peu
    importe le contenu de ce fichier qui peut être totalement vide.
    Attention, les droits de ce fichier doivent être corrects une fois
    celui-ci créé.

[^15]: Même remarque que pour le fichier .

[^16]: Cette valeur règle le système, le temps de l’exécution des
    scripts, sur la locale standard qui est la seule locale parfaitement
    normalisée et a priori disponible sur n’importe quel système de type
    Unix.

[^17]: Un compte local est un compte figurant dans le fichier du client
    GNU/Linux.

[^18]: Attention d’utiliser un éditeur de texte respectueux de
    l’encodage et des fins de ligne lorsque vous modifierez le fichier .

[^19]: Du coup, mettre ou mettre comme premier argument revient
    exactement au même.

[^20]: En informatique, le masculin est autorisé pour le mot icône.

[^21]: Et c’est normal qu’il en soit ainsi puisque l’ouverture de
    session de termine **après** l’exécution du script de logon, même
    pas immédiatement après mais 1 ou 2 secondes après selon la rapidité
    de la machine hôte.

[^22]: Vous pouvez par exemple lancer l’installation via un script qui
    contiendrait à peu de choses près l’instruction .

[^23]: Changez bien sûr ... par l’IP réelle de votre Se3...

[^24]: Si vous avez du code bash à me proposer pour automatiser
    l’installation des imprimantes sur les clients GNU/Linux via par
    exemple la fonction , je suis preneur ().

[^25]: Même après redémarrage du système.

[^26]: Ce qu’on appelle les fichiers personnels , ce sont les fichiers
    que vous avez le droit de modifier, ceux qui sont en vert dans
    l’arborescence située à la section [arborescence] page .

[^27]: Attention, pour pouvoir écrire à cette liste de diffusion, il
    faut d’abord s’y inscrire :
    <http://listes.tice.ac-caen.fr/mailman/listinfo/samba-edu>.

[^28]: Car tester une fonctionnalité prend du temps (la coder aussi
    d’ailleurs), et c’est le temps qui nous limite dans l’élaboration du
    paquet et non un manque de volonté bien sûr.

