#!/bin/sh
FLAGS="-o kill_on_unmount -o reconnect -o defer_permissions -o direct_io -o local"
sshfs $FLAGS -o volname=homedir $PHON:/home/obukhova phon/
sshfs $FLAGS -o volname=glusterfs $PHON:/srv/glusterfs/obukhova glusterfs/
sshfs $FLAGS -o volname=phonscratch $PHON:/scratch_net/phon/obukhova phonscratch/
