#************************************************
# TS_DebugFlagsCheck.ps1
# Version 1.0.1
# Date: 02-27-2011
# Author: Andre Teixeira - andret@microsoft.com
# Description: - This script checks if any of the 'GFlags' are enabled on the system and fire an alert.
#                Version 1.0 only checks for PageHeap enabled against a process
#************************************************


Import-LocalizedData -BindingVariable ScriptVariables

Write-DiagProgress -Activity $ScriptVariables.ID_GFlags -Status $ScriptVariables.ID_GFlagsObtaining

$ImageFileExecutionRegKey = Get-Item ("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options")

$PageHeapEnabled = $false
$PageHeapProcesses = $ImageFileExecutionRegKey | Get-ChildItem | Where-Object {$_.Property -eq "PageHeapFlags"}

if ($PageHeapProcesses -ne $null)
{
	foreach ($ProcesswithPageHeapEnabled in $PageHeapProcesses)
	{
		if ($ProcesswithPageHeapEnabled.GetValue("PageHeapFlags") -gt 0)
		{
			$ProcessName = Split-Path ($ProcesswithPageHeapEnabled.Name) -Leaf
			$InformationCollected = @{"Process Name" = $ProcessName; "PageHeap Flags" = $ProcesswithPageHeapEnabled.GetValue("PageHeapFlags")}
			$PageHeapEnabled = $true
			Write-GenericMessage -RootCauseId "RC_PageHeapEnabled" -ProcessName $ProcessName -PublicContentURL "http://blogs.technet.com/b/askperf/archive/2007/06/29/what-a-heap-of-part-two.aspx" -InformationCollected $InformationCollected -Verbosity "Error" -Visibility 4 -SupportTopicsID 8117 -MessageVersion 2 -Component "Windows Core" 
		}
	}
}
else
{
	Update-DiagRootCause -id "RC_PageHeapEnabled" -Detected $false
}

if ($PageHeapEnabled)
{
	Update-DiagRootCause -id "RC_PageHeapEnabled" -Detected $true
}


#Rule ID 603
#-----------
#http://sharepoint/sites/rules/_layouts/listform.aspx?PageType=4&ListId={9318793E-073A-415E-8FF5-C433133C2A9E}&ID=1759&ContentTypeID=0x01008FE8F6282AC12B4DB4505EA8C2BDB8F8
#
#Description
#-----------
# Typically, an engineer will review the verifier.txt in an MSDT report to determine if driver verification is enabled for certain test types.  I suggest creating an alert in 
# UDE whenever any driver is being verified.   Anything other then none, should be alerted to an engineer.   For example: Disabled Special pool: DisabledForce IRQL checking: 
# DisabledLow resources simulation: DisabledPool tracking: DisabledI/O verification: DisabledDeadlock detection: DisabledEnhanced I/O verification: DisabledDMA checking: DisabledDisk 
# integrity checking: Disabled Verified drivers: None   Enabled Special pool: EnabledPool tracking: DisabledForce IRQL checking: DisabledI/O verification: DisabledDeadlock detection: 
# DisabledDMA checking: DisabledSecurity checks: DisabledForce pending I/O requests: DisabledLow resources simulation: DisabledIRP Logging: DisabledMiscellaneous checks: Disabled Verified 
# drivers: ataport.sys  In the alert, we should alert of the driver and the test type current being used.   Other then querying the verifiy.txt, you can also query the registry:   
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management   To enable Driver Verifier by editing the registry, follow these steps: Start Registry Editor 
# (Regedt32). Locate the following registry key: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\VerifyDriversEdit the REG_SZ key.Set the REG_SZ key 
# to the case-insensitive names of the drivers that you want to test. You can specify multiple drivers, but only use one driver. By doing so, you can make sure that available system resources 
# are not prematurely exhausted. Premature exhaustion of resources does not cause any system reliability problems, but it can cause some driver checking to be bypassed.   The following list 
# shows examples of values for the REG_SZ key: Ntfs.sysWin32k.sys ftdisk.sys*.sys 
#
#Related KB 
#----------
# 244617 
#
#Script Author
#-------------
# anecho

Write-DiagProgress -Activity $ScriptVariables.ID_Verifier -Status $ScriptVariables.ID_VerifierObtaining

$RootCauseDetected = $false
$RootCauseName = "RC_DriverVerifierEnabled"
	
#********************
#Data gathering
#********************
	$InformationCollected = new-object PSObject
	
	$keyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
	
	
	###Table of verifier values
	$verifierTable = ("Miscellaneous checks" , $false),
					   ("IRP logging", $false),
					   ("Force pending I/O requets" , $false),
					   ("Security checks" , $false),
					   ("DMA verification" , $false),
					   ("Unused" , $false),
					   ("Deadlock detection" , $false),
					   ("I/O verification" , $false),
					   ("Pool tracking" , $false),
					   ("Low resources simulation", $false),
					   ("Force irql checking" , $false),
					   ("Special pool checking" , $false)
	
		
	Function Get-RegistryValue($Name)
	{
		#
		#	.SYNOPSIS
		#		Gets a specific value from the selected key
		#	.DESCRIPTION
		#		Uses Get-ItemProperty to pull the value out of the key path defined above
		#	.NOTES
		#	.LINK
		#	.EXAMPLE
		#	.OUTPUTS
		#		PSObject
		#	.PARAMETER file
		#
		if(Test-Path $keyPath)
		{
			return Get-ItemProperty -Path $keyPath -Name $Name -ErrorAction SilentlyContinue 
		}
		else
		{
			return $null
		}
	}
	
	Function Set-VerifierFlags($verifyDriverLevel)
	{
		#
		#	.SYNOPSIS
		#		Sets the Flags for the Veifier types
		#	.DESCRIPTION
		#		Converts the decimal version of the verifyDriverLevel one bit at a time
		#	.NOTES
		#	.LINK
		#	.EXAMPLE
		#	.OUTPUTS
		#	.PARAMETER file
		#
		
		
		[int]$i = 2048
		
		foreach($verifier in $verifierTable)
		{
			if(($verifyDriverLevel-$i) -ge 0)
			{
				$verifier[1] = $true
				$verifyDriverLevel =  $verifyDriverLevel - $i
			}
			if($i -gt 1)
			{
				$i /= 2
			}
		}
		
	}
	
	Function Get-VerifyDrivers
	{
		#
		#	.SYNOPSIS
		#		Gets the values for verify drivers
		#	.DESCRIPTION
		#		Uses the Get-RegistryValue function to pull the drivers by name and saves them to global variables
		#	.NOTES
		#	.LINK
		#	.EXAMPLE
		#	.OUTPUTS
		#		PSObject
		#	.PARAMETER file
		#
		
		$Driver = Get-RegistryValue -Name "VerifyDrivers"
		if($Driver -ne $null)
		{
			$verifyDriver = $Driver.VerifyDrivers
			$verifyDriver = $verifyDriver.Replace(" ", ", ")
		}
		else
		{
			$verifyDriver = $null
		}
		
		return $verifyDriver
	}
	
	Function Get-VerifyDriverLevel
	{
		#
		#	.SYNOPSIS
		#		Gets the values for verify Driver Level
		#	.DESCRIPTION
		#		Uses the Get-RegistryValue function to pull the drivers by name 
		#	.NOTES
		#	.LINK
		#	.EXAMPLE
		#	.OUTPUTS
		#		PSObject
		#	.PARAMETER file
		#
		
		$Driver  = Get-RegistryValue -Name "VerifyDriverLevel"
		if($Driver -ne $null)
		{
			$verifyDriverLevel = $Driver.VerifyDriverLevel	
			if($verifyDriverLevel -eq 0)
			{
				$verifyDriverLevel = $null
			}
		}
		else
		{
			$verifyDriverLevel = $null
		}
		
		return $verifyDriverLevel
	}
		
#********************
#Detection Logic
#********************
		
		$HasIssue = $false 
		$verifyDriver = Get-VerifyDrivers
		$verifyDriverLevel = Get-VerifyDriverLevel	
		
		if(($verifyDriver -ne $null)-and ($verifyDriverLevel -ne $null))
		{					
			Set-VerifierFlags -verifyDriverLevel $verifyDriverLevel			
			$HasIssue = $true
		}
	
	
#********************
#Alert Evaluation
#********************

	if($HasIssue)
	{
		add-member -inputobject $InformationCollected -membertype noteproperty -name "Drivers" -value $verifyDriver
		
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[0][0] -value $verifierTable[0][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[1][0] -value $verifierTable[1][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[2][0] -value $verifierTable[2][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[3][0] -value $verifierTable[3][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[4][0] -value $verifierTable[4][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[5][0] -value $verifierTable[5][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[6][0] -value $verifierTable[6][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[7][0] -value $verifierTable[7][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[8][0] -value $verifierTable[8][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[9][0] -value $verifierTable[9][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[10][0] -value $verifierTable[10][1]
		add-member -inputobject $InformationCollected -membertype noteproperty -name $verifierTable[11][0] -value $verifierTable[11][1]
		
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL "http://support.microsoft.com/kb/244617" -Verbosity "Warning" -InformationCollected $InformationCollected  -Visibility 4 -SupportTopicsID 8117 -MessageVersion 2 -Component "Windows Core" 
		
	}
	else
	{
		Update-DiagRootCause -id $RootCauseName -Detected $false
	} 

# SIG # Begin signature block
# MIIa7wYJKoZIhvcNAQcCoIIa4DCCGtwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU10oyDQv8W0CJPE43j/dujWT8
# pS+gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNcwggTT
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFMW
# qTMT2aFBv9677hjFrMT4tNmAMIGPBgorBgEEAYI3AgEMMYGAMH6gZIBiAEMAVABT
# AF8ATgBlAHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABf
# AFQAUwBfAEQAZQBiAHUAZwBGAGwAYQBnAHMAQwBoAGUAYwBrAC4AcABzADGhFoAU
# aHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEANsI1xZG005lt
# Dws+rvide5bhY2KpBF+Vbt0yAwfixP/nwKATNizY16JAzOEYPJKrerEic3P1Rc+o
# 80PlcsnfVU/2k1w+EuLcExy2DDM0ZKzFFsfRyf7cSxmmrCMLuxCOLg2u5yoqNZkW
# DjEUkuRaxziDEDRLODD9jI2cL4a8LwdKeQdgDIvFpQPLNJd3FCR0m0Z51Q1wDMML
# yZzqBxIqqOa9kDbyhrBJMhKMpu55I+tyJ4CQpTR9wGeEeApr898H6589Iq7MscU9
# OyXRlNCf+cSR3gBX0f6AJzUu6bkvwNLYradukf9jeKvj4glDF0+SpZNHGhum5DdW
# 0z0urMdHyKGCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4DAhoF
# AKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0
# MTAyMDE4MDgzOVowIwYJKoZIhvcNAQkEMRYEFPAxF7U3hvuiduOVmq/jnlc5ck1S
# MA0GCSqGSIb3DQEBBQUABIIBACaJaQqTPqTN/ki2z66te4DsD2f9SNEu41QikZlC
# iFE8zXmbHzGWGR7k6wpJre2sDXbpXweJwh75TGqMI4dHCFRzVn1NJq//Jt23OLjZ
# YNGCjWt1eOeuLIZ6ZgIvjPDimplUdEX+k7B2wwxTmPzHB8bSffeX1qF51hlB8I4v
# ysjDdj5JTXslDOpXKpSkpYtQd1U3Qc381Qx8Ej4zHGUY+KgVfeLMHb/HIrtcv0Il
# sM2qcSJ99EF/XE2iiK0F5Bt7BqHcoY3iQLNXUs6dD6wAFM3lfMsYZbY+CFCDdMa8
# T8nJ/8AoIeFG7+jTZtQv1XEdqRLwolVKnEU0CvdcXciryF8=
# SIG # End signature block
