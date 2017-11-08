#************************************************
# DC_RAS-Component.ps1
# Version 1.0
#   Collects registry and netsh information.
# Version 1.1
#   Commented out "ras show activeservers". <- On Win7, this caused a Windows Firewall prompt to allow RAS server advertisements
#   Commented out "ras show user" <- This command enumerates all User accounts from the Active Directory and their Dial-in Settings, which can take a very long time in a big enterprise environment.
# Version 1.2
#   Corrected the section that collects RAS Tracing logs.
# Date: 2009, 2013, 2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects information about RAS.
# Called from: Main Networking Diag, etc
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

Import-LocalizedData -BindingVariable RasTracingStrings
Write-DiagProgress -Activity $RasTracingStrings.ID_RasTracingLogs -Status $RasTracingStrings.ID_RasTracingLogsDesc

$sectionDescription = "RAS Component"

function RunNetSH ([string]$NetSHCommandToExecute="")
{
	Write-DiagProgress -Activity $RasTracingStrings.ID_RasNetsh -Status "netsh $NetSHCommandToExecute"
	
	$NetSHCommandToExecuteLength = $NetSHCommandToExecute.Length + 6
	"-" * ($NetSHCommandToExecuteLength) + "`r`n" + "netsh $NetSHCommandToExecute" + "`r`n" + "-" * ($NetSHCommandToExecuteLength) | Out-File -FilePath $OutputFile -append

	$CommandToExecute = "cmd.exe /c netsh.exe " + $NetSHCommandToExecute + " >> $OutputFile "
	RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
	"`n"		| Out-File -FilePath $OutputFile -append
	"`n"		| Out-File -FilePath $OutputFile -append
	"`n"		| Out-File -FilePath $OutputFile -append
}


#----------Log Files
$RasTracing = "$Env:windir\tracing"
if (Test-Path -Path $RasTracing)
{
	New-Item $Pwd.Path -Name RasTracingDir -ItemType directory
	$RasTracingPath =  $Pwd.Path + "\RasTracingDir"
	Copy-Item  -Path "$Env:windir\tracing\*.*" -Destination $RasTracingPath
	$RasTracingFiles = $RasTracingPath + "\*.*"
	$RasTracingLogs = $ComputerName + "_RasTracingLogs.zip" 
	CompressCollectFiles -NumberofDays 10 -filesToCollect $RasTracingFiles -DestinationFileName $RasTracingLogs -renameOutput $false -fileDescription "RAS Tracing Logs" -sectionDescription $sectionDescription  
	Remove-Item  -Path $RasTracingFiles -Recurse
}


#----------Registry
$OutputFile= $Computername + "_RAS_reg_.TXT"
$CurrentVersionKeys =   "HKLM\System\CurrentControlSet\services\RasMan"

RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "RAS registry output" -SectionDescription $sectionDescription



#----------Netsh
$OutputFile = $ComputerName + "_RAS_netsh_ras-output.TXT"
"===================================================="	| Out-File -FilePath $OutputFile -append
"RAS Netsh Output"										| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"   1. netsh ras aaaa show accounting"					| Out-File -FilePath $OutputFile -append
"   2. netsh ras aaaa show acctserver"					| Out-File -FilePath $OutputFile -append
"   3. netsh ras aaaa show authentication"				| Out-File -FilePath $OutputFile -append
"   4. netsh ras aaaa show authserver"					| Out-File -FilePath $OutputFile -append
"   5. netsh ras aaaa show ipsecpolicy"					| Out-File -FilePath $OutputFile -append
"   6. netsh ras demanddial show interface"				| Out-File -FilePath $OutputFile -append
"   7. netsh ras demanddial show"						| Out-File -FilePath $OutputFile -append
"   8. netsh ras diagnostics show tracefacilities"		| Out-File -FilePath $OutputFile -append
"   9. netsh ras ip show config"						| Out-File -FilePath $OutputFile -append
"  10. netsh ras ip show preferredadapter"				| Out-File -FilePath $OutputFile -append
"  11. netsh ras ipv6 show config"						| Out-File -FilePath $OutputFile -append
"  12. netsh ras show authmode"							| Out-File -FilePath $OutputFile -append
"  13. netsh ras show authtype"							| Out-File -FilePath $OutputFile -append
"  14. netsh ras show client"							| Out-File -FilePath $OutputFile -append
"  15. netsh ras show conf"								| Out-File -FilePath $OutputFile -append
"  16. netsh ras show ikev2connection"					| Out-File -FilePath $OutputFile -append
"  17. netsh ras show ikev2saexpiry"					| Out-File -FilePath $OutputFile -append
"  18. netsh ras show link"								| Out-File -FilePath $OutputFile -append
"  19. netsh ras show multilink"						| Out-File -FilePath $OutputFile -append
"  20. netsh ras show portstatus"						| Out-File -FilePath $OutputFile -append
"  21. netsh ras show registeredserver"					| Out-File -FilePath $OutputFile -append
"  22. netsh ras show sstp-ssl-cert"					| Out-File -FilePath $OutputFile -append
"  23. netsh ras show status"							| Out-File -FilePath $OutputFile -append
"  24. netsh ras show type"								| Out-File -FilePath $OutputFile -append
"  25. netsh ras show wanports"							| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"													| Out-File -FilePath $OutputFile -append
"`n"													| Out-File -FilePath $OutputFile -append
"`n"													| Out-File -FilePath $OutputFile -append
"`n"													| Out-File -FilePath $OutputFile -append
"`n"													| Out-File -FilePath $OutputFile -append
RunNetSH -NetSHCommandToExecute "ras aaaa show accounting"
RunNetSH -NetSHCommandToExecute "ras aaaa show acctserver"
RunNetSH -NetSHCommandToExecute "ras aaaa show authentication"
RunNetSH -NetSHCommandToExecute "ras aaaa show authserver"
RunNetSH -NetSHCommandToExecute "ras aaaa show ipsecpolicy"
RunNetSH -NetSHCommandToExecute "ras demanddial show interface"
RunNetSH -NetSHCommandToExecute "ras demanddial show"
RunNetSH -NetSHCommandToExecute "ras diagnostics show tracefacilities"
RunNetSH -NetSHCommandToExecute "ras ip show config"
RunNetSH -NetSHCommandToExecute "ras ip show preferredadapter"
RunNetSH -NetSHCommandToExecute "ras ipv6 show config"
# RunNetSH -NetSHCommandToExecute "ras show activeservers"              <- On Win7, this caused a Windows Firewall prompt to allow RAS server advertisements
RunNetSH -NetSHCommandToExecute "ras show authmode"
RunNetSH -NetSHCommandToExecute "ras show authtype"
RunNetSH -NetSHCommandToExecute "ras show client"
RunNetSH -NetSHCommandToExecute "ras show conf"
RunNetSH -NetSHCommandToExecute "ras show ikev2connection"
RunNetSH -NetSHCommandToExecute "ras show ikev2saexpiry"
RunNetSH -NetSHCommandToExecute "ras show link"
RunNetSH -NetSHCommandToExecute "ras show multilink"
RunNetSH -NetSHCommandToExecute "ras show portstatus"
RunNetSH -NetSHCommandToExecute "ras show registeredserver"
RunNetSH -NetSHCommandToExecute "ras show sstp-ssl-cert"
RunNetSH -NetSHCommandToExecute "ras show status"
RunNetSH -NetSHCommandToExecute "ras show type"
# RunNetSH -NetSHCommandToExecute "ras show user"                       <- This command enumerates  all User accounts from the Active Directory and their Dial-in Settings, which can take a very long time in a big enterprise environment.
RunNetSH -NetSHCommandToExecute "ras show wanports"

CollectFiles -sectionDescription $sectionDescription -fileDescription "RAS netsh output" -filesToCollect $OutputFile

# SIG # Begin signature block
# MIIa6gYJKoZIhvcNAQcCoIIa2zCCGtcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOdhL634/C66sdZSl/f03bJFd
# jW+gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFBi
# upg4eETBjP+z/GS1xtFqEQNfMIGKBgorBgEEAYI3AgEMMXwweqBggF4AQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# RABDAF8AUgBBAFMALQBDAG8AbQBwAG8AbgBlAG4AdAAuAHAAcwAxoRaAFGh0dHA6
# Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAB6m+6UQ/jqLsqul93z/
# OCbjC02mJ6UiyM0FsqnxBGRROqiKin7gREQazP8ZWjAMgkiL/2OIq4M2Df9zwfXh
# ZQYlw8xMl6Hp/E9eeLzua1AoEsvurZ3V0khFDMkf56tLW8hzMmxTM3vUmK+rqLaG
# Q5mm6BfJzGI4fmYu1FoFURV2yaRrp2iQ/zCgM3NqO9XqUHw5JFAEBxWtZ7pZibi4
# cQzwn4eh4E72SjXywgjd5FUNVBr00EFR4emLRadCiD9ZQZf7tCebBZ3Px+lB907S
# 8q783IRaWfkiyatYKk7HFMVIirWi1vXfgfixRB3UIoQWq0uaxVZtx/PXk+f1fKVp
# Rr+hggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBAhMzAAAATKHoTcy0dHs7AAAAAABMMAkGBSsOAwIaBQCgXTAY
# BgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAx
# ODA4MzZaMCMGCSqGSIb3DQEJBDEWBBRejGAoltboh5L0KGoIKzVPh6JZ1DANBgkq
# hkiG9w0BAQUFAASCAQAK2inIgIQxD2AxITyiU+kPIQ5fnfjtZEJKhVUL1qYr8OJm
# nPUr9rci5/bypCR3JTiNu6EQqptFDKt06RMmFUNAUjU3UGT2j0H2ciMDaxyGzbVp
# oKIxogwGllmVZIAmI/+quFIRI8NFru18509W8Qt8Uu1U3Ej2ThOi0HLtlpuD+UiT
# Y/yvnOTVanenGmlGzZJZpaBrvrFfE1WaOb8PjkYh4sNirbkBjHMKXrjtnoBSSfPm
# /dpqiQnRQGlx5rCz/PjAFMwI+6W7BvNrTvz/XeHMeL3gcwSbpREzSoxQdFpaZANg
# lte6E3E2MSieJIkjHjUA1mXnFPQdSR1Xo1Rhkqs5
# SIG # End signature block
