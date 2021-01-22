#!/bin/sh

echo "Install full text search"
echo -n "sudo yum install mssql-server-fts"
read 
sudo yum install mssql-server-fts
echo

echo "Install High Availability support"
echo -n "sudo yum install -y mssql-server-ha"
read
sudo yum install -y mssql-server-ha
echo

echo "Enable High Availability support"
echo -n "sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1"
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1

echo "Enable SQL Agent"
echo -n "sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true"
read
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
echo

echo "To make sure that all of our changes take effect, we restart SQL Server"
echo -n "sudo systemctl restart mssql-server"
read
sudo systemctl restart mssql-server
