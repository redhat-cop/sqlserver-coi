#!/bin/sh
# Configure the SQL Server repos
#
# The SQL Server repo
echo -n "sudo curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2019.repo"
read
sudo curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2019.repo

# The SQL Server tools repo
echo 
echo -n "sudo curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/8/prod.repo"
read
sudo curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/8/prod.repo

# Do some cleanup in case it's needed
echo 
echo -n "sudo yum remove unixODBC-utf16 unixODBC-utf16-devel"
read
sudo yum remove unixODBC-utf16 unixODBC-utf16-devel

# Install the RPMs
echo
echo -n "sudo yum install -y tuned-profiles-mssql"
read
sudo yum install -y tuned-profiles-mssql
echo 
echo -n "sudo yum install -y mssql-server mssql-tools unixODBC-devel"
read
sudo yum install -y mssql-server mssql-tools unixODBC-devel

# Prepare RHEL to run SQL Server
# Open the firewall port
echo 
echo -n "sudo firewall-cmd --zone=public --add-port=1433/tcp --permanent"
read
sudo firewall-cmd --zone=public --add-port=1433/tcp --permanent
echo -n "sudo firewall-cmd --reload"
read
sudo firewall-cmd --reload

# Run tuned
echo
echo -n "sudo tuned-adm profile mssql"
read
sudo tuned-adm profile mssql

# Setup SQL Server
echo 
echo -n "sudo /opt/mssql/bin/mssql-conf setup"
read
sudo /opt/mssql/bin/mssql-conf setup

# Verify that SQL Server is running
echo 
echo -n "sudo systemctl status mssql-server"
read
sudo systemctl status mssql-server

echo
echo -n "cat myscript.sql"
read
cat myscript.sql

# Run a sqlcmd from a file
echo
echo -n "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -i myscript.sql"
read
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -i myscript.sql

