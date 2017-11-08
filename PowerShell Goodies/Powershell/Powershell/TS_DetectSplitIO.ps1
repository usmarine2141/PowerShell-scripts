#************************************************
# TS_SplitIO.ps1
# Version 1.0.1
# Date: 2/21/2013
# Author: Tspring
# Description:  [Idea ID 7345] [Windows] Perfmon - Split IO Counter
# Rule number:  7345
# Rule URL:  http://sharepoint/sites/rules/Rule Submissions/Forms/DispForm.aspx?ID=7345
#Split IO/sec
# Shows the rate, in incidents per second, at which input/output (I/O) requests to the disk were split into multiple requests. 
# A split I/O might result from requesting data in a size that is too large to fit into a single I/O, or from a fragmented disk subsystem.
#************************************************

Import-LocalizedData -BindingVariable ScriptStrings
Write-DiagProgress -Activity $ScriptStrings.ID_SplitIO_Activity -Status $ScriptStrings.ID_SplitIO_Status

$RootCauseDetected = $false
$RootCauseName = "RC_SplitIO"
$InformationCollected = new-object PSObject

# ***************************
# Data Gathering
# ***************************
function QueryTotalSplitIO
	{
	 $ReturnedObject = New-Object PSObject
	 $PhysDisk = New-Object System.Diagnostics.PerformanceCounter("PhysicalDisk", "Split IO/Sec", "_Total")
	 $LogDisk = New-Object System.Diagnostics.PerformanceCounter("LogicalDisk", "Split IO/Sec", "_Total")
	 $CookedPhysDisk = $PhysDisk.NextValue()
	 $CookedLogDisk = $LogDisk.NextValue()
	 add-member -inputobject $ReturnedObject  -membertype noteproperty -name "PhysicalDisk" -value $CookedPhysDisk
	 add-member -inputobject $ReturnedObject  -membertype noteproperty -name "LogicalDisk" -value $CookedLogDisk
	 return $ReturnedObject
	}
	

Function CollectedData
	{
	 $Sample1 = QueryTotalSplitIO
	 Start-Sleep 3
	 $Sample2 = QueryTotalSplitIO
	 Start-Sleep 3
	 $Sample3 = QueryTotalSplitIO
	 Start-Sleep 3
	 $Sample4 = QueryTotalSplitIO
	 Start-Sleep 3
	 $Sample5 = QueryTotalSplitIO
	 if ((($Sample1."PhysicalDisk" -ge 5) -or ($Sample1."LogicalDisk" -ge 5)) -or (($Sample2."PhysicalDisk" -ge 5) -or ($Sample2."LogicalDisk" -ge 5)) -or `
		(($Sample3."PhysicalDisk" -ge 5) -or ($Sample3."LogicalDisk" -ge 5)) -or (($Sample4."PhysicalDisk" -ge 5) -or ($Sample4."LogicalDisk" -ge 5)) -or `
		(($Sample5."PhysicalDisk" -ge 5) -or ($Sample5."LogicalDisk" -ge 5)))
		{
		 #Problem detected.
		 return $true
		}
	}



# **************
# Detection Logic
# **************

#Check to see if rule is applicable to this computer
if (CollectedData -eq $true)
	{
	 $RootCauseDetected = $true	
	 $SplitIOResults = New-Object PSObject
	 
	$SplitIODiskFlags = @{}

	 #Gather all logical and physical drives and then query each specific disk or logical
	 #disk to see which one(s) have the problem.
	 $Phys = New-Object System.Diagnostics.PerformanceCounterCategory("PhysicalDisk")
	 $PhysInstances = $Phys.GetInstanceNames()
	 $Log = New-Object System.Diagnostics.PerformanceCounterCategory("LogicalDisk")
	 $LogInstances = $Log.GetInstanceNames()
	 ForEach ($PhysInstance in $PhysInstances)
	 	{
		 WriteTo-StdOut "Within PhysInstance Foreach"
		 #Query for that drive letters statistic and place it into a PSObject.
		 $PhysSplitIOValue = New-Object System.Diagnostics.PerformanceCounter("PhysicalDisk", "Split IO/Sec", $PhysInstance)
		 $PhysSplitIOValue = $PhysSplitIOValue.NextValue()
		 #place Split IO into array for use in identifying correct key pair in hash table.
		 $SplitIOValuesArray = $SplitIOValuesArray + $PhysSplitIOValue
		 if (($PhysSplitIOValue -ge 5) -and ($PhysInstance -notmatch "_Total"))
			{
			 $PhysInstanceName = $PhysInstance
			 WriteTo-StdOut "PhysInstance is $PhysInstance"
			 $SplitIODiskFlags.Add($PhysInstance, "Physical Disk")
			 WriteTo-StdOut "SplitIODiskFlags is $SplitIODiskFlags"
			 add-member -inputobject $SplitIOResults  -membertype noteproperty -name $PhysInstanceName -value $PhysSplitIOValue
			}
		 $Drive = $null
		}
	 ForEach ($LogInstance in $LogInstances) 
	 	{
		 WriteTo-StdOut "Within LogInstance Foreach"
		 #Query for that drive letters statistic and place it into a PSObject.
		 $LogSplitIOValue = New-Object System.Diagnostics.PerformanceCounter("LogicalDisk", "Split IO/Sec", $LogInstance)
		 $LogSplitIOValue = $LogSplitIOValue.NextValue()
		 #place Split IO into array for use in identifying correct key pair in hash table.
		 $SplitIOValuesArray = $SplitIOValuesArray + $LogSplitIOValue
		 if (($LogSplitIOValue -ge 5) -and ($LogInstance -notmatch "_Total"))
			{
			 $LogInstanceName = $LogInstance
			 WriteTo-StdOut "LogInstance is $LogInstance"
			 $SplitIODiskFlags.Add($LogInstance, "Logical Disk")
			 WriteTo-StdOut "SplitIODiskFlags is $SplitIODiskFlags"
			 add-member -inputobject $SplitIOResults  -membertype noteproperty -name $LogInstanceName -value $LogSplitIOValue
			}
		 $Drive = $null
		}
		
	$SortedSplitIOArray =  $SplitIOValuesArray | Sort-Object -Descending

		$SplitIOResults | Get-Member -MemberType Properties |             
    		ForEach {$hash=@{}} {            
       		 $hash.($_.Name) = $SplitIOResults.($_.Name)
    			} 
		$SortedHash = $hash.GetEnumerator() | Sort-Object Value -Descending
		$SortedHash.GetEnumerator() | Foreach-Object {    
    		if($_.Value -eq $SortedSplitIOArray[0])
				{
					$WorstSplitIO = @{$_.Key = $_.Value}
					$Key = $_.Key
				}
			}
    WriteTo-StdOut "SplitIODiskFlags is $SplitIODiskFlags"


	$WorstSplitIO
	$WorstSplitIO.GetEnumerator() | Foreach-Object {    
			$BadKeyname = $_.Key
			$BadValue =  $_.Value
		}


    WriteTo-StdOut  "BadKeyname is $BadKeyname"
	WriteTo-StdOut  "BadValue is $BadValue"

	#Determine whether the disk was a logical one or physical one for reporting to engineer.
	$SplitIODiskFlags.GetEnumerator() | Foreach-Object {    
    		
			$Name = $_.Name
			$Value = $_.Value
			WriteTo-StdOut "Name is $Name"
			if ($Name -eq $Key)
				{ 
				 WriteTo-StdOut "Name is $_.Name and Key is $_.Key"
				 $PhysorLogFlag = $Value
				}
			}

	#Export results to a CSV for engineer review.
	$ExportCSV = Join-Path $Pwd.Path ($ComputerName + "_SplitIODiskInfo.csv")
	$SortedHash.GetEnumerator() | Export-Csv -Path $ExportCSV -Force
	
	$Date = Get-Date
	add-member -inputobject $InformationCollected  -membertype noteproperty -name "Date" -value $Date
	add-member -inputobject $InformationCollected  -membertype noteproperty -name "Problematic Volume" -value $BadKeyname
	add-member -inputobject $InformationCollected  -membertype noteproperty -name "Physical or Logical Disk" -value $Value
	add-member -inputobject $InformationCollected  -membertype noteproperty -name "Highest Split IO Value" -value $BadValue
	Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL $PublicContent -InformationCollected $InformationCollected -Verbosity "Error" -Visibility 3 -SupportTopicsID $SupportTopicsID -SolutionTitle $ScriptStrings.ID_SplitIO_ST -SDPFileReference $ExportCSV

}


# *********************
# Root Cause processing
# *********************

if ($RootCauseDetected)
	{
	 # Red/ Yellow Light
	 Update-DiagRootCause -id $RootCauseName -Detected $true
	 CollectFiles -filesToCollect $ExportCSV -fileDescription "CSV output of logical and physical disk split IO performance counters." -sectionDescription "Split IO Disk Info" -renameOutput $false
	}
	else
	{
	 # Green Light
	 Update-DiagRootCause -id $RootCauseName -Detected $false
	}
	
# SIG # Begin signature block
# MIIa6gYJKoZIhvcNAQcCoIIa2zCCGtcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULTdjlLMiTRBeZajXiVFGsBY4
# daOgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFEh7
# iyiHNROCVZyPcX5Y2PQBV5xyMIGKBgorBgEEAYI3AgEMMXwweqBggF4AQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# VABTAF8ARABlAHQAZQBjAHQAUwBwAGwAaQB0AEkATwAuAHAAcwAxoRaAFGh0dHA6
# Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAGt/0EIaxY3MnN+mN0bn
# 6ohxpBOrdHjM/tETPp03LKr+NtGIsNMJaooHE1CHoVWZQV21FnQ0A+rqIdg67qri
# DKvc3Fa+Ie4Qj1r01WPHJZvq4eXWYsYDRpAnX5BRjwPpDH+Z8P5pan1YXsHMxhGy
# L3VX+7in5Ex04NbRsLYiai5Z+vkLRXcpRhOGKDXswgM2dLx/mpb/OnYDSXsDt52E
# XQkfO7DLUUTNazO2x6IH1G1eiQxFZS39Kpe0XLv+rtPVZzSFd/ND+u6PplOcKMFB
# r4PE+qpE4tktnnm3QVzdtgflvyfScgWq4eHihn+CPJVZjZ4kaN+iU205mc3zYj5Q
# a8ehggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBAhMzAAAATKHoTcy0dHs7AAAAAABMMAkGBSsOAwIaBQCgXTAY
# BgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAx
# ODA4MzlaMCMGCSqGSIb3DQEJBDEWBBSg9m5y+LMYfceAp7A5gLHu5NsAEjANBgkq
# hkiG9w0BAQUFAASCAQA58MQO/4iXhG6dnI8rn50cKpFPXEjIiflMCY/0vYQtzi+J
# S95AvmHnPF2NwHSHwl+IF94vHYoLNZFCPfCTQiGBlr4887P8527+0v45BQYbTocA
# OGDGxRZVtJ+qmuBLvvRxrcVLLkuig+EBntXy8Lhu1adoAabIrpzyJGTtryJP3bLO
# HnM03hmdjkfMedN0slQECTusqfYi0FFKCNSUTz83u6a7mgm9+qRWuRxcHCLJ4p7F
# QIYA4dkZ4w9EFrOePSojbPzyV2rtFtJKIeVNp2x8tJlmrLM/WFgyRPG76dBQ0qA/
# Wy/vdeySNJemJ2z6K3oBAf/wxZYtJhbxb65kSeGp
# SIG # End signature block
