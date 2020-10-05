
# runsqlcmd(server, file)
#
#     Use the sqlcmd utility to run file
#
runsqlcmd()
{
    server=$1
    file=$2
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -V 16 -i $file
    if [ $? -eq 0 ]
    then
	rm -rf $file
    else
	echo "sqlcmd failed: see $file"
    fi
}

