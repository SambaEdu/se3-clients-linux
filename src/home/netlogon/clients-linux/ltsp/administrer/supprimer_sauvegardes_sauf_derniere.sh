#!/bin/sh

SE3="__SE3__"

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash << EOF

rm -rf /var/se3/ltsp/precedentes/*
printf "Toutes les sauvegardes à l exception de la derniere realisee ont ete supprimees \n"

sleep 5

exit 0

EOF"
