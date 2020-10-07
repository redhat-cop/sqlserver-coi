#!/bin/sh

# This file contains the parameters used by all of the other scripts


# Debug mode.  If set to 1, then unsuccesful sql commands are saved
# to /tmp.  We do not save them there by default since they can
# contain passwords.
DEBUG_MODE=0

# Update PATH to include sqlcmd as it will be needed
PATH=$PATH:/opt/mssql-tools/bin

# The initial primary server where we configure SQL Server and Pacemaker
# You must have 1 primary server. 
# There can be at most 9 servers in a writeable SQL Server Availability Group.
PRIMARY_SERVER=sql1.ag1

# Sync replica servers.  You can have up to 5 syncronous replicas
# You need at least one syncronous replica for automatic failover. 
# There can be at most 9 servers in a read-write SQL Server Availability Group.
SYNC_SERVERS="sql2.ag1"

# Async replica servers.  You can have up to 8 asyncronous replicas
# There can be at most 9 servers in a read-write SQL Server Availability Group.
# Async replicas are manual failover only.
ASYNC_SERVERS=""

# Configuration-only servers.  You can use one of these to support Microsoft's three node limit for 
# Availabiliy Groups (AGs) on Linux, even if you only have two syncronous replicas.  Configuration replicas
# can use a no-charge SQL Server Express license for the third node. It's only used by the AG to maintain
# internal quorum.  There's no replication to the node and you'll never actually fail over to it.
CONFIG_ONLY_SERVERS="sql3.ag1"

# All the servers in the cluster
ALL_SERVERS="$PRIMARY_SERVER $SYNC_SERVERS $ASYNC_SERVERS $CONFIG_ONLY_SERVERS"

# SQL Server administrative login and password
SQL_ADMIN="sa"
SQL_PASS="RedHat123"

# The port the servers listen on for replication
LISTENER_PORT=5022

# The SQL Server port (doesn't have to be the default one)
SQL_PORT=1433

# The availability group name in SQL Server
AG_NAME="ag1"

# The database name and the path for a backup
DB_NAME=AdventureWorksLT2019
DB_BKUP_PATH=/var/opt/mssql/data/$DB_NAME.bak

# A password for the hacluster user added by pacemaker 
HACLUSTER_PW="RedHat123"

# A floating virtual IP address for accessing the master SQL Server node
VIRTUAL_IP=192.168.200.254

# Keys for SQL replication
MASTER_KEY_PASSWORD='Nmre34JGmDmUX3G1mdQ'
PRIVATE_KEY_PASSWORD='w22yQeEXW9cjvr2hRig'

# Name for certificates
DBM_CERTIFICATE_NAME="dbm_certificate"

PACEMAKER_SQL_PW='f9YHkyxHb8vlP0rC3g4'
PACEMAKER_SQL_PW_FILE="/var/opt/mssql/secrets/passwd"
