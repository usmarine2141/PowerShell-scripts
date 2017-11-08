#************************************************
# DC_DhcpServer-Component.ps1
# Version x
# Date: 2009-2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects information about DHCP Server.
# Called from: Networking Diags
#*******************************************************

Trap [Exception]
	{
	 # Handle exception and throw it to the stdout log file. Then continue with function and script.
		 $Script:ExceptionMessage = $_
		 "[info]: Exception occurred."  | WriteTo-StdOut
		 "[info]: Exception.Message $ExceptionMessage."  | WriteTo-StdOut 
		 $Error.Clear()
		 continue
		 # later use return to return the exception message to an object:   return $Script:ExceptionMessage
	}

Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_CTSDHCPServer -Status $ScriptVariable.ID_CTSDHCPServerDescription

function RunNetSH ([string]$NetSHCommandToExecute="")
{
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSDHCPServer -Status "netsh $NetSHCommandToExecute"
	
	$NetSHCommandToExecuteLength = $NetSHCommandToExecute.Length + 6
	"-" * ($NetSHCommandToExecuteLength) + "`r`n" + "netsh $NetSHCommandToExecute" + "`r`n" + "-" * ($NetSHCommandToExecuteLength) | Out-File -FilePath $OutputFile -append

	$CommandToExecute = "cmd.exe /c netsh.exe " + $NetSHCommandToExecute + " >> $OutputFile "
	RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
}


function RunPS ([string]$RunPScmd="", [switch]$ft)
{
	$RunPScmdLength = $RunPScmd.Length
	"-" * ($RunPScmdLength)		| Out-File -FilePath $OutputFile -append
	"$RunPScmd"  				| Out-File -FilePath $OutputFile -append
	"-" * ($RunPScmdLength)  	| Out-File -FilePath $OutputFile -append
	
	if ($ft)
	{
		# This format-table expression is useful to make sure that wide ft output works correctly
		Invoke-Expression $RunPScmd	|format-table -autosize -outvariable $FormatTableTempVar | Out-File -FilePath $outputFile -Width 500 -append
	}
	else
	{
		Invoke-Expression $RunPScmd	| Out-File -FilePath $OutputFile -append
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append	
}


$sectionDescription = "DHCP Server"

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber


#----------W8/WS2012 powershell cmdlets
$outputFile= $Computername + "_DhcpServer_info_pscmdlets.TXT"
"===================================================="	| Out-File -FilePath $OutputFile -append
"DHCP Server Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"DHCP Server Settings"									| Out-File -FilePath $OutputFile -append
"   1. Get-DhcpServerAuditLog"							| Out-File -FilePath $OutputFile -append
"   2. Get-DhcpServerDatabase"							| Out-File -FilePath $OutputFile -append
"   3. Get-DhcpServerDnsCredential"						| Out-File -FilePath $OutputFile -append
"   4. Get-DhcpServerInDC"								| Out-File -FilePath $OutputFile -append
"   5. Get-DhcpServerSetting"							| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"DHCP Server v4"										| Out-File -FilePath $OutputFile -append
"   1. Get-DhcpServerv4Binding"							| Out-File -FilePath $OutputFile -append
"   2. Get-DhcpServerv4Class"							| Out-File -FilePath $OutputFile -append
"   3. Get-DhcpServerv4DnsSetting"						| Out-File -FilePath $OutputFile -append
"   4. Get-DhcpServerv4ExclusionRange"					| Out-File -FilePath $OutputFile -append
"   5. Get-DhcpServerv4Failover"						| Out-File -FilePath $OutputFile -append
"   6. Get-DhcpServerv4Filter"							| Out-File -FilePath $OutputFile -append
"   7. Get-DhcpServerv4FilterList"						| Out-File -FilePath $OutputFile -append
"   8. Get-DhcpServerv4MulticastExclusionRange"			| Out-File -FilePath $OutputFile -append
"   9. Get-DhcpServerv4MulticastScope"					| Out-File -FilePath $OutputFile -append
"  10. Get-DhcpServerv4MulticastScopeStatististics"		| Out-File -FilePath $OutputFile -append
"  11. Get-DhcpServerv4OptionDefinition"				| Out-File -FilePath $OutputFile -append
"  12. Get-DhcpServerv4OptionValue"						| Out-File -FilePath $OutputFile -append
"  13. Get-DhcpServerv4Policy"							| Out-File -FilePath $OutputFile -append
"  14. Get-DhcpServerv4Scope"							| Out-File -FilePath $OutputFile -append
"  15. Get-DhcpServerv4ScopeStatistics"					| Out-File -FilePath $OutputFile -append
"  16. Get-DhcpServerv4Statistics"						| Out-File -FilePath $OutputFile -append
"  17. Get-DhcpServerv4Superscope"						| Out-File -FilePath $OutputFile -append
"  18. Get-DhcpServerv4SuperscopeStatistics"			| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"DHCP Server v6"										| Out-File -FilePath $OutputFile -append
"   1. Get-DhcpServerv6Binding"							| Out-File -FilePath $OutputFile -append
"   2. Get-DhcpServerv6Class"							| Out-File -FilePath $OutputFile -append
"   3. Get-DhcpServerv6DnsSetting"						| Out-File -FilePath $OutputFile -append
"   4. Get-DhcpServerv6ExclusionRange"					| Out-File -FilePath $OutputFile -append
"   5. Get-DhcpServerv6OptionDefinition"				| Out-File -FilePath $OutputFile -append
"   6. Get-DhcpServerv6OptionValue"						| Out-File -FilePath $OutputFile -append
"   7. Get-DhcpServerv6Scope"							| Out-File -FilePath $OutputFile -append
"   8. Get-DhcpServerv6ScopeStatistics"					| Out-File -FilePath $OutputFile -append
"   9. Get-DhcpServerv6StatelessStatistics"				| Out-File -FilePath $OutputFile -append
"  10. Get-DhcpServerv6StatelessStore"					| Out-File -FilePath $OutputFile -append
"  11.Get-DhcpServerv6Statistics"						| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"DHCP Server Version"									| Out-File -FilePath $OutputFile -append
"   1. Get-DhcpServerVersion"							| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"DHCP Server Failover Statistics"						| Out-File -FilePath $OutputFile -append
"   1. DHCP Server Failover Statistics Per Scope"								| Out-File -FilePath $OutputFile -append
"       (using Get-DhcpServer4Failover and Get-DhcpServerv4ScopeStatistics)"	| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



$dhcpServerCheck = Test-path "HKLM:\SYSTEM\CurrentControlSet\Services\DHCPserver"
if ($dhcpServerCheck)
{
	if ((Get-Service "DHCPserver").Status -eq 'Running')
	{
		if ($bn -ge 9200)
		{
			# The powershell cmdlets that have been removed by comment because they require input
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DHCP Server Settings"									| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			RunPS "Get-DhcpServerAuditLog" 							# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerDatabase" 							# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerDnsCredential" 				-ft # W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerInDC" 							-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerSetting" 							# W8/WS2012, W8.1/WS2012R2	#fl
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DHCP Server v4"										| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			RunPS "Get-DhcpServerv4Binding" 					-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4Class" 						-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4DnsSetting" 						# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerv4ExclusionRange" 				-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4Failover" 						# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv4Filter" 							# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv4FilterList" 					-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			#RunPS "Get-DhcpServerv4FreeIPAddress" 					# W8/WS2012, W8.1/WS2012R2	
			#RunPS "Get-DhcpServerv4Lease" 							# W8/WS2012, W8.1/WS2012R2	
			RunPS "Get-DhcpServerv4MulticastExclusionRange"			# W8/WS2012, W8.1/WS2012R2	#unknown
			#RunPS "Get-DhcpServerv4MulticastLease" 				# W8/WS2012, W8.1/WS2012R2	
			RunPS "Get-DhcpServerv4MulticastScope" 					# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv4MulticastScopeStatistics" 		# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv4OptionDefinition" 			-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4OptionValue" 					# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv4Policy" 							# W8/WS2012, W8.1/WS2012R2	#unknown
			#RunPS "Get-DhcpServerv4PolicyIPRange" 					# W8/WS2012, W8.1/WS2012R2	
			#RunPS "Get-DhcpServerv4Reservation" 					# W8/WS2012, W8.1/WS2012R2	
			RunPS "Get-DhcpServerv4Scope" 						-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4ScopeStatistics" 			-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv4Statistics" 						# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerv4Superscope" 						# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerv4SuperscopeStatistics" 			# W8/WS2012, W8.1/WS2012R2	#unknown
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DHCP Server v6"										| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			RunPS "Get-DhcpServerv6Binding" 						# W8/WS2012, W8.1/WS2012R2	#unknown	
			RunPS "Get-DhcpServerv6Class" 						-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv6DnsSetting" 						# W8/WS2012, W8.1/WS2012R2	#fl
			RunPS "Get-DhcpServerv6ExclusionRange" 					# W8/WS2012, W8.1/WS2012R2	#unknown
			#RunPS "Get-DhcpServerv6FreeIPAddress"					# W8/WS2012, W8.1/WS2012R2	
			#RunPS "Get-DhcpServerv6Lease" 							# W8/WS2012, W8.1/WS2012R2	
			RunPS "Get-DhcpServerv6OptionDefinition" 			-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv6OptionValue" 					# W8/WS2012, W8.1/WS2012R2	#unknown
			#RunPS "Get-DhcpServerv6Reservation" 					# W8/WS2012, W8.1/WS2012R2	
			RunPS "Get-DhcpServerv6Scope" 							# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv6ScopeStatistics" 				# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv6StatelessStatistics" 			# W8/WS2012, W8.1/WS2012R2	#unknown
			RunPS "Get-DhcpServerv6StatelessStore" 				-ft	# W8/WS2012, W8.1/WS2012R2	#ft
			RunPS "Get-DhcpServerv6Statistics"						# W8/WS2012, W8.1/WS2012R2	#fl
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DHCP Server Version"									| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			RunPS "Get-DhcpServerVersion" 							# W8/WS2012, W8.1/WS2012R2	#fl
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DHCP Server Failover Statistics"						| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
			"DHCP Server Failover Statistics Per Scope"				| Out-File -FilePath $OutputFile -append
			"  (using Get-DhcpServer4Failover and Get-DhcpServerv4ScopeStatistics)"	| Out-File -FilePath $OutputFile -append
			"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
			$dhcpSrvFailoverScopes = Get-DhcpServerv4Failover
			foreach ($scope in $dhcpSrvFailoverScopes)
			{
				$scopeId = $scope.ScopeId
				Get-DhcpServerv4ScopeStatistics -ScopeId $scopeId | fl	| Out-File -FilePath $OutputFile -append
			}
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
		}
		else
		{
			"This server is not running WS2012 or WS2012 R2. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
		}
	}
	else
	{ "The `"DHCP Server`" service is not Running. Not running pscmdlets." 	| Out-File -FilePath $OutputFile -append }
}
else
{ "The `"DHCP Server`" service does not exist. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append }
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append

CollectFiles -filesToCollect $OutputFile -fileDescription "DHCP Server Information (Powershell)" -SectionDescription $sectionDescription





$OutputFile = $ComputerName + "_DhcpServer_netsh_info.TXT"
"===================================================="	| Out-File -FilePath $OutputFile -append
"DHCP Server Netsh Output"								| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------"				| Out-File -FilePath $OutputFile -append
"   1. netsh dhcp show server"							| Out-File -FilePath $OutputFile -append
"   2. netsh dhcp server show all"						| Out-File -FilePath $OutputFile -append
"   3. netsh dhcp server show version"					| Out-File -FilePath $OutputFile -append
"   4. netsh dhcp server show auditlog"					| Out-File -FilePath $OutputFile -append
"   5. netsh dhcp server show dbproperties"				| Out-File -FilePath $OutputFile -append
"   6. netsh dhcp server show bindings"					| Out-File -FilePath $OutputFile -append
"   7. netsh dhcp server show detectconflictretry"		| Out-File -FilePath $OutputFile -append
"   8. netsh dhcp server show server"					| Out-File -FilePath $OutputFile -append
"   9. netsh dhcp server show serverstatus"				| Out-File -FilePath $OutputFile -append
"  10. netsh dhcp server show scope"					| Out-File -FilePath $OutputFile -append
"  11. netsh dhcp server show superscope"				| Out-File -FilePath $OutputFile -append
"  12. netsh dhcp server show class"					| Out-File -FilePath $OutputFile -append
"  13. netsh dhcp server show dnsconfig"				| Out-File -FilePath $OutputFile -append
"  14. netsh dhcp server show dnscredentials"			| Out-File -FilePath $OutputFile -append
"  15. netsh dhcp server show mibinfo"					| Out-File -FilePath $OutputFile -append
"  16. netsh dhcp server show mscope"					| Out-File -FilePath $OutputFile -append
"  17. netsh dhcp server show optionvalue"				| Out-File -FilePath $OutputFile -append
"  18. netsh dhcp server show scope"					| Out-File -FilePath $OutputFile -append
"  19. netsh dhcp server show superscope"				| Out-File -FilePath $OutputFile -append
"  20. netsh dhcp server show userclass"				| Out-File -FilePath $OutputFile -append
"  21. netsh dhcp server show vendorclass"				| Out-File -FilePath $OutputFile -append
"  22. netsh dhcp server show optiondef"				| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append


$dhcpServerCheck = Test-path "HKLM:\SYSTEM\CurrentControlSet\Services\DHCPserver"
if ($dhcpServerCheck)
{
	if ((Get-Service "DHCPserver").Status -eq 'Running')
	{
		#----------Netsh for DHCP Server
		RunNetSH -NetSHCommandToExecute "dhcp show server"
		RunNetSH -NetSHCommandToExecute "dhcp server show all"
		RunNetSH -NetSHCommandToExecute "dhcp server show version"
		RunNetSH -NetSHCommandToExecute "dhcp server show auditlog"
		RunNetSH -NetSHCommandToExecute "dhcp server show dbproperties"
		RunNetSH -NetSHCommandToExecute "dhcp server show bindings"
		RunNetSH -NetSHCommandToExecute "dhcp server show detectconflictretry"
		RunNetSH -NetSHCommandToExecute "dhcp server show server"
		RunNetSH -NetSHCommandToExecute "dhcp server show serverstatus"
		RunNetSH -NetSHCommandToExecute "dhcp server show scope"
		RunNetSH -NetSHCommandToExecute "dhcp server show superscope"
		RunNetSH -NetSHCommandToExecute "dhcp server show class"
		RunNetSH -NetSHCommandToExecute "dhcp server show dnsconfig"
		RunNetSH -NetSHCommandToExecute "dhcp server show dnscredentials"
		RunNetSH -NetSHCommandToExecute "dhcp server show mibinfo"
		RunNetSH -NetSHCommandToExecute "dhcp server show mscope"
		RunNetSH -NetSHCommandToExecute "dhcp server show optionvalue"
		RunNetSH -NetSHCommandToExecute "dhcp server show scope"
		RunNetSH -NetSHCommandToExecute "dhcp server show superscope"
		RunNetSH -NetSHCommandToExecute "dhcp server show userclass"
		RunNetSH -NetSHCommandToExecute "dhcp server show vendorclass"
		RunNetSH -NetSHCommandToExecute "dhcp server show optiondef"

		#-----DHCP Server Dump
		$filesToCollect = $ComputerName + "_DhcpServer_netsh_dump.TXT"
		$commandToRun = "netsh dhcp server dump > " +  $filesToCollect
		RunCMD -CommandToRun $commandToRun -filesToCollect $filesToCollect -fileDescription "DHCP Server Netsh Dump" -sectionDescription $sectionDescription 
	}
	else
	{
		"The DHCP Server service is not Running. Not running netsh commands." 	| Out-File -FilePath $OutputFile -append
		"The DHCP Server service is not Running. Not running netsh commands." 	| Out-File -FilePath $filesToCollect -append
	}
}
else
{
	"The `"DHCP Server`" service does not exist. Not running netsh commands."	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
}

CollectFiles -sectionDescription $sectionDescription -fileDescription "DHCP Server Netsh Output" -filesToCollect $filesToCollect
CollectFiles -sectionDescription $sectionDescription -fileDescription "DHCP Server Netsh Dump" -filesToCollect $OutputFile



#----------DHCP Server registry output
$SvcKey = "HKLM:\SYSTEM\CurrentControlSet\services\DHCPServer"
if (Test-Path $SvcKey) 
{
	#----------Registry
	$OutputFile= $Computername + "_DhcpServer_reg_.TXT"
	$CurrentVersionKeys = "HKLM\SYSTEM\CurrentControlSet\Services\DHCPServer"
	$sectionDescription = "DHCP Server"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "DhcpServer Registry Keys" -SectionDescription $sectionDescription
}


#----------DHCP Server BPA
	# This runs in the TS_Main.ps1 script.


#----------CDHCP Server event logs for WS2008+
if ($OSVersion.Build -gt 6000)
{
	$sectionDescription = "DHCP Server EventLog"
	
	#----------Dhcp-Server EventLog / Operational
	$EventLogNames = "Microsoft-Windows-Dhcp-Server/Operational"
	$Prefix = ""
	$Suffix = "_evt_"
	.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
	
	#----------Dhcp-Server EventLog /Admin
	$EventLogNames = "Microsoft-Windows-Dhcp-Server/Admin"
	$Prefix = ""
	$Suffix = "_evt_"
	.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
}

# SIG # Begin signature block
# MIIa8gYJKoZIhvcNAQcCoIIa4zCCGt8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu0NBP9DebCH2BZ34hyLr6S8v
# ilCgghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTQwNTIzMTcxMzE1
# WhcNMTUwODIzMTcxMzE1WjCBqzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# DTALBgNVBAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjpCOEVDLTMw
# QTQtNzE0NDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALMhIt9q0L/7KcnVbHqJqY0T
# vJS16X0pZdp/9B+rDHlhZlRhlgfw1GBLMZsJr30obdCle4dfdqHSxinHljqjXxeM
# duC3lgcPx2JhtLaq9kYUKQMuJrAdSgjgfdNcMBKmm/a5Dj1TFmmdu2UnQsHoMjUO
# 9yn/3lsgTLsvaIQkD6uRxPPOKl5YRu2pRbRptlQmkRJi/W8O5M/53D/aKWkfSq7u
# wIJC64Jz6VFTEb/dqx1vsgpQeAuD7xsIsxtnb9MFfaEJn8J3iKCjWMFP/2fz3uzH
# 9TPcikUOlkYUKIccYLf1qlpATHC1acBGyNTo4sWQ3gtlNdRUgNLpnSBWr9TfzbkC
# AwEAAaOCAQkwggEFMB0GA1UdDgQWBBS+Z+AuAhuvCnINOh1/jJ1rImYR9zAfBgNV
# HSMEGDAWgBQjNPjZUkZwCu1A+3b7syuwwzWzDzBUBgNVHR8ETTBLMEmgR6BFhkNo
# dHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNyb3Nv
# ZnRUaW1lU3RhbXBQQ0EuY3JsMFgGCCsGAQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRUaW1l
# U3RhbXBQQ0EuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBBQUA
# A4IBAQAgU4KQrqZNTn4zScizrcTDfhXQEvIPJ4p/W78+VOpB6VQDKym63VSIu7n3
# 2c5T7RAWPclGcLQA0fI0XaejIiyqIuFrob8PDYfQHgIb73i2iSDQLKsLdDguphD/
# 2pGrLEA8JhWqrN7Cz0qTA81r4qSymRpdR0Tx3IIf5ki0pmmZwS7phyPqCNJp5mLf
# cfHrI78hZfmkV8STLdsWeBWqPqLkhfwXvsBPFduq8Ki6ESus+is1Fm5bc/4w0Pur
# k6DezULaNj+R9+A3jNkHrTsnu/9UIHfG/RHpGuZpsjMnqwWuWI+mqX9dEhFoDCyj
# MRYNviGrnPCuGnxA1daDFhXYKPvlMIIE7DCCA9SgAwIBAgITMwAAAMps1TISNcTh
# VQABAAAAyjANBgkqhkiG9w0BAQUFADB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBD
# QTAeFw0xNDA0MjIxNzM5MDBaFw0xNTA3MjIxNzM5MDBaMIGDMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQD
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCWcV3tBkb6hMudW7dGx7DhtBE5A62xFXNgnOuntm4aPD//ZeM08aal
# IV5WmWxY5JKhClzC09xSLwxlmiBhQFMxnGyPIX26+f4TUFJglTpbuVildGFBqZTg
# rSZOTKGXcEknXnxnyk8ecYRGvB1LtuIPxcYnyQfmegqlFwAZTHBFOC2BtFCqxWfR
# +nm8xcyhcpv0JTSY+FTfEjk4Ei+ka6Wafsdi0dzP7T00+LnfNTC67HkyqeGprFVN
# TH9MVsMTC3bxB/nMR6z7iNVSpR4o+j0tz8+EmIZxZRHPhckJRIbhb+ex/KxARKWp
# iyM/gkmd1ZZZUBNZGHP/QwytK9R/MEBnAgMBAAGjggFgMIIBXDATBgNVHSUEDDAK
# BggrBgEFBQcDAzAdBgNVHQ4EFgQUH17iXVCNVoa+SjzPBOinh7XLv4MwUQYDVR0R
# BEowSKRGMEQxDTALBgNVBAsTBE1PUFIxMzAxBgNVBAUTKjMxNTk1K2I0MjE4ZjEz
# LTZmY2EtNDkwZi05YzQ3LTNmYzU1N2RmYzQ0MDAfBgNVHSMEGDAWgBTLEejK0rQW
# WAHJNy4zFha5TJoKHzBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNDb2RTaWdQQ0FfMDgtMzEtMjAx
# MC5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY0NvZFNpZ1BDQV8wOC0zMS0yMDEwLmNy
# dDANBgkqhkiG9w0BAQUFAAOCAQEAd1zr15E9zb17g9mFqbBDnXN8F8kP7Tbbx7Us
# G177VAU6g3FAgQmit3EmXtZ9tmw7yapfXQMYKh0nfgfpxWUftc8Nt1THKDhaiOd7
# wRm2VjK64szLk9uvbg9dRPXUsO8b1U7Brw7vIJvy4f4nXejF/2H2GdIoCiKd381w
# gp4YctgjzHosQ+7/6sDg5h2qnpczAFJvB7jTiGzepAY1p8JThmURdwmPNVm52Iao
# AP74MX0s9IwFncDB1XdybOlNWSaD8cKyiFeTNQB8UCu8Wfz+HCk4gtPeUpdFKRhO
# lludul8bo/EnUOoHlehtNA04V9w3KDWVOjic1O1qhV0OIhFeezCCBbwwggOkoAMC
# AQICCmEzJhoAAAAAADEwDQYJKoZIhvcNAQEFBQAwXzETMBEGCgmSJomT8ixkARkW
# A2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9z
# b2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTEwMDgzMTIyMTkzMloX
# DTIwMDgzMTIyMjkzMloweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCycllcGTBkvx2aYCAgQpl2U2w+G9Zv
# zMvx6mv+lxYQ4N86dIMaty+gMuz/3sJCTiPVcgDbNVcKicquIEn08GisTUuNpb15
# S3GbRwfa/SXfnXWIz6pzRH/XgdvzvfI2pMlcRdyvrT3gKGiXGqelcnNW8ReU5P01
# lHKg1nZfHndFg4U4FtBzWwW6Z1KNpbJpL9oZC/6SdCnidi9U3RQwWfjSjWL9y8lf
# RjFQuScT5EAwz3IpECgixzdOPaAyPZDNoTgGhVxOVoIoKgUyt0vXT2Pn0i1i8UU9
# 56wIAPZGoZ7RW4wmU+h6qkryRs83PDietHdcpReejcsRj1Y8wawJXwPTAgMBAAGj
# ggFeMIIBWjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTLEejK0rQWWAHJNy4z
# Fha5TJoKHzALBgNVHQ8EBAMCAYYwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEE
# AYI3FQIEFgQU/dExTtMmipXhmGA7qDFvpjy82C0wGQYJKwYBBAGCNxQCBAweCgBT
# AHUAYgBDAEEwHwYDVR0jBBgwFoAUDqyCYEBWJ5flJRP8KuEKU5VZ5KQwUAYDVR0f
# BEkwRzBFoEOgQYY/aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUFBwEBBEgwRjBEBggr
# BgEFBQcwAoY4aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNy
# b3NvZnRSb290Q2VydC5jcnQwDQYJKoZIhvcNAQEFBQADggIBAFk5Pn8mRq/rb0Cx
# MrVq6w4vbqhJ9+tfde1MOy3XQ60L/svpLTGjI8x8UJiAIV2sPS9MuqKoVpzjcLu4
# tPh5tUly9z7qQX/K4QwXaculnCAt+gtQxFbNLeNK0rxw56gNogOlVuC4iktX8pVC
# nPHz7+7jhh80PLhWmvBTI4UqpIIck+KUBx3y4k74jKHK6BOlkU7IG9KPcpUqcW2b
# Gvgc8FPWZ8wi/1wdzaKMvSeyeWNWRKJRzfnpo1hW3ZsCRUQvX/TartSCMm78pJUT
# 5Otp56miLL7IKxAOZY6Z2/Wi+hImCWU4lPF6H0q70eFW6NB4lhhcyTUWX92THUmO
# Lb6tNEQc7hAVGgBd3TVbIc6YxwnuhQ6MT20OE049fClInHLR82zKwexwo1eSV32U
# jaAbSANa98+jZwp0pTbtLS8XyOZyNxL0b7E8Z4L5UrKNMxZlHg6K3RDeZPRvzkbU
# 0xfpecQEtNP7LN8fip6sCvsTJ0Ct5PnhqX9GuwdgR2VgQE6wQuxO7bN2edgKNAlt
# HIAxH+IOVN3lofvlRxCtZJj/UBYufL8FIXrilUEnacOTj5XJjdibIa4NXJzwoq6G
# aIMMai27dmsAHZat8hZ79haDJLmIz2qoRzEvmtzjcT3XAH5iR9HOiMm4GPoOco3B
# oz2vAkBq/2mbluIQqBC0N1AI1sM9MIIGBzCCA++gAwIBAgIKYRZoNAAAAAAAHDAN
# BgkqhkiG9w0BAQUFADBfMRMwEQYKCZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPy
# LGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZp
# Y2F0ZSBBdXRob3JpdHkwHhcNMDcwNDAzMTI1MzA5WhcNMjEwNDAzMTMwMzA5WjB3
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhN
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCfoWyx39tIkip8ay4Z4b3i48WZUSNQrc7dGE4kD+7Rp9FMrXQwIBHr
# B9VUlRVJlBtCkq6YXDAm2gBr6Hu97IkHD/cOBJjwicwfyzMkh53y9GccLPx754gd
# 6udOo6HBI1PKjfpFzwnQXq/QsEIEovmmbJNn1yjcRlOwhtDlKEYuJ6yGT1VSDOQD
# LPtqkJAwbofzWTCd+n7Wl7PoIZd++NIT8wi3U21StEWQn0gASkdmEScpZqiX5NMG
# gUqi+YSnEUcUCYKfhO1VeP4Bmh1QCIUAEDBG7bfeI0a7xC1Un68eeEExd8yb3zuD
# k6FhArUdDbH895uyAc4iS1T/+QXDwiALAgMBAAGjggGrMIIBpzAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBQjNPjZUkZwCu1A+3b7syuwwzWzDzALBgNVHQ8EBAMC
# AYYwEAYJKwYBBAGCNxUBBAMCAQAwgZgGA1UdIwSBkDCBjYAUDqyCYEBWJ5flJRP8
# KuEKU5VZ5KShY6RhMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAXBgoJkiaJk/Is
# ZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eYIQea0WoUqgpa1Mc1j0BxMuZTBQBgNVHR8ESTBHMEWgQ6BB
# hj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9taWNy
# b3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjho
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jvc29mdFJvb3RD
# ZXJ0LmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQUFAAOCAgEA
# EJeKw1wDRDbd6bStd9vOeVFNAbEudHFbbQwTq86+e4+4LtQSooxtYrhXAstOIBNQ
# md16QOJXu69YmhzhHQGGrLt48ovQ7DsB7uK+jwoFyI1I4vBTFd1Pq5Lk541q1YDB
# 5pTyBi+FA+mRKiQicPv2/OR4mS4N9wficLwYTp2OawpylbihOZxnLcVRDupiXD8W
# mIsgP+IHGjL5zDFKdjE9K3ILyOpwPf+FChPfwgphjvDXuBfrTot/xTUrXqO/67x9
# C0J71FNyIe4wyrt4ZVxbARcKFA7S2hSY9Ty5ZlizLS/n+YWGzFFW6J1wlGysOUzU
# 9nm/qhh6YinvopspNAZ3GmLJPR5tH4LwC8csu89Ds+X57H2146SodDW4TsVxIxIm
# dgs8UoxxWkZDFLyzs7BNZ8ifQv+AeSGAnhUwZuhCEl4ayJ4iIdBD6Svpu/RIzCzU
# 2DKATCYqSCRfWupW76bemZ3KOm+9gSd0BhHudiG/m4LBJ1S2sWo9iaF2YbRuoROm
# v6pH8BJv/YoybLL+31HIjCPJZr2dHYcSZAI9La9Zj7jkIeW1sMpjtHhUBdRBLlCs
# lLCleKuzoJZ1GtmShxN1Ii8yqAhuoFuMJb+g74TKIdbrHk/Jmu5J4PcBZW+JC33I
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTiMIIE3gIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIH7MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTbbhFsv1O5rkgB
# xp0neQeXdqz1aDCBmgYKKwYBBAGCNwIBDDGBizCBiKBugGwAQwBUAFMAXwBOAGUA
# dAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8ARABDAF8A
# RABoAGMAcABTAGUAcgB2AGUAcgAtAEMAbwBtAHAAbwBuAGUAbgB0AC4AcABzADGh
# FoAUaHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAf2R9Lqrv
# akebHp6wscNIo+xPbXKpXq43It3zUxSa3CyPY0VUnnY3ryJXPh6aR2tD4G4YH+/2
# Qww/0b+OzQ8OcxO4r3FExLbDKwqHZYpY28CjdPWfIstzP9PTT5ZKZVVDvoh9EeIL
# WSbkgaCkix9NKoFIAE6gCb8MHR3OGs6lvdiWlpE6ZZ7GOUdtz/4tnMttZW7e53hR
# XbO/8ijndboptsMLohmC5YAYqnySbpvF30O6tzks6jx43MOYNRrFC5mg63zkp8St
# PEzPsvRjGRb0dz++E+i/N+n/fYIqmHkow/SwnA/Te3n6LIwJV425/U043AlZ9Yd7
# KiyWLg0pxG1976GCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABa7S/05CCZPzoAAAAAAFowCQYFKw4D
# AhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTE0MTAyMDE4MDgyOVowIwYJKoZIhvcNAQkEMRYEFFzOcBWQgLptRc3QmjkZI36q
# jcUAMA0GCSqGSIb3DQEBBQUABIIBAB7mMHTOKQIqpTd01bKIZnX+VagFId32gd8i
# SA85SZp0VIr5b2Lubw7zBLjn3tbuICIXaxugmVVdTiGsfzp/zWeghTiCm4O5UM4L
# KE0BAxlO+nvjFIM4hJ9GpSa9O2zDWoX0PsvMaCRhLLcNH1ESqH95Uei4XsQAAkim
# wkau9e1RgNKgiM/nJ7w3USi9sR33V3KP7SoyGB9qGrqHzMUc+8tVBvfveCPEfst0
# sVDrlhlBGNZlSCeFKiUBu35MTLuR81TeRrKwKmyhJUPro9SXe0CF+wIv1VFFj7rb
# gOEUWOO8tDWszFkxQJ8V0ccODl1tOCbe4LFIFbmUxgBQ6e/Pmjw=
# SIG # End signature block
