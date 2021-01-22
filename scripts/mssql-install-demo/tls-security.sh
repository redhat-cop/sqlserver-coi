#!/bin/sh

echo "Make sure we have a cert and private key to work with."
echo "The certificate should really come from a CA, so this is just an example."
echo -n "openssl req -x509 -nodes -newkey rsa:2048 -subj \"/CN=$HOSTNAME\" -keyout mssql.key -out mssql.pem -days 365"
read
openssl req -x509 -nodes -newkey rsa:2048 -subj "/CN=$HOSTNAME" -keyout mssql.key -out mssql.pem -days 365
echo "Now we set permissions and owner for the private key and the certificate"
echo "and place them in the standard system locations."
echo -n "sudo chown mssql:mssql mssql.pem mssql.key"
read
sudo chown mssql:mssql mssql.pem mssql.key
echo

echo -n "sudo chmod 600 mssql.pem mssql.key"
read
sudo chmod 600 mssql.pem mssql.key
echo

echo -n "sudo mv mssql.pem /etc/pki/tls/certs"
read
sudo mv mssql.pem /etc/pki/tls/certs
echo

echo -n "sudo mv mssql.key /etc/pki/tls/private"
read
sudo mv mssql.key /etc/pki/tls/private
echo

echo "Here we point SQL Server to the certificate"
echo -n "sudo /opt/mssql/bin/mssql-conf set network.tlscert /etc/pki/tls/certs/mssql.pem"
read
sudo /opt/mssql/bin/mssql-conf set network.tlscert /etc/pki/tls//certs/mssql.pem
echo

echo "Here we Point SQL Server to the private key"
echo -n "sudo /opt/mssql/bin/mssql-conf set network.tlskey /etc/pki/tls/private/mssql.key"
read
sudo /opt/mssql/bin/mssql-conf set network.tlskey /etc/pki/tls/private/mssql.key 
echo

echo "Set the most modern version Microsoft supports (currently 1.2)"
echo -n "sudo /opt/mssql/bin/mssql-conf set network.tlsprotocols 1.2"
read
sudo /opt/mssql/bin/mssql-conf set network.tlsprotocols 1.2 
echo 

echo "Force the use of encryption by clients connecting to SQL Server"
echo -n "sudo /opt/mssql/bin/mssql-conf set network.forceencryption 1"
read
sudo /opt/mssql/bin/mssql-conf set network.forceencryption 1 
echo

echo "To make sure that all of our changes take effect, we restart"
echo -n "sudo systemctl restart mssql-server"
read
sudo systemctl restart mssql-server
