#!/bin/sh

echo "This is a set of commands that should be used to improve performance."
echo "It should always be used with FUA capable) storage."
echo "Verify your storage is FUA capable with: sg_modes device_name"
echo "if DpoFua=1, then you're good to go."

df /var/opt/mssql

echo -n "/opt/mssql/bin/mssql-conf traceflag 3979 on"
read
/opt/mssql/bin/mssql-conf traceflag 3979 on
echo

echo -n "/opt/mssql/bin/mssql-conf set control.writethrough 1"
read
/opt/mssql/bin/mssql-conf set control.writethrough 1
echo

echo -n "/opt/mssql/bin/mssql-conf set control.alternatewritethrough 0"
read
/opt/mssql/bin/mssql-conf set control.alternatewritethrough 0
echo

echo "To make sure that all of our changes take effect, we restart"
echo -n "sudo systemctl restart mssql-server"
read
sudo systemctl restart mssql-server
