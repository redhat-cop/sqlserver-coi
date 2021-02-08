
# runsqlcmd(server, file)
#
#     Use the sqlcmd utility to run file
#
runsqlcmd()
{
    server=$1
    file=$2
    sqlcmd -S $server -U $SQL_ADMIN -P "$SQL_PASS" -V 16 -i $file
    if [ $? -ne 0 ]
    then
        echo "sqlcmd failed: $file" >&2
    fi

    if [ "$DEBUG_MODE" -ne 1 ]
    then
        rm -rf $file
    fi
}


# runsshcmd(server, pass, cmd)
#
#     Use the sshpass and ssh utilities to run a command as root
#
runsshcmd()
{
   server=$1
   pass=$2
   shift 2
   cmd=$@

   if [ "$SSH_PASS_PROMPT" = "" ]
   then
       ssh root@$server $cmd
   else
       echo "$pass" | sshpass -P "$SSH_PASS_PROMPT" ssh root@$server "$cmd"
   fi
}

# runscpcmd(pass, src, dest)
#
#     Use the sshpass and scp utilities to perform a remote copy as root
#
runscpcmd()
{
   pass=$1
   src=$2
   dest=$3

   if [ $SSH_PASS_PROMPT = "" ]
   then
       scp $src $dest
   else
       echo "$pass" | sshpass -P "$SSH_PASS_PROMPT" scp $src $dest
   fi
}
