echo -n "ansible-playbook mssql.yml -b -K -l localhost, --ask-vault-pass"
read
ansible-playbook mssql.yml -b -K -l localhost, --ask-vault-pass
