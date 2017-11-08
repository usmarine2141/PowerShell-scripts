#***********************************************
# TS_DetectSHA512-TLS.ps1
# Version 1.0
# Date: 03/19/2014
# Author: Tim Springston [MSFT]
# Description:  On Windows 7/Server 2008 R2 and later computers which are default and do not have
#  RSA/SHA512 (OID 1.2.840.113549.1.1.5) enabled for TLS 1.2, the script searches through the user and computer My certificate
#  stores for Server Auth and Client Auth certificates which are signed with SHA512RSA signatures.
#  The script then warns the engineer that there are certificates which will cause SSL/TLS to fail. 
#  http://bemis/2950636
#************************************************
$RootCauseDetected = $False 

"Within SHA 512 Script." | WriteTo-StdOut -shortformat

#Add root cause and status string stuff here.
Import-LocalizedData -BindingVariable ScriptStrings
Write-DiagProgress -Activity $ScriptStrings.ID_PKITests_Wait -Status $ScriptStrings.ID_PKITests_Status

function RC_DetectSHA512-TLS
{	PARAM( $InformationCollected)
	"InfoCollected is $InformationCollected" | WriteTo-StdOut -shortformat
	Add-GenericMessage -id "RC_DetectSHA512-TLS" -InformationCollected $InformationCollected
}

#Detect if the OS may have the issue, and if the workaround to the issue is in the registry or not.
$OSApplies = $false
$512Value = $false

$OS = gwmi -Class win32_operatingsystem
if ($OS.Buildnumber -ge 7600)
	{
	$OSApplies = $True
	"Applies to this OS" | WriteTo-StdOut -shortformat
	}

$SSLKey = get-item -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL\00010003
$FunctionsValue = $SSLKey.GetValue('Functions')

if ($FunctionsValue -contains 'RSA/SHA512')
	{
	$512Value = $true
	"Within RSA/SHA512 registry value detected" | WriteTo-StdOut -shortformat
	}


if (($OSApplies -eq $true) -and ($512Value -eq $true))
	{
	#Look through the My stores of computer and user for Server Auth or Client Auth certificates which have been signed using RSA512 sigs.
	get-childitem -path cert:\ -recurse | Where-Object {(($_.PSParentPath -ne $null) -or ($CheckStores -contains (Split-Path ($_.PSParentPath) -Leaf))) -and `
	($_.PSIsContainer -ne $true) -and  (($_.EnhancedKeyUsageList -match '(1.3.6.1.5.5.7.3.1)') -or ($_.EnhancedKeyUsageList -match '(1.3.6.1.5.5.7.3.2)')) `
	-and ($_.SignatureAlgorithm.value -eq '1.2.840.113549.1.1.13')  } | % {

		"Within detection of a certificate which matches." | WriteTo-StdOut -shortformat
		"Certificate details $_" | WriteTo-StdOut -shortformat

		$Store = (Split-Path ($_.PSParentPath) -Leaf)
	    $StorePath = (($_.PSParentPath).Split("\"))     
	    $CertObject = new-object PSObject
	    $StoreWorkingContext = $Store
	    $StoreContext = Split-Path $_.PSParentPath.Split("::")[-1] -Leaf
	   if ($_.FriendlyName.length -gt 0)
	  	{add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value $_.FriendlyName}
	  	else
	  	{add-member -inputobject $CertObject -membertype noteproperty -name "Friendly Name" -value "[None]"}
	  
		#Determine the context (User or Computer) of the certificate store.
	   $StoreWorkingContext = (($_.PSParentPath).Split("\"))
	   $StoreContext = ($StoreWorkingContext[1].Split(":"))
	   add-member -inputobject $CertObject -membertype noteproperty -name "Path" -value $StoreContext[2]
	   add-member -inputobject $CertObject -membertype noteproperty -name "Store" -value $StorePath[$StorePath.count-1]
	   add-member -inputobject $CertObject -membertype noteproperty -name "Has Private Key" -value $_.HasPrivateKey
	   add-member -inputobject $CertObject -membertype noteproperty -name "Serial Number" -value $_.SerialNumber
	   add-member -inputobject $CertObject -membertype noteproperty -name "Thumbprint" -value $_.Thumbprint
	   add-member -inputobject $CertObject -membertype noteproperty -name "Issuer" -value $_.IssuerName.Name
		if ($_.SignatureAlgorithm.value -eq  '1.2.840.113549.1.1.12')
	    {add-member -inputobject $CertObject -membertype noteproperty -name "Signature Strength" -value 'sha384RSA'}
			if ($_.SignatureAlgorithm.value -eq  '1.2.840.113549.1.1.13')
	    {add-member -inputobject $CertObject -membertype noteproperty -name "Signature Strength" -value 'sha512RSA'}
	   add-member -inputobject $CertObject -membertype noteproperty -name "Not Before" -value $_.NotBefore
	   add-member -inputobject $CertObject -membertype noteproperty -name "Not After" -value $_.NotAfter
	   add-member -inputobject $CertObject -membertype noteproperty -name "Subject Name" -value $_.SubjectName.Name
	   if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Subject Alternative Name" -value "[None]"}
	   if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Key Usage"}) -ne $null) 
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -like "Key Usage"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Key Usage" -value "[None]"}
	   if ($_.EnhancedKeyUsageList -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value $_.EnhancedKeyUsageList}
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Enhanced Key Usage" -value "[None]"}
	   if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "Certificate Template Information"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "Certificate Template Information"}).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Certificate Template Information" -value "[None]"}
	   if (($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "authority key identifier"}) -ne $null)
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Authority Key Identifier" -value ($_.Extensions | Where-Object {$_.Oid.FriendlyName -match "Authority Key Identifier" }).Format(1)
	        }
	        else
	        {add-member -inputobject $CertObject -membertype noteproperty -name "Authority Key Identifier"  -value "[None]"}
	
	   ForEach ($Extension in $_.Extensions)
	        {
	        if ($Extension.OID.FriendlyName -eq 'Authority Information Access')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $AIAFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value $FormattedExtension
	              }
	        if ($Extension.OID.FriendlyName -eq 'CRL Distribution Points')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $CDPFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value $FormattedExtension
	              }
	        if ($Extension.OID.Value -eq '1.3.6.1.5.5.7.48.1')
	              {
	              #Convert the RawData in the extension to readable form.
	              $FormattedExtension = $Extension.Format(1)
				  $OCSPFound = $True
	              add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value $FormattedExtension
	              }
	        }
		
		if ($AIAFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "AIA URLs" -value "[None]"}
		if ($CDPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "CDP URLs" -value "[None]"}
		if ($OCSPFound -ne $true)
			{add-member -inputobject $CertObject -membertype noteproperty -name "OCSP URLs" -value "[None]"}

		"CertObject is $CertObject" | WriteTo-StdOut -shortformat
     	RC_DetectSHA512-TLS $CertObject
		$RootCauseDetected = $true
	 	$CertObject = $null

	  }
}





if ($RootCauseDetected -eq $true)
	{
	#Red/ Yellow Light
	Update-DiagRootCause -id "RC_DetectSHA512-TLS" -Detected $true
	}
	else
	{
	#Green Light
	Update-DiagRootCause -id "RC_DetectSHA512-TLS" -Detected $false
	}


# SIG # Begin signature block
# MIIa8gYJKoZIhvcNAQcCoIIa4zCCGt8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/M40hNApGxHvfFTxDxeRfPtw
# luCgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNowggTW
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfMwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFP1c
# t1qNh4vdK7Em0cuXJzBXd++ZMIGSBgorBgEEAYI3AgEMMYGDMIGAoGaAZABDAFQA
# UwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwA
# XwBUAFMAXwBEAGUAdABlAGMAdABTAEgAQQA1ADEAMgAtAFQATABTAC4AcABzADGh
# FoAUaHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEARna4O+5a
# SkF+fvVkKYr+g+E2Avn8CEOX/6+3c1p7VY7pXUB+Mm69xiWPFVX+kZpjnyM1bhMR
# 9EnkkOTld1nclPgz+RGMZqBp7dmrUGGe1yj+z1koh3gWGz8t26yo8uf8AxHfKan9
# G22fxc9le8n3rWyB7T+C3Cuw0BEdjpTq9iN3sDRpHsrahZlPpAqHL3Ar82ZRK4PB
# yYV9d1EpQ7oRr5bDnD+HzMhBj8T+ydmSdXkUXsTihR9L7SrflEtADmTZ11UaIygF
# Gxnxqc819BpodiWzHnt0rkb42NSaK35201JXEjFLpUpB+i2N5qCDe7oYA0Bkm9cr
# 0tCeYna+Z+xtKKGCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4D
# AhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTE0MTAyMDE4MDgzOVowIwYJKoZIhvcNAQkEMRYEFK/I4Wv4+jBAl3ornGBh8bES
# MGT5MA0GCSqGSIb3DQEBBQUABIIBAFogf9DEPvDyfzUSpomDcozrOESFgS9zmUMq
# iQdMivhT5TlAy9x/JPB5ye3rv349UcGjUg5XAmetAmVgbKodgXJGLKAfAjVYljb0
# RwBXFDARev3H19LhsAkGfs94rG83+WaWf2H9f/AI+UyJMULsytm9t1vP/QoGZ4RX
# 4HSjiIN0D9xvgsGpL2B/qHe9RKS09/FdPZW8coh8+CWux4m/7OiGhjJ7V/+GeLEO
# pXxDfskbcgoTYMvfxfnixRyMEXhQJUxCFHPNxXG2P40FnGUqBb5sulr9FU3VviZi
# ZZVinffjUNfHhr6H6KsY5y2+898Giz9s21uF1o4CPnFDpuLyStQ=
# SIG # End signature block
