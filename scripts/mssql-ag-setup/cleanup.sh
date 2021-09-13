#!/bin/sh
source ./params.sh
source ./initvars.sh
source ./functions.sh

# Cleanup the configuration for demo purposes

echo "Backing up the database"
cat << __EOF>/tmp/sqlcmd-cleanup1.$PRIMARY_SERVER
BACKUP DATABASE [$DB_NAME]
  TO DISK = N'$DB_BKUP_PATH';
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-cleanup1.$PRIMARY_SERVER"

if [ $CLUSTER_TYPE = "EXTERNAL" ]
then
    echo "Destroying the Pacemaker cluster"
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" pcs cluster destroy --all
fi

echo "Removing any config-only server configuration"
for server in $CONFIG_ONLY_SERVERS
do
	cat<<__EOF>/tmp/sqlcmd-cleanup2.$server
DROP LOGIN [pacemakerLogin];
GO
DROP AVAILABILITY GROUP $AG_NAME;
GO
DROP ENDPOINT [Hadr_endpoint];
GO
DROP CERTIFICATE [$DBM_CERTIFICATE_NAME];
GO
DROP MASTER KEY;
GO
__EOF
        runsqlcmd $server "/tmp/sqlcmd-cleanup2.$server"

        runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" rm /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk

done


echo "Removing any replica server configurations"
for server in $SYNC_SERVERS $ASYNC_SERVERS
do
	cat<<__EOF>/tmp/sqlcmd-cleanup3.$server
DROP LOGIN [pacemakerLogin];
GO
ALTER DATABASE [$DB_NAME] SET HADR OFF;
GO
DROP AVAILABILITY GROUP [$AG_NAME];
GO
DROP DATABASE [$DB_NAME];
GO
DROP ENDPOINT [Hadr_endpoint];
GO
DROP CERTIFICATE [$DBM_CERTIFICATE_NAME];
GO
DROP MASTER KEY;
GO
__EOF
        runsqlcmd $server "/tmp/sqlcmd-cleanup3.$server"

        runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" rm /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk

done


echo "Removing the primary server configuration"
cat<<__EOF>/tmp/sqlcmd-cleanup4.$PRIMARY_SERVER
DROP LOGIN [pacemakerLogin];
GO
DROP AVAILABILITY GROUP [$AG_NAME];
GO
DROP DATABASE [$DB_NAME];
GO
DROP ENDPOINT [Hadr_endpoint];
GO
DROP CERTIFICATE [$DBM_CERTIFICATE_NAME];
GO
DROP MASTER KEY;
GO
__EOF
runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-cleanup4.$PRIMARY_SERVER"

runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" rm /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk

echo "Restoring the database from backup to the primary"

cat <<__EOF>/tmp/sqlcmd-cleanup3.$PRIMARY_SERVER
RESTORE DATABASE [$DB_NAME] FROM DISK="/var/opt/mssql/data/$DB_NAME.bak";
GO
__EOF
runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-cleanup3.$PRIMARY_SERVER"

