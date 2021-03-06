#!/bin/sh

# ag-sw-add.sh -   installs the additional software that will be needed for
#                  HA on new servers for an existing cluster. You can skip 
#                  this if you already have the software installed

# Bring in the configuration parameters
source ./params.sh
source ./initvars.sh
source ./functions.sh

if [ $# -gt 1 ]
then
    echo "usage: ag-sw-add.sh server1 server2 ..." >&2
    exit 1
fi

NEW_SERVERS="$*"


echo "Install pacemaker"
# Install pacemaker and assign a cluster password
# Note that the hacluster user is hardcoded
# You will be prompted for the hacluster password on each node

for server in $NEW_SERVERS
do
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" subscription-manager repos --enable=rhel-8-for-x86_64-highavailability-rpms
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" "firewall-cmd --permanent --add-service=high-availability; firewall-cmd --reload"
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" yum install -y pacemaker pcs fence-agents-all resource-agents
done # for server in $NEW_SERVERS

# Install the SQL Server resource agent on all nodes
sleep 3
echo "Install the SQL Server resource agent on all nodes"
for server in $NEW_SERVERS
do
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" yum install -y mssql-server-ha
done # for server in $NEW_SERVERS
