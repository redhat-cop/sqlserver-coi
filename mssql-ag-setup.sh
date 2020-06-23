#!/bin/sh

# The initial primary server where we configure SQL Server and Pacemaker
# You must have 1 primary server. 
# There can be at most 9 servers in a writeable SQL Server Availability Group.
PRIMARY_SERVER=sql1.ag1

# Secondary servers.  You can have up to 5 syncronous replicas
# You need at least one syncronous replica for automatic failover. 
# There can be at most 9 servers in a read-write SQL Server Availability Group.
SECONDARY_SERVERS="sql2.ag1 sql3.ag1"

# Tertiary servers.  You can have up to 8 asyncronous replicas
# There can be at most 9 servers in a read-write SQL Server Availability Group.
# Async replicas are manual failover only.
TERTIARY_SERVERS="sql4.ag1"

# All the servers in the cluster
ALL_SERVERS="$PRIMARY_SERVER $SECONDARY_SERVERS $TERTIARY_SERVERS"

# SQL Server administrative login and password
SQL_ADMIN="sa"
SQL_PASS="RedHat123"

# The port the servers listen on for replication
LISTENER_PORT=5022

# The SQL Server port (doesn't have to be the default one)
SQL_PORT=1433

# The availability group name in SQL Server
AG_NAME="ag1"

# The database name and the path for a backup
DB_NAME=db1
DB_BKUP_PATH=/var/opt/mssql/data/$DB_NAME.bak

# A password for the hacluster user added by pacemaker 
HACLUSTER_PW="RedHat123"

# A floating virtual IP address for accessing the master SQL Server node
VIRTUAL_IP=192.168.200.254

# Keys for SQL replication
MASTER_KEY_PASSWORD='Nmre34JGmDmUX3G1mdQ'
PRIVATE_KEY_PASSWORD='w22yQeEXW9cjvr2hRig'

# Tell SQL Server to turn on ha and health monitoring
for server in $ALL_SERVERS
do
    ssh root@$server '/opt/mssql/bin/mssql-conf set hadr.hadrenabled  1; systemctl restart mssql-server'
done # for server in $ALL_SERVERS

sleep 10
for server in $ALL_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd1.$server
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd1.$server

    #cleanup
    rm /tmp/sqlcmd1.$server

done # for server in $ALL_SERVERS


sleep 3
# Set up the master certificate
echo "Setting up the master certificate"


cat<<__EOF>/tmp/sqlcmd2.$PRIMARY_SERVER
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$MASTER_KEY_PASSWORD';
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
   TO FILE = '/var/opt/mssql/data/dbm_certificate.cer'
   WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           ENCRYPTION BY PASSWORD = '$PRIVATE_KEY_PASSWORD'
       );
GO
__EOF
sqlcmd -S $PRIMARY_SERVER -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd2.$PRIMARY_SERVER
#cleanup
rm /tmp/sqlcmd2.$PRIMARY_SERVER

sleep 3
echo "Copying certificates to secondary and tertiary servers"
# Copy the certificates to the secondary and tertiary servers
for server in $SECONDARY_SERVERS $TERTIARY_SERVERS
do
    scp root@$PRIMARY_SERVER:/var/opt/mssql/data/dbm_certificate.* root@$server:/var/opt/mssql/data/
    ssh root@$server chown mssql:mssql /var/opt/mssql/data/dbm_certificate.*
done # for server in $SECONDARY_SERVERS $TERTIARY_SERVERS

sleep 3
echo "Creatingcertificates to secondary and tertiary servers"
# Copy the certificates to the secondary servers
# Create certificates on the secondary servers
# Note that PRIVATE_KEY_PASSWORD is re-used here as the decryption piece
for server in $SECONDARY_SERVERS $TERTIARY_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd3.$server
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$MASTER_KEY_PASSWORD';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = '$PRIVATE_KEY_PASSWORD'
            );
GO
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd3.$server

    #cleanup
    rm /tmp/sqlcmd3.$server

done # for server in $SECONDARY_SERVERS $TERTIARY_SERVERS

    
sleep 3
echo "Creating database mirroring endpoints on all instances for replication"
# Create database mirroring endpoints on all instances for replication

for server in $ALL_SERVERS
do
    ssh root@$server "firewall-cmd --zone=public --add-port="$LISTENER_PORT"/tcp --permanent; firewall-cmd --reload"

    cat<<__EOF >/tmp/sqlcmd4.$server
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = $LISTENER_PORT)
    FOR DATABASE_MIRRORING (
	    ROLE = ALL,
	    AUTHENTICATION = CERTIFICATE dbm_certificate,
		ENCRYPTION = REQUIRED ALGORITHM AES
		);
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GO:
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd4.$server

    #cleanup
    rm /tmp/sqlcmd4.$server

done # for server in $ALL_SERVERS


sleep 3
echo "Creating the availability group"
# Here we'll actually create the availability group

SHORT_NAME=`echo $PRIMARY_SERVER | awk -F . '{ print $1 }'`
 
cat<<__EOF>/tmp/sqlcmd5
CREATE AVAILABILITY GROUP [$AG_NAME]
     WITH (DB_FAILOVER = ON, CLUSTER_TYPE = EXTERNAL)
     FOR REPLICA ON
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$PRIMARY_SERVER:$LISTENER_PORT',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    FAILOVER_MODE = EXTERNAL,
    SEEDING_MODE = AUTOMATIC
__EOF

for server in $SECONDARY_SERVERS
do
    SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

    cat<<__EOF>>/tmp/sqlcmd5
),
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    FAILOVER_MODE = EXTERNAL,
    SEEDING_MODE = AUTOMATIC
__EOF
done # for server in $SECONDARY_SERVERS

for server in $TERTIARY_SERVERS
do
    SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

    cat<<__EOF>>/tmp/sqlcmd5
),
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
    FAILOVER_MODE = EXTERNAL,
    SEEDING_MODE = AUTOMATIC
__EOF
done # for server in $TERTIARY_SERVERS

cat<<__EOF>>/tmp/sqlcmd5
);

ALTER AVAILABILITY GROUP [$AG_NAME] GRANT CREATE ANY DATABASE;
GO
__EOF

sqlcmd -S $PRIMARY_SERVER -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd5

#cleanup
rm /tmp/sqlcmd5

for server in $SECONDARY_SERVERS $TERTIARY_SERVERS
do
    cat<<__EOF>>/tmp/sqlcmd5.$server
ALTER AVAILABILITY GROUP [$AG_NAME] JOIN WITH (CLUSTER_TYPE = EXTERNAL);
ALTER AVAILABILITY GROUP [$AG_NAME] GRANT CREATE ANY DATABASE;
GO
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd5.$server
done #for server in $SECONDARY_SERVERS $TERTIARY_SERVERS

sleep 3
echo "Create the database and back it up"

cat<<__EOF >/tmp/sqlcmd6.$PRIMARY_SERVER
CREATE DATABASE [$DB_NAME];
ALTER DATABASE [$DB_NAME] SET RECOVERY FULL;
BACKUP DATABASE [$DB_NAME]
  TO DISK = N'$DB_BKUP_PATH';
GO
__EOF
sqlcmd -S $PRIMARY_SERVER -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd6.$PRIMARY_SERVER

#cleanup
rm /tmp/sqlcmd6.$PRIMARY_SERVER

sleep 3
echo "Add the databae to the AG and replicate it"
# Add the database to the AG and replicate it
cat<<__EOF >/tmp/sqlcmd7.$PRIMARY_SERVER
ALTER AVAILABILITY GROUP [$AG_NAME] ADD DATABASE [$DB_NAME];
GO
__EOF
sqlcmd -S $PRIMARY_SERVER -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd7.$PRIMARY_SERVER

#cleanup
rm /tmp/sqlcmd7.$PRIMARY_SERVER

echo "Give the database time to replicate"

sleep 30
echo "See if the database was created on the secondary nodes"

# Now we check to make sure the database was created on the secondaries and tertiaries
for server in $SECONDARY_SERVERS $TERTIARY_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd8.$server
SELECT * FROM sys.databases WHERE name = '$DB_NAME';
GO
SELECT DB_NAME(database_id) AS 'database', synchronization_state_desc FROM sys.dm_hadr_database_replica_states;
GO
quit
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd8.$server

    #cleanup
    rm /tmp/sqlcmd8.$server

done # for server in $SECONDARY_SERVERS $TERTIARY_SERVERS


echo "Install pacemaker and assign a cluster password"
# Install pacemaker and assign a cluster password
# Note that the hacluster user is hardcoded

for server in $ALL_SERVERS
do
    ssh root@$server subscription-manager repos --enable=rhel-8-for-x86_64-highavailability-rpms
    ssh root@$server  "firewall-cmd --permanent --add-service=high-availability; firewall-cmd --reload"
    ssh root@$server yum install -y pacemaker pcs fence-agents-all resource-agents
    ssh root@$server passwd --stdin hacluster<<__EOF
$HACLUSTER_PW
__EOF
    ssh root@$server "systemctl enable pcsd;sudo systemctl start pcsd; sudo systemctl enable pacemaker"
done # for server in $ALL_SERVERS

sleep 3
echo "Setup the pacemaker cluster"
# Now setup and start the cluster
echo "For now, we have to enter in hacluster account and passwd"
ssh root@$PRIMARY_SERVER pcs host auth $ALL_SERVERS
ssh root@$PRIMARY_SERVER pcs cluster setup $AG_NAME $ALL_SERVERS
ssh root@$PRIMARY_SERVER "pcs cluster start --all; sudo pcs cluster enable --all"


# Install the SQL Server resource agent on all nodes
sleep 3
echo "Install the SQL Server resource agent on all nodes"
for server in $ALL_SERVERS
do
    ssh root@$server yum install -y mssql-server-ha
done # for server in $ALL_SERVERS

sleep 3
echo "Set the recheck interval of pacemaker to 2 minutes"
# Set the recheck interval for pacemaker to 2min (MS recommended)
ssh root@$PRIMARY_SERVER pcs property set cluster-recheck-interval=2min


sleep 3
echo "Create a SQL Server login for Pacemaker on all servers"
# Create a SQL Server login for Pacemaker on all servers
PACEMAKER_SQL_PW='f9YHkyxHb8vlP0rC3g4'
PACEMAKER_SQL_PW_FILE="/var/opt/mssql/secrets/passwd"
for server in $ALL_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd9.$server
USE [master]
GO
CREATE LOGIN [pacemakerLogin] with PASSWORD= N'$PACEMAKER_SQL_PW'
ALTER SERVER ROLE [sysadmin] ADD MEMBER [pacemakerLogin]
GO
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd9.$server

    #cleanup
    rm /tmp/sqlcmd9.$server

    ssh root@$server "printf \"pacemakerLogin\n$PACEMAKER_SQL_PW\n\" > $PACEMAKER_SQL_PW_FILE; chown root:root $PACEMAKER_SQL_PW_FILE; chmod 400 $PACEMAKER_SQL_PW_FILE"

    cat<<__EOF>/tmp/sqlcmd10.$server
GRANT ALTER, CONTROL, VIEW DEFINITION ON AVAILABILITY GROUP::$AG_NAME TO pacemakerLogin
GRANT VIEW SERVER STATE TO pacemakerLogin
__EOF
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/sqlcmd10.$server

    #cleanup
    rm /tmp/sqlcmd10.$server

done # for server in $ALL_SERVERS

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

sleep 3
echo "Turn on fencing, use a watchdog timer on barmetal/KVM"
# Enable fencing, on baremetal or KVM we just use a watchdog timer
ssh root@$PRIMARY_SERVER  pcs property set stonith-watchdog-timeout=10s
ssh root@$PRIMARY_SERVER pcs stonith sbd enable

