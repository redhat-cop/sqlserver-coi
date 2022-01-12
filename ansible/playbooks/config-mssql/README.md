mssql.yml

A sample playbook for configuring and tuning Microsoft SQL Server using 
the Ansible Collection for Microsoft SQL Server.

This playbook installs SQL Server and the SQL Server client tools. System and 
application specific tuning are then performed to deliver the best 
performance.  The playbook also installs Microsoft PowerShell to allow 
insights to make use of the SQL Assessment API to report on database health.  

Lastly, the  playbook opens the necessary firewall port for SQL Server 
communications.  Note that today firwalld configuration is handled by generic
ansible but in future, configuration will be handled by a RHEL System Role.
