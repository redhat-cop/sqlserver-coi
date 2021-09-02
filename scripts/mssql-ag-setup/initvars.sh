#!/bin/sh
#
# This file contains parameters initialization code used by all of the 
# other scripts

# Set the primary server name as a stand-alone variable for convenience
PRIMARY_SERVER=${!PRIMARY_SERVER_PASS[@]}

# Create a password variable for all servers in the cluster
declare -A ALL_SERVERS_PASS

ALL_SERVERS_PASS=([$PRIMARY_SERVER]=${PRIMARY_SERVER_PASS[$PRIMARY_SERVER]})

for server in $SYNC_SERVERS
do
   ALL_SERVERS_PASS+=([$server]=${SYNC_SERVERS_PASS[$server]})
done

for server in $ASYNC_SERVERS
do
   ALL_SERVERS_PASS+=([$server]=${ASYNC_SERVERS_PASS[$server]})
done

for server in $CONFIG_ONLY_SERVERS
do
   ALL_SERVERS_PASS+=([$server]=${CONFIG_ONLY_SERVERS_PASS[$server]})
done

ALL_SERVERS=${!ALL_SERVERS_PASS[@]}

ALL_SERVERS_NB=""

for server in $ALL_SERVERS
do
    ALL_SERVERS_NB+=`echo $server | awk -F . '{ print $1 }'`" "
done

if [ $CLUSTER_TYPE = "EXTERNAL" ]
then 
    FAILOVER_MODE="EXTERNAL"
else
    FAILOVER_MODE="MANUAL"
fi
