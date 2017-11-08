#************************************************
# DC_DirectAccessClient-Component.ps1
# Version 1.0.11.15.12: Created script. Output for registry and netsh
# Version 1.1.03.26.13: Updated registry for GPO for DNS Client and netsh for DNS Client
# Version 1.2.03.27.13: Added registry keys for DA Connectivity Assistant, NCSI, and IPv6 Transition Technologies
# Version 1.3.04.11.14: Added pscmdlets (and other updates over time)
# Version 1.4.04.24.14: Added overview headings showing all commands run in each section.
# Version 1.5.08.12.14: Added eventlog collection for "Microsoft-Windows-Ncasvc/Operational" (JoelCh suggestion)
# Version 1.6.08.24.14: Cleaned up the registry section by adding all registry keys to $CurrentVersionKeys TFS264124
# Version 1.7.09.26.14: Added registry output for "HKLM\SOFTWARE\Policies\Microsoft\NetworkConnectivityAssistant"
# Date: 2012-2014
# Authors: Boyd Benson (bbenson@microsoft.com); Joel Christiansen (joelch@microsoft.com)
# Description: Collects information about the DirectAccess Client.
# Called from: DirectAccess Diag, Main Networking Diag
#*******************************************************

Trap [Exception]
	{
	 # Handle exception and throw it to the stdout log file. Then continue with function and script.
		 $Script:ExceptionMessage = $_
		 "[info]: Exception occurred."  | WriteTo-StdOut
		 "[info]: Exception.Message $ExceptionMessage."  | WriteTo-StdOut 
		 $Error.Clear()
		 continue
	}


Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_CTSDirectAccessClient -Status $ScriptVariable.ID_CTSDirectAccessClientDescription

#os version
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber


function RunNetSH ([string]$NetSHCommandToExecute="")
{
	
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSDirectAccessClient -Status "netsh $NetSHCommandToExecute"
	
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


function RunNetCmd ([string]$NetCmd="", [string]$NetCmdArg="")
{
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSTCPIP -Status "$NetCmd $NetCmdArg"
	$NetCmdLen = $NetCmd.length
	$NetCmdArgLen = $NetCmdArg.Length
	$NetCmdFullLen = $NetCmdLen + $NetCmdArgLen + 1
	"-" * ($NetCmdFullLen)	| Out-File -FilePath $outputFile -append
	"$NetCmd $NetCmdArg"	| Out-File -FilePath $outputFile -append
	"-" * ($NetCmdFullLen)	| Out-File -FilePath $outputFile -append
	$CommandToExecute = "cmd.exe /c $NetCmd $NetCmdArg >> $outputFile"
	RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append	
}


function Heading ([string]$header)
{
	"=" * ($borderLen)	| Out-File -FilePath $outputFile -append
	"$header"			| Out-File -FilePath $outputFile -append
	"=" * ($borderLen)	| Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
}


$sectionDescription = "DirectAccess Client"
$borderLen = 52

if ($bn -gt 9000)
{
	$outputFile= $Computername + "_DirectAccessClient_info_pscmdlets.TXT"

	"=" * ($borderLen)									| Out-File -FilePath $outputFile -append
	"DirectAccess Client Powershell Cmdlets"			| Out-File -FilePath $OutputFile -append
	"=" * ($borderLen)									| Out-File -FilePath $outputFile -append
	"Overview"											| Out-File -FilePath $OutputFile -append
	"-" * ($borderLen)									| Out-File -FilePath $outputFile -append
	"DirectAccess Client Powershell Cmdlets"			| Out-File -FilePath $OutputFile -append
	"   1. Get-DnsClientNrptPolicy"						| Out-File -FilePath $OutputFile -append
	"   2. Get-DnsClientNrptGlobal"						| Out-File -FilePath $OutputFile -append
	"   3. Get-DAClientExperienceConfiguration"			| Out-File -FilePath $OutputFile -append
	"   4. Get-DAEntryPointTableItem"					| Out-File -FilePath $OutputFile -append
	"=" * ($borderLen)									| Out-File -FilePath $outputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append

	Heading "DirectAccess Client Powershell Cmdlets"
	runPS "Get-DnsClientNrptPolicy"						# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-DnsClientNrptGlobal"					-ft	# W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-DAClientExperienceConfiguration"			# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-DAEntryPointTableItem"					# W8/WS2012, W8.1/WS2012R2	# fl


	$NcaSvcStatus=(Get-Service -Name NcaSvc).Status
	If ($NcaSvcStatus -eq "Running")
	{
		runPS "Get-DAConnectionStatus"					# W8/WS2012, W8.1/WS2012R2	# defaults to fl
	}
	else
	{	
		"----------------------" | out-file $outputFile -append
		"Get-DAConnectionStatus" | out-file $outputFile -append
		"----------------------" | out-file $outputFile -append
		"Network Connectivity Assistant (NcaSvc) service is not running." | out-file $outputFile -append
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	CollectFiles -sectionDescription $sectionDescription -fileDescription "DirectAccess Client Info" -filesToCollect $outputFile	

	
	$outputFile= $Computername + "_DirectAccessClient_reg_.TXT"
	
	# GPO NetworkConnectivityAssistant
	$CurrentVersionKeys = "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityAssistant"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -outputFile $outputFile -fileDescription "DirectAccess Client Registry Keys" -SectionDescription $sectionDescription

}

if ($bn -ge 9000)
{
	"[info] DirectAccess Event logs" | WriteTo-StdOut
	#----------
	# EventLogs
	#----------
	# This event log is disabled by default, so the log will be collected if the user/engineer enables it.
	$EventLogNames = "Microsoft-Windows-Ncasvc/Operational"
	$Prefix = ""
	$Suffix = "_evt_"
	.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
}
elseif ($bn -ge 7000)
{
	"[info] DirectAccess Event logs" | WriteTo-StdOut
	#----------
	# EventLogs
	#----------
	#
	$EventLogNames = "Microsoft-Windows-OtpCredentialProvider/Operational"
	$Prefix = ""
	$Suffix = "_evt_"
	.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
}




if ($bn -gt 7000)
{
	#----------Registry output
	$sectionDescription = "DirectAccess Client"
	$outputFile= $Computername + "_DirectAccessClient_reg_.TXT"
	$CurrentVersionKeys = "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"							# GPO DNSClient
							"HKLM\SOFTWARE\Policies\Microsoft\DirectAccessConnectivityAssistant",			# GPO DA Connectivity Assistant
							"HKLM\SOFTWARE\Policies\Microsoft\NetworkConnectivityAssistant",				# GPO NetworkConnectivityAssistant
							"HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator",	# GPO NetworkConnectivityStatusIndicator for DA
							"HKLM\SOFTWARE\Policies\Microsoft\Windows\TCPIP"								# GPO IPv6 Transition Technologies
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -outputFile $outputFile -fileDescription "DirectAccess Client Registry Keys" -SectionDescription $sectionDescription


	#----------Netsh dnsclient show state
	$outputFile = $ComputerName + "_DirectAccessClient_netsh_dnsclient-show-state.TXT"
	RunNetSH -NetSHCommandToExecute "dnsclient show state"
	CollectFiles -sectionDescription $sectionDescription -fileDescription "DNS Client netsh show state" -filesToCollect $outputFile
	
	#----------Netsh namespace show effectivepolicy
	$outputFile = $ComputerName + "_DirectAccessClient_netsh_namespace_show_effectivepolicy.TXT"
	RunNetSH -NetSHCommandToExecute "namespace show effectivepolicy"
	CollectFiles -sectionDescription $sectionDescription -fileDescription "DirectAccess Client Effective Policy" -filesToCollect $outputFile

	#----------Netsh namespace show policy
	$outputFile = $ComputerName + "_DirectAccessClient_netsh_namespace_show_policy.TXT"
	RunNetSH -NetSHCommandToExecute "namespace show policy"
	CollectFiles -sectionDescription $sectionDescription -fileDescription "DirectAccess Client Policy" -filesToCollect $outputFile
}






# SIG # Begin signature block
# MIIbAwYJKoZIhvcNAQcCoIIa9DCCGvACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtXNZ2QP7rfgSX/xRX7G3t/7C
# /3igghV6MIIEuzCCA6OgAwIBAgITMwAAAFnWc81RjvAixQAAAAAAWTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTQwNTIzMTcxMzE1
# WhcNMTUwODIzMTcxMzE1WjCBqzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# DTALBgNVBAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjpGNTI4LTM3
# NzctOEE3NjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMZsTs9oU/3vgN7oi8Sx8H4H
# zh487AyMNYdM6VE6vLawlndC+v88z+Ha4on6bkIAmVsW3QlkOOJS+9+O+pOjPbuH
# j264h8nQYE/PnIKRbZEbchCz2EN8WUpgXcawVdAn2/L2vfIgxiIsnmuLLWzqeATJ
# S8FwCee2Ha+ajAY/eHD6du7SJBR2sq4gKIMcqfBIkj+ihfeDysVR0JUgA3nSV7wT
# tU64tGxWH1MeFbvPMD/9OwHNX3Jo98rzmWYzqF0ijx1uytpl0iscJKyffKkQioXi
# bS5cSv1JuXtAsVPG30e5syNOIkcc08G5SXZCcs6Qhg4k9cI8uQk2P6hTXFb+X2EC
# AwEAAaOCAQkwggEFMB0GA1UdDgQWBBRbKBqzzXUNYz39mfWbFQJIGsumrDAfBgNV
# HSMEGDAWgBQjNPjZUkZwCu1A+3b7syuwwzWzDzBUBgNVHR8ETTBLMEmgR6BFhkNo
# dHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNyb3Nv
# ZnRUaW1lU3RhbXBQQ0EuY3JsMFgGCCsGAQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRUaW1l
# U3RhbXBQQ0EuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBBQUA
# A4IBAQB68A30RWw0lg538OLAQgVh94jTev2I1af193/yCPbV/cvKdHzbCanf1hUH
# mb/QPoeEYnvCBo7Ki2jiPd+eWsWMsqlc/lliJvXX+Xi2brQKkGVm6VEI8XzJo7cE
# N0bF54I+KFzvT3Gk57ElWuVDVDMIf6SwVS3RgnBIESANJoEO7wYldKuFw8OM4hRf
# 6AVUj7qGiaqWrpRiJfmvaYgKDLFRxAnvuIB8U5B5u+mP0EjwYsiZ8WU0O/fOtftm
# mLmiWZldPpWfFL81tPuYciQpDPO6BHqCOftGzfHgsha8fSD4nDkVJaEmLdaLgb3G
# vbCdVP5HC18tTir0h+q1D7W37ZIpMIIE7DCCA9SgAwIBAgITMwAAAMps1TISNcTh
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTzMIIE7wIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIIBCzAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUnCOR1ji3DxR5
# Mikwl0ieICZBYpwwgaoGCisGAQQBgjcCAQwxgZswgZigfoB8AEMAVABTAF8ATgBl
# AHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAEQAQwBf
# AEQAaQByAGUAYwB0AEEAYwBjAGUAcwBzAEMAbABpAGUAbgB0AC0AQwBvAG0AcABv
# AG4AZQBuAHQALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG
# 9w0BAQEFAASCAQCRnM4dTufQfLdEquINumNKz1/s61wAinqcxZdYkpwcrfz+y8n5
# HTfBQRUsX0Scv2tczSrJZV6GS7719RIteWXhNZlg7kuJvgbpBuBX4SaCHTMm52Ub
# a/FxFuZNQYfbmPz//vU4xEr0X8fFLCCc1YvxXz3v/KnfCU0mtk8NEVAufS04yCrU
# WKk89bUnOX+0+QNqkFBJlFkloiqys+93uWdE99ES0hz7fJQi8pUrxfDZlF9uf8wC
# PVRqvSHt3wpgwHhFpD6LALKaS7i/La7YLQdQcsgiVpXGSw+lPXiBEwIrOssvVRiv
# QNSwiO067S1pydLzNHqg3JovHymPIehL1ObuoYICKDCCAiQGCSqGSIb3DQEJBjGC
# AhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAAFnWc81R
# jvAixQAAAAAAWTAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgwODMwWjAjBgkqhkiG9w0BCQQxFgQU
# 6vdPoHoI7fqKWLZetlcnLAts8kgwDQYJKoZIhvcNAQEFBQAEggEAswIPQHZdONtW
# CG7X90K5xD6NULk9uO0LMewMNM19gS52dJ+5DZEwC01Uker+1f/iqV9Eqjee4bfv
# k3b6HgTUJgy8tLKTuFgJjmsB6WKrdoj0Cn40BqLypTs/cqfVOYtVvh8V3GIkUz1A
# O+ZDObZfUsm7HqwU3PTJWmH+ofL2Llp7L4bFclIhhvPLVMpi4Kc/AebuJ4ia7EmW
# uGD1UwnPUUvcWE7QtsWt6uCvdcVHQCLPVkr7a2LHDRBSJhdgrzzHFm3gRpej/5kc
# 9LGixXyzpltxomMIA3h5OJl1ZLQnIDxgr7OimEiMk9YF+UfdeKrz7LyZviMJ6v0v
# //5MetPYwg==
# SIG # End signature block
