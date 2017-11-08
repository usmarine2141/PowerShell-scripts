#************************************************
# TS_SurfacePro3DetectConnectedStandbyHibernationConfig.ps1
# Version 1.0.09.19.14: Created and tested SurfacePro3 scripts from Sep12-19
# Date: 2014
# Author: bbenson
# Description: SurfacePro3DetectConnectedStandbyHibernationConfig
#
# Rule GUID: 03F8CAD0-6D61-4501-AA1F-ACAECC18411C
#
# Files:
# TS_SurfacePro3DetectConnectedStandbyConfig.ps1
# RC_SurfacePro3DetectConnectedStandbyConfig.xml
# Include.xml
#
# Output Files:
# none
#
#
# Called from: Networking and Setup Diagnostics
#************************************************

Import-LocalizedData -BindingVariable RegKeyCheck
Write-DiagProgress -Activity $RegKeyCheck.ID_SurfacePro3DetectConnectedStandbyHibernationConfig -Status $RegKeyCheck.ID_SurfacePro3DetectConnectedStandbyHibernationConfigDesc


$RootCauseDetected = $false
$HasIssue = $false
$RootCauseName = "RC_SurfacePro3DetectConnectedStandbyHibernationConfig"
#$PublicContent Title: ""
#$PublicContent = ""
#InternalContent Title: "Surface Pro 3 does not hibernate after 4 hours in connected standby"
$InternalContent = "https://vkbexternal.partners.extranet.microsoft.com/VKBWebService/ViewContent.aspx?scid=KB;EN-US;2998588"
$Verbosity = "Error"
$Visibility = "3"
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
	if ($bn -ge 9600)
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
	"[info] W8.1 or later AND SurfacePro3" | WriteTo-Stdout
	#
	# Connected Standby Battery Saver Timeout
	#
	#HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\7398e821-3937-4469-b07b-33eb785aaca1
	$regkeyCsBsTimeout = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\7398e821-3937-4469-b07b-33eb785aaca1"
	If (test-path $regkeyCsBsTimeout)
	{
		$regvalueCsBsTimeoutACSettingIndexRecommended = 14400
		$regvalueCsBsTimeoutACSettingIndex = Get-ItemProperty -path $regkeyCsBsTimeout -name "ACSettingIndex" -ErrorAction SilentlyContinue	
		if ($regvalueCsBsTimeoutACSettingIndex -ne $null)
		{
			$regvalueCsBsTimeoutACSettingIndex = $regvalueCsBsTimeoutACSettingIndex.ACSettingIndex
			if ($regvalueCsBsTimeoutACSettingIndex -ne 14400)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: ACSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBsTimeoutACSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: ACSettingIndex (Recommended Setting)" -value $regvalueCsBsTimeoutACSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: ACSettingIndex (No Action Needed)" -value $regvalueCsBsTimeoutACSettingIndexRecommended	
			}
		}
		
		$regvalueCsBsTimeoutDCSettingIndexRecommended = 14400
		$regvalueCsBsTimeoutDCSettingIndex = Get-ItemProperty -path $regkeyCsBsTimeout -name "DCSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsTimeoutDCSettingIndex -ne $null)
		{
			$regvalueCsBsTimeoutDCSettingIndex = $regvalueCsBsTimeoutDCSettingIndex.DCSettingIndex
			if ($regvalueCsBsTimeoutDCSettingIndex -ne 14400)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: DCSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBsTimeoutDCSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: DCSettingIndex (Recommended Setting)" -value $regvalueCsBsTimeoutDCSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Timeout: DCSettingIndex (No Action Needed)" -value $regvalueCsBsTimeoutDCSettingIndex	
			}
		}
	}

	#
	# Connected Standby Battery Saver Trip Point
	#
	#HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\1e133d45-a325-48da-8769-14ae6dc1170b
	$regkeyCsBsTripPoint = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\1e133d45-a325-48da-8769-14ae6dc1170b"
	If (test-path $regkeyCsBsTripPoint)
	{
		$regvalueCsBstpACSettingIndexRecommended = 100
		$regvalueCsBstpACSettingIndex = Get-ItemProperty -path $regkeyCsBsTripPoint -name "ACSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBstpACSettingIndex -ne $null)	
		{
			$regvalueCsBstpACSettingIndex = $regvalueCsBstpACSettingIndex.ACSettingIndex
			if ($regvalueCsBstpACSettingIndex -ne 100)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: ACSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBstpACSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: ACSettingIndex (Recommended Setting)" -value $regvalueCsBstpACSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: ACSettingIndex (No Action Needed)" -value $regvalueCsBstpACSettingIndex				
			}
		}

		$regvalueCsBstpDCSettingIndex = Get-ItemProperty -path $regkeyCsBsTripPoint -name "DCSettingIndex" -ErrorAction SilentlyContinue	
		if ($regvalueCsBstpDCSettingIndex -ne $null)	
		{
			$regvalueCsBstpDCSettingIndex = $regvalueCsBstpDCSettingIndex.DCSettingIndex
			$regvalueCsBstpDCSettingIndexRecommended = 100
			if ($regvalueCsBstpDCSettingIndex -ne 100)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: DCSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBstpDCSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: DCSettingIndex (Recommended Setting)" -value $regvalueCsBstpDCSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Trip Point: DCSettingIndex (No Action Needed)" -value $regvalueCsBstpDCSettingIndex				
			}
		}
	}
	
	#
	# Connected Standby Battery Saver Action
	#
	# HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\c10ce532-2eb1-4b3c-b3fe-374623cdcf07
	$regkeyCsBsAction = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\c10ce532-2eb1-4b3c-b3fe-374623cdcf07"
	If (test-path $regkeyCsBsAction)
	{
		$regvalueCsBsActionACSettingIndex = Get-ItemProperty -path $regkeyCsBsAction -name "ACSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsActionACSettingIndex -ne $null)
		{
			$regvalueCsBsActionACSettingIndex = $regvalueCsBsActionACSettingIndex.ACSettingIndex
			$regvalueCsBsActionACSettingIndexRecommended = 1
			if ($regvalueCsBsActionACSettingIndex -ne 1)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: ACSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBsActionACSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: ACSettingIndex (Recommended Setting)" -value $regvalueCsBsActionACSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: ACSettingIndex (No Action Needed)" -value $regvalueCsBsActionACSettingIndex
			}
		}
		
		$regvalueCsBsActionDCSettingIndex = Get-ItemProperty -path $regkeyCsBsAction -name "DCSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsActionDCSettingIndex -ne $null)
		{
			$regvalueCsBsActionDCSettingIndex = $regvalueCsBsActionDCSettingIndex.DCSettingIndex
			$regvalueCsBsActionDCSettingIndexRecommended = 1
			if ($regvalueCsBsActionDCSettingIndex -ne 1)
			{
				$RootCauseDetected = $true
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: DCSettingIndex (Current Setting Not Optimal)" -value $regvalueCsBsActionDCSettingIndex
				#add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: DCSettingIndex (Recommended Setting)" -value $regvalueCsBsActionDCSettingIndexRecommended
			}
			else
			{
				add-member -inputobject $InformationCollected -membertype noteproperty -name "Connected Standby Battery Saver Action: DCSettingIndex (No Action Needed)" -value $regvalueCsBsActionDCSettingIndex
			}
		}
	}



	if ($RootCauseDetected -eq $true)
	{
		# Completing the Root Cause
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName  -InternalContentURL $InternalContent -Verbosity $Verbosity -InformationCollected $InformationCollected -Visibility $Visibility -SupportTopicsID $SupportTopicsID -MessageVersion 1
		# -PublicContentURL $PublicContent
	}
	else
	{
		Update-DiagRootCause -id $RootCauseName -Detected $false
	}
}




# SIG # Begin signature block
# MIIbOQYJKoZIhvcNAQcCoIIbKjCCGyYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHq30MHyKLaR3QwHYG0pWKUK4
# BJygghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBSEwggUd
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCgggE5MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTi
# xSkygXM7HYS6hD9b+lKhAisDxTCB2AYKKwYBBAGCNwIBDDGByTCBxqCBq4CBqABD
# AFQAUwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBh
# AGwAXwBUAFMAXwBTAHUAcgBmAGEAYwBlAFAAcgBvADMARABlAHQAZQBjAHQAQwBv
# AG4AbgBlAGMAdABlAGQAUwB0AGEAbgBkAGIAeQBIAGkAYgBlAHIAbgBhAHQAaQBv
# AG4AQwBvAG4AZgBpAGcALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBcn3VBzDaK7cvAOVRapsm7a/1rjs1PeDjhtN15yPol
# 5fd8IyG+ea64eeu2GKTuxfv4Bl+zgaeqSEKXrflSt+QbYd1qJOlQqCdLIG1dk2tS
# BxVw7FdbzOUomh/hRmnAJQlZFyjUPL3kB52ID8xT9C/94F4GJsDTf9TfKpCW/eZT
# OLIUbQiujRwmiuMCRc7QxycIHeUoQS5960nv+0K9yi1n5ICOjNX8khK1Vhu4lPdv
# djsT9Ney3qdGix2QRd0KSN66aQJj0vcgDJGWUcaI5wM04bvBJY+pX09FtSkpsjeG
# RHnF71nIRDyuEggFOzPsXSVIph6YFtASrQjMDfEOKUApoYICKDCCAiQGCSqGSIb3
# DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAA
# AEyh6E3MtHR7OwAAAAAATDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgwODQxWjAjBgkqhkiG9w0B
# CQQxFgQUaVYu4sonfqG18kZYFVYZ39ikZqMwDQYJKoZIhvcNAQEFBQAEggEAA6FJ
# jA/JuBIIOM2gYDFxI5QyD/UrkgbqvwvV0mefILN2Igi7u5Ci4nQPF1Sryg99Hraj
# 3XKTefYr0vC9hasnTk3EAIMR7+HrnnjHZp18B645cCiasLF8GHf/6w/XfFb3FodX
# wngzzP70ZOfgsBGPBPfOB3jDRkf9nc73LzfRQr4WHHXOFEL8Gh77cFtRLTRLgioF
# wXps1DjZQRfwcprxNkP+P3BckS16qKwpwzx8XSYJnb4bUQBdbaYpziwGXc8PA6gF
# PjpeBTZHPxk9wULnFs0DeH/N+RnqHJuUNJN2zqAynczsWKy4JzTXySqOnbK7Jylh
# FkY95zxuzwNN3+ntmA==
# SIG # End signature block
