#!/bin/sh

# ag-add - adds a node to an existing AG and configures it for
#          the Red Hat High Availability Add-On.
#          Note that even though this has arguments, it still relies on the 
#          params.sh file.  This command should be run from the primary server.


# Bring in the configuration parameters
source ./params.sh
source ./initvars.sh
source ./functions.sh

if [ $# -lt 2 ]
then
    echo "usage: ag-add sync|async|config-only server1 passwd1 server2 passwd2 ..." >&2
    exit 1
else
    type=$1
fi

shift 1

# List of passwords keyed by server name
declare -A NEW_SERVERS_PASS

while [ $# -gt 0 ]
do
    server=$1
    shift 1
    passwd=$1
    NEW_SERVERS_PASS+=([$server]=$pass)
    shift 1
done

# List of server names
NEW_SERVERS=${!NEW_SERVERS_PASS[@]}

case $type in

    sync)
        echo "Adding sync servers $@ to $AG_NAME"
	;;
    async)
        echo "Adding async servers $@ to $AG_NAME"
	;;
    config-only)
        echo "Adding config-only servers $@ to $AG_NAME"
	;;
    *)
	echo "incorrect server type" >&2
        echo "usage: ag-add sync|async|config-only server1 server2 ..." >&2
        exit 1
	;;
esac


echo "Copying master certificate to new servers"
# Copy the certificates to the new servers
#
# First cache the certs locally
mkdir ./dbm_cert_cache
runscpcmd "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" "root@$PRIMARY_SERVER:/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.*" ./dbm_cert_cache 

for server in $NEW_SERVERS
do
    runscpcmd "${ALL_SERVERS_PASS[$server]}" "./dbm_cert_cache/$DBM_CERTIFICATE_NAME.*" root@$server:/var/opt/mssql/data/
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" chown mssql:mssql /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.*
done # for server in $NEW_SERVERS

# Clear the dbm_cert_cache
rm -rf dbm_cert_cache

echo "Creating certificates for new servers"
# Copy the certificates to the new servers
# Create certificates on these servers
# Note that PRIVATE_KEY_PASSWORD is re-used here as the decryption piece
for server in $NEW_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd-ag-add0.$server
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$MASTER_KEY_PASSWORD';
CREATE CERTIFICATE $DBM_CERTIFICATE_NAME
    FROM FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer'
    WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk',
    DECRYPTION BY PASSWORD = '$PRIVATE_KEY_PASSWORD'
            );
GO
__EOF

    runsqlcmd $server "/tmp/sqlcmd-ag-add0.$server"

done # for server in $NEW_SERVERS

# Tell SQL Server to turn on ha and health monitoring
echo "Turn on HADR SQL Server"
for server in $NEW_SERVERS
do
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" '/opt/mssql/bin/mssql-conf set hadr.hadrenabled  1; systemctl restart mssql-server'
done # for server in $NEW_SERVERS

sleep 10
echo "Turn on health monitoring for SQL Server"

for server in $NEW_SERVERS
do
    cat<<__EOF >/tmp/sqlcmd-ag-add1.$server
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
__EOF
    
    runsqlcmd $server "/tmp/sqlcmd-ag-add1.$server"

done # for server in $NEW_SERVERS

sleep 3
echo "Creating database mirroring endpoints on all instances for replication"
# Create database mirroring endpoints on all instances for replication

for server in $NEW_SERVERS
do
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" "firewall-cmd --zone=public --add-port=$LISTENER_PORT/tcp --permanent; firewall-cmd --reload"
done # for server in $NEW_SERVERS

if [ $type != "config-only" ]
then
   for server in $NEW_SERVERS
   do
      cat<<__EOF >/tmp/sqlcmd-ag-add2.$server
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

        runsqlcmd $server "/tmp/sqlcmd-ag-add2.$server"

    done # for server in sync or async $NEW_SERVERS
else

    for server in $NEW_SERVERS
    do
       cat<<__EOF >/tmp/sqlcmd-ag-add3.$server
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
        runsqlcmd $server "/tmp/sqlcmd-ag-add3.$server"

    done # for server in config-only $NEW_SERVERS
fi


sleep 3
echo "Updating the availability group"
# Here we'll actually create the availability group


if [ $type = "sync" ]
then
    for server in $NEW_SERVERS
    do
        SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

        cat<<__EOF >/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server
ALTER AVAILABILITY GROUP [$AG_NAME]
     ADD REPLICA ON '$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    FAILOVER_MODE = $FAILOVER_MODE,
    SEEDING_MODE = AUTOMATIC,
    SECONDARY_ROLE = (ALLOW_CONNECTIONS = ALL)
  );
__EOF
       echo "Altering $AG_NAME to add servers:$NEW_SERVERS of type:$type"
       runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server"
    done # for server in sync $NEW_SERVERS

elif [ $type = "async" ]
then

    for server in $NEW_SERVERS
    do
        SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

        cat<<__EOF >/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server
ALTER AVAILABILITY GROUP [$AG_NAME]
     ADD REPLICA ON '$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
    FAILOVER_MODE = $FAILOVER_MODE,
    SEEDING_MODE = AUTOMATIC,
    SECONDARY_ROLE = (ALLOW_CONNECTIONS = ALL)
  );
__EOF
        echo "Altering $AG_NAME to add servers:$NEW_SERVERS of type:$type"
        runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server"

    done # for server in $NEW_SERVERS

else # type is config-only
    for server in $CONFIG_ONLY_SERVERS
    do
        SHORT_NAME=`echo $server | awk -F . '{ print $1 }'`

        cat<<__EOF >/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server
ALTER AVAILABILITY GROUP [$AG_NAME]
     ADD REPLICA ON '$SHORT_NAME'
  WITH (
    ENDPOINT_URL = N'tcp://$server:$LISTENER_PORT',
    AVAILABILITY_MODE = CONFIGURATION_ONLY
  );
__EOF
        echo "Altering $AG_NAME to add servers:$NEW_SERVERS of type:$type"
        runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-add4.$PRIMARY_SERVER-$server"

    done # for server in config-only $NEW_SERVERS
fi


if [ $type != "config-only" ]
then
    for server in $NEW_SERVERS
    do
        cat<<__EOF >/tmp/sqlcmd-ag-add5.$server
ALTER AVAILABILITY GROUP [$AG_NAME] JOIN WITH (CLUSTER_TYPE = $CLUSTER_TYPE);
ALTER AVAILABILITY GROUP [$AG_NAME] GRANT CREATE ANY DATABASE;
GO
__EOF

        echo "Joining $server to $AG_NAME"
        runsqlcmd $server "/tmp/sqlcmd-ag-add5.$server"

    done #for server in non config-only $NEW_SERVERS

else # the config-only case

    for server in $NEW_SERVERS
    do
        cat<<__EOF >/tmp/sqlcmd-ag-add6.$server
ALTER AVAILABILITY GROUP [$AG_NAME] JOIN WITH (CLUSTER_TYPE = $CLUSTER_TYPE);
GO
__EOF
        echo "Joining configuration-only server $server to $AG_NAME"
        runsqlcmd $server "/tmp/sqlcmd-ag-add6.$server"

    done #for server in $NEW_SERVERS
fi # config-only

echo "Give the database time to replicate"

sleep 30
echo "See if the database was created on any new sync or async nodes"

# Now we check to make sure the database was created on the sync and async nodes, but not for config-only
if [ $type != "config-only" ]
then
    for server in $NEW_SERVERS
    do
        cat<<__EOF >/tmp/sqlcmd-ag-add7.$server
SELECT * FROM sys.databases WHERE name = '$DB_NAME';
GO
SELECT DB_NAME(database_id) AS 'database', synchronization_state_desc FROM sys.dm_hadr_database_replica_states;
GO
quit
__EOF

        runsqlcmd $server "/tmp/sqlcmd-ag-add7.$server"

    done # for server in sync or async $NEW_SERVERS
fi

# Verify that we have a cluster in place to support RHEL HA Add-On
if [ $CLUSTER_TYPE != "EXTERNAL" ]
then
    echo "Cluster type is $CLUSTER_TYPE" >&2
    echo "Skipping RHEL HA Add-on configuration"
    exit 0
fi

echo "Setting password for hacluster account and enabling RHEL HA Add-On"
for server in $NEW_SERVERS
do
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" passwd --stdin hacluster<<__EOF
$HACLUSTER_PW
__EOF
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" "systemctl enable pcsd;sudo systemctl start pcsd; sudo systemctl enable pacemaker"
done # for server in $NEW_SERVERS

echo "Create a SQL Server login for Pacemaker on new servers"

# Create a SQL Server login for Pacemaker on new servers
for server in $NEW_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd-pcs-add8.$server
USE [master]
GO
CREATE LOGIN [pacemakerLogin] with PASSWORD= N'$PACEMAKER_SQL_PW'
ALTER SERVER ROLE [sysadmin] ADD MEMBER [pacemakerLogin]
GO
__EOF

    runsqlcmd $server "/tmp/sqlcmd-pcs-add8.$server"

    runsshcmd  "$server" "${NEW_SERVERS_PASS[$server]}" "printf \"pacemakerLogin\\n$PACEMAKER_SQL_PW\\n\" > $PACEMAKER_SQL_PW_FILE; chown root:root $PACEMAKER_SQL_PW_FILE; chmod 400 $PACEMAKER_SQL_PW_FILE"

    cat<<__EOF>/tmp/sqlcmd-pcs-add9.$server
GRANT ALTER, CONTROL, VIEW DEFINITION ON AVAILABILITY GROUP::$AG_NAME TO pacemakerLogin
GRANT VIEW SERVER STATE TO pacemakerLogin
__EOF

    runsqlcmd $server "/tmp/sqlcmd-pcs-add9.$server"

done # for server in $NEW_SERVERS

sleep 3
echo "Authorize hosts and add them to the Pacemaker cluster"
# Authorize hosts and add them to the Pacemaker cluster

for server in $NEW_SERVERS
do
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" pcs host auth $server -u hacluster -p "$HACLUSTER_PW"
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" pcs cluster node add $server
    runsshcmd "$server" "${NEW_SERVERS_PASS[$server]}" pcs cluster start $server
done
