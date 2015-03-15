#!/bin/bash

SE3="__SE3__"

xterm -e "ssh -o 'StrictHostKeyChecking no' -l root '$SE3' bash < /mnt/netlogon/.defaut/reconfigure.bash"


