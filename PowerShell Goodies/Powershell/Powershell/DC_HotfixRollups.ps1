﻿#************************************************
# DC_HotfixRollups.ps1
# Version 1.0.04.02.14: Created script to easily view what rollups are installed for W7/WS2008R2, W8/WS2012, and W8.1/WS2012R2
# Version 1.1.05.16.14: Added W8.1 Update1 (April2014 rollup);  Added OS Version below each heading.
# Version 1.2.05.19.14: Added May2014 updates for W8/W8.1
# Version 1.3.07.23.14: Added June and July, 2014
# Version 1.4.08.13.14: Added Aug2014 updates for W8/W8.1
# Version 1.5.09.17.14: Added Sep2014 updates for W8/W8.1
# Version 1.6.10.16.14: Added Oct2014 updates for W8/W8.1
# Date: 2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Creates output to easily identify what rollups are installed on W7/WS2008R2 and later.
# Called from: Networking Diagnostics
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

$OutputFile = $ComputerName + "_HotfixRollups.TXT"
$sectionDescription = "Hotfix Rollups"


function CheckForHotfix ($hotfixID, $title)
{
	$hotfixesWMIQuery = "SELECT * FROM Win32_QuickFixEngineering WHERE HotFixID='KB$hotfixID'"
	$hotfixesWMI = get-wmiobject -query $hotfixesWMIQuery
	$link = "http://support.microsoft.com/kb/" + $hotfixID
	if ($hotfixesWMI -eq $null)
	{
		"No          $hotfixID - $title   ($link)" | Out-File -FilePath $OutputFile -append
	}
	else
	{
		"Yes         $hotfixID - $title   ($link)" | Out-File -FilePath $OutputFile -append
	}
}

#----------detect OS version and SKU
	$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
	[int]$bn = [int]$wmiOSVersion.BuildNumber
	$sku = $((gwmi win32_operatingsystem).OperatingSystemSKU)
	

if ($bn -eq 9600)
{
	"==================================================" | Out-File -FilePath $OutputFile -append
	"Windows 8.1 and Windows Server 2012 R2 Rollups"	 | Out-File -FilePath $OutputFile -append
	"==================================================" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"OS Version:  " + $bn | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Installed   Rollup Title and Link" | Out-File -FilePath $OutputFile -append
	"---------   ---------------------" | Out-File -FilePath $OutputFile -append

	CheckForHotfix -hotfixID 2995387 -title "October 2014 update rollup for Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2"
	CheckForHotfix -hotfixID 2984006 -title "September 2014 update rollup for Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2"	
	CheckForHotfix -hotfixID 2975719 -title "August 2014 update rollup for Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2"	
	CheckForHotfix -hotfixID 2967917 -title "July 2014 update rollup for Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2"
	CheckForHotfix -hotfixID 2962409 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: June 2014"
	CheckForHotfix -hotfixID 2955164 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: May 2014"
	CheckForHotfix -hotfixID 2919355 -title "[Windows 8.1 Update 1] Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: April 2014"
	CheckForHotfix -hotfixID 2928680 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: March 2014"
	CheckForHotfix -hotfixID 2919394 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: February 2014"
	CheckForHotfix -hotfixID 2911106 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: January 2014"
	CheckForHotfix -hotfixID 2903939 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: December 2013"
	CheckForHotfix -hotfixID 2887595 -title "Windows RT 8.1, Windows 8.1, and Windows Server 2012 R2 update rollup: November 2013"
	CheckForHotfix -hotfixID 2884846 -title "Windows 8.1 and Windows Server 2012 R2 update rollup: October 2013"
	CheckForHotfix -hotfixID 2883200 -title "Windows 8.1 and Windows Server 2012 R2 General Availability Update Rollup"
}
elseif ($bn -ge 9200)
{
	"==================================================" | Out-File -FilePath $OutputFile -append
	"Windows 8 and Windows Server 2012 Rollups" | Out-File -FilePath $OutputFile -append
	"==================================================" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"OS Version:  " + $bn | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Installed   Rollup Title and Link" | Out-File -FilePath $OutputFile -append
	"---------   ---------------------"  | Out-File -FilePath $OutputFile -append
	
	CheckForHotfix -hotfixID 2995388 -title "October 2014 update rollup for Windows RT, Windows 8, and Windows Server 2012 "
	CheckForHotfix -hotfixID 2984005 -title "September 2014 update rollup for Windows RT, Windows 8, and Windows Server 2012"
	CheckForHotfix -hotfixID 2975331 -title "August 2014 update rollup for Windows RT, Windows 8, and Windows Server 2012"
	CheckForHotfix -hotfixID 2967916 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: July 2014" 
	CheckForHotfix -hotfixID 2962407 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: June 2014" 
	CheckForHotfix -hotfixID 2955163 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: May 2014"
	CheckForHotfix -hotfixID 2934016 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: April 2014" 	
	CheckForHotfix -hotfixID 2928678 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: March 2014" 	
	CheckForHotfix -hotfixID 2919393 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: February 2014"
	CheckForHotfix -hotfixID 2911101 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: January 2014"
	CheckForHotfix -hotfixID 2903938 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: December 2013"
	CheckForHotfix -hotfixID 2889784 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: November 2013"
	CheckForHotfix -hotfixID 2883201 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: October 2013"
	CheckForHotfix -hotfixID 2876415 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: September 2013"
	CheckForHotfix -hotfixID 2862768 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: August 2013"	
	CheckForHotfix -hotfixID 2855336 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: July 2013"	
	CheckForHotfix -hotfixID 2845533 -title "Windows RT, Windows 8, and Windows Server 2012 update rollup: June 2013"	
	CheckForHotfix -hotfixID 2836988 -title "Windows 8 and Windows Server 2012 Update Rollup: May 2013" 				
	CheckForHotfix -hotfixID 2822241 -title "Windows 8 and Windows Server 2012 Update Rollup: April 2013"				
	CheckForHotfix -hotfixID 2811660 -title "Windows 8 and Windows Server 2012 Update Rollup: March 2013"				
	CheckForHotfix -hotfixID 2795944 -title "Windows 8 and Windows Server 2012 Update Rollup: February 2013"			
	CheckForHotfix -hotfixID 2785094 -title "Windows 8 and Windows Server 2012 Update Rollup: January 2013"				
	CheckForHotfix -hotfixID 2779768 -title "Windows 8 and Windows Server 2012 Update Rollup: December 2012"			
	CheckForHotfix -hotfixID 2770917 -title "Windows 8 and Windows Server 2012 Update Rollup: November 2012"			
	CheckForHotfix -hotfixID 2756872 -title "Windows 8 Client and Windows Server 2012 General Availability Update Rollup"
}
elseif ($bn -ge 6000)
{
	"==================================================" | Out-File -FilePath $OutputFile -append
	"Windows 7 and Windows Server 2008 R2 Rollups" | Out-File -FilePath $OutputFile -append
	"==================================================" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"OS Version:  " + $bn + "   (RTM=7600, SP1=7601)" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Installed   Rollup Title and Link" | Out-File -FilePath $OutputFile -append
	"---------   ---------------------"  | Out-File -FilePath $OutputFile -append
	CheckForHotfix -hotfixID 2775511 -title "An enterprise hotfix rollup is available for Windows 7 SP1 and Windows Server 2008 R2 SP1"
	"`n" | Out-File -FilePath $OutputFile -append
	"Installed   Followup Fixes Title and Link" | Out-File -FilePath $OutputFile -append
	"---------   -----------------------------"  | Out-File -FilePath $OutputFile -append
	CheckForHotfix -hotfixID 2732673 -title "`"Delayed write failed`" error message when .pst files are stored on a network file server that is running Windows Server 2008 R2"
	CheckForHotfix -hotfixID 2728738 -title "You experience a long logon time when you try to log on to a Windows 7-based or a Windows Server 2008 R2-based client computer that uses roaming profiles"
	CheckForHotfix -hotfixID 2878378 -title "OpsMgr 2012 or OpsMgr 2007 R2 generates a "Heartbeat Failure" message and then goes into a greyed out state in Windows Server 2008 R2 SP1"
}

	CollectFiles -filesToCollect $OutputFile -fileDescription "Hotfix Rollups" -SectionDescription $sectionDescription

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
# SIG # Begin signature block
# MIIa6gYJKoZIhvcNAQcCoIIa2zCCGtcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJKU1srED1JBQZlkNX/Vh6sI2
# BvqgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNIwggTO
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggeswGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOU2
# ZW5Gm82wjWz7Z/ju0ZHF4zdHMIGKBgorBgEEAYI3AgEMMXwweqBggF4AQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# RABDAF8ASABvAHQAZgBpAHgAUgBvAGwAbAB1AHAAcwAuAHAAcwAxoRaAFGh0dHA6
# Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAFLKvVx7RT8dN+HMn4CS
# L/WAKv6UA+LUmiYS64P761wVZMcgRhEqrXWLYUpQQTtz7FALcT/5cJCto1yJkovH
# lfiTyCfdo4RGznb5XD+GJtSSdSGmqMdlNkySl9mNmWBKS724XveSURzU7CUg2/VF
# VvKFTwOa0wNsDI7JpcppL9gnct64ktEpRABZ+zUkWnUgatkADa0fB2cnoWowOP62
# w9bJMrzsaVE+Do+7GaYg07YEDT+YwE6weC8m6HTX4C3tANuA2swp6lnPL4YxycoD
# QTGXjPQh5OwHO0N2WcxWPii5CleiuwE3jf/4akzEWGXP3O3sRkACrVfo+0nY2Nz5
# d1GhggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBAhMzAAAATKHoTcy0dHs7AAAAAABMMAkGBSsOAwIaBQCgXTAY
# BgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAx
# ODA4MzBaMCMGCSqGSIb3DQEJBDEWBBQtoNWzhL7wHXQt46q/CYQ4bEip6zANBgkq
# hkiG9w0BAQUFAASCAQAxAYeEt+9VpUrZHPIPK7G/D90yVfhzaeDn8TSKeRhYbClw
# 1k57OQa3Sd/Oiu3JbWDtevwUec6ge0ZtqgZxV2IghN3cBsPr1tjOGToIuFxLwzNi
# rsrNs6SXjYl1SC06yiSuX9F4Idt1yqr/+IaHz/Y8RjewnyLFCPWgUUe2c14A/zoY
# ykeTezkW+CDoynymYx2bYqVqjsJXk7gv04oHdCqr9Y6LzGZLkfrW1tsOCfNufn+W
# lCLcJtmgc8XJzd6wu/uDGxwqmmxzg4RQihxe0BQOn1AHctfz4vKAgDAzNTrqTqcM
# 29FgQpnyd6K6mQ0x2wvA5UC3HKrIrd2pIjv/liJS
# SIG # End signature block
