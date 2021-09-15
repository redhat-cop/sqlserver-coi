#!/bin/sh

PATH=$PATH:/opt/mssql-tools/bin

# Name for the SQL user
SQL_USER="assessmentLogin"

echo "Provide a SQL password for the assessment user"
echo -n "Password: "
read -s PASSWORD1
echo ""

echo -n "Verify Password: "
read -s PASSWORD2
echo ""

# Check if the passwords match
if [ $PASSWORD1 == $PASSWORD2 ]
then
   SQL_PASSWORD=$PASSWORD1 
else
   echo "Passwords do not match" >&2
   exit 1
fi

# Check password strength
PWSCORE=`echo $SQL_PASSWORD |  pwscore`
if [ "$PWSCORE" == "" ]
then
    PWSCORE=0
fi

if [ $PWSCORE  -le 50 ]
then
    echo "Choose a stronger password" >&2
    exit 1
fi

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
    echo ""
done

cat<<__EOF>/tmp/sqlcmd-assess-setup
USE [master]
GO
CREATE LOGIN [$SQL_USER] with PASSWORD= N'$SQL_PASSWORD'
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$SQL_USER]
GO
__EOF

if [ USE_AD = true ]
then
    sqlcmd -S $HOSTNAME -V 16 -i /tmp/sqlcmd-assess-setup
else
    sqlcmd -S $HOSTNAME -U $SA_USER -P $SA_PASSWORD -V 16 -i /tmp/sqlcmd-assess-setup
fi

if [ $? -ne 0 ]
then
    echo "failed to create $SA_USER login" >&2
    rm /tmp/sqlcmd-assess-setup
    exit 1
fi
rm /tmp/sqlcmd-assess-setup


# Save credentials for use by the assessment tool as only readable
# by the Linux mssql user.
sudo sh -c "echo \"$SQL_USER\" > /var/opt/mssql/secrets/assessment"
sudo sh -c "echo \"$SQL_PASSWORD\" >> /var/opt/mssql/secrets/assessment"
sudo chown mssql:mssql /var/opt/mssql/secrets/assessment
sudo chmod 0400 /var/opt/mssql/secrets/assessment

# Install Microsoft powershell if it's not already installed
sudo yum install -y powershell

# Install the SQLServer module for use by Powershell
sudo su mssql -c "/usr/bin/pwsh -Command Install-Module SqlServer"

# Install the runassessment.ps1 utility from Github
sudo /bin/curl -LJ0 -o /opt/mssql/bin/runassessment.ps1 https://raw.githubusercontent.com/microsoft/sql-server-samples/master/samples/manage/sql-assessment-api/RHEL/runassessment.ps1 
sudo chown mssql:mssql /opt/mssql/bin/runassessment.ps1
sudo chmod 0700 /opt/mssql/bin/runassessment.ps1

# Create a directory for the assessment log
sudo mkdir /var/opt/mssql/log/assessments/
sudo chown mssql:mssql /var/opt/mssql/log/assessments/
sudo chmod 0640 /var/opt/mssql/log/assessments/

# Run our first assessment
sudo su mssql -c "pwsh -File /opt/mssql/bin/runassessment.ps1"

# Copy the systemd files into place
sudo cp systemd-mssql-runassessment/mssql-runassessment.service /etc/systemd/system/mssql-runassessment.service
sudo chmod 0644 /etc/systemd/system/mssql-runassessment.service
sudo cp systemd-mssql-runassessment/mssql-runassessment.timer /etc/systemd/system/mssql-runassessment.timer
sudo chmod 0644 /etc/systemd/system/mssql-runassessment.timer

exit 0
