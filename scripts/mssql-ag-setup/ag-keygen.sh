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

echo "Creating certificates to secondary, tertiary, and configuration-only servers"
# Copy the certificates to the secondary, tertiary, and configuration-only servers
# Create certificates on these servers
=======
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

done # for server in $SECONDARY_SERVERS $TERTIARY_SERVERS $CONFIG_ONLY_SERVERS
