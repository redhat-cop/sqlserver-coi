#!/bin/sh

# pcs-setup.sh - configure the Red Hat High Availabilit Add-on for use with
#                a SQL Server Always-On Availability Group

# Bring in the configuration parameters
source ./params.sh
source ./functions.sh

echo "Setting password for hacluster account and enabling RHEL HA Add-On"
for server in $ALL_SERVERS
do
    ssh root@$server passwd --stdin hacluster<<__EOF
$HACLUSTER_PW
__EOF
    ssh root@$server "systemctl enable pcsd;sudo systemctl start pcsd; sudo systemctl enable pacemaker"
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

    ssh root@$server "printf \"pacemakerLogin\\n$PACEMAKER_SQL_PW\\n\" > $PACEMAKER_SQL_PW_FILE; chown root:root $PACEMAKER_SQL_PW_FILE; chmod 400 $PACEMAKER_SQL_PW_FILE"

    cat<<__EOF>/tmp/sqlcmd-pcs-setup2.$server
GRANT ALTER, CONTROL, VIEW DEFINITION ON AVAILABILITY GROUP::$AG_NAME TO pacemakerLogin
GRANT VIEW SERVER STATE TO pacemakerLogin
__EOF

    runsqlcmd $server "/tmp/sqlcmd-pcs-setup2.$server"

done # for server in $ALL_SERVERS

sleep 3
echo "Setup the pacemaker cluster"
# Now setup and start the cluster
ssh root@$PRIMARY_SERVER pcs host auth -u hacluster -p $HACLUSTER_PW $ALL_SERVERS 
ssh root@$PRIMARY_SERVER pcs cluster setup $AG_NAME $ALL_SERVERS
ssh root@$PRIMARY_SERVER "pcs cluster start --all; sudo pcs cluster enable --all"
ssh root@$PRIMARY_SERVER pcs cluster auth -u hacluster -p $HACLUSTER_PW

sleep 3
echo "Set the recheck interval of pacemaker to 2 minutes"
# Set the recheck interval for pacemaker to 2min (MS recommended)
ssh root@$PRIMARY_SERVER pcs property set cluster-recheck-interval=2min

sleep 3
echo "Create the availability group resource"

# Create the availability group resource
ssh root@$PRIMARY_SERVER pcs resource create ag_cluster ocf:mssql:ag ag_name=$AG_NAME meta failure-timeout=60s promotable notify=true

sleep 3
echo "Create  the floating virtual IP address"
# Set up a floating virtual IP address for the SQL Server AG
ssh root@$PRIMARY_SERVER pcs resource create virtualip ocf:heartbeat:IPaddr2 ip=$VIRTUAL_IP

sleep 3
echo "Add a colocation constraint"
# Add a colocation constraint
ssh root@$PRIMARY_SERVER pcs constraint colocation add virtualip with master ag_cluster-clone INFINITY with-rsc-role=Master

sleep 3
echo "Add an ordering constraint"
# Add an ordering constraint
ssh root@$PRIMARY_SERVER pcs constraint order promote ag_cluster-clone then start virtualip

