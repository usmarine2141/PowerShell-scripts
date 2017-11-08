#************************************************
# DC_HyperVNetworking.ps1
# Version 1.0.04.22.14: Created script.
# Version 1.1.04.26.14: Corrected formatting issues with PowerShell output using format-table
# Version 1.2.05.23.14: Added Get-SCIPAddress; Added Hyper-V registry output (and placed at the top of the script)
# Version 1.3.07.31.14: Moved the "Hyper-V Network Virtualization NAT Configuration" section into its own code block for WS2012R2+. 
# Date: 2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: PS cmdlets
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
	}

Import-LocalizedData -BindingVariable ScriptVariable


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



$sectionDescription = "Hyper-V Networking Settings"

#----------Registry
$outputFile = $Computername + "_HyperVNetworking_reg_.TXT"
#grouped registry values together:
#  RegKeys: vmms;
#  RegKeys: vmsmp, smsp, vmsvsf, vmsvsp
#  RegKeys: vmbus, vmbushid, vmbusr
#  RegKeys: vmbusr, vmicguestinterface, vmicheartbeat, vmickvpexchange, vmicrdv, vmicshutdown, vmictimesync, vmicvss

$CurrentVersionKeys = 	"HKLM\SYSTEM\CurrentControlSet\services\vmms",
						"HKLM\SYSTEM\CurrentControlSet\services\vmsmp",
						"HKLM\SYSTEM\CurrentControlSet\services\VMSP",
						"HKLM\SYSTEM\CurrentControlSet\services\VMSVSF",
						"HKLM\SYSTEM\CurrentControlSet\services\VMSVSP",
						"HKLM\SYSTEM\CurrentControlSet\services\vmbus",
						"HKLM\SYSTEM\CurrentControlSet\services\VMBusHID",
						"HKLM\SYSTEM\CurrentControlSet\services\vmbusr",
						"HKLM\SYSTEM\CurrentControlSet\services\vmicguestinterface",
						"HKLM\SYSTEM\CurrentControlSet\services\vmicheartbeat",
						"HKLM\SYSTEM\CurrentControlSet\services\vmickvpexchange",
						"HKLM\SYSTEM\CurrentControlSet\services\vmicrdv",
						"HKLM\SYSTEM\CurrentControlSet\services\vmicshutdown",
						"HKLM\SYSTEM\CurrentControlSet\services\vmictimesync",
						"HKLM\SYSTEM\CurrentControlSet\services\vmicvss"
RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $outputFile -fileDescription "Hyper-V Registry Keys" -SectionDescription $sectionDescription



# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber

$outputFile = $Computername + "_HyperVNetworking_info_pscmdlets.TXT"
"===================================================="	| Out-File -FilePath $OutputFile -append
"Hyper-V Networking Settings Powershell Cmdlets"		| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Server Configuration"							| Out-File -FilePath $OutputFile -append
"  1. Get-VMHost"										| Out-File -FilePath $OutputFile -append
"  2. Get-VMHostNumaNode"								| Out-File -FilePath $OutputFile -append
"  3. Get-VMHostNumaNodeStatus"							| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Switch Configuration"							| Out-File -FilePath $OutputFile -append
"  1. Get-VMSwitch *"									| Out-File -FilePath $OutputFile -append
"  2. Get-VMSwitch * | fl"								| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Adapter Configuration"					| Out-File -FilePath $OutputFile -append
"  1. Get-VMNetworkAdapter -ManagementOS"				| Out-File -FilePath $OutputFile -append
"  2. Get-VMNetworkAdapter -All"						| Out-File -FilePath $OutputFile -append
"  3. Get-VMNetworkAdapter *"							| Out-File -FilePath $OutputFile -append
"  4. Get-VMNetworkAdapter * | fl"						| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Virtualization Configuration"			| Out-File -FilePath $OutputFile -append
"  1. Get-NetVirtualizationCustomerRoute"				| Out-File -FilePath $OutputFile -append
"  2. Get-NetVirtualizationProviderAddress"				| Out-File -FilePath $OutputFile -append
"  3. Get-NetVirtualizationProviderRoute"				| Out-File -FilePath $OutputFile -append
"  4. Get-NetVirtualizationLookupRecord"				| Out-File -FilePath $OutputFile -append
"  4. Get-NetVirtualizationGlobal"						| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Virtualization SCVMM Configuration"	| Out-File -FilePath $OutputFile -append
"  1. Get-SCIPAddress"									| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Virtualization NAT Configuration [HNV Gateway]"		| Out-File -FilePath $OutputFile -append
"  1. Get-NetNat"										| Out-File -FilePath $OutputFile -append
"  2. Get-NetNatGlobal"									| Out-File -FilePath $OutputFile -append
"  3. Get-NetNatSession"								| Out-File -FilePath $OutputFile -append
"  4. Get-NetNatStaticMapping"							| Out-File -FilePath $OutputFile -append
"  5. Get-NetNatExternalAddress"						| Out-File -FilePath $OutputFile -append	
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append


$vmmsCheck = Test-path "HKLM:\SYSTEM\CurrentControlSet\Services\vmms"
if ($vmmsCheck)
{
	if ((Get-Service "vmms").Status -eq 'Running')
	{
		if ($bn -gt 9000) 
		{
			"[info] Hyper-V Server Configuration section."  | WriteTo-StdOut	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Hyper-V Server Configuration"							| Out-File -FilePath $OutputFile -append	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			# Hyper-V: Get-VMHost
			runPS "Get-VMHost"		-ft # W8/WS2012, W8.1/WS2012R2	# ft	
			$vmhost = get-vmhost
			runPS "Get-VMHostNumaNode"		-ft # W8/WS2012, W8.1/WS2012R2	# ft
			if ($vmhost.NumaSpanningEnabled -eq $false)
			{
				"NUMA Spanning has been disabled within Hyper-V Settings, running the `"Get-VMHostNumaNodeStatus`" ps cmdlet."		| Out-File -FilePath $OutputFile -append
				"`n"	| Out-File -FilePath $OutputFile -append				
				runPS "Get-VMHostNumaNodeStatus"			# W8/WS2012, W8.1/WS2012R2	# ft	
			}
			else
			{
				"------------------------"	| Out-File -FilePath $OutputFile -append
				"Get-VMHostNumaNodeStatus"	| Out-File -FilePath $OutputFile -append
				"------------------------"	| Out-File -FilePath $OutputFile -append
				"NUMA Spanning is NOT enabled. Not running the `"Get-VMHostNumaNodeStatus`" ps cmdlet."	| Out-File -FilePath $OutputFile -append
				"`n"	| Out-File -FilePath $OutputFile -append
				"`n"	| Out-File -FilePath $OutputFile -append
				"`n"	| Out-File -FilePath $OutputFile -append
			}

			
			"[info] Hyper-V Switch Configuration section."  | WriteTo-StdOut	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Hyper-V Switch Configuration"							| Out-File -FilePath $OutputFile -append	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			# Hyper-V: Get-VMSwitch
			runPS "Get-VMSwitch *"			-ft # W8/WS2012, W8.1/WS2012R2	# ft	
			runPS "Get-VMSwitch * | fl"		-ft # W8/WS2012, W8.1/WS2012R2	# ft


			"[info] Hyper-V Network Adapter Configuration section."  | WriteTo-StdOut
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Hyper-V Network Adapter Configuration"					| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
			# Hyper-V: Get-VMNetworkAdapter
			runPS "Get-VMNetworkAdapter -ManagementOS"		-ft # W8/WS2012, W8.1/WS2012R2	# ft
			runPS "Get-VMNetworkAdapter -All"				-ft # W8/WS2012, W8.1/WS2012R2	# ft				
			runPS "Get-VMNetworkAdapter *"					-ft # W8/WS2012, W8.1/WS2012R2	# ft	
			runPS "Get-VMNetworkAdapter * | fl"					# W8/WS2012, W8.1/WS2012R2	# fl	


			"[info] Hyper-V Network Virtualization Configuration section."  | WriteTo-StdOut	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Hyper-V Network Virtualization Configuration"			| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append		
			"`n"	| Out-File -FilePath $OutputFile -append
			# Hyper-V: Get-NetVirtualization
			runPS "Get-NetVirtualizationCustomerRoute"			# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-NetVirtualizationProviderAddress"		# W8/WS2012, W8.1/WS2012R2	# fl	
			runPS "Get-NetVirtualizationProviderRoute"			# W8/WS2012, W8.1/WS2012R2	# unknown
			runPS "Get-NetVirtualizationLookupRecord"			# W8/WS2012, W8.1/WS2012R2	# fl
			runPS "Get-NetVirtualizationGlobal"					# W8/WS2012, W8.1/WS2012R2	# fl		#Added 4/26/14


			"[info] Hyper-V Network Virtualization Configuration section."  | WriteTo-StdOut	
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Hyper-V Network Virtualization SCVMM Configuration"	| Out-File -FilePath $OutputFile -append
			"===================================================="	| Out-File -FilePath $OutputFile -append		
			"`n"	| Out-File -FilePath $OutputFile -append

			If (Test-path “HKLM:\SYSTEM\CurrentControlSet\Services\SCVMMService”)
			{
				if ($bn -ge 9600) 
				{
					runPS "Get-SCIPAddress"						# W8.1/WS2012R2	# fl
				}
				else
				{
					"This server is not running WS2012 R2. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
				}
			}
			else
			{
				"SCVMM is not installed."					| Out-File -FilePath $OutputFile -append
				"Not running the Get-SCIPAddress pscmdlet."	| Out-File -FilePath $OutputFile -append			
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
	{
		"The `"Hyper-V Virtual Machine Management`" service is not running. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
	}
}
else
{
	"The `"Hyper-V Virtual Machine Management`" service does not exist. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}


"[info] Hyper-V Network Virtualization Configuration section."  | WriteTo-StdOut	
"===================================================="	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Virtualization NAT Configuration"		| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append	
"`n"	| Out-File -FilePath $OutputFile -append
if ($bn -ge 9600) 
{
	# Hyper-V: Get-NetVirtualization
	runPS "Get-NetNat"						# W8.1/WS2012R2	# unknown		# Added 4/26/14
	runPS "Get-NetNatGlobal"				# W8.1/WS2012R2	# unknown		# Added 4/26/14
	"---------------------------"			| Out-File -FilePath $OutputFile -append
	"Get-NetNatSession"						| Out-File -FilePath $OutputFile -append
	"---------------------------"			| Out-File -FilePath $OutputFile -append
	"Not running Get-NetNatSession currently because of exception."			| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	#runPS "Get-NetNatSession"				# W8.1/WS2012R2	# unknown		# Added 4/26/14 -> commented out because of exception... Need a check in place.
	runPS "Get-NetNatStaticMapping"			# W8.1/WS2012R2	# unknown		# Added 4/26/14
	runPS "Get-NetNatExternalAddress"		# W8.1/WS2012R2	# unknown		# Added 4/26/14
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
}
else
{
	"The Get-NetNat* powershell cmdlets only run on WS2012 R2. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
CollectFiles -filesToCollect $outputFile -fileDescription "Hyper-V Networking Settings" -SectionDescription $sectionDescription













# SIG # Begin signature block
# MIIa8gYJKoZIhvcNAQcCoIIa4zCCGt8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBe7U+0JZB3dI03ieY2aWqjU5
# 3o2gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNowggTW
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfMwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFChp
# 2n3V98KVQ83aaAr6ZYEMfA0IMIGSBgorBgEEAYI3AgEMMYGDMIGAoGaAZABDAFQA
# UwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwA
# XwBEAEMAXwBIAHkAcABlAHIAVgBOAGUAdAB3AG8AcgBrAGkAbgBnAC4AcABzADGh
# FoAUaHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAIdPo/JM+
# 89EftEba6zfJ2/iVZQjeySbZgIVv07wyzjpHafhR3CZ/HsXB1GGNN8w8Mnao1x+a
# aBkFYcJ+oyWBgh7XugpwYfdYiZ2D2e0+83txzuSTYEoHovrUum8nfdu7eqRnBjUX
# UmnGyP+COPd4GYOLsDbjtLzN40nVpdTBLkR8dLmuo0anaDCIewZpan3pe1eRRw4I
# Gql8AZr/Iqcf277GyhPOauU43EkOhPjnuAah+ypm3A1sj3Zr1GS2y3HOaPAF9Zvc
# zDNIw5vZCi7xypt7+inuAToItrxkK0r1W0whWLsqRJesngpavoybdr1+BfBjEVOv
# bjhsqYKgv/KT+KGCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4D
# AhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTE0MTAyMDE4MDgyOVowIwYJKoZIhvcNAQkEMRYEFG1I5/ezxoW9Xy2YVICUpgcb
# V4zUMA0GCSqGSIb3DQEBBQUABIIBAJRAiSKTkjzc1nH7RIueXVAkEfmxKVs0H2lE
# KL/avXTYyjLoC6naujh0ss/m3gQsGlckPs/+LbkCqgwPXnRGO4/aFm5RYqdjxc5I
# r3kGG7HOuEULqIdNCV3OduZmUseon0p93W7npFQIKojseGPmIrqkGSP8y8jgjqa9
# snBDI515/0JxJq5cZ/GNnNHNF27ke+JUMPAmdRdVlj/D4ADcLbEnL+5DyDashxYw
# awt3w3qG17Mtmf76DdWxI/dtuMASofvzG5HrpasFisxi0JJj4kUa+uJSoigc5JZy
# FneFge2FWCljwoWLyMQr8O6VKWYQohBmFHGqzQhoC4/rXb3Q6go=
# SIG # End signature block
