#!/bin/sh

# pcs-setup.sh - configure the Red Hat High Availabilit Add-on for use with
#                a SQL Server Always-On Availability Group

# Bring in the configuration parameters
source ./params.sh
source ./initvars.sh
source ./functions.sh

# Verify that we have a cluster in place to support RHEL HA Add-On
if [ $CLUSTER_TYPE != "EXTERNAL" ]
then
    echo "Cluster type is $CLUSTER_TYPE" >&2
    echo "Skipping RHEL HA Add-on configuration"
    exit 0
fi

echo "Setting password for hacluster account and enabling RHEL HA Add-On"
for server in $ALL_SERVERS
do
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" passwd --stdin hacluster<<__EOF
$HACLUSTER_PW
__EOF
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" "systemctl enable pcsd;sudo systemctl start pcsd; sudo systemctl enable pacemaker"
done # for server in $ALL_SERVERS

echo "Create a SQL Server login for Pacemaker on all servers"

# Create a SQL Server login for Pacemaker on all servers
for server in $ALL_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd-pcs-setup1.$server
USE [master]
GO
CREATE LOGIN [pacemakerLogin] with PASSWORD= N'$PACEMAKER_SQL_PW'
ALTER SERVER ROLE [sysadmin] ADD MEMBER [pacemakerLogin]
GO
__EOF

    runsqlcmd $server "/tmp/sqlcmd-pcs-setup1.$server"

    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" "printf \"pacemakerLogin\\n$PACEMAKER_SQL_PW\\n\" > $PACEMAKER_SQL_PW_FILE; chown root:root $PACEMAKER_SQL_PW_FILE; chmod 400 $PACEMAKER_SQL_PW_FILE"

    cat<<__EOF>/tmp/sqlcmd-pcs-setup2.$server
GRANT ALTER, CONTROL, VIEW DEFINITION ON AVAILABILITY GROUP::$AG_NAME TO pacemakerLogin
GRANT VIEW SERVER STATE TO pacemakerLogin
__EOF

    runsqlcmd $server "/tmp/sqlcmd-pcs-setup2.$server"

done # for server in $ALL_SERVERS

sleep 3
echo "Setup the pacemaker cluster"
# Now setup and start the cluster
server=$PRIMARY_SERVER
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs host auth -u hacluster -p "$HACLUSTER_PW" $ALL_SERVERS 
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs cluster setup $AG_NAME $ALL_SERVERS
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" "pcs cluster start --all; sudo pcs cluster enable --all"
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs cluster auth -u hacluster -p "$HACLUSTER_PW"

sleep 3
echo "Set the recheck interval of pacemaker to 2 minutes"
# Set the recheck interval for pacemaker to 2min (MS recommended)
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs property set cluster-recheck-interval=2min

sleep 3
echo "Create the availability group resource"

# Create the availability group resource
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs resource create ag_cluster ocf:mssql:ag ag_name=$AG_NAME meta failure-timeout=60s promotable notify=true

sleep 3
echo "Create the floating virtual IP address"
# Set up a floating virtual IP address for the SQL Server AG
runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs resource create virtualip ocf:heartbeat:IPaddr2 ip=$VIRTUAL_IP

sleep 3
if [ $FENCING_TYPE = "azure" ]
then
    echo "Create the Azure load balancer resource"
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs resource create azure_load_balancer azure-lb port=$AZURE_LB_PROBE_PORT
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs resource group add virtualip_group azure_load_balancer virtualip
fi

sleep 3
echo "Add a colocation constraint"
# Add a colocation constraint
if [ $FENCING_TYPE = "baremetal" ]
then
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs constraint colocation add virtualip with master ag_cluster-clone INFINITY \
	   with-rsc-role=Master
elif [ $FENCING_TYPE = "azure" ]
then
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs constraint colocation add azure_load_balancer ag_cluster-clone \
	   INFINITY with-rsc-role=Master
else
   echo "unknown cluster type" >&2
   exit 1
fi

sleep 3
echo "Add an ordering constraint"
# Add an ordering constraint
if [ $FENCING_TYPE = "baremetal" ]
then
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs constraint order promote ag_cluster-clone then start virtualip
elif [ $FENCING_TYPE = "azure" ]
then
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs constraint order promote ag_cluster-master then start azure_load_balancer
    cat<<__EOF>/tmp/sqlcmd-pcs-setup3.$PRIMARY_SERVER
ALTER AVAILABILITY GROUP [ag1] ADD LISTENER 'ag1-listener' (
        WITH IP(($AZURE_LB_IP ,'255.255.255.0')),PORT = 1433);
GO
__EOF

    runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-pcs-setup3.$PRIMARY_SERVER"
else
   echo "unknown cluster type" >&2
   exit 1
fi

