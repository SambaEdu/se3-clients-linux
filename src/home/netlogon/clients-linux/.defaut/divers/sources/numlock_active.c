#include <X11/XKBlib.h>
#include <X11/extensions/XKB.h>
#include <X11/keysym.h>

int main () {
    Display *disp = XOpenDisplay(NULL);
    if(disp == NULL) return 1;
    unsigned int nl_mask = XkbKeysymToModifiers(disp, XK_Num_Lock);
    XkbLockModifiers(disp, XkbUseCoreKbd, nl_mask, nl_mask);
    XCloseDisplay(disp);
    return 0;
}

/*
    Je n'y connais pas grand chose en C. J'ai trouvé des informations ici :
    http://www.siteduzero.com/tutoriel-3-31992-compilez-sous-gnu-linux.html

    Paquet à installer pour que la compilation fonctionne : 
        libx11-dev
        
    1) Compilation sans inclure les bibliothèques dynamiques (*.so) dans le binaire :
        # Avec « -l X11 », on signale à l'éditeur de liens qu'il pourra utiliser la bibliothèque X11.
        gcc -l X11 <file.c> -o <file.exe>
        
    2) Compilation en incluant les bibliothèques dynamiques (*.so) dans le binaire :
        # Avec « -l X11 », on signale à l'éditeur de liens qu'il pourra utiliser la bibliothèque X11.
        gcc -l X11 -c <file.c> -o <file.o>
        # Ensuite on compile le fichier objet en incluant les bibliothèques statiques (*.a)
        gcc <file.o> /usr/lib/libX11.a /usr/lib/libxcb.a /usr/lib/libXau.a /usr/lib/libXdmcp.a -o <file.exe>
        
    Rq1: apparemment, il ne vaut mieux utiliser la solution 1), ie ne pas inclure
         les bibliothèques dans le binaire car :
         - ça sert à ça justement. Les bibliothèques sont présentes
           sur le système hôte et sont appelées par le binaire quand c'est nécessaire.
         - ça peut être source de problèmes. Si on inclut une bibliothèque
           dans le binaire, celle-ci peut ne pas être compatible avec le système
           hôte et il vaut mieux que le système hôte appelle sa propre bibliothèque
           (à condition que celle-ci soit présente bien sûr).

    Rq2: la compilation est à faire sur un système 32 bits et sur un système 64 bits
         afin d'avoir un binaire compatible 32 bits et un autre binaire compatible
         64 bits.
         
         
    Rq3: pour savoir si le système est 64 bits ou non :
         $ grep '^flags' /proc/cpuinfo | grep 'lm'
         Il faut que les lignes contiennent le flag « lm ».
         Attention, le flag « lahf_lm » lui n'a rien à voir.
         Il faut le flag « lm » tout court. S'il n'est pas présent,
         alors le système n'est pas 64 bits et donc il est
         très probablement 32 bits.
*/
