#************************************************
# TS_BPAInfo.ps1
# Version 1.5.6
# Date: 12-10-2010
# Author: Andre Teixeira - andret@microsoft.com
# Description: - This script is used to obtain a report from any inbox BPA Module information or other BPAs with MBCA support.
#************************************************


Param ($BPAModelID = $null, $OutputFileName, $ReportTitle, $ModuleName="BestPractices", $InvokeCommand="Invoke-BpaModel", $GetBPAModelCommand="Get-BPAModel", $GetBPAResultCommand="Get-BpaResult")

Trap [Exception]
{
	WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "TS_BPAInfo.ps1 Error, ReportTitle: $ReportTitle, BPAModelID: $BPAModelID"
	continue 
}

Function Write-ScriptProgress ($Activity = "", $Status = "") {
	if ($Activity -ne $LastActivity) {
		if (-not $TroubleShootingModuleLoaded -and ($Activity -ne "")) {
			$Activity | Out-Host
		}
		if ($Activity -ne "") {
			Set-variable -Name "LastActivity" -Value $Activity -Scope "global"
		} else {
			$Activity = $LastActivity
		}	
	}
	if ($TroubleShootingModuleLoaded) {
			Write-DiagProgress -activity $Activity -status $Status
		
	} else {
		"    [" + (Get-Date) + "] " + $Status | Out-Host
	}
}

Function SaveToHTMLFile($SourceXMLDoc, $HTMLFileName)
{
	
	$XMLFilename = $Env:TEMP + "\" + [System.IO.Path]::GetFileNameWithoutExtension($HTMLFileName) + ".XML"
	$SourceXMLDoc.Save($XMLFilename)
	
	[xml] $XSLContent = Get-Content 'BPAInfo.xsl'

	$XSLObject = New-Object System.Xml.Xsl.XslTransform
	$XSLObject.Load($XSLContent)
	$XSLObject.Transform($XMLFilename, $HTMLFilename)
    
	Remove-Item $XMLFilename
	"Output saved to $HTMLFilename" | WriteTo-StdOut -ShortFormat
}

Function AddXMLElement ([xml] $xmlDoc,
						[string] $ElementName="Item", 
						[string] $Value,
						[string] $AttributeName="name", 
						[string] $attributeValue,
						[string] $xpath="/Root")
{
	[System.Xml.XmlElement] $rootElement=$xmlDoc.SelectNodes($xpath).Item(0)
	if ($rootElement -ne $null) { 
		[System.Xml.XmlElement] $element = $xmlDoc.CreateElement($ElementName)
		if ($attributeValue.Length -ne 0) {$element.SetAttribute($AttributeName, $attributeValue)}
		if ($Value.lenght -ne 0) { 
			if ($PowerShellV2) {
				$element.innerXML = $Value
			} else {
				$element.set_InnerXml($Value)
			}
		}
		$x = $rootElement.AppendChild($element)
	} else {
		"Error. Path $xpath returned a null value. Current XML document: `n" + $xmlDoc.OuterXml
	}
}

#***********************************************
#*  Starts here
#***********************************************

if (($ModuleName -eq "BestPractices") -and ($InvokeCommand -eq "Invoke-BpaModel") -and ($OSVersion.Build -lt 7600))
{
	"Inbox BPAs Not Supported on OS Build " + $OSVersion.Build | WriteTo-StdOut
}
else
{
	if (Test-Path (Join-Path $PWD.Path 'BPAInfo.xsl'))
	{
		if ($BPAModelID -ne $null)
		{
			Import-LocalizedData -BindingVariable BPAInfo

			if ((Get-WmiObject -Class Win32_ComputerSystem).DomainRole -gt 1) 
			{ #Server

				if ((Get-Host).Name -ne "Default Host") {
					"Windows Troubleshooting Platform not loaded."
					$TroubleshootingModuleLoaded = $false
				} else {
					$TroubleshootingModuleLoaded = $true
				}
				
				Write-ScriptProgress -activity $ReportTitle -status $BPAInfo.ID_BPAStarting
				
				$PowerShellV2 = (((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine").PowerShellVersion).Substring(0,1) -ge 2)
				
				$Error.Clear()
				Import-Module $ModuleName
				
				if ($Error.Count -eq 0) 
				{
					$InstalledBPAs = Invoke-Expression "$GetBPAModelCommand"
					
					if ((($InstalledBPAs | where-object {$_.Id -eq $BPAModelID}).Id) -ne $null) 
					{
						
						Write-ScriptProgress -activity $ReportTitle -status $BPAInfo.ID_BPARunning	
						
						$BPAResults = Invoke-Expression "$InvokeCommand $BPAModelID"
						
						if (($BPAResults | where-object {($_.ModelID -eq $BPAModelID) -and ($_.Success -eq $true)}) -ne $null) 
						{
							Write-ScriptProgress -activity $ReportTitle -status $BPAInfo.ID_BPAGenerating	
							$BPAXMLDoc = Invoke-Expression "$GetBPAResultCommand $BPAModelID | ConvertTo-XML"
							
							if ($BPAXMLDoc -ne $null) 
							{
								AddXMLElement -xmlDoc $BPAXMLDoc -ElementName "Machine" -Value $Env:COMPUTERNAME -xpath "/Objects"
								AddXMLElement -xmlDoc $BPAXMLDoc -ElementName "TimeField" -Value ($BPAResults[0].Detail).ScanTime -xpath "/Objects"
								AddXMLElement -xmlDoc $BPAXMLDoc -ElementName "ModelId" -Value ($BPAResults[0].Detail).ModelId -xpath "/Objects"
								AddXMLElement -xmlDoc $BPAXMLDoc -ElementName "ReportTitle" -Value $ReportTitle -xpath "/Objects"
								AddXMLElement -xmlDoc $BPAXMLDoc -ElementName "OutputFileName" -Value $OutputFileName -xpath "/Objects"
								
								SaveToHTMLFile -HTMLFileName $OutputFileName -SourceXMLDoc $BPAXMLDoc
								
								if ($TroubleshootingModuleLoaded) 
								{
									CollectFiles -filesToCollect $OutputFileName -fileDescription $ReportTitle -sectionDescription "Best Practices Analyzer reports"
									
									$XMLName = [System.IO.Path]::GetFileNameWithoutExtension($OutputFileName) + ".xml"
									$BPAXMLDoc.Save($XMLName)
									
									CollectFiles -filesToCollect $XMLName -fileDescription $ReportTitle -sectionDescription "Best Practices Analyzer RAW XML Files" -Verbosity "Debug"
									if ($BPAXMLDoc.SelectNodes("(//Object[(Property[@Name=`'Severity`'] = `'Warning`') or (Property[@Name=`'Severity`'] = `'Error`')])").Count -ne 0) 
									{
										$BPAXMLFile = [System.IO.Path]::GetFullPath($PWD.Path + ("\..\BPAResults.XML"))
										if (Test-Path $BPAXMLFile)
										{
											[xml] $ExistingBPAXMLDoc = Get-Content $BPAXMLFile
											AddXMLElement -xmlDoc $ExistingBPAXMLDoc -xpath "/Root" -ElementName "BPAModel" -Value $BPAXMLDoc.SelectNodes("/Objects").Item(0).InnerXML
											$ExistingBPAXMLDoc.Save($BPAXMLFile)
										} else {
											[xml] $BPAFileXMLDoc = "<Root/>"
											AddXMLElement  -xmlDoc $BPAFileXMLDoc -xpath "/Root" -ElementName "BPAModel" -Value $BPAXMLDoc.SelectNodes("/Objects").Item(0).InnerXML
											$BPAFileXMLDoc.Save($BPAXMLFile)
										}
										Update-DiagRootCause -id RC_BPAInfo -Detected $true
									}
								}
								Write-ScriptProgress -activity $ReportTitle -status "Completed."
							} else {
								"$GetBPAResultCommand did not return any result" | WriteTo-StdOut -ShortFormat
							}
						}
					
					} else {
						$Msg = "ERROR: BPA Module $BPAModelID is not installed. Follow the list of installed BPAs: `r`n"
						foreach ($BPA in $InstalledBPAs) 
						{
							$Msg += "   " + $BPA.Id + "`r`n"
						}
						$Msg | WriteTo-StdOut -ShortFormat
						
					}
				} else {
					"ERROR: Unable to load BestPractices module - $ModuleName"  | WriteTo-StdOut -ShortFormat
				}
			}
		}
		else
		{
			"ERROR: BPAModelID was not specified. BPAInfo not executed"  | WriteTo-StdOut -ShortFormat
		}
	}
	else
	{
		"ERROR: BPAInfo.xsl not found. Make sure to use <Folder source> instead of <File source>" | WriteTo-StdOut -IsError
		"ERROR: BPAInfo.xsl not found. Make sure to use <Folder source> instead of <File source>" | WriteTo-ErrorDebugReport
	}
}
# SIG # Begin signature block
# MIIa3QYJKoZIhvcNAQcCoIIazjCCGsoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpjrewhkj/leg8Nc9o8BywRPA
# 7ZmgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBMUwggTB
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggd4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOwQ
# Ly2yyqTmi8YJmkEvrzWd+fYpMH4GCisGAQQBgjcCAQwxcDBuoFSAUgBDAFQAUwBf
# AE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwAXwBU
# AFMAXwBCAFAAQQBJAG4AZgBvAC4AcABzADGhFoAUaHR0cDovL21pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAJl2Ivqx2yfIYxP9Xf1Fk9C/1KMPbmwg5HWpm
# BcOXe/W2ITpMhFgM9iWOLBN1+790fsq9Fv5bPi/mVGQJ6hCZe1Ordk94HoP9T4kD
# Pjj7QmKYiRYOYU2cr+KY82QiehKHc5P6fEEIU+3XYMl06JgMZioCCenmhbSY9Zo0
# 3eXkN6czIQvaFk5iksY6Bs7orBNJVDbb9T4hYEJKb5Tdh5ejnk0XR1RnFwgj7Z8S
# RzWc6x7APPJgtiyiomRd+25advaYijU9HOicw6kNB5fn8DAZGTpqlcLRPo0OAf3+
# GjZWfVONKRdH9NYGj1dMFV3ZJ2GnWEouGaK26esap1KEv2z2cKGCAigwggIkBgkq
# hkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EC
# EzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzEL
# BgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTAyMDE4MDgzOVowIwYJKoZI
# hvcNAQkEMRYEFM0sDC2GgKJ5+IPaydlKVpML0DWjMA0GCSqGSIb3DQEBBQUABIIB
# AKTk8eBZhQPt3gs9cjfllnBEhwH/8/RwAiyCypFcotBgCCMxA/Aa8Wo0u/efvX31
# TR8Dw6k+pGhsPl7U4fBwFM8ovUMckMPa1xLBZC+iCKUomMngNQyilIoMgd1g3kbW
# N3u3g4jzjlFEFlWNWsBsI54lO3eK59QvSHlpnH4QsE/Bzo+0SEOSOj93NRju7+pS
# 5l7rqas5mfyAw3iygHnSxeDA0UnNnAiLfaFYaq+ox+5BZSw/Lvdf6Bn1P5xaYR96
# pI0hCnYtqpr2QwrF0ezWe9VdHd+YF9hOKO9aza95LmBNS0k+dWXFDuqbeiD4u2ZP
# GfgGaFMLaWGglNu8eTUSOPo=
# SIG # End signature block
