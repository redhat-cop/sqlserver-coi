config-mssql-tls


File: mssql-sec.yml

A sample playbook for configuring SQL Server to use TLS-encrypted connections
using the Ansible Collection for Microsoft SQL Server.  The playbook also 
uses the RHEL System Role for Certificates to generate a certificate and 
private key that can be managed by certmonger.  Be sure to change the hostname
so that it matches the name of your server.  

To utilize the certificate, you will need to install the CA into the system
CA cache on the server as well as on any clients you wish to allow to access
the server securely.

This can be done using these commands:

$ sudo openssl pkcs12 -in /var/lib/certmonger/local/creds \
  -out /etc/pki/ca-trust/source/anchors/localCA.pem -nokeys \
  -nodes -passin pass:
$ sudo update-ca-trust

FILE: check_tls.sql 

A T-SQL script for confirming that  connections are being encrypted by 
your SQL Server.  If you installed SQL Server with the ansible role, 
and have the CA installed properly as described above, you should be 
able to connect to the server and run this script using:

$ /opt/mssql-tools/bin/sqlcmd -S HOSTNAME -U ADMIN -P PASSWORD -i check-tls.sql

Where HOSTNAME is the name of your SQL Server host as specified in
the certificate, ADMIN is an administrative account such as "sa", 
and PASSWORD is the password for the administrative account.

