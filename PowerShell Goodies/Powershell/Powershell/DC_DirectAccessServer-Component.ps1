#************************************************
# DC_DirectAccessServer-Component.ps1
# Version 1.0.04.03.13: Created script.
# Version 1.1.03.20.14: Multiple updates over time improving formatting, commands run, etc. [worked with JoelCh]
# Version 1.2.04.28.14: Added overview headings showing all commands run in each section.
# Version 1.3.08.24.14: Updated comments, changed script so the file would only be created on server SKUs, and then warn the user if the RaMgmtSvc does not exist. TFS264123
# Date: 2013-2014
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
Write-DiagProgress -Activity $ScriptVariable.ID_CTSDirectAccessServer -Status $ScriptVariable.ID_CTSDirectAccessServerDescription


#os version
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber
$isServerSku = (Get-WmiObject -Class Win32_ComputerSystem).DomainRole -gt 1


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
}


$sectionDescription = "DirectAccess Server"
If ($isServerSku -eq $true)
{
	$outputFile= $Computername + "_DirectAccessServer_info_pscmdlets.TXT"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"DirectAccess Server Powershell Cmdlets"				| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Overview"												| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"DirectAccess Server (Get-DA*) Powershell cmdlets"		| Out-File -FilePath $OutputFile -append
	"   1. Get-DAAppServer"									| Out-File -FilePath $OutputFile -append
	"   2. Get-DAClient"									| Out-File -FilePath $OutputFile -append
	"   3. Get-DAClientDnsConfiguration"					| Out-File -FilePath $OutputFile -append
	"   4. Get-DAMgmtServer"								| Out-File -FilePath $OutputFile -append
	"   5. Get-DANetworkLocationServer"						| Out-File -FilePath $OutputFile -append
	"   5. Get-DAOtpAuthentication"							| Out-File -FilePath $OutputFile -append
	"   5. Get-DaServer"									| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"DirectAccess Server (Get-RemoteAccess*) Powershell cmdlets"		| Out-File -FilePath $OutputFile -append
	"   1. Get-RemoteAccess"								| Out-File -FilePath $OutputFile -append
	"   2. Get-RemoteAccessAccounting"						| Out-File -FilePath $OutputFile -append
	"   3. Get-RemoteAccessConnectionStatistics"			| Out-File -FilePath $OutputFile -append
	"   4. Get-RemoteAccessConnectionStatisticsSummary"		| Out-File -FilePath $OutputFile -append
	"   5. Get-RemoteAccessHealth"							| Out-File -FilePath $OutputFile -append
	"   6. Get-RemoteAccessLoadBalancer"					| Out-File -FilePath $OutputFile -append
	"   7. Get-RemoteAccessRadius"							| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"DirectAccess Server (Get-Vpn*) Powershell cmdlets"		| Out-File -FilePath $OutputFile -append
	"   1. Get-VpnAuthProtocol"								| Out-File -FilePath $OutputFile -append
	"   2. Get-VpnServerIPsecConfiguration"					| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append
		"`n"	| Out-File -FilePath $OutputFile -append


	# Add registry check to determine if this is a DAServer (with Get-RemoteAccess).
	$regkeyRemoteAccessCheck = "HKLM:\SYSTEM\CurrentControlSet\Services\RaMgmtSvc"
	if (Test-Path $regkeyRemoteAccessCheck) 
	{
		if ($bn -ge 9000)
		{
			"[info] DA ps cmdlets (those that start with Get-DA)" | WriteTo-StdOut

			"===================================================="	| Out-File -FilePath $OutputFile -append
			"DirectAccess Server (Get-DA*) Powershell cmdlets"		| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			#----------
			# W8/W2012 Powershell Cmdlets
			#----------
			# RemoteAccess
			runPS "Get-DAAppServer"						# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-DAClient"						# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-DAClientDnsConfiguration"	-ft	# W8/WS2012, W8.1/WS2012R2	# ft	
			runPS "Get-DAMgmtServer"					# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-DANetworkLocationServer"			# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-DAOtpAuthentication"				# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-DaServer"						# W8/WS2012, W8.1/WS2012R2	# fl
		}	
			
		if ($bn -gt 9000)
		{
			"[info] RemoteAccess ps cmdlets section (those that start with Get-RemoteAccess*)" | WriteTo-StdOut
			"[info] If there is nothing in this section, then we cannot reach a DC" | WriteTo-StdOut
			"===================================================="			| Out-File -FilePath $OutputFile -append
			"DirectAccess Server (Get-RemoteAccess*) Powershell cmdlets"	| Out-File -FilePath $OutputFile -append
			"===================================================="			| Out-File -FilePath $OutputFile -append

			runPS "Get-RemoteAccess"								# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-RemoteAccessAccounting"						# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-RemoteAccessConnectionStatistics"		-ft	# W8/WS2012, W8.1/WS2012R2	# ft
			runPS "Get-RemoteAccessConnectionStatisticsSummary"		# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-RemoteAccessHealth"						-ft	# W8/WS2012, W8.1/WS2012R2	# ft
			runPS "Get-RemoteAccessLoadBalancer"					# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-RemoteAccessRadius"						-ft	# W8/WS2012, W8.1/WS2012R2	# ft

			"[info] VPN ps cmdlets section: Verifying the RemoteAccess service is running" | WriteTo-StdOut
			"===================================================="			| Out-File -FilePath $OutputFile -append
			"DirectAccess Server (Get-Vpn*) Powershell cmdlets"				| Out-File -FilePath $OutputFile -append
			"===================================================="			| Out-File -FilePath $OutputFile -append
			# verifying that the RemoteAccess service is running
			if ((Get-Service "RemoteAccess").Status -eq 'Running')
			{	
				"[info] RemoteAccess service is running; running ps cmdlets that start with Get-Vpn" | WriteTo-StdOut
				# Errors if the RemtoteAccess service is not started.
					# The following pscmdlet removed via commented 10/08/13; reason: exception)
					# runPS "Get-VpnS2SInterface" 
					runPS "Get-VpnAuthProtocol"						# W8/WS2012, W8.1/WS2012R2	# default <unknown>	
					runPS "Get-VpnServerIPsecConfiguration"			# W8/WS2012, W8.1/WS2012R2	# default <unknown>	
			}
			else
			{
				"The RemoteAccess service is not running. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
			}
			

			<#
				#Currently not including these pscmdlets:
				#RemoteAccess
						# Requires the RRAS service to be started (I think this is the service it relies on)
						runPS "Get-RemoteAccessConnectionStatistics"
						# need trap
						runPS "Get-DAMultiSite"
						# need trap
						runPS "Get-DAEntryPoint"
						# need trap
						runPS "Get-DAEntryPointDC"
					# Requires Input - not running.
						# Get-RemoteAccessUserActivity
					# Requires Input - not running.
						# Get-VpnS2SInterfaceStatistics
			#>	
		}

		if ($bn -ge 9000)
		{
			# Denial of Service pscmdlet. Added 10.10.13
			# This pscmdlet exceptions on client SKUs.
			"[info]: get-NetIpsecdospSetting" | WriteTo-StdOut
			runPS "get-NetIpsecDospSetting"							# W8/WS2012, W8.1/WS2012R2	# default fl
		}
	}
	else
	{
		"The RaMgmtSvc service does not exist. Not running pscmdlets." | Out-File -FilePath $OutputFile -append
	}
	CollectFiles -sectionDescription $sectionDescription -fileDescription "DirectAccess Server Info PSCmdlets" -filesToCollect $outputFile	


	if (Test-Path $regkeyRemoteAccessCheck) 
	{	
		if ($bn -ge 9000)
		{
			"[info] DirectAccess Event logs" | WriteTo-StdOut
			#----------
			# EventLogs
			#----------
			#
			$EventLogNames = "Microsoft-Windows-RemoteAccess-MgmtClient/Operational"
			$Prefix = ""
			$Suffix = "_evt_"
			.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

			$EventLogNames = "Microsoft-Windows-RemoteAccess-RemoteAccessServer/Admin"
			$Prefix = ""
			$Suffix = "_evt_"
			.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

			$EventLogNames = "Microsoft-Windows-RemoteAccess-RemoteAccessServer/Operational"
			$Prefix = ""
			$Suffix = "_evt_"
			.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

		}

		if ($bn -ge 7600)
		{
			#----------Registry
			$outputFile = $Computername + "_DirectAccessServer_reg_.TXT"
			$CurrentVersionKeys = "HKLM\SOFTWARE\Policies\Microsoft\DirectAccess",
									"HKLM\SOFTWARE\Policies\Microsoft\Windows\RemoteAccess",
									"HKLM\System\CurrentControlSet\Services\RemoteAccess",
									"HKLM\System\CurrentControlSet\Services\RaMgmtSvc"
			$sectionDescription = "DirectAccess Server"
			RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -outputFile $outputFile -fileDescription "DirectAccess Server Registry Keys" -SectionDescription $sectionDescription
		}
	}
}
# SIG # Begin signature block
# MIIbCwYJKoZIhvcNAQcCoIIa/DCCGvgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU12FlqhsIekaebQhf1K+08eF1
# kOugghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBPMwggTv
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCgggELMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTQ
# LIcIXhKiWqFltF6whgCHTP0PITCBqgYKKwYBBAGCNwIBDDGBmzCBmKB+gHwAQwBU
# AFMAXwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBs
# AF8ARABDAF8ARABpAHIAZQBjAHQAQQBjAGMAZQBzAHMAUwBlAHIAdgBlAHIALQBD
# AG8AbQBwAG8AbgBlAG4AdAAuAHAAcwAxoRaAFGh0dHA6Ly9taWNyb3NvZnQuY29t
# MA0GCSqGSIb3DQEBAQUABIIBAGyPPLficTfnIy7sBEzTNKzotOHrwJSAS19mLR26
# PqpsnDmnOjb1NpSkUp+TZCCOvRwzU5V4ucvCkN4ufjJ7L8h2bveNwNo3KKP42Pn+
# TUQrKH3eu6aH2hPIes73g5SDhm11zYa97prNhCDjJr3vlX6nfalF5/QWJVprCnX/
# CnBShMs2raHotZiaK2VSk1SCGkkt8WJqq167NdYloPo8hilCqrla6DKE5kkklyT9
# HIm8dzEanXr0LW8IXlTuggUmyx1RLpReCW/WTrLO8+bMdjGwMg2uLg29YEGZ1JSf
# 5ettCke3if5hEuNl/Y34vAY3GxdIdjeDrOwlL5IB+AN0PiehggIoMIICJAYJKoZI
# hvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBAhMz
# AAAATKHoTcy0dHs7AAAAAABMMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAxODA4MjlaMCMGCSqGSIb3
# DQEJBDEWBBRwmDlzd505Nkkip8z9SStFdzN8VTANBgkqhkiG9w0BAQUFAASCAQBm
# LJSZ6ChznvW4+cFGSAd2Vi1s3Le1rl1jgftL6Y16FZxhj8kC2+ujHWY5WNQBgZ3p
# zElWE3A3W0Csap9yL5jVDNWz0gdvtbqf43aRYSlUEs9kltIiEO1k8IppcWvG4YBI
# 1YvRE5anBcdhS7dL3xZnfHI4V87N8mKWMNL82GnBcsutxbMo9zgYdsvtZEtnCn9B
# O5W+Ph2JoRnnWZdRroPBK0mLhNdACAYxe+dB1ocpiOORb4bBVg7VTZpI6cK+S+Ie
# qIbNzI+joHRQjt5Xdnh30+iifpuj2qW8rSRCpppgj8MaLFbJYbezgelmgaCMyusK
# kOG0cl8yTQcNTHu6WpZN
# SIG # End signature block
