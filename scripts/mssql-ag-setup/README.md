mssql-ag-setup

Author: Louis Imershein
Email:  limershe@redhat.com

This set of tools is intended to simplify the setup of SQL Server on Red Hat 
Enterprise Linux.  Prior to running any of these shell scripts, you should 
modify the configuration variables in the params.sh file.

I also recommend that you temporarily setup ssh root host equvalence between 
the cluster nodes using ssh-keygen and ssh-copy-id. This will allow you to 
configure the device with mostly passwordless experience. Once the configuration
process is completed, you should clear unwanted certificates out of the 
directory: /root/.ssh/


The following scripts are available:

params.sh        - contains the parameters all of the scripts use to configure 
                   SQL Server.

functions.sh     - common functions used by the different scripts

all-setup.sh     - calls all the other scripts in this directory.  Comment out 
                   any you don't need.

sw-install.sh    - installs pacemaker, resource and fencing agents including 
                   the SQL Server resource agent from Microsoft. If you're 
                   behind a DMZ, you'll want to perform this step through other
                   means.

ag-keygen.sh     - generates keys that secure the SQL Server AG data 
                   replication process

ag-setup.sh      - sets up the SQL Server Availability Group

fence-setup.sh   - this script is reserved for fencing configuration.  
                   By default we just use watchdog timers, but for 
                   installations that are either not bare metal or using 
                   Red Hat Virtualization, you'll want to modify 
                   this  script to configure a fencing agent.

pcs-setup.sh     - this script configures Pacemaker for the cluster

cleanup.sh       - this script attempts to cleanup everything then restores
                   the most recent database backup associated with the AG 
                   to the primary node. Usefull for demos.
