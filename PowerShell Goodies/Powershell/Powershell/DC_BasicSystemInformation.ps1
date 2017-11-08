PARAM($MachineName=$null)

if ($MachineName -ne $Null) {
	$AddToHeader = "$MachineName - "
	if ($ComputerName -eq $MachineName)
	{
		$MachineName = "."
	}
} else {
	$AddToHeader = ""
	$MachineName = "."
}

Import-LocalizedData -BindingVariable DC_Strings

Write-DiagProgress -activity $DC_Strings.ID_CollectActivity -status ($AddToHeader + $DC_Strings.ID_CollectingData)

$OS_Summary = new-object PSObject                  # Operating System Summary
$CS_Summary = new-object PSObject                  # Computer System Summary

$WMIOS = $null

$error.Clear()

$WMIOS = get-wmiobject -class "win32_operatingsystem" -ComputerName $MachineName -ErrorAction SilentlyContinue

if ($Error.Count -ne 0) {
	$errorMessage = $Error[0].Exception.Message
	$errorCode = "0x{0:X}" -f $Error[0].Exception.ErrorCode
	"Error" +  $errorCode + ": $errorMessage connecting to $MachineName" | WriteTo-StdOut
	$Error.Clear()
}

# Get all data from WMI

if ($WMIOS -ne $null) { #if WMIOS is null - means connection failed. Abort script execution.

	$WMICS = get-wmiobject -Class "win32_computersystem" -ComputerName $MachineName
	$WMIProcessor = get-wmiobject -Class "Win32_processor" -ComputerName $MachineName

	Write-DiagProgress -activity $DC_Strings.ID_CollectActivity -status ($AddToHeader + $DC_Strings.ID_FormattingData)

	$OSProcessorArch = $WMIOS.OSArchitecture
	$OSProcessorArchDisplay = " " + $OSProcessorArch
	#There is no easy way to detect the OS Architecture on pre-Windows Vista Platform
	if ($OSProcessorArch -eq $null)
	{
		if ($MachineName -eq ".") { #Local Computer
			$OSProcessorArch = $Env:PROCESSOR_ARCHITECTURE
		} else {
			$RemoteReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine",$MachineName)
			$OSProcessorArch = ($RemoteReg.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment")).GetValue("PROCESSOR_ARCHITECTURE")
		}

		if ($OSProcessorArch -ne $null) {
			switch ($OSProcessorArch) {
				"AMD64" {$ProcessorArchDisplay = " (64-bit)"}
				"i386" {$ProcessorArchDisplay = " (32-bit)"}
				"IA64" {$ProcessorArchDisplay = " (64-bit - Itanium)"}
				default {$ProcessorArchDisplay = " ($ProcessorArch)"}
			}
		} else {
			$OSProcessorArchDisplay = ""
		}
	}


	# Build OS Summary
	# Name
	add-member -inputobject $OS_Summary -membertype noteproperty -name "Machine Name" -value $WMIOS.CSName
	add-member -inputobject $OS_Summary -membertype noteproperty -name "OS Name" -value ($WMIOS.Caption + " Service Pack " + $WMIOS.ServicePackMajorVersion + $OSProcessorArchDisplay)
	add-member -inputobject $OS_Summary -membertype noteproperty -name "Build" -value ($WMIOS.Version)
	add-member -inputobject $OS_Summary -membertype noteproperty -name "Time Zone/Offset" -value (Replace-XMLChars -RAWString ((Get-WmiObject -Class Win32_TimeZone).Caption + "/" + $WMIOS.CurrentTimeZone))

	# Install Date
	#$date = [DateTime]::ParseExact($wmios.InstallDate.Substring(0, 8), "yyyyMdd", $null)
	#add-member -inputobject $OS_Summary -membertype noteproperty -name "Install Date" -value $date.ToShortDateString()
	add-member -inputobject $OS_Summary -membertype noteproperty -name "Last Reboot/Uptime" -value ($WMIOS.ConvertToDateTime($WMIOS.LastBootUpTime).ToString() + " (" + (GetAgeDescription(New-TimeSpan $WMIOS.ConvertToDateTime($WMIOS.LastBootUpTime))) + ")")
	
	# Build Computer System Summary
	# Name
	add-member -inputobject $CS_Summary -membertype noteproperty -name "Computer Model" -value ($WMICS.Manufacturer + ' ' + $WMICS.model)
	
	$numProcs=0
	$ProcessorType = ""
	$ProcessorName = ""
	$ProcessorDisplayName= ""

	foreach ($WMIProc in $WMIProcessor) 
	{
		$ProcessorType = $WMIProc.manufacturer
		switch ($WMIProc.NumberOfCores) 
		{
			1 {$numberOfCores = "single core"}
			2 {$numberOfCores = "dual core"}
			4 {$numberOfCores = "quad core"}
			$null {$numberOfCores = "single core"}
			default { $numberOfCores = $WMIProc.NumberOfCores.ToString() + " core" } 
		}
		
		switch ($WMIProc.Architecture)
		{
			0 {$CpuArchitecture = "x86"}
			1 {$CpuArchitecture = "MIPS"}
			2 {$CpuArchitecture = "Alpha"}
			3 {$CpuArchitecture = "PowerPC"}
			6 {$CpuArchitecture = "Itanium"}
			9 {$CpuArchitecture = "x64"}
		}
		
		if ($ProcessorDisplayName.Length -eq 0)
		{
			$ProcessorDisplayName = " " + $numberOfCores + " $CpuArchitecture processor " + $WMIProc.name
		} else {
			if ($ProcessorName -ne $WMIProc.name) 
			{
				$ProcessorDisplayName += "/ " + " " + $numberOfCores + " $CpuArchitecture processor " + $WMIProc.name
			}
		}
		$numProcs += 1
		$ProcessorName = $WMIProc.name
	}
	$ProcessorDisplayName = "$numProcs" + $ProcessorDisplayName
	
	add-member -inputobject $CS_Summary -membertype noteproperty -name "Processor(s)" -value $ProcessorDisplayName
	
	if ($WMICS.Domain -ne $null) {
		add-member -inputobject $CS_Summary -membertype noteproperty -name "Machine Domain" -value $WMICS.Domain
	}
	
	if ($WMICS.DomainRole -ne $null) {
		switch ($WMICS.DomainRole) {
			0 {$RoleDisplay = "Workstation"}
			1 {$RoleDisplay = "Member Workstation"}
			2 {$RoleDisplay = "Standalone Server"}
			3 {$RoleDisplay = "Member Server"}
			4 {$RoleDisplay = "Backup Domain Controller"}
			5 {$RoleDisplay = "Primary Domain controller"}
		}
		add-member -inputobject $CS_Summary -membertype noteproperty -name "Role" -value $RoleDisplay
	}
	
	if ($WMIOS.ProductType -eq 1) { #Client
		$AntivirusProductWMI = get-wmiobject -query "select companyName, displayName, versionNumber, productUptoDate, onAccessScanningEnabled FROM AntivirusProduct" -Namespace "root\SecurityCenter" -ComputerName $MachineName
		if ($AntivirusProductWMI.displayName -ne $null) {
			$AntivirusDisplay= $AntivirusProductWMI.companyName + " " + $AntivirusProductWMI.displayName + " version " + $AntivirusProductWMI.versionNumber
			if ($AntivirusProductWMI.onAccessScanningEnabled) {
				$AVScanEnabled = "Enabled"
			} else {
				$AVScanEnabled = "Disabled"
			}
			if ($AntivirusProductWMI.productUptoDate) {
				$AVUpToDate = "Yes"
			} else {
				$AVUpToDate = "No"
			}
			#$AntivirusStatus = "OnAccess Scan: $AVScanEnabled" + ". Up to date: $AVUpToDate" 
	
			add-member -inputobject $OS_Summary -membertype noteproperty -name "Anti Malware" -value $AntivirusDisplay
		} else {
			$AntivirusProductWMI = get-wmiobject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $MachineName
			if ($AntivirusProductWMI -ne $null) 
			{	
				$X = 0
				$Antivirus = @()
				$AntivirusProductWMI | ForEach-Object -Process {
					$ProductVersion = $null
					if ($_.pathToSignedProductExe -ne $null)
					{
						$AVPath = [System.Environment]::ExpandEnvironmentVariables($_.pathToSignedProductExe)
						if (($AVPath -ne $null) -and (Test-Path $AVPath))
						{
							$VersionInfo = (Get-ItemProperty $AVPath).VersionInfo
							if ($VersionInfo -ne $null)
							{
								$ProductVersion = " version " + $VersionInfo.ProductVersion.ToString()
							}
						}
					}
					
					$Antivirus += "$($_.displayName) $ProductVersion"
				}
				if ($Antivirus.Count -gt 0)
				{
					add-member -inputobject $OS_Summary -membertype noteproperty -name "Anti Malware" -value ([string]::Join('<br/>', $Antivirus))
				}
			}
		}
	}
	
	if ($MachineName -eq ".") { #Local Computer
		$SystemPolicies = get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
		$EnableLUA = $SystemPolicies.EnableLUA
		$ConsentPromptBehaviorAdmin = $SystemPolicies.ConsentPromptBehaviorAdmin
	} else {
		$RemoteReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine",$MachineName)
		$EnableLUA  = ($RemoteReg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System")).GetValue("EnableLUA")
		$ConsentPromptBehaviorAdmin = ($RemoteReg.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System")).GetValue("ConsentPromptBehaviorAdmin")
	}
	
	if ($EnableLUA) {
		$UACDisplay = "Enabled"
	
		switch ($ConsentPromptBehaviorAdmin) {
			0 {$UACDisplay += " / " + $DC_Strings.ID_UACAdminMode + ": " + $DC_Strings.ID_UACNoPrompt}
			1 {$UACDisplay += " / " + $DC_Strings.ID_UACAdminMode + ": " + $DC_Strings.ID_UACPromptCredentials}
			2 {$UACDisplay += " / " + $DC_Strings.ID_UACAdminMode + ": " + $DC_Strings.ID_UACPromptConsent}
			5 {$UACDisplay += " / " + $DC_Strings.ID_UACAdminMode + ": " + $DC_Strings.ID_UACPromptConsentApp}
		}
	} else {
		$UACDisplay = "Disabled"
	}
	
	add-member -inputobject $OS_Summary -membertype noteproperty -name $DC_Strings.ID_UAC -value $UACDisplay
	
	if ($MachineName -eq ".") { #Local Computer only. Will not retrieve username from remote computers
		add-member -inputobject $OS_Summary -membertype noteproperty -name "Username" -value ($Env:USERDOMAIN + "\" + $Env:USERNAME)
	}
	
	#System Center Advisor Information
	$SCAKey = "HKLM:\SOFTWARE\Microsoft\SystemCenterAdvisor"
	if (Test-Path($SCAKey))
	{
		$CustomerID = (Get-ItemProperty -Path $SCAKey).CustomerID
		if ($CustomerID -ne $null)
		{
			"System Center Advisor detected. Customer ID: $CustomerID" | writeto-stdout
			$SCA_Summary = New-Object PSObject
			$SCA_Summary | add-member -membertype noteproperty -name "Customer ID" -value $CustomerID
			$SCA_Summary | ConvertTo-Xml2 | update-diagreport -id ("01_SCACustomerSummary") -name "System Center Advisor" -verbosity Informational
		}		
	}

	Add-Member -InputObject $CS_Summary -MemberType NoteProperty -name "RAM (physical)" -value (FormatBytes -bytes $WMICS.TotalPhysicalMemory -precision 1)
	
	$OS_Summary | convertto-xml2 | update-diagreport -id ("00_OSSummary") -name ($AddToHeader + "Operating System")  -verbosity informational
	$CS_Summary | convertto-xml | update-diagreport -id ("01_CSSummary") -name ($AddToHeader + "Computer System") -verbosity informational
	
}

# SIG # Begin signature block
# MIIa/gYJKoZIhvcNAQcCoIIa7zCCGusCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIcH/NLRAGhn/t2os1CDg/mwV
# gm+gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBOYwggTi
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggf8wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKyi
# 3aQUCtFbT8gIshCRbfRBh53EMIGeBgorBgEEAYI3AgEMMYGPMIGMoHKAcABDAFQA
# UwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwA
# XwBEAEMAXwBCAGEAcwBpAGMAUwB5AHMAdABlAG0ASQBuAGYAbwByAG0AYQB0AGkA
# bwBuAC4AcABzADGhFoAUaHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAH6HRbIqlpNZM55BEbYu5+X9xCehoq0EdyaDu7FPXo/I/8ux2UPnIKZ95
# fBSVhCXXGl/SoKhARoYTBh05bBMX888v1+UnW/n53alloyS+pF203WF/jSQDbag+
# 0jTZ7xvT/9EK/zz73ftk9lAoI7U6EGekXYwkRuW2lPESvTSYUTr9fqI41DrIQ5T6
# YYn8LnAWhgGTE3YLwUXfCacQTNXQRBcwtRdvCVowM4ufWtq5ehSjZFDg8ZafW6Jc
# hPG8buogz5tVWEq9Ld8CNPKIZVHOl6OUSzTf9zOnE7r7yfCYhjxcoEjrE58t7nX5
# a9zEHTMTgF9E1b3/cH+puMdJkQa2wKGCAigwggIkBgkqhkiG9w0BCQYxggIVMIIC
# EQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsA
# AAAAAEwwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE0MTAyMDE4MDgzMFowIwYJKoZIhvcNAQkEMRYEFO6Vun7n
# V8uRrksGWvcAI5VyI+2oMA0GCSqGSIb3DQEBBQUABIIBAIiY2EpKXqWYY3hkNQ3C
# lJ6ZUJ69FZ6lqYMMIimj2OQeYfAMPVjTL4pZm+g7vRJrghqlDyf1+e81WjPbumS2
# sONo4GbAbiJNs3SWWxIwSdvZkpdQj2mmfJkjUnJZ04smqP8AhayoONqTZP/Rz9QZ
# AjkxCrYxs5ejE4OkqjLg+ugLjZWzBDf79Fo+Oo3ibc+5pMsT4ofA1YVALu7tS9H9
# Xajq8dwXT3/BftkNszNm9vvqNLv6LeYT8f9a37ILN10p9ttsfvduc/6sFuMjQiKB
# +9bBDcwv6y7kCX5cGiHx8v1wPor82M+1FtfHNKtSsmUSHmDsQh7kMAUPARflBB5L
# Jrw=
# SIG # End signature block
