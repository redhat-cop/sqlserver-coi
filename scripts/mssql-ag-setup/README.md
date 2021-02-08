mssql-ag-setup

Author: Louis Imershein
Email:  limershe@redhat.com

This set of tools is intended to simplify the setup of SQL Server on Red Hat 
Enterprise Linux.  Prior to running any of these shell scripts, you should 
modify the configuration variables in the params.sh file.

I used to recommend that you temporarily setup passwordless ssh root host 
equvalence between the cluster nodes using ssh-keygen and ssh-copy-id but 
the tool now supports specifying a root password for each host in the params.sh
file. The use of ssh keys on top of a strong password for each node highly 
recommended, but if you do use keys, you should still prompt for a passphrase 
as well.  

Remember that the params.sh file contains all the passwords for this 
configuration as well as the choice of mechanisms to use:

1. ssh with root passwd
2. ssh with keys but no passphrase (default)
3. ssh setup with keys and a passphrase


For security reasons, you should always keep your params.sh file encrypted and
backed up when not in use.  You encrypt using a tool such as gpg or openssl.

The following scripts are available:

params.sh        - contains the parameters all of the scripts use to configure 
                   SQL Server.

all-setup.sh     - calls all the other scripts in this directory.  Comment out 
                   any you don't need.

sw-install.sh    - installs Red Hat HA including the SQL Server resource agent 
                   from Microsoft. If you're behind a DMZ, you'll want to 
                   perform this step through other means.

ag-keygen.sh     - generates keys that secure the SQL Server AG data 
                   replication process

ag-setup.sh      - sets up the SQL Server Availability Group

pcs-setup.sh     - configures Red Hat HA for the cluster

fence-setup.sh   - reserved for Red Hat HA fencing configuration.  
                   By default we just use watchdog timers, but for 
                   installations that are not bare metal, using 
                   Red Hat Virtualization, using Azure, or VMware,
                   you'll want to modify this script to configure 
                   a fencing agent.

ag-add.sh        - adds one or more of a particular type of server
                   to the existing cluster documented in params.sh
                   Once you've added these, be sure to update your params.sh
                   file to include the information about the new servers.


ag-sw-add.sh     - adds Red Hat HA including the SQL Server resource agent 
                   from Microsoft to new servers being added into a cluster. 
                   If you're behind a DMZ, you'll want to 
                   perform this step through other means.
