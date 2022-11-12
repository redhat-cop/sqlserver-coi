SQLclusterPlaybooks

FILE: create_example_db.j2

A sample T-SQL script that is used to create a database on the SQL Server we 
create in step1.yml

FILE: inventory

A file that contains the names of the servers that we'll be configuring into
a SQL Server cluster.

FILE: step1.yml

An ansible playbook that uses the Microsoft SQL Server collection to configure
a SQL Server on Red Hat Enterprise Linux and populate it with the database we
create with the T-SQL script create_example_db.j2

FILE: step2.yml

An ansible playbook that uses the Microsoft SQL Server collection to configure
two additional SQL Server on Red Hat Enterprise Linux systems for use in 
creating an Always On availability group cluster.

FILE: step3-rhkvm.yml

An ansible playbook that configures a SQL Server Always On availability group 
using the Microsoft SQL Server ansible collection and then configures the
Red Hat Enterprise Linux High Availability add-on using the RHEL System Role 
for High Availability.  This example configures a RHEL HA cluster that is
designed for use with Bare Metal, RHEL KVM virtualization, Red Hat 
Virtualization, or Red Hat OpenShift Virtualization. 

If you want to configure Pacemaker from this role, you can set 
mssql_ha_cluster_run_role to true and provide variables required by the 
redhat.rhel_system_roles.ha_cluster role to configure Pacemaker for your 
environment properly.

This example configures required Pacemaker properties and resources and 
enables SBD watchdog.

The redhat.rhel_system_roles.ha_cluster role expects watchdog devices to be 
configured on /dev/watchdog by default, you can set a different device per 
host in inventory. For more information, see the 
redhat.rhel_system_roles.ha_cluster role documentation.

FILE: step3-rhvmw.yml

An ansible playbook that configures a SQL Server Always On availability group 
using the Microsoft SQL Server ansible collection and then configures the
Red Hat Enterprise Linux High Availability add-on using the RHEL System Role 
for High Availability.  This example configures a RHEL HA cluster that is
designed for use with VMWare VSphere.

If you want to configure Pacemaker from this role, you can set 
mssql_ha_cluster_run_role to true and provide variables required by the 
redhat.rhel_system_roles.ha_cluster role to configure Pacemaker for your 
environment properly. See the redhat.rhel_system_roles.ha_cluster role 
documentation for more information.

Note that production environments require Pacemaker configured with fencing agents, this example playbook configures the stonith:fence_vmware_soap agent.


FILE: step3-rhazure.yml

An ansible playbook that configures a SQL Server Always On availability group 
using the Microsoft SQL Server ansible collection and then configures the
Red Hat Enterprise Linux High Availability add-on using the RHEL System Role 
for High Availability.  This example configures a RHEL HA cluster that is
designed for use with VMWare VSphere.

If you want to configure Pacemaker from this role, you can set 
mssql_ha_cluster_run_role to true and provide variables required by the 
redhat.rhel_system_roles.ha_cluster role to configure Pacemaker for your 
environment properly. See the redhat.rhel_system_roles.ha_cluster role 
documentation for more information.

Prerequisites You must configure all required resources in Azure. For more information, see the following articles in Microsoft documentation:

Setting up Pacemaker on Red Hat Enterprise Linux in Azure
https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-rhel-pacemaker#1-create-the-stonith-devices


Tutorial: Configure availability groups for SQL Server on RHEL virtual 
machines in Azure
https://docs.microsoft.com/en-us/azure/azure-sql/virtual-machines/linux/rhel-high-availability-stonith-tutorial?view=azuresql

Note that production environments require Pacemaker configured with fencing 
agents, this example playbook configures the stonith:fence_azure_arm agent.

This example playbooks sets the firewall variables for the 
redhat.rhel_system_roles.firewall role and then runs this role to open the 
probe port configured in Azure.
