ConvertFrom-StringData @'
id_ctshttpredirectioncheck=Check HTTP Redirection on TSGateway
id_ctshttpredirectioncheckdescription=HTTP Redirection is currently not correctly configured and this may cause problems to logon to Remote Desktop Gateway. Verify in Internet Information Server (IIS) Manager that HTTP redirection is not configured on the /rpc virtual directory or inherited from the web site. Please see the internal KB article for more information about this problem
id_ctshttpredirectionchecksolution=HTTP redirection that would effect Terminal Services Gateway/Remote Desktop Gateway
'@
