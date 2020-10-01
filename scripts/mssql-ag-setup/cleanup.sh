#!/bin/sh
source ./params.sh

# Cleanup the configuration for demo purposes

echo "Destroy the Pacemaker cluster"
pcs cluster destroy --all

for server in $ALL_SERVERS
do
	cat<<__EOF>/tmp/cleanup.$server
ALTER DATABASE [$DB_NAME] SET HADR OFF;
GO
DROP DATABASE [$DB_NAME];
GO
DROP AVAILABILITY GROUP [$AG_NAME];
GO
DROP ENDPOINT [Hadr_endpoint];
GO
DROP CERTIFICATE [$DBM_CERTIFICATE_NAME];
GO
DROP MASTER KEY;
GO
__EOF
        sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -i /tmp/cleanup.$server
	ssh root@$server  rm /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk
done

cat <<__EOF>/tmp/restore.$PRIMARY_SERVER
RESTORE DATABASE [$DB_NAME] FROM DISK="/var/opt/mssql/data/$DB_NAME.bak";
GO
__EOF

sqlcmd -S $PRIMARY_SERVER -U $SQL_ADMIN -P $SQL_PASS -i /tmp/restore.$PRIMARY_SERVER

