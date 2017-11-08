#************************************************
# TS_SurfacePro3DetectFirmwareVersions.ps1
# Version 1.0.09.19.14: Created and tested SurfacePro3 scripts from Sep12-19
# Date: 2014
# Author: bbenson
# Description: SurfacePro3DetectFirmwareVersions
#
# Rule GUID: 34F6567E-7B92-4C37-B1CA-5DE6E66D4881
#
# Files:
# TS_SurfacePro3DetectFirmwareVersions.ps1
# RC_SurfacePro3DetectFirmwareVersions.xml
# Include.xml
#
# Output files:
# none
#
# Called from: Networking and Setup Diagnostics
#************************************************

Import-LocalizedData -BindingVariable RegKeyCheck
Write-DiagProgress -Activity $RegKeyCheck.ID_SurfacePro3DetectFirmwareVersions -Status $RegKeyCheck.ID_SurfacePro3DetectFirmwareVersionsDesc


$RootCauseDetected = $false
$HasIssue = $false
$RootCauseName = "RC_SurfacePro3DetectFirmwareVersions"
#$PublicContent Title: "Surface Pro 3, Surface Pro 2, and Surface Pro firmware and driver packs"
$PublicContent = "http://www.microsoft.com/en-us/download/details.aspx?id=38826"
#InternalContent Title: "2961421 - Surface: How to check firmware versions"
$InternalContent = "https://vkbexternal.partners.extranet.microsoft.com/VKBWebService/ViewContent.aspx?scid=B;EN-US;2961421"
$Verbosity = "Error"
$Visibility = "4"
$SupportTopicsID = "8041"
$InformationCollected = new-object PSObject


#********************
#Functions
#********************
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber
$sku = $((gwmi win32_operatingsystem).OperatingSystemSKU)

Function isOSVersionAffected
{
	if ($bn -eq 9600)
	 {
		return $true
	 }
	 else
	 {
		return $false
	 }
}

Function isSurfacePro3
{
	# Check for: "HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\BIOS"; SystemSKU = Surface_Pro_3
	$regkeyBIOS = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
	If (test-path $regkeyBIOS)
	{
		$regvalueSystemSKUReg = Get-ItemProperty -path $regkeyBIOS -name "SystemSKU" -ErrorAction SilentlyContinue
		$regvalueSystemSKU = $regvalueSystemSKUReg.SystemSKU
		if ($regvalueSystemSKU -eq "Surface_Pro_3")
		{
			return $true
		}
		else
		{
			return $false
		}
	}
}




#********************
#Detection Logic and Alert Evaluation
#********************
if ((isOSVersionAffected) -and (isSurfacePro3))
{
	# Using this method to detect the firmware version:
	# Check for "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FirmwareResources\{512B1F42-CCD2-403B-8118-2F54353A1226}"  Filename = "SamFirmware.3.9.350.0.cap"
	# Check for "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FirmwareResources\{52D9DA80-3D55-47E4-A9ED-D538A9B88146}"  Filename = "ECFirmware.38.6.50.0.cap"
	# Check for "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FirmwareResources\{5A2D987B-CB39-42FE-A4CF-D5D0ABAE3A08}"  Filename = "UEFI.3.10.250.0.cap"
	# Check for "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FirmwareResources\{E5FFF56F-D160-4365-9E21-22B06F6746DD}"  Filename = "TouchFirmware.426.27.66.0.cap"
	#
	# This method shows the correct driver if the driver is rolled back, but this is not needed since firmware cannot be rolled back.
	# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\UEFI\RES_{GUID}\0\Device Parameters
	#
	$regkeySamFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{512B1F42-CCD2-403B-8118-2F54353A1226}"
	If (test-path $regkeySamFirmware)
	{
		$regvalueSamFirmwareFilename = Get-ItemProperty -path $regkeySamFirmware -name "Filename" -ErrorAction SilentlyContinue
		if ($regvalueSamFirmwareFilename -ne $null)
		{
			$regvalueSamFirmwareFilename = $regvalueSamFirmwareFilename.Filename
			$regvalueSamFirmwareFileNameLatest = "SamFirmware.3.9.350.0.cap"
		}
		$regvalueSamFirmwareVersion = Get-ItemProperty -path $regkeySamFirmware -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueSamFirmwareVersion -ne $null)
		{
			add-member -inputobject $InformationCollected -membertype noteproperty -name "Surface Pro System Aggregator Firmware" -value " "
			$regvalueSamFirmwareVersion = $regvalueSamFirmwareVersion.Version
			if ($regvalueSamFirmwareVersion -lt 50922320)	# Hex 0x03090350
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "SamFirmware Installed Version" -value $regvalueSamFirmwareFileName
				add-member -inputobject $InformationCollected -membertype noteproperty -name "SamFirmware Recommended Version" -value $regvalueSamFirmwareFileNameLatest
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "SamFirmware Version: No Action Needed" -value $regvalueSamFirmwareFileName
			}
		}
	}

	$regkeyECFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{52D9DA80-3D55-47E4-A9ED-D538A9B88146}"
	If (test-path $regkeyECFirmware)
	{
		$regvalueECFirmwareFileName = Get-ItemProperty -path $regkeyECFirmware -name "Filename" -ErrorAction SilentlyContinue
		if ($regvalueECFirmwareFileName -ne $null)
		{
			$regvalueECFirmwareFileName = $regvalueECFirmwareFileName.Filename
			$regvalueECFirmwareFileNameLatest = "ECFirmware.38.6.50.0"
		}
		$regvalueECFirmwareVersion = Get-ItemProperty -path $regkeyECFirmware -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueECFirmwareVersion -ne $null)
		{
			add-member -inputobject $InformationCollected -membertype noteproperty -name "Surface Pro Embedded Controller Firmware" -value " "
			$regvalueECFirmwareVersion = $regvalueECFirmwareVersion.Version
			if ($regvalueECFirmwareVersion -lt 3671632)	# Hex 0x00380650
			{
				$RootCauseDetected  = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "ECFirmware Installed Version" -value $regvalueECFirmwareFileName
				add-member -inputobject $InformationCollected -membertype noteproperty -name "ECFirmware Recommended Version" -value $regvalueECFirmwareFileNameLatest
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "ECFirmware Version: No Action Needed" -value $regvalueECFirmwareFileName
			}
		}
	}


	$regkeyUEFI = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{5A2D987B-CB39-42FE-A4CF-D5D0ABAE3A08}"
	If (test-path $regkeyUEFI)
	{
		$regvalueUEFIFileName = Get-ItemProperty -path $regkeyUEFI -name "Filename" -ErrorAction SilentlyContinue
		if ($regvalueUEFIFileName -ne $null)
		{
			$regvalueUEFIFileName = $regvalueUEFIFileName.Filename
			$regvalueUEFIFileNameLatest = "UEFI.3.10.250.0.cap"
		}
		
		$regvalueUEFIVersion = Get-ItemProperty -path $regkeyUEFI -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueUEFIVersion -ne $null)
		{
			add-member -inputobject $InformationCollected -membertype noteproperty -name "Surface Pro UEFI" -value " "
			$regvalueUEFIVersion  = $regvalueUEFIVersion.Version
			if ($regvalueUEFIVersion -lt 50987258)	# Hex 0x030a00fa
			{
				$RootCauseDetected  = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "UEFI Installed Version" -value $regvalueUEFIFileName
				add-member -inputobject $InformationCollected -membertype noteproperty -name "UEFI Recommended Version" -value $regvalueUEFIFileNameLatest
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "UEFI Version: No Action Needed" -value $regvalueUEFIFileName
			}
		}
	}


	$regkeyTouchFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{E5FFF56F-D160-4365-9E21-22B06F6746DD}"
	If (test-path $regkeyTouchFirmware)
	{
		$regvalueTouchFirmwareFileName = Get-ItemProperty -path $regkeyTouchFirmware -name "Filename" -ErrorAction SilentlyContinue
		if ($regvalueTouchFirmwareFileName -ne $null)
		{
			$regvalueTouchFirmwareFileName = $regvalueTouchFirmwareFileName.Filename
			$regvalueTouchFirmwareFileNameLatest = "TouchFirmware.426.27.66.0"
		}
		$regvalueTouchFirmwareVersion = Get-ItemProperty -path $regkeyTouchFirmware -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueTouchFirmwareVersion -ne $null)
		{
			add-member -inputobject $InformationCollected -membertype noteproperty -name "Surface Pro Touch Controller Firmware" -value " "
			$regvalueTouchFirmwareVersion  = $regvalueTouchFirmwareVersion.Version
			if ($regvalueTouchFirmwareVersion -lt 27925314)	# Hex 0x01aa1b42
			{
				$RootCauseDetected  = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "TouchFirmware Installed Version:" -value $regvalueTouchFirmwareFileName
				add-member -inputobject $InformationCollected -membertype noteproperty -name "TouchFirmware Recommended Version" -value $regvalueTouchFirmwareFileNameLatest
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "TouchFirmware Version: No Action Needed" -value $regvalueTouchFirmwareFileName
			}
		}
	}

	if ($RootCauseDetected -eq $true)
	{
		"[info] RootCauseDetected: Completing RootCause" | WriteTo-StdOut
		# Completing the Root Cause
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL $PublicContent -InternalContentURL $InternalContent -Verbosity $Verbosity -InformationCollected $InformationCollected -Visibility $Visibility -SupportTopicsID $SupportTopicsID -MessageVersion 1
	}
	else
	{
		Update-DiagRootCause -id $RootCauseName -Detected $false
	}
}








# SIG # Begin signature block
# MIIbDwYJKoZIhvcNAQcCoIIbADCCGvwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5p2tC0gEMAwisIYUWG4RCJLb
# eaWgghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggT/MIIE+wIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIIBFzAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUM0qgPJMkZXCQ
# UJUeIU2QlKdxy4cwgbYGCisGAQQBgjcCAQwxgacwgaSggYmAgYYAQwBUAFMAXwBO
# AGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8AVABT
# AF8AUwB1AHIAZgBhAGMAZQBQAHIAbwAzAEQAZQB0AGUAYwB0AEYAaQByAG0AdwBh
# AHIAZQBWAGUAcgBzAGkAbwBuAHMALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0
# LmNvbTANBgkqhkiG9w0BAQEFAASCAQB2pmuC+gYQWxTd9t23eTfQIuJ1wftoLKi8
# F4UDh7yivo0enT9yF+rniAJ5wD/zj66E2kMJj6LwT8+O8S7QDu4rgL6rKb0eZAxf
# UqvZUHlr7mpEwFwgkP77q2MsbSt9EopKFOpubBAd2rLARMFxlmX3wKXd1q5hNqtU
# Wj3gr7LZrCo/FObPfSYw9W2Ty+JsCPju6zwhluXZWp0wjsT20emAY/1g5Gvjb6uS
# kRZ6xo+8n2aRewlCHVk9NWRxTQQZIvyGAiDrVfGZtTAsV0zRdONVaf1KLvNmHhZe
# PgU2EC16dkUEZE9QeBchEwvMRCA+ENxILFW9eJhM+Y3IckedPx7FoYICKDCCAiQG
# CSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QQITMwAAAFrtL/TkIJk/OgAAAAAAWjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgwODQwWjAjBgkq
# hkiG9w0BCQQxFgQUz5ND8S3tV6XHw510QDEbCDFRMjgwDQYJKoZIhvcNAQEFBQAE
# ggEAN3vSB06ytvdbAof3Rdy9ETb3rs8mscvtAt+zWkv7YK170SLJz1lCfypCyoGJ
# rp9m5NnQvn/N7TB9K09QLK2JHooKItkGu0gwao1Jgp9v75dPCUFVdgwP5TYvzDRK
# Mv4TfVlHei/8FfwW8qW2Xlpx7F3wu6cf2eM1e5nL8frrDZ7Cz68z/2nsYDTZtgFV
# N/+zpN38xtk0T1WBe3eYP9NrA/bBKpqaNIqsvk7C001SrJ0KTaxrv1SWBX0ecB/r
# npMpZUMBnQ/ln0aRVnmJRBz+QKgeI7ToBulF44nzgDJEuBwvWrDcpr4P9L+VIBjA
# tPWAoi5TSkn+6cderWcQ2OVNtQ==
# SIG # End signature block
