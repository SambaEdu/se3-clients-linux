#!/bin/bash

if [ "$RUNNING_IN_NEW_XTERM" != t ] ; then
        RUNNING_IN_NEW_XTERM=t exec xterm -e "$0 $*"
        exit 0
fi

NOM_CLIENT=""
while [ -z "${NOM_CLIENT}" ]
do
	echo -e "
Changement de nom de la machine.
Nouveau nom: \c"
	read NOM_CLIENT

	if [ -n "${NOM_CLIENT}" ]; then
		t=$(echo "${NOM_CLIENT:0:1}"|grep "[A-Za-z]")
		if [ -z "$t" ]; then
			echo "Le nom doit commencer par une lettre."
			NOM_CLIENT=""
		else
			t=$(echo "${NOM_CLIENT}"|sed -e "s/[A-Za-z0-9\-]//g")
			if [ -n "$t" ]; then
				echo "Le nom $NOM_CLIENT contient des caracteres invalides: '$t'"
				NOM_CLIENT=""
			fi
		fi
	fi
done



/usr/bin/gksu "/home/admin/clients-linux/bin/renome_poste.bash $NOM_CLIENT"
read tst
exit 0
