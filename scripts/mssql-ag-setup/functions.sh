
# runsqlcmd(server, file)
#
#     Use the sqlcmd utility to run file
#
runsqlcmd()
{
    server=$1
    file=$2
    sqlcmd -S $server -U $SQL_ADMIN -P $SQL_PASS -V 16 -i $file
    if [ $? -ne 0 ]
    then
        echo "sqlcmd failed: $file" >&2
    fi

    if [ "$DEBUG_MODE" -ne 1 ]
    then
        rm -rf $file
    fi
}

