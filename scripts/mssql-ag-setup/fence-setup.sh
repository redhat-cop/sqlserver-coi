#!/bin/sh

# fence-setup.sh - any fencing resource agent settings should go here.
#                  with baremetal you can enable a watchdog and skip the complexity

# Bring in the configuration parameters
source ./params.sh

echo "Turn on fencing. A watchdog timer is all you need for barmetal/KVM"
# Enable fencing, on baremetal or KVM we just use a watchdog timer
ssh root@$PRIMARY_SERVER  pcs property set stonith-watchdog-timeout=10s
ssh root@$PRIMARY_SERVER pcs stonith sbd enable
echo "Restarting the cluster now"
ssh root@$PRIMARY_SERVER pcs cluster stop --all
ssh root@$PRIMARY_SERVER pcs cluster start --all
