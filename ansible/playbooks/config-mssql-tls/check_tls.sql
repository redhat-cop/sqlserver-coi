SELECT session_id, connect_time, net_transport, encrypt_option, auth_scheme, client_net_address 
FROM sys.dm_exec_connections
