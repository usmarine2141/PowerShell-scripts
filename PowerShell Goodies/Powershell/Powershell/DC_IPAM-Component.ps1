﻿#************************************************
# DC_IPAM-Component.ps1
# Version 1.0
# Date: 2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects information about IPAM.
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


# Data Collection consists of:
#  Powershell
#  Netsh (none)
#  Registry
#  EventLogs
#  IPAM Local Groups


$sectionDescription = "IPAM"

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber


#----------W8/WS2012 powershell cmdlets
$outputFile= $Computername + "_IPAM_info_pscmdlets.TXT"
"===================================================="	| Out-File -FilePath $OutputFile -append
"IPAM Powershell Cmdlets"								| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"    1. Get-IpamServerInventory"						| Out-File -FilePath $OutputFile -append
"    2. Get-IpamDiscoveryDomain"						| Out-File -FilePath $OutputFile -append
"    3. Get-IpamDatabase"								| Out-File -FilePath $OutputFile -append
"    4. Get-IpamAddressSpace"							| Out-File -FilePath $OutputFile -append
"    5. Get-IpamCapability"								| Out-File -FilePath $OutputFile -append
"    6. Get-IpamConfiguration"							| Out-File -FilePath $OutputFile -append
"    7. Get-IpamCustomField"							| Out-File -FilePath $OutputFile -append
"    8. Get-IpamCustomFieldAssociation"					| Out-File -FilePath $OutputFile -append
"    9. Get-IpamAddressUtilizationThreshold"			| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
$IpamCheck = Test-path "HKLM:\SOFTWARE\Microsoft\IPAM"
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		# The powershell cmdlets that have been removed by comment because they require input
		RunPS "Get-IpamServerInventory" 					# W8.1/WS2012R2  # fl
		RunPS "Get-IpamDiscoveryDomain" 				-ft # W8.1/WS2012R2  # ft
		RunPS "Get-IpamDatabase" 							# W8.1/WS2012R2  # fl
		RunPS "Get-IpamAddressSpace" 					-ft # W8.1/WS2012R2  # ft
		RunPS "Get-IpamCapability" 						-ft # W8.1/WS2012R2  # ft
		RunPS "Get-IpamConfiguration" 					-ft # W8.1/WS2012R2  # ft
		RunPS "Get-IpamCustomField" 					-ft # W8.1/WS2012R2  # ft
		RunPS "Get-IpamCustomFieldAssociation" 				# W8.1/WS2012R2  # fl
		RunPS "Get-IpamAddressUtilizationThreshold" 	-ft	# W8.1/WS2012R2  # ft
		# RunPS "Get-IpamAddress"							# W8.1/WS2012R2  # unknown, takes arguments [exception]
		# RunPS "Get-IpamBlock" 							# W8.1/WS2012R2  # unknown, takes arguments [exception]
		# RunPS "Get-IpamConfigurationEvent" 				# W8.1/WS2012R2  # unknown, takes arguments [no exception]
		# RunPS "Get-IpamDhcpConfigurationEvent" 			# W8.1/WS2012R2  # unknown, takes arguments [exception]
		# RunPS "Get-IpamIpAddressAuditEvent" 				# W8.1/WS2012R2  # unknown, takes arguments [exception]
		# RunPS "Get-IpamRange" 							# W8.1/WS2012R2  # unknown, takes arguments [exception]
		# RunPS "Get-IpamSubnet" 							# W8.1/WS2012R2  # unknown, takes arguments	[exception]
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append

CollectFiles -filesToCollect $OutputFile -fileDescription "DHCP Server Information (Powershell)" -SectionDescription $sectionDescription





#----------IPAM registry output
$IpamCheck = Test-path "HKLM:\SOFTWARE\Microsoft\IPAM"
if ($IpamCheck)
{
	#----------Registry
	$OutputFile= $Computername + "_IPAM_reg_.TXT"
	$CurrentVersionKeys = "HKLM\SOFTWARE\Microsoft\IPAM"
	$sectionDescription = "IPAM"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "IPAM Registry Keys" -SectionDescription $sectionDescription
}



#----------DHCP Server event logs for WS2012+
$IpamCheck = Test-path "HKLM:\SOFTWARE\Microsoft\IPAM"
if (($IpamCheck) -and ($OSVersion.Build -ge 9000))
{
	$sectionDescription = "IPAM EventLogs"
	# IPAM EventLog / Admin					# Enabled by default
	# IPAM EventLog / Analytic				# Does not appear in EventViewer
	# IPAM EventLog / ConfigurationChange	# Enabled by default
	# IPAM EventLog / Debug					# Does not exist in EventViewer
	# IPAM EventLog / Operational			# Disabled by default

	$EventLogNames = 	"Microsoft-Windows-IPAM/Admin",
						"Microsoft-Windows-IPAM/Analytic",
						"Microsoft-Windows-IPAM/ConfigurationChange",	
						"Microsoft-Windows-IPAM/Debug",
						"Microsoft-Windows-IPAM/Operational"
	$Prefix = ""
	$Suffix = "_evt_"
	.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
}



# Group memberships of the IPAM group
$outputFile= $Computername + "_IPAM_info_localgroups.TXT"

"===================================================="				| Out-File -FilePath $OutputFile -append
"IPAM Local Group Membership"										| Out-File -FilePath $OutputFile -append
"===================================================="				| Out-File -FilePath $OutputFile -append
"Overview"															| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
"   1. Members of the local group `"IPAM Administrators`""			| Out-File -FilePath $OutputFile -append
"   2. Members of the local group `"IPAM ASM Administrators`"" 		| Out-File -FilePath $OutputFile -append
"   3. Members of the local group `"IPAM IP Audit Administrators`"" | Out-File -FilePath $OutputFile -append
"   4. Members of the local group `"IPAM MSM Administrators`"" 		| Out-File -FilePath $OutputFile -append
"   5. Members of the local group `"IPAM Users`"" 					| Out-File -FilePath $OutputFile -append
"===================================================="				| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$ContextType = [System.DirectoryServices.AccountManagement.ContextType]::Machine

"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
"Members of the local group `"IPAM Administrators`"" 		| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		$IpamAdministrators = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ContextType ,"IPAM Administrators")
		$IpamAdministratorsMembers = $IpamAdministrators.GetMembers($true)
		$IpamAdministratorsMembers | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
"Members of the local group `"IPAM ASM Administrators`"" 	| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		$IpamAsmAdministrators = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ContextType ,"IPAM ASM Administrators")
		$IpamAsmAdministratorsMembers = $IpamAsmAdministrators.GetMembers($true)
		$IpamAsmAdministratorsMembers | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



"----------------------------------------------------"			| Out-File -FilePath $OutputFile -append
"Members of the local group `"IPAM IP Audit Administrators`"" 	| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"			| Out-File -FilePath $OutputFile -append
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		$IpamIpAuditAdministrators = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ContextType ,"IPAM IP Audit Administrators")
		$IpamIpAuditAdministratorsMembers = $IpamIpAuditAdministrators.GetMembers($true)
		$IpamIpAuditAdministratorsMembers | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append




"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
"Members of the local group `"IPAM MSM Administrators`"" 	| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		$IpamMSMAdministrators = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ContextType ,"IPAM MSM Administrators")
		$IpamMSMAdministratorsMembers = $IpamMSMAdministrators.GetMembers($true)
		$IpamMSMAdministratorsMembers | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Members of the local group `"IPAM Users`"" 			| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
if ($IpamCheck)
{
	if ($bn -ge 9600)
	{
		$IpamUsers = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ContextType ,"IPAM Users")
		$IpamUsersMembers = $IpamUsers.GetMembers($true)
		$IpamUsersMembers | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The get-IPAM* powershell cmdlets are only available on W8.1/WS2012R2 and later. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"IPAM does not appear to be installed. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append

CollectFiles -filesToCollect $OutputFile -fileDescription "DHCP Server Information (Powershell)" -SectionDescription $sectionDescription











# SIG # Begin signature block
# MIIa7AYJKoZIhvcNAQcCoIIa3TCCGtkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXp2aiokjQg4N9R9bdguLrNlb
# AUKgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTMxMTExMjIxMTMx
# WhcNMTUwMjExMjIxMTMxWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsdj6GwYrd6jk
# lF18D+Z6ppLuilQdpPmEdYWXzMtcltDXdS3ZCPtb0u4tJcY3PvWrfhpT5Ve+a+i/
# ypYK3EbxWh4+AtKy4CaOAGR7vjyT+FgyeYfSGl0jvJxRxA8Q+gRYtRZ2buy8xuW+
# /K2swUHbqs559RyymUGneiUr/6t4DVg6sV5Q3mRM4MoVKt+m6f6kZi9bEAkJJiHU
# Pw0vbdL4d5ADbN4UEqWM5zYf9IelsEEXb+NNdGbC/aJxRjVRzGsXUWP6FZSSml9L
# KLrmFkVJ6Sy1/ouHr/ylbUPcpjD6KSjvmw0sXIPeEo1qtNtx71wUWiojKP+BcFfx
# jAeaE9gqUwIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFLkNrbNN9NqfGrInJlUNIETY
# mOL0MB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAmKTgav6O2Czx0HftcqpyQLLa+aWyR/lHEMVYgkGlIVY+KQ
# TQVKmEqc++GnbWhVgrkp6mmpstXjDNrR1nolN3hnHAz72ylaGpc4KjlWRvs1gbnk
# PUZajuT8dTdYWUmLTts8FZ1zUkvreww6wi3Bs5tSLeA1xbnBV7PoPaE8RPIjFh4K
# qlk3J9CVUl6ofz9U8IHh3Jq9ZdV49vdMObvd4NY3DpGah4xz53FkUvc+A9jGzXK4
# NDSYW4zT9Qim63jGUaANDm/0azxAGmAWLKkGUp0cE5DObwIe6nucs/b4l2DyZdHR
# H4c6wXXwQo167Yxysnv7LIq0kUdU4i5pzBZUGlkwggTsMIID1KADAgECAhMzAAAA
# ymzVMhI1xOFVAAEAAADKMA0GCSqGSIb3DQEBBQUAMHkxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBMB4XDTE0MDQyMjE3MzkwMFoXDTE1MDcyMjE3MzkwMFowgYMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xDTALBgNVBAsTBE1PUFIx
# HjAcBgNVBAMTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJZxXe0GRvqEy51bt0bHsOG0ETkDrbEVc2Cc66e2bho8
# P/9l4zTxpqUhXlaZbFjkkqEKXMLT3FIvDGWaIGFAUzGcbI8hfbr5/hNQUmCVOlu5
# WKV0YUGplOCtJk5MoZdwSSdefGfKTx5xhEa8HUu24g/FxifJB+Z6CqUXABlMcEU4
# LYG0UKrFZ9H6ebzFzKFym/QlNJj4VN8SOTgSL6RrpZp+x2LR3M/tPTT4ud81MLrs
# eTKp4amsVU1Mf0xWwxMLdvEH+cxHrPuI1VKlHij6PS3Pz4SYhnFlEc+FyQlEhuFv
# 57H8rEBEpamLIz+CSZ3VlllQE1kYc/9DDK0r1H8wQGcCAwEAAaOCAWAwggFcMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQfXuJdUI1Whr5KPM8E6KeHtcu/
# gzBRBgNVHREESjBIpEYwRDENMAsGA1UECxMETU9QUjEzMDEGA1UEBRMqMzE1OTUr
# YjQyMThmMTMtNmZjYS00OTBmLTljNDctM2ZjNTU3ZGZjNDQwMB8GA1UdIwQYMBaA
# FMsR6MrStBZYAck3LjMWFrlMmgofMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9j
# cmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY0NvZFNpZ1BDQV8w
# OC0zMS0yMDEwLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljQ29kU2lnUENBXzA4LTMx
# LTIwMTAuY3J0MA0GCSqGSIb3DQEBBQUAA4IBAQB3XOvXkT3NvXuD2YWpsEOdc3wX
# yQ/tNtvHtSwbXvtUBTqDcUCBCaK3cSZe1n22bDvJql9dAxgqHSd+B+nFZR+1zw23
# VMcoOFqI53vBGbZWMrrizMuT269uD11E9dSw7xvVTsGvDu8gm/Lh/idd6MX/YfYZ
# 0igKIp3fzXCCnhhy2CPMeixD7v/qwODmHaqelzMAUm8HuNOIbN6kBjWnwlOGZRF3
# CY81WbnYhqgA/vgxfSz0jAWdwMHVd3Js6U1ZJoPxwrKIV5M1AHxQK7xZ/P4cKTiC
# 095Sl0UpGE6WW526Xxuj8SdQ6geV6G00DThX3DcoNZU6OJzU7WqFXQ4iEV57MIIF
# vDCCA6SgAwIBAgIKYTMmGgAAAAAAMTANBgkqhkiG9w0BAQUFADBfMRMwEQYKCZIm
# iZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQD
# EyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTAwODMx
# MjIxOTMyWhcNMjAwODMxMjIyOTMyWjB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJyWVwZMGS/HZpgICBC
# mXZTbD4b1m/My/Hqa/6XFhDg3zp0gxq3L6Ay7P/ewkJOI9VyANs1VwqJyq4gSfTw
# aKxNS42lvXlLcZtHB9r9Jd+ddYjPqnNEf9eB2/O98jakyVxF3K+tPeAoaJcap6Vy
# c1bxF5Tk/TWUcqDWdl8ed0WDhTgW0HNbBbpnUo2lsmkv2hkL/pJ0KeJ2L1TdFDBZ
# +NKNYv3LyV9GMVC5JxPkQDDPcikQKCLHN049oDI9kM2hOAaFXE5WgigqBTK3S9dP
# Y+fSLWLxRT3nrAgA9kahntFbjCZT6HqqSvJGzzc8OJ60d1ylF56NyxGPVjzBrAlf
# A9MCAwEAAaOCAV4wggFaMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMsR6MrS
# tBZYAck3LjMWFrlMmgofMAsGA1UdDwQEAwIBhjASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBT90TFO0yaKleGYYDuoMW+mPLzYLTAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTAfBgNVHSMEGDAWgBQOrIJgQFYnl+UlE/wq4QpTlVnk
# pDBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9taWNyb3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEE
# SDBGMEQGCCsGAQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2Nl
# cnRzL01pY3Jvc29mdFJvb3RDZXJ0LmNydDANBgkqhkiG9w0BAQUFAAOCAgEAWTk+
# fyZGr+tvQLEytWrrDi9uqEn361917Uw7LddDrQv+y+ktMaMjzHxQmIAhXaw9L0y6
# oqhWnONwu7i0+Hm1SXL3PupBf8rhDBdpy6WcIC36C1DEVs0t40rSvHDnqA2iA6VW
# 4LiKS1fylUKc8fPv7uOGHzQ8uFaa8FMjhSqkghyT4pQHHfLiTviMocroE6WRTsgb
# 0o9ylSpxbZsa+BzwU9ZnzCL/XB3Nooy9J7J5Y1ZEolHN+emjWFbdmwJFRC9f9Nqu
# 1IIybvyklRPk62nnqaIsvsgrEA5ljpnb9aL6EiYJZTiU8XofSrvR4Vbo0HiWGFzJ
# NRZf3ZMdSY4tvq00RBzuEBUaAF3dNVshzpjHCe6FDoxPbQ4TTj18KUicctHzbMrB
# 7HCjV5JXfZSNoBtIA1r3z6NnCnSlNu0tLxfI5nI3EvRvsTxngvlSso0zFmUeDord
# EN5k9G/ORtTTF+l5xAS00/ss3x+KnqwK+xMnQK3k+eGpf0a7B2BHZWBATrBC7E7t
# s3Z52Ao0CW0cgDEf4g5U3eWh++VHEK1kmP9QFi58vwUheuKVQSdpw5OPlcmN2Jsh
# rg1cnPCiroZogwxqLbt2awAdlq3yFnv2FoMkuYjPaqhHMS+a3ONxPdcAfmJH0c6I
# ybgY+g5yjcGjPa8CQGr/aZuW4hCoELQ3UAjWwz0wggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNQwggTQ
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCgge0wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMyp
# 88OmKUzMc0CtmkauhmX6RrS3MIGMBgorBgEEAYI3AgEMMX4wfKBigGAAQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# RABDAF8ASQBQAEEATQAtAEMAbwBtAHAAbwBuAGUAbgB0AC4AcABzADGhFoAUaHR0
# cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAE0AW0lcx+Jwf4PMq
# XxofEh77vHCt1ZwpP7MczzaPYjr3Rqj5D61zAl0183D+wHjIkskITBeLOBO9ELNa
# RxQvy+uGpu8PHyhqfgKn0tVJSiCZbhkNekqEUM32tbxCAPTPZOoi7KWJ9pyAeRnr
# l2cg1ld2F5gagFW2MbN9EUJOHETyDtgL1V2Jyi6cR6e833QgAc/nzXnyi6d3GpZl
# JM34ooWONTvfGB2MNVBsVBiWjB+mvVaDbNHiC4E4axU91eC2BWEnB5aIUzCyNH4U
# tUuIxl9QOIJDycf7sHNjSCw0G5+Gn/gpZPbZwctBSuSV/LG8/4T6aipzp7BV5IKs
# SwIj/KGCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4DAhoFAKBd
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTAy
# MDE4MDgzMVowIwYJKoZIhvcNAQkEMRYEFIfEEfnWfmDxs+F39Fkargfe0Ym3MA0G
# CSqGSIb3DQEBBQUABIIBAHD3HhK1aGH15C939MsH1BcpieZpXtTAk8qBIju5OYMO
# qBqwoCLf1TAL7dD+r3bggXYXHji559meMR3j2I8FTSN7uDEICri9Ze+WEl37SgeC
# WCW6yvXrPaQWsdt80n6i5ljhU68wYDhCh613+zkOT2f12RZ54vqb2xJTf3vyhOXu
# jjV6CAuDkyWZ/QM2ajnlttlgN0u+fGIb1ANSZrK/JzdaWgP55yR0yVRtCPohmSab
# 22yo+5j/zVRgNmiqgrqgjdyea34hWwmhdpCAWi29T1x+D7pK6o/2RMPvIXzBM1vG
# HNMq0EikcVBNSfBROvVm41SubtmhVCGscGsN3Y89djE=
# SIG # End signature block
