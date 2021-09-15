runassessment tools

Author Louis Imershein Email: limershe@redhat.com

This is a setup script which will install the runassessment.ps1 script 
from Microsoft under /opt/mssql/bin and configure the system to perform 
assessments.  The most recent assessment is written to the file: 

    /var/opt/mssql/log/assessments/assessment.latest 

The tooling assumes that you have first installed SQL Server as well as 
mssql-tools.

You will be required to supply a password for the assessmentsLogin account
which will be created in the local SQL Server database using SQL Server
authentication.

If you are not already authenticated (via kinit) as a SQL Server 
administrator in Active Directory, you will also be promoted for a SQL
Server administrator login and password.  This will be used to create
the assessmentsLogin account.

The script performs the following tasks:

1. Prompts for a strong password for the assessmentLogin account to be used by runassessment.ps1 in connecting to SQL

2. Determines if it can connect to SQL Server via AD support or  prompts for a SQL administrative user/password if that's not set up.

3. Creates an assessmentLogin user in SQL using the supplied password, stores the credentials in a file with perms 0400 (-r--) owned by mssql user/group

4. Installs pwsh from the MS repo

5. Installs the SQL module for pwsh in the mssql account

6. Pulls down the runassement.ps1 script from GitHub

7. Installs mssql-runassessment.timer and mssql-runassessment.system into 
   /etc/systems/system this can be enabled to collect a daily report from 
   SQL Server

To enable the automatic daily assessments use the command:

    sudo systemctl enable mssql-runassessments.timer

If you want to manually invoke an assessment you should do it as the 
mssql user using the command:

    sudo su mssql -c "pwsh -File /opt/mssql/bin/runassessment.ps1"

