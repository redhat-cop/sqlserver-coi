#!/bin/sh

PATH=$PATH:/opt/mssql-tools/bin

# Name for the SQL user
SQL_USER="assessmentLogin"


# Disable the systemd timer if it's enabled
sudo systemctl disable mssql-runassessment.timer

# Remove the systemd files 
sudo rm /etc/systemd/system/mssql-runassessment.service
sudo rm /etc/systemd/system/mssql-runassessment.timer

# Remove the $SQL_USER account 
if sqlcmd -S $HOSTNAME -Q quit > /dev/null 2>&1
then
    USE_AD=true
else
    USE_AD=false
fi


if [ -z ${SA_USER} ] 
then
    SA_USER=none
fi

if [ -z ${SA_PASSWORD} ] 
then
    SA_PASSWORD=none
fi

while ! sqlcmd -S $HOSTNAME -U $SA_USER -P $SA_PASSWORD -Q quit > /dev/null 2>&1
do
    echo -n "Enter a SQL Server adminstrator login: "
    read SA_USER
    echo -n "Enter a SQL Server administrator password: "
    read -s SA_PASSWORD
done

cat<<__EOF>/tmp/sqlcmd-assess-drop
USE [master]
GO
DROP LOGIN [$SQL_USER] 
GO
__EOF

echo $USER_AD
if [ $USE_AD = "true" ]
then
    sqlcmd -S $HOSTNAME -V 16 -i /tmp/sqlcmd-assess-drop
else
    sqlcmd -S $HOSTNAME -U $SA_USER -P $SA_PASSWORD -V 16 -i /tmp/sqlcmd-assess-drop
fi

if [ $? -ne 0 ]
then
    echo "failed to drop $SA_USER login" >&2
    rm /tmp/sqlcmd-assess-drop
    exit 1
fi
rm /tmp/sqlcmd-assess-drop

# Remove credentials used by the assessment tool 
sudo rm /var/opt/mssql/secrets/assessment

# Remove the runassessment.ps1 utility
sudo rm /opt/mssql/bin/runassessment.ps1

exit 0
