#!/bin/sh

source ./params.sh
source ./initvars.sh
source ./functions.sh

# Set up the master certificate
echo "Setting up the master certificate"


cat<<__EOF>/tmp/sqlcmd-ag-keygen1.$PRIMARY_SERVER
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$MASTER_KEY_PASSWORD';
CREATE CERTIFICATE $DBM_CERTIFICATE_NAME WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE $DBM_CERTIFICATE_NAME
   TO FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer'
   WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk',
           ENCRYPTION BY PASSWORD = '$PRIVATE_KEY_PASSWORD'
       );
GO
__EOF

runsqlcmd $PRIMARY_SERVER "/tmp/sqlcmd-ag-keygen1.$PRIMARY_SERVER"

sleep 3
echo "Copying certificates to sync, async, and configuration-only servers"
# Copy the certificates to the sync, async, and configuration-only servers
#
# First cache the certs locally
mkdir ./dbm_cert_cache
runscpcmd "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" "root@$PRIMARY_SERVER:/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.*" ./dbm_cert_cache 

for server in $SYNC_SERVERS $ASYNC_SERVERS $CONFIG_ONLY_SERVERS
do
    runscpcmd "${ALL_SERVERS_PASS[$server]}" "./dbm_cert_cache/$DBM_CERTIFICATE_NAME.*" root@$server:/var/opt/mssql/data/
    runsshcmd "$server" "${ALL_SERVERS_PASS[$server]}" chown mssql:mssql "/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.*"
done # for server in $SYNC_SERVERS $ASYNC_SERVERS $CONFIG_ONLY_SERVERS

# Clear the dbm_cert_cache
rm -rf dbm_cert_cache

sleep 3
echo "Creating certificates to sync, async, and configuration-only servers"
# Copy the certificates to the sync, async, and configuration-only servers
# Create certificates on these servers
# Note that PRIVATE_KEY_PASSWORD is re-used here as the decryption piece
for server in $SYNC_SERVERS $ASYNC_SERVERS $CONFIG_ONLY_SERVERS
do
    cat<<__EOF>/tmp/sqlcmd-ag-keygen2.$server
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$MASTER_KEY_PASSWORD';
CREATE CERTIFICATE $DBM_CERTIFICATE_NAME
    FROM FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.cer'
    WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/data/$DBM_CERTIFICATE_NAME.pvk',
    DECRYPTION BY PASSWORD = '$PRIVATE_KEY_PASSWORD'
            );
GO
__EOF

    runsqlcmd $server "/tmp/sqlcmd-ag-keygen2.$server"

done # for server in $SYNC_SERVERS $ASYNC_SERVERS $CONFIG_ONLY_SERVERS
