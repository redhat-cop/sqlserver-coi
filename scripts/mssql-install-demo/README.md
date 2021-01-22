mssql-install-demo

Author: Louis Imershein 
Email:  limershe@redhat.com

These tools can be used to demonstrate the basic command line install of a 
SQL Server intance on Red Hat Enterprise Linux.  There are also a set of
more advanced optional tasks.

install.sh - is the basic minimum install proceedure which includes install
and basic tuning of SQL Server as well as the basic setup of an example 
database.

extras.sh - installs the full text search and HA packages and enables the 
HADR feature of SQL Server but does not configure a cluster. It also enables 
the SQL Agent.

enterprise-storage.sh - configures SQL Server to use FUA-capable storage.
This can yield performance improvements of 30% or more in some workloads
so you want it turned on if your storage devices support it!

tls-security.sh - sets up a certificate and private key and configures 
SQL Server to require their use.
