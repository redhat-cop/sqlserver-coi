#!/bin/sh

# ag-setup - setup enables always-on, creates the AG and configures it for
#            the Red Hat High Availability Add-On

source ./params.sh
source ./initvars.sh
source ./functions.sh

# Tell SQL Server to turn on ha and health monitoring
echo "Turn on HADR and Health Monitoring for SQL Server"
for server in $ALL_SERVERS
do
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" '/opt/mssql/bin/mssql-conf set hadr.hadrenabled  1; systemctl restart mssql-server'
done # for server in $ALL_SERVERS

echo "Turn on Health Monitoring for SQL Server"
sleep 10
for server in $ALL_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup1.$server
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
__EOF
    
    runsqlcmd $server "/tmp/sqlcmd-ag-setup1.$server"

done # for server in $ALL_SERVERS

sleep 3
echo "Creating database mirroring endpoints on all instances for replication"
# Create database mirroring endpoints on all instances for replication

for server in $ALL_SERVERS
do
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" "firewall-cmd --zone=public --add-port=$LISTENER_PORT/tcp --permanent; firewall-cmd --reload"
done

for server in $PRIMARY_SERVER $SYNC_SERVERS $ASYNC_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup2.$server
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = $LISTENER_PORT)
    FOR DATABASE_MIRRORING (
	    ROLE = ALL,
	    AUTHENTICATION = CERTIFICATE $DBM_CERTIFICATE_NAME,
		ENCRYPTION = REQUIRED ALGORITHM AES
		);
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GO:
__EOF

    runsqlcmd $server "/tmp/sqlcmd-ag-setup2.$server"

done # for server in $PRIMARY_SERVER $SYNC_SERVERS $ASYNC_SERVERS

for server in $CONFIG_ONLY_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup3.$server
CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = $LISTENER_PORT)
    FOR DATABASE_MIRRORING (
	    ROLE = WITNESS,
	    AUTHENTICATION = CERTIFICATE $DBM_CERTIFICATE_NAME,
		ENCRYPTION = REQUIRED ALGORITHM AES
		);
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GO:
__EOF
    runsqlcmd $server "/tmp/sqlcmd-ag-setup3.$server"

done # for server in $CONFIG_ONLY_SERVERS


sleep 3
echo "Creating the availability group"
# Here we'll actually create the availability group

SHORT_NAME=`echo $PRIMARY_SERVER | awk -F . '{ print $1 }'`
 
cat<<__EOF >/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER
CREATE AVAILABILITY GROUP [$AG_NAME]
     WITH (DB_FAILOVER = ON, CLUSTER_TYPE = $CLUSTER_TYPE)
     FOR REPLICA ON
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$PRIMARY_SERVER:$LISTENER_PORT',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    FAILOVER_MODE = $FAILOVER_MODE,
    SEEDING_MODE = AUTOMATIC,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
__EOF

for server in $SYNC_SERVERS
do
    SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

    cat<<__EOF >>/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER
),
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    FAILOVER_MODE = $FAILOVER_MODE,
    SEEDING_MODE = AUTOMATIC,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
__EOF
done # for server in $SYNC_SERVERS

for server in $ASYNC_SERVERS
do
    SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

    cat<<__EOF >>/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER
),
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
    FAILOVER_MODE = $FAILOVER_MODE,
    SEEDING_MODE = AUTOMATIC,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
__EOF
done # for server in $ASYNC_SERVERS

for server in $CONFIG_ONLY_SERVERS
do
    SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

    cat<<__EOF >>/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER
),
N'$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = CONFIGURATION_ONLY
__EOF
done # for server in $ASYNC_SERVERS

cat<<__EOF >>/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER
);

ALTER AVAILABILITY GROUP [$AG_NAME] GRANT CREATE ANY DATABASE;
GO
__EOF

echo "Creating $AG_NAME"
runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-setup4.$PRIMARY_SERVER"


for server in $SYNC_SERVERS $ASYNC_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup5.$server
ALTER AVAILABILITY GROUP [$AG_NAME] JOIN WITH (CLUSTER_TYPE = $CLUSTER_TYPE);
ALTER AVAILABILITY GROUP [$AG_NAME] GRANT CREATE ANY DATABASE;
GO
__EOF

    echo "Joining $server to $AG_NAME"
    runsqlcmd $server "/tmp/sqlcmd-ag-setup5.$server"

done #for server in $SYNC_SERVERS $ASYNC_SERVERS

for server in $CONFIG_ONLY_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup6.$server
ALTER AVAILABILITY GROUP [$AG_NAME] JOIN WITH (CLUSTER_TYPE = $CLUSTER_TYPE);
GO
__EOF
    echo "Joining configuration-only server $server to $AG_NAME"
    runsqlcmd $server "/tmp/sqlcmd-ag-setup6.$server"

done #for server in $CONFIG_ONLY_SERVERS

sleep 3
echo "Backup the database"

cat<<__EOF >/tmp/sqlcmd-ag-setup7.$PRIMARY_SERVER
ALTER DATABASE [$DB_NAME] SET RECOVERY FULL;
BACKUP DATABASE [$DB_NAME]
  TO DISK = N'$DB_BKUP_PATH';
GO
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-setup7.$PRIMARY_SERVER"

sleep 3
echo "Add the database to the AG and replicate it"
# Add the database to the AG and replicate it
cat<<__EOF >/tmp/sqlcmd-ag-setup8.$PRIMARY_SERVER
ALTER AVAILABILITY GROUP [$AG_NAME] ADD DATABASE [$DB_NAME];
GO
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-setup8.$PRIMARY_SERVER"

echo "Give the database time to replicate"

sleep 30
echo "See if the database was created on the sync and async replica servers"

# Now we check to make sure the database was created on the sync and async servers
for server in $SYNC_SERVERS $ASYNC_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-setup9.$server
SELECT * FROM sys.databases WHERE name = '$DB_NAME';
GO
SELECT DB_NAME(database_id) AS 'database', synchronization_state_desc FROM sys.dm_hadr_database_replica_states;
GO
quit
__EOF

    runsqlcmd $server "/tmp/sqlcmd-ag-setup9.$server"

done # for server in $SYNC_SERVERS $ASYNC_SERVERS


