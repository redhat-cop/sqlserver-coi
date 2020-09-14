#!/bin/sh

# Bring in the configuration parameters
source ./params.sh

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
