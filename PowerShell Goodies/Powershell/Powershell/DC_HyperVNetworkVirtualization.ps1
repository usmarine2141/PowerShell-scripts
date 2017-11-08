#************************************************
# DC_HyperVNetworkVirtualization.ps1
# Version 1.0
# Date: May 2014
# Author:  Boyd Benson (bbenson@microsoft.com) with assistance from Tim Quinn (tiquinn@microsoft.com)
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
		 # later use return to return the exception message to an object:   return $Script:ExceptionMessage
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



$sectionDescription = "Hyper-V Networking Virtualization"

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber

$outputFile = $Computername + "_HyperVNetworking_HNV.TXT"


"===================================================="	| Out-File -FilePath $OutputFile -append
"Hyper-V Networking Virtualization Settings"			| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"Hyper-V Network Virtualization Configuration"			| Out-File -FilePath $OutputFile -append
"  1. Overview stats"									| Out-File -FilePath $OutputFile -append
"       Number of VMs"									| Out-File -FilePath $OutputFile -append
"       Number of VM Network Adapters"					| Out-File -FilePath $OutputFile -append
"       Number of Virtual Switches"						| Out-File -FilePath $OutputFile -append
"       Number of NVLookupRecords"						| Out-File -FilePath $OutputFile -append
"  2. HNV Hierarchical View"							| Out-File -FilePath $OutputFile -append
"       RoutingDomainID / VirtualSubnetID / VMs"		| Out-File -FilePath $OutputFile -append
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
			"===================================================="	| Out-File -FilePath $OutputFile -append
			"Stats:"	| Out-File -FilePath $OutputFile -append
			"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
			
			# How many Virtual Machines?
			$vms = Get-VM
			$vmsCount = $vms.length
			"Number of VMs               : " + $vmsCount	| Out-File -FilePath $OutputFile -append

			# How many Virtual Network Adapters?
			$vmNetworkAdapters = get-vmnetworkadapter *
			$vmNetworkAdaptersCount = $vmNetworkAdapters.length
			"Number of VMNetworkAdapters : " + $vmNetworkAdaptersCount	| Out-File -FilePath $OutputFile -append

			# How many Virtual Switches?
			$vmSwitch = get-vmswitch *
			$vmSwitchCount = $vmSwitch.length
			"Number of VMSwitches        : " + $vmSwitchCount	| Out-File -FilePath $OutputFile -append

			# How many Routing Domains (CustomerIDs)?
			# 	Get-NetVirtualizationLookupRecord shows the CustomerID
			#   Get-NetVirtualizationCustomerRoute shows the RoutingDomainID

			$nvLookupRecord = Get-NetVirtualizationLookupRecord
			$nvLookupRecordCount = $nvLookupRecord.length
			"Number of NVLookupRecords   : " + $nvLookupRecordCount		| Out-File -FilePath $OutputFile -append	
			"`n" | Out-File -FilePath $OutputFile -append
			"`n" | Out-File -FilePath $OutputFile -append
			"`n" | Out-File -FilePath $OutputFile -append

			[array]$nvLrCustomerIdsAll = @()
			[array]$nvLrVirtualSubnetIdsAll = @()
			[array]$nvLrProviderAddressesAll = @()
			[array]$nvLrCustomerAddressesAll = @()
			foreach ($lookupRecord in $nvLookupRecord)
			{
				$nvLrCustomerIdsAll       = $nvLrCustomerIdsAll       + $lookupRecord.CustomerID		# example: CustomerID      : {066ADA42-D48D-4104-937F-6FDCFF48B4AB}
				$nvLrVirtualSubnetIdsAll  = $nvLrVirtualSubnetIdsAll  + $lookupRecord.VirtualSubnetID	# example: VirtualSubnetID : 641590
				$nvLrProviderAddressesAll = $nvLrProviderAddressesAll + $lookupRecord.ProviderAddress
				$nvLrCustomerAddressesAll = $nvLrCustomerAddressesAll + $lookupRecord.CustomerAddress
			}

			# find unique values
			$nvLrCustomerIds       = $nvLrCustomerIdsAll | sort | Get-Unique	
			$nvLrVirtualSubnetIds  = $nvLrVirtualSubnetIdsAll | sort | Get-Unique
			$nvLrProviderAddresses = $nvLrProviderAddressesAll | sort | Get-Unique
			$nvLrCustomerAddresses = $nvLrCustomerAddressesAll | sort | Get-Unique

			$nvLrCustomerIdsCount       = $nvLrCustomerIds.length
			$nvLrVirtualSubnetIdsCount  = $nvLrVirtualSubnetIds.length
			$nvLrProviderAddressesCount = $nvLrProviderAddresses.length
			$nvLrCustomerAddressesCount = $nvLrCustomerAddresses.length
			
			# How many CustomerRoutes are there?
			$nvCustomerRoute = Get-NetVirtualizationCustomerRoute
			$nvCustomerRouteCount = $nvCustomerRoute.length
			[array]$nvCrRoutingDomainIdsAll = @()
			[array]$nvCrVirtualSubnetIdsAll = @()
			foreach ($customerRoute in $nvCustomerRoute)
			{
				$nvCrRoutingDomainIdsAll = $nvCrRoutingDomainIdsAll + $customerRoute.RoutingDomainId
				$nvCrVirtualSubnetIdsAll = $nvCrVirtualSubnetIdsAll + $customerRoute.VirtualSubnetId
			}

			# find unique CustomerIDs
			$nvCrRoutingDomainIds      = $nvCrRoutingDomainIdsAll | sort | Get-Unique
			$nvCrRoutingDomainIdsCount = $nvCrRoutingDomainIds.length
			# find unique VirtualSubnetIDs
			$nvCrVirtualSubnetIds      = $nvCrVirtualSubnetIdsAll | sort | Get-Unique
			$nvCrVirtualSubnetIdsCount = $nvCrVirtualSubnetIdsAll.length

			# How many Provider Addresses are there?
			$nvPa  = Get-NetVirtualizationProviderAddress
			$nvPaCount = $nvPa.length
			[array]$nvPaProviderAddressesAll = @()
			foreach ($pa in $nvPa)
			{
				$nvPaProviderAddressesAll = $nvPaProviderAddressesAll + $pa.ProviderAddress
			}
			$nvPaProviderAddresses = $nvPaProviderAddressesAll | sort | Get-Unique

			# Build an array that contains just the Provider Addresses from other hosts
			# This array contains only PAs from this host: $nvPaProviderAddresses
			# This array contains all PAs in the HNV scenario: $nvLrProviderAddresses

			[array]$nvProviderAddressesOnOtherHosts = @()
			foreach ($lrpa in $nvLrProviderAddresses)
			{
				if ($nvPaProviderAddresses -notcontains $lrpa)
				{
					$nvProviderAddressesOnOtherHosts = $nvProviderAddressesOnOtherHosts + $lrpa
				}
			}


			"===================================================="		| Out-File -FilePath $OutputFile -append
			"HNV Hierarchical View" 									| Out-File -FilePath $OutputFile -append
			"  RoutingDomainID / VirtualSubnetID / VMs"					| Out-File -FilePath $OutputFile -append
			"===================================================="		| Out-File -FilePath $OutputFile -append
			"`n"														| Out-File -FilePath $OutputFile -append

			foreach ($rdid in $nvCrRoutingDomainIds)
			{
				# All of the following output is from the Get-NetVirtualizationCustomerRoute pscmdlet.
				
				# Show the RDID
				"`n"| Out-File -FilePath $OutputFile -append
				"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append	
				"Routing Domain ID        : " + $rdid 					| Out-File -FilePath $OutputFile -append	
				
				# Show the unique VSID(s) for this RDID
					# [array]$nvPaLocalVms = @()		#	$nvPaLocalVms = $nvPaLocalVms + $lr.VMName
					# [array]$nvPaRemoteVms = @()		#	$nvPaRemoteVms = $nvPaRemoteVms + $lr.VMName
				
				foreach ($vsid in $nvCrVirtualSubnetIds)
				{
					foreach ($cr in $nvCustomerRoute)
					{
						if (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID))
						{
							"`n" 										| Out-File -FilePath $OutputFile -append	
							"  VirtualSubnetID        :   " + $vsid 	| Out-File -FilePath $OutputFile -append	
							# Show the VMs per VSID [this host]
							foreach ($lr in $nvLookupRecord)
							{
								if ( (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID)) -and (($rdid -eq $lr.CustomerID) -and ($vsid -eq $lr.VirtualSubnetID)) )
								{
									# Only show the VMs with ProviderAddresses on this machine (IPs in this array: $nvPaProviderAddresses)
									foreach ($nvPaProviderAddress in $nvPaProviderAddresses)
									{
										if (($lr.ProviderAddress -eq $nvPaProviderAddress)  -and ($lr.VMName -ne "GW") -and ($lr.VMName -ne "GW-External") -and ($lr.VMName -ne "DHCPExt.sys"))
										{
											"      VM [THIS HOST]     :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
										}
									}						
								}
							}

							# Show the VMs per VSID [other hosts]
							foreach ($lr in $nvLookupRecord)
							{
								if ( (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID)) -and (($rdid -eq $lr.CustomerID) -and ($vsid -eq $lr.VirtualSubnetID)) )
								{
									# Only show the VMs with ProviderAddresses on this machine (IPs in this array: $nvPaProviderAddresses)
									foreach ($addr in $nvProviderAddressesOnOtherHosts)
									{
										if (($lr.ProviderAddress -eq $addr) -and ($lr.VMName -ne "GW") -and ($lr.VMName -ne "GW-External") -and ($lr.VMName -ne "DHCPExt.sys"))
										{
											"      VM                 :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress		 | Out-File -FilePath $OutputFile -append	
										}
									}
								}
							}

							foreach ($lr in $nvLookupRecord)
							{
								if ( (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID)) -and (($rdid -eq $lr.CustomerID) -and ($vsid -eq $lr.VirtualSubnetID)) )
								{
									# Only show the VMs with ProviderAddresses on this machine (IPs in this array: $nvPaProviderAddresses)
									foreach ($nvPaProviderAddress in $nvPaProviderAddresses)
									{
										if (($lr.ProviderAddress -eq $nvPaProviderAddress) -and ($lr.VMName -eq "GW"))
										{
											"      HNV GW (Internal)  :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
										}
										if (($lr.ProviderAddress -eq $nvPaProviderAddress) -and ($lr.VMName -eq "GW-External"))
										{
											"      HNV GW (External)  :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
										}
									}
								}
							}


							# Show the VMs per VSID [other hosts]
							foreach ($lr in $nvLookupRecord)
							{
								if ( (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID)) -and (($rdid -eq $lr.CustomerID) -and ($vsid -eq $lr.VirtualSubnetID)) )
								{
									# Only show the VMs with ProviderAddresses on this machine (IPs in this array: $nvPaProviderAddresses)
									foreach ($addr in $nvProviderAddressesOnOtherHosts)
									{
										if (($lr.ProviderAddress -eq $addr) -and ($lr.VMName -eq "GW"))
										{
											"      HNV GW (Internal)  :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
										}
										if (($lr.ProviderAddress -eq $addr) -and ($lr.VMName -eq "GW-External"))
										{
											"      HNV GW (External)  :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
										}
									}
								}
							}
							
						}
					}
				}

				"`n" 						| Out-File -FilePath $OutputFile -append	
				"  SCVMM DHCP Server" 		| Out-File -FilePath $OutputFile -append	
				# Show the SCVMM Software DHCP Server
				foreach ($vsid in $nvCrVirtualSubnetIds)
				{
					foreach ($cr in $nvCustomerRoute)
					{
						if (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID))
						{
							# Show the HNV Tenant Gateway (Internal)
							foreach ($lr in $nvLookupRecord)
							{
								if ( (($rdid -eq $cr.RoutingDomainID) -and ($vsid -eq $cr.VirtualSubnetID)) -and (($rdid -eq $lr.CustomerID) -and ($vsid -eq $lr.VirtualSubnetID)) )
								{
									if ($lr.VMName -eq "DHCPExt.sys")
									{
										"      SCVMM DHCP Server  :     " + $lr.VMName + " ; " + $lr.CustomerAddress + " ; " + $lr.ProviderAddress 		| Out-File -FilePath $OutputFile -append	
									}
								}
							}
						}
					}
				}	

			}
			"`n"			| Out-File -FilePath $OutputFile -append
			"`n"			| Out-File -FilePath $OutputFile -append
			"`n"			| Out-File -FilePath $OutputFile -append
			
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

CollectFiles -filesToCollect $outputFile -fileDescription "Hyper-V Networking Settings" -SectionDescription $sectionDescription


# SIG # Begin signature block
# MIIbCQYJKoZIhvcNAQcCoIIa+jCCGvYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNpW2zDlpaXHHG6o4f1P5j4yw
# +figghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBPEwggTt
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCgggEJMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTn
# Dz8SsSi1N2N8H6HDG5UA5S6cBjCBqAYKKwYBBAGCNwIBDDGBmTCBlqB8gHoAQwBU
# AFMAXwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBs
# AF8ARABDAF8ASAB5AHAAZQByAFYATgBlAHQAdwBvAHIAawBWAGkAcgB0AHUAYQBs
# AGkAegBhAHQAaQBvAG4ALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBTqcpweqsS9J3BMaNd1GFxpojKKdwvAJSVqF2nZsRe
# DKWqQ87M9WRnvbVll8E39YvaO7TNBuJyeHWKU3fqvUtLUk+0zcY1pr1taxFf7Dtu
# S/M78I/5chfOAAHO7RdDI+lQgUT//8HGfzSPmMKMxa95G+VXKv2J7c3IqUaPfuJr
# toOXZv4qixq0iDwXa3uwCVg3HvFjDvpaLqa5sKPcE8o1fqAvf3jb8ZS/f3WDMC3y
# VHxhpjDq7F4c+Dbq3Oiv4gY63xIDopyGLjEdcZLBU91gLQ4SqI3/icI6tRQvKFyM
# m1q0m+m2Kt6GUmpCo0jz92+6MSqUDyrtpp6YsEPeYuBmoYICKDCCAiQGCSqGSIb3
# DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAA
# AEyh6E3MtHR7OwAAAAAATDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgwODI5WjAjBgkqhkiG9w0B
# CQQxFgQUEeuR13tZETHzLV4dmCVR89avDX4wDQYJKoZIhvcNAQEFBQAEggEArNeG
# C0N5Ci4EI2rPI6w93fT+Pm5RvOIiQbwRv1vZkRSNJ8Nxldtg4QJU43fYORlMZwMI
# ksb0oig5Zt5T/XS2fV7whcFFrDHLNzGmaGvm5H4KZs2NohbhoZOlyyxjc9+FQ4e9
# UerIvJu0+GoockT8/BTAC5q4/SrkRKbK4yjNRBjOToDA17ZF/9z4ciR/NX32f4sH
# lJIuP64sp5vpKiyihpcUJBa3bQkWdYNcIrJ6TyZ42bMYEgGkHgyw8UxSw6XFP1Yj
# J5jmTq/1ZbmPs0bkbHZzZwD12ZEumhB3iSedWtJFcv7PaQMIm5BjXy7zPPUKFQqo
# l6eF/TupuHtqblxoyw==
# SIG # End signature block
