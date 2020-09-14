#!/bin/sh

# sw-install.sh - installs additional software that might be needed for
#                  HA, you can skip this if you already have the software 
#                  installed

# Bring in the configuration parameters
source ./params.sh

echo "Install pacemaker"
# Install pacemaker and assign a cluster password
# Note that the hacluster user is hardcoded
# You will be prompted for the hacluster password on each node

for server in $ALL_SERVERS
do
    ssh root@$server subscription-manager repos --enable=rhel-8-for-x86_64-highavailability-rpms
    ssh root@$server  "firewall-cmd --permanent --add-service=high-availability; firewall-cmd --reload"
    ssh root@$server yum install -y pacemaker pcs fence-agents-all resource-agents
done # for server in $ALL_SERVERS

# Install the SQL Server resource agent on all nodes
sleep 3
echo "Install the SQL Server resource agent on all nodes"
for server in $ALL_SERVERS
do
    ssh root@$server yum install -y mssql-server-ha
done # for server in $ALL_SERVERS
