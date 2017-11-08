#************************************************
# DC_NetworkAdapters-Component.ps1
# Version 1.0 Dumped the registry key where adapter information is stored, and added Powershell Cmdlets (via JoelCh)
# Version 1.1 Added registry output for the CurrentControlSet\Control class ID for Adapters.
# Version 1.2: Altered the runPS function to correct a column width issue.
# Version 1.3.07.31.2014: Added the detailed output for Get-NetAdapterBinding -AllBindings.
# Version 1.4.08.08.2014: Added regkey "HKLM\SYSTEM\CurrentControlSet\Control\Network" to reg output so we can correlate GUIDs to Interface names.
# Version 1.5.08.11.2014: Added "Network Adapter to GUID Mappings" section using output from "HKLM:\SYSTEM\CurrentControlSet\Control\Network"
# Date: 2013-2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: 
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


function RunPS ([string]$RunPScmd="", [switch]$ft, [switch]$noHeader)
{
	if ($noHeader)
	{
	}
	else
	{
		$RunPScmdLength = $RunPScmd.Length
		"-" * ($RunPScmdLength)		| Out-File -FilePath $OutputFile -append
		"$RunPScmd"  				| Out-File -FilePath $OutputFile -append
		"-" * ($RunPScmdLength)  	| Out-File -FilePath $OutputFile -append
	}
		
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


$sectionDescription = "Network Adapters"

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber

$outputFile = $Computername + "_NetworkAdapters_info_pscmdlets.TXT"
"===================================================="		| Out-File -FilePath $OutputFile -append
"Network Adapter Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
"===================================================="		| Out-File -FilePath $OutputFile -append
"Overview"													| Out-File -FilePath $OutputFile -append
"----------------------------------------------"			| Out-File -FilePath $OutputFile -append
"Network Adapter Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
"   1. Get-NetAdapter"										| Out-File -FilePath $OutputFile -append
"   2. Get-NetAdapter -IncludeHidden"						| Out-File -FilePath $OutputFile -append
"   3. Get-NetAdapterAdvancedProperty"						| Out-File -FilePath $OutputFile -append
"   4. Get-NetAdapterBinding -AllBindings -IncludeHidden | select Name, InterfaceDescription, DisplayName, ComponentID, Enabled"	| Out-File -FilePath $OutputFile -append
"   5. Get-NetAdapterChecksumOffload"						| Out-File -FilePath $OutputFile -append
"   6. Get-NetAdapterEncapsulatedPacketTaskOffload"			| Out-File -FilePath $OutputFile -append
"   7. Get-NetAdapterHardwareInfo"							| Out-File -FilePath $OutputFile -append
"   8. Get-NetAdapterIPsecOffload"							| Out-File -FilePath $OutputFile -append
"   9. Get-NetAdapterLso"									| Out-File -FilePath $OutputFile -append
"  10. Get-NetAdapterPowerManagement"						| Out-File -FilePath $OutputFile -append
"  11. Get-NetAdapterQos"									| Out-File -FilePath $OutputFile -append
"  12. Get-NetAdapterRdma"									| Out-File -FilePath $OutputFile -append
"  13. Get-NetAdapterRsc"									| Out-File -FilePath $OutputFile -append
"  14. Get-NetAdapterRss"									| Out-File -FilePath $OutputFile -append
"  15. Get-NetAdapterSriov"									| Out-File -FilePath $OutputFile -append
"  16. Get-NetAdapterSriovVf"								| Out-File -FilePath $OutputFile -append
"  17. Get-NetAdapterStatistics"							| Out-File -FilePath $OutputFile -append
"  18. Get-NetAdapterVmq"									| Out-File -FilePath $OutputFile -append
"  19. Get-NetAdapterVmqQueue"								| Out-File -FilePath $OutputFile -append
"  20. Get-NetAdapterVPort"									| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
"Network Adapter Details For NON-HIDDEN Adapters (formatted list, non-hidden)"	| Out-File -FilePath $OutputFile -append
"   1. Get-NetAdapter | fl *"	| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"		| Out-File -FilePath $OutputFile -append
"Network Adapter Details For HIDDEN Adapters (formatted list, ONLY hidden)"	| Out-File -FilePath $OutputFile -append
"   1. Get-NetAdapter -IncludeHidden (parsed to show hidden only)"	| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"			| Out-File -FilePath $OutputFile -append
"Network Adapter to GUID Mappings"								| Out-File -FilePath $OutputFile -append
"  Using regkey HKLM:\SYSTEM\CurrentControlSet\Control\Network"	| Out-File -FilePath $OutputFile -append
"===================================================="			| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append


if ($bn -gt 9000)
{
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Network Adapter Powershell Cmdlets"					| Out-File -FilePath $OutputFile -append	
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" 	| Out-File -FilePath $OutputFile -append
	"-------------------------------"	| Out-File -FilePath $OutputFile -append
	"Get-NetAdapter (formatted table)"	| Out-File -FilePath $OutputFile -append
	"-------------------------------"	| Out-File -FilePath $OutputFile -append
	$networkAdapters = get-netadapter
	$networkAdaptersLen = $networkAdapters.length
	"Number of Network Adapters (output from get-netadapter; does not include hidden adapters): " + $networkAdaptersLen	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	runPS "Get-NetAdapter"				-ft -noheader	# W8/WS2012, W8.1/WS2012R2	# ft

	"-------------------------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"Get-NetAdapter -IncludeHidden (formatted table, hidden)"	| Out-File -FilePath $OutputFile -append
	"-------------------------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	$networkAdaptersWithHidden = Get-NetAdapter -IncludeHidden
	$networkAdaptersWithHiddenLen = $networkAdaptersWithHidden.length
	$hiddenNetworkAdaptersLen = 0
	foreach ($adapter in $networkAdaptersWithHidden)
	{
		if ($adapter.Hidden -eq $true)
		{ $hiddenNetworkAdaptersLen++ }
	}
	"Number of Network Adapters (output from get-netadapter; does not include hidden adapters): " + $networkAdaptersLen	| Out-File -FilePath $OutputFile -append
	"Number of Network Adapters (including hidden adapters) : " + $networkAdaptersWithHiddenLen	| Out-File -FilePath $OutputFile -append

	"`n"	| Out-File -FilePath $OutputFile -append
	runPS "Get-NetAdapter -IncludeHidden"						-ft -noheader	# W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterAdvancedProperty"						-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterBinding -AllBindings -IncludeHidden | select Name, InterfaceDescription, DisplayName, ComponentID, Enabled"	-ft # W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterChecksumOffload"						-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterEncapsulatedPacketTaskOffload"			-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterHardwareInfo"							-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterIPsecOffload"							-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterLso"									-ft # W8/WS2012, W8.1/WS2012R2	# ft	
	runPS "Get-NetAdapterPowerManagement"							# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetAdapterQos"										# W8/WS2012, W8.1/WS2012R2	# unknown
	runPS "Get-NetAdapterRdma"										# W8/WS2012, W8.1/WS2012R2	# unknown
	runPS "Get-NetAdapterRsc"									-ft # W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterRss"										# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetAdapterSriov"										# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetAdapterSriovVf"									# W8/WS2012, W8.1/WS2012R2	# unknown
	runPS "Get-NetAdapterStatistics"							-ft # W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterVmq"									-ft # W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterVmqQueue"								-ft # W8/WS2012, W8.1/WS2012R2	# ft
	runPS "Get-NetAdapterVPort"										# W8/WS2012, W8.1/WS2012R2	# unknown
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Network Adapter Details For NON-HIDDEN Adapters (formatted list, non-hidden)"	| Out-File -FilePath $OutputFile -append
	"   1. Get-NetAdapter | fl *"	| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Number of Network Adapters (output from get-netadapter; does not include hidden adapters): " + $networkAdaptersLen	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	runPS "Get-NetAdapter | fl *"				# W8/WS2012, W8.1/WS2012R2	# fl
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Network Adapter Details For HIDDEN Adapters (formatted list, ONLY hidden)"	| Out-File -FilePath $OutputFile -append
	"   1. Get-NetAdapter -IncludeHidden (parsed to show hidden only)"	| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Number of Hidden Network Adapters: " + $hiddenNetworkAdaptersLen	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	foreach ($adapter in $networkAdaptersWithHidden)
	{
		if ($adapter.Hidden -eq $true)
		{
			"-------------------------------"	| Out-File -FilePath $OutputFile -append
			$adapter | fl * 	| Out-File -FilePath $OutputFile -append
			"`n"	| Out-File -FilePath $OutputFile -append
		}
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append

}
else
{
	"The Windows OS version is W2008.R2 or earlier. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}


"===================================================="			| Out-File -FilePath $OutputFile -append
"Network Adapter to GUID Mappings"								| Out-File -FilePath $OutputFile -append
"  Using regkey HKLM:\SYSTEM\CurrentControlSet\Control\Network"	| Out-File -FilePath $OutputFile -append
"===================================================="			| Out-File -FilePath $OutputFile -append
if ($bn -ge 6000)
{
	$networkRegKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network"
	if (test-path $networkRegKeyPath) 
	{
		#$networkNameToGUIDObj = new-object PSObject

		$networkRegKey = Get-ItemProperty -Path $networkRegKeyPath
		$networkGUIDRegKey = Get-ChildItem -Path $networkRegKeyPath

		foreach ($netChildGUID in $networkGUIDRegKey)
		{
			$netChildGUIDName = $netChildGUID.PSChildName
			if ( ($netChildGUIDName.StartsWith("`{4D36E972")) -or ($netChildGUIDName.StartsWith("`{4d36E972")) )
			{
				# "Network Subkey GUID: $netChildGUIDName"
				$netChildGUIDRegKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\$netChildGUIDName"
				$netConnectionGUIDs = Get-ChildItem -Path $netChildGUIDRegKeyPath
				foreach ($netConnectionGUID in $netConnectionGUIDs)
				{
					$netConnectionGUIDName = $netConnectionGUID.PSChildName
					if ($netConnectionGUIDName.StartsWith("`{"))
					{
						$netConnectionNameRegkey = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\$netChildGUIDName\$netConnectionGUIDName\Connection"
						if (test-path $netConnectionNameRegkey)
						{
							$netConnectionName = (Get-ItemProperty -Path $netConnectionNameRegkey).Name
							" Connection Name    : " + $netConnectionName	| Out-File -FilePath $OutputFile -append
							" Connection GUID    : " + $netConnectionGUIDName	| Out-File -FilePath $OutputFile -append
							"`n" | Out-File -FilePath $OutputFile -append
						}
					}
				}
			}
		}
	}
}
else
{
	"The Windows OS version is W2003 or earlier. Not running ps cmdlets."	| Out-File -FilePath $OutputFile -append
}
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append

CollectFiles -filesToCollect $OutputFile -fileDescription "Network Adapter Information" -SectionDescription $sectionDescription



#----------Registry
$OutputFile= $Computername + "_NetworkAdapters_reg_output.TXT"
$CurrentVersionKeys =   "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}",
						"HKLM\SYSTEM\CurrentControlSet\Control\Network"
RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "Network Adapter registry information" -SectionDescription $sectionDescription









# SIG # Begin signature block
# MIIa/QYJKoZIhvcNAQcCoIIa7jCCGuoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnL99qd2OlNAfTKxROgDD5Qws
# f2KgghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTtMIIE6QIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIIBBTAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUk6rcq0mPwj+5
# 3PBmlWZRBaY3fjIwgaQGCisGAQQBgjcCAQwxgZUwgZKgeIB2AEMAVABTAF8ATgBl
# AHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAEQAQwBf
# AE4AZQB0AHcAbwByAGsAQQBkAGEAcAB0AGUAcgBzAC0AQwBvAG0AcABvAG4AZQBu
# AHQALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEF
# AASCAQBA8710/Ozo/UhPIsAirnREVTcXvLrd48YBg2yf+HvWDbol/KIQtqO9G6R3
# oigxcgG9AQgbINratwvEbZLkAHNgJdym3QxBkUI+i/YpGpQahH5JMXlnjSFdesxz
# +NQGrXZ1tUdURM1JN2m5zkhnptKCOfioo3+fhLMRS4LCuOoDElYxM1HYQ4G4c4N1
# PWvZobhvYfnnW6+7um/N+cayU66k9alN844m7Qx5+Wm1e2GE3tMxhOi3FerM4SLx
# 5mDdulQzFYUXCNVVtOMVXy8Twr0OR/hnoLjnRRUP1ucK6Y5tj8vposaKg6LFjxKD
# GKkS1K2eGwPaLREb/3DiZXl1mPgSoYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIR
# AgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAAFrtL/TkIJk/OgAA
# AAAAWjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkq
# hkiG9w0BCQUxDxcNMTQxMDIwMTgwODMyWjAjBgkqhkiG9w0BCQQxFgQUkbjceSCq
# YGQ6ShsIAnCcWSrNh8IwDQYJKoZIhvcNAQEFBQAEggEAWsiw7qM/Z6ilgabzZifY
# SWhqcFXrwGzQRFaFdPFpjm/elQsw4OGHFdHJXiq8kLZXMuRsSBk9NZqLbjl7p9XO
# f4bpaPwr/uszUZR1lvSeji6jlNftBScy/DCXFPKH4zOvpv6ALFkq+kqhF6dsaiZ5
# EAhz73wQ/e2m/LEuEl8mdrUDhsGwOd+VUbs41irmWR1O4r4UZZYEqv+KDfpH3LA2
# 2xjaeGu/BM1+0/C2okqq+kF1TQhKC/fufTM0lfNCVECo/YKTqUVhJpLh6tReKJRL
# i7crgtJ3UjYpGKJ6YydF7Ve3yvtOwgK4rpU4FgP9nyFv+fuhgM1IjJfR94uefjOi
# bA==
# SIG # End signature block
