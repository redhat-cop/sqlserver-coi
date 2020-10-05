#!/bin/sh
source ./params.sh
source ./functions.sh

# Cleanup the configuration for demo purposes

echo "Backup the database"
cat << __EOF>/tmp/backup.$PRIMARY_SERVER
BACKUP DATABASE [$DB_NAME]
  TO DISK = N'$DB_BKUP_PATH';
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/backup.$PRIMARY_SERVER"

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
        runsqlcmd $server "/tmp/cleanup.$server"

	ssh root@$server  rm /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer /var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk

done

cat <<__EOF>/tmp/restore.$PRIMARY_SERVER
RESTORE DATABASE [$DB_NAME] FROM DISK="/var/opt/mssql/data/$DB_NAME.bak";
GO
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/restore.$PRIMARY_SERVER"

