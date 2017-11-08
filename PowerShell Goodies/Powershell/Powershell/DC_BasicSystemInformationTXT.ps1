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

# Write-DiagProgress -activity $DC_Strings.ID_CollectActivity -status ($AddToHeader + $DC_Strings.ID_CollectingData)

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

	# Write-DiagProgress -activity $DC_Strings.ID_CollectActivity -status ($AddToHeader + $DC_Strings.ID_FormattingData)

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
			# $SCA_Summary | ConvertTo-Xml2 | update-diagreport -id ("01_SCACustomerSummary") -name "System Center Advisor" -verbosity Informational
		}		
	}

	Add-Member -InputObject $CS_Summary -MemberType NoteProperty -name "RAM (physical)" -value (FormatBytes -bytes $WMICS.TotalPhysicalMemory -precision 1)
	

	$OutputFile = $Computername + "_BasicSystemInfo.TXT"
	$sectionDescription = "Basic System Info TXT output"
	$OS_Summary | Out-File -FilePath $OutputFile -append
	$CS_Summary | Out-File -FilePath $OutputFile -append

    CollectFiles -filesToCollect $OutputFile -fileDescription "Basic System Information" -SectionDescription $sectionDescription

}

# SIG # Begin signature block
# MIIa/QYJKoZIhvcNAQcCoIIa7jCCGuoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHIdH815ab52Ar2RC1GZmpXQ8
# yrigghV6MIIEuzCCA6OgAwIBAgITMwAAAFnWc81RjvAixQAAAAAAWTANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTtMIIE6QIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIIBBTAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKz8NYv/paVlw
# qcqHjM1x3pkU3V4wgaQGCisGAQQBgjcCAQwxgZUwgZKgeIB2AEMAVABTAF8ATgBl
# AHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAEQAQwBf
# AEIAYQBzAGkAYwBTAHkAcwB0AGUAbQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AVABY
# AFQALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEF
# AASCAQAPNEOwg7mruQtoOA2AQ8GMfkgovFSx+hUs5jCaVBuxPUpla6bFdT5lHAZE
# 1whq5R+vBKihNlYq1tmOq9nw6ZQ6c9FqNGEMb3Bi9N1oCwuYRLWdQQ9CWj/grobS
# BzS61PuXG/Mb7mt5E6hRBOHhcBt91Dbd0tkokCR+LofhnEaxiey+1wL5DdumiKdP
# 2dfUKyCRxGjY1jNvmOjz59/UJ0CUQBaomANZifrajD5cyFqrj0+lUjoIRmV05ffc
# VbNKJzv/m++QXzUlGyyJTPdS+deqMEVYfrY65eWJRjqblHvMfo2KNzZhiBWEsstY
# RVfVQWzFJ3PJQWcEwT+fF8Rt8ToeoYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIR
# AgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAAFnWc81RjvAixQAA
# AAAAWTAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkq
# hkiG9w0BCQUxDxcNMTQxMDIwMTgwODI5WjAjBgkqhkiG9w0BCQQxFgQUwygyq8AP
# +mFetHkmZ0ThRWX+Pr0wDQYJKoZIhvcNAQEFBQAEggEAdJVbcTFVA6KWDM6aaSAs
# ADYahO/DxymndHMzsmApsdiNbpKKPz1eTLdieoWAom60Lzelfgnu09dxo6xxhh6w
# ip9XSJRLBLgdduxMFS/PJWgeJdnPs3C4/oIy/siUAHBTT9ANWa5BeMCqW/rMvf80
# sgfqA/eBa02l1WuxaecAiTgw6hnIOMLvkxP8KZyrkjVqoSsRIEOzcXG/ZHxQNT/c
# 8Awjqxz8qmaFEhfCXFY4Cxc9WtDIvvm0ufKHWGzymm18IgCD2288dccVmnJUo+1P
# Xm0gzNYwt3Q5MqCcUriZTUuzOI0XzagFvtb18G4Z53HX2gsoc4QLjgBSysfwrYIP
# 8Q==
# SIG # End signature block
