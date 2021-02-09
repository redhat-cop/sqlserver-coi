#!/bin/sh

# This file contains the parameters used by all of the other scripts

# Debug mode.  If set to 1, then unsuccesful sql commands are saved
# to /tmp.  We do not save them there by default since they can
# contain passwords.
DEBUG_MODE=0

# Update PATH to include sqlcmd as it will be needed
PATH=$PATH:/opt/mssql-tools/bin

# Prompt expected by sshpass when connecting via ssh to a remote root account
SSH_PASS_PROMPT=""
#
#     SSH_PASS_PROMPT="id_rsa':" 
#
# should be used if you're using a passphrase which you have specified with 
# ssh_keygen
#
#     SSH_PASS_PROMPT="word:" 
#
# can be used if you've not set up keys and are just using a traditional 
# password (not recommended).
#
#     SSH_PASS_PROMPT="";
#
# Assumes keys are in place via ssh-keygen, but no passphrase has been set. 
# This allows connection without a passphrase.

# SQL Server administrative login and password
SQL_ADMIN="sa"
SQL_PASS='ftFqn58F?'

# The port the servers listen on for replication
LISTENER_PORT=5022

# The SQL Server port (doesn't have to be the default one)
SQL_PORT=1433

# The availability group name in SQL Server
AG_NAME="ag1"

# The database name and the path for a backup
DB_NAME=ExampleDB
DB_BKUP_PATH=/var/opt/mssql/data/$DB_NAME.bak

# A password for the hacluster user added by pacemaker 
HACLUSTER_PW='aMhc:8Di3'

# A floating virtual IP address for accessing the master SQL Server node
VIRTUAL_IP=192.168.200.254

# Keys for SQL replication
MASTER_KEY_PASSWORD='Nmre34JGmDmUX3G1mdQ'
PRIVATE_KEY_PASSWORD='w22yQeEXW9cjvr2hRig'

# Name for certificates
DBM_CERTIFICATE_NAME="dbm_certificate"

# Password for Pacemaker account in SQL Server
PACEMAKER_SQL_PW='f9YHkyxHb8vlP0rC3g4'
PACEMAKER_SQL_PW_FILE="/var/opt/mssql/secrets/passwd"

# Type of fencing to use.  Current supported types are baremetal azure or 
# vmware.  Note that baremetal fencing
# also supports Red Hat Virtualization.
FENCING_TYPE="baremetal"

# Parameters used if FENCING_TYPE is azure
# See: https://docs.microsoft.com/en-us/azure/azure-sql/virtual-machines/linux/rhel-high-availability-stonith-tutorial

# Application ID value from your application registration in Azure.
AZURE_APPLICATION_ID=""

# The Service Principal Password with the value from the client secret in Azure.
AZURE_SP_PASSWORD="" 

# The resource group from your subscription
AZURE_RESOURCE_GROUP_NAME="" 

# The tenantID from your Azure Subscription.
AZURE_TENANT_ID=""

# The subscriptionId from your Azure Subscription.
AZURE_SUBSCRIPTION_ID=""

# The port number for
AZURE_LB_PROBE_PORT=59999

# Azure load balancer IP address
AZURE_LB_IP="10.0.0.7"

# Parameters used if FENCING_TYPE is vmware

# ESXi/vCenter IP address
VMWARE_IP_ADDRESS="vcenter.mydomain"

# ESXi login and password
VMWARE_LOGIN="vmsoap@VSPHERE.LOCAL"
VMWARE_PASSWORD="M15ecurePasswd!"

# Here we specify the type of cluster to use.
CLUSTER_TYPE="EXTERNAL"
#
# Set the cluster to use Pacemaker as follows:
#
#    CLUSTER_TYPE=EXTERNAL
#
# Set the cluster to provide a read-scale availability group as follows:
#
#    CLUSTER_TYPE=NONE
#
# 
# Below we specify the initial primary server where we configure SQL Server 
# and Pacemaker.
#
# You must have 1 primary server and it must  have a password associated with 
# it and SSH_PASS_PROMPT must be set appropriately (see above).
#
# There can be at most 9 servers in a writeable SQL Server Availability Group.
#
# The default example sets the hostname but no password. 
declare -A PRIMARY_SERVER_PASS=(["sql1.mydomain"]="")

# You can set the host name and password as follows:
#
#    declare -A PRIMARY_SERVER_PASS=(["sql1.ag1"]="passwd1")
#
# In the above example, the server name is sql1.ag1 and the password is 
# set to: passwd1
#

# Sync replica servers.  You can have up to 5 syncronous replicas
# You need at least one syncronous replica for automatic failover. 
# There can be at most 9 servers in a read-write SQL Server Availability Group.
# 
# By default, we'll configure servers sql2.ag1 and sql3.ag1 but leave 
# the passords unset since we're relying on ssh key's only for security.
#
declare -A SYNC_SERVERS_PASS=(["sql2.mydomain"]="" ["sql3.mydomain"]="")

#
# You can assign passwords as in the following example: 
#
# declare -A SYNC_SERVERS_PASS=(["sql2.ag1"]="passwd2" ["sql3.ag1"]="passwd3")
#
# Here the server names sql2.ag1 and sql3.ag1 their respective passwords are
# set to passwd2 and passwd3

SYNC_SERVERS=${!SYNC_SERVERS_PASS[@]}


# Async replica servers.  You can have up to 8 asyncronous replicas
# There can be at most 9 servers in a read-write SQL Server Availability Group.
# Async replicas are manual failover only.
#
# example: 
# declare -A ASYNC_SERVERS_PASS=(["sql4.ag1"]="passwd4" ["sql5.ag1"]="passwd5")
#
declare -A ASYNC_SERVERS_PASS=()
ASYNC_SERVERS=${!ASYNC_SERVERS_PASS[@]}

# Configuration-only servers.  You can use one of these to support Microsoft's 
# three node limit for Availabiliy Groups (AGs) on Linux, even if you only 
# have two syncronous replicas.  Configuration replicas can use a no-charge SQL 
# Server Express license for the third node. It's only used by the AG to 
# maintain internal quorum.  There's no replication to the node and you'll 
# never actually fail over to it.
#
# example: 
# declare -A CONFIG_ONLY_SERVERS=(["sql6.ag1"]="passwd6")
#
declare -A CONFIG_ONLY_SERVERS_PASS=()
CONFIG_ONLY_SERVERS=${!CONFIG_ONLY_SERVERS_PASS[@]}

