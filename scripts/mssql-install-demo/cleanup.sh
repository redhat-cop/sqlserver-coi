#!/bin/sh
# Cleanup a SQL Server repo
#
# Close the firewall
sudo firewall-cmd --remove-port=1433/tcp --zone=public --permanent
sudo firewall-cmd --reload

# Stop SQL Server
sudo systemctl stop mssql-server

# Reset the tuned profile to virtual-guest
sudo tuned-adm profile virtual-guest

# Remove the RPMS
sudo yum remove -y mssql-server mssql-tools unixODBC-devel tuned-profiles-mssql

# Remove the repos
sudo rm -rf /etc/yum.repos.d/mssql-server.repo 

sudo rm -rf /etc/yum.repos.d/msprod.repo 

# Clean up any remaining files in the Microsoft SSOs
sudo rm -rf /var/opt/mssql
sudo rm -rf /opt/mssql
sudo rm -rf /opt/mssql-tools
sudo rm -f /etc/pki/tls/certs/mssql.pem
sudo rm -f /etc/pki/tls/private/mssql.key
