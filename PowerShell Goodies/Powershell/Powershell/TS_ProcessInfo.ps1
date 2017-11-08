#************************************************
# TS_ProcOverview.ps1
# Version 1.0.1
# Date: 2-2-2010
# Author: Andre Teixeira - andret@microsoft.com
# Description: This script executes a series of WMI queries to obtain process statistics - such as top process by handle count/ memory usage and so.
#              Also, it shows statistics for Kernel Pool memory usage using MemSnap tool
#************************************************


trap 
{
	$errorMessage = "Error [{4}]:`r`n Category {0}, Error Type {1}, ID: {2}, Message: {3}" -f  $_.CategoryInfo.Category, $_.Exception.GetType().FullName,  $_.FullyQualifiedErrorID, $_.Exception.Message, $_.InvocationInfo.PositionMessage
	$errorMessage | WriteTo-StdOut
	continue
}

Import-LocalizedData -BindingVariable ProcInfoStrings

Write-DiagProgress -Activity $ProcInfoStrings.ID_ProcInfo -Status $ProcInfoStrings.ID_ProcInfoObtaining

$KernelGraph = "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"GraphValue`" class=`"vmlimage`" style=`"width:300px;height:15px;vertical-align:middle`" coordsize=`"{MaxValue},100`" title=`"{ValueDisplay}`"><v:rect class=`"vmlimage`" style=`"top:1;left:1;width:{MaxValue};height:100`" strokecolor=`"#336699`"><v:fill type=`"gradient`" angle=`"0`" color=`"#C4CCC7`" color2=`"white`" /></v:rect><v:rect class=`"vmlimage`" style=`"top:2;left:2;width:{Value};height:99`" strokecolor=`"{GraphColorEnd}`"><v:fill type=`"gradient`" angle=`"270`" color=`"{GraphColorStart}`" color2=`"{GraphColorEnd}`" /></v:rect></v:group></span>"
$ProcGraph   = "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"GraphValue`" class=`"vmlimage`" style=`"width:200px;height:15px;vertical-align:middle`" coordsize=`"{MaxValue},100`" title=`"{ValueDisplay}`"><v:rect class=`"vmlimage`" style=`"top:1;left:1;width:{MaxValue};height:100`" strokecolor=`"#336699`"><v:fill type=`"gradient`" angle=`"0`" color=`"#C4CCC7`" color2=`"white`" /></v:rect><v:rect class=`"vmlimage`" style=`"top:2;left:1;width:{Value};height:99`" strokecolor=`"{GraphColorEnd}`"><v:fill type=`"gradient`" angle=`"270`" color=`"{GraphColorStart}`" color2=`"{GraphColorEnd}`" /></v:rect><v:rect style=`"top:-70;left:1;width:{MaxValue};height:50`" filled=`"false`" stroked=`"false`" textboxrect=`"top:19;left:1;width:{MaxValue};height:30`"><v:textbox style=`"color:white;`" inset=`"10px, 10px, 28px, 177px`">{ValueDisplay}</v:textbox></v:rect></v:group></span>"

$sectionDescription = "Processes and Kernel Memory information"
$fileDescription = "Processess/Performance Information"
$OutputFile = $ComputerName + "_ProcessesPerfInfo.htm"
$CommandToExecute = "cscript.exe ProcessesPerfInfo.vbs /generatescripteddiagxmlalerts"

$OutputXMLFileName = ($Computername + "_ProcessesPerfInfo.xml")

if (-not (Test-Path $OutputXMLFileName))
{

	RunCmD -commandToRun $CommandToExecute -sectionDescription $sectionDescription -filesToCollect $OutputFile -fileDescription $fileDescription

	[xml] $ProcOverviewXML = Get-Content $OutputXMLFileName

	$MAXITEMS_TO_DISPLAY = 3

	$PoolMemoryXML = $ProcOverviewXML.SelectSingleNode("//Section[SectionTitle = 'Kernel Memory Information']")

	foreach ($PoolMemorySection in $PoolMemoryXML.SubSection) 
	{
		$Item_Summary = new-object PSObject
		$PoolMemorySectionTitle = $PoolMemorySection.SectionTitle.get_InnerText()
		$MaxValue = $PoolMemorySection.KernelMemory.MaxValue.get_InnerText()
		$Displayed = 0
		foreach ($Tag in $PoolMemorySection.SelectNodes("KernelMemory/PoolMemory"))
		{
			$Displayed++
			if ($Displayed -le $MAXITEMS_TO_DISPLAY) {
				$TagName = $Tag.Tag.get_InnerText()
				$MemoryAllocationDisplay = $Tag.ValueDisplay.get_InnerText()
				$MemoryAllocationValue = $Tag.Value.get_InnerText()
				$GraphColorStart = $Tag.GraphColorStart.get_InnerText()
				$GraphColorEnd = $Tag.GraphColorEnd.get_InnerText()
				
				$Graph = $KernelGraph -replace "{MaxValue}", "$MaxValue" -replace "{ValueDisplay}", "$MemoryAllocationDisplay" -replace "{Value}", "$MemoryAllocationValue" -replace "{GraphColorStart}", "$GraphColorStart" -replace "{GraphColorEnd}", "$GraphColorEnd"
				
				add-member -inputobject $Item_Summary  -membertype noteproperty -name $TagName -value ("<table><tr><td width=`"100px`">$MemoryAllocationDisplay</td><td> $Graph</td></tr></table>")
			}
		}
		$Item_Summary | ConvertTo-Xml2 | update-diagreport -id ("52_$PoolMemorySectionTitle") -name $PoolMemorySectionTitle -verbosity informational
	}

	$ProcXML = $ProcOverviewXML.SelectSingleNode("//Section[SectionTitle = 'Process Statistics']")

	$Item_Summary = new-object PSObject
	foreach ($ProcSection in $ProcXML.SubSection) 
	{
		$ProcSectionTitle = $ProcSection.SectionTitle.get_InnerText()
		$MaxValue = $ProcSection.ProcessCollection.MaxValue.get_InnerText()
		$Displayed = 0
		#$MaxValue = $null
		$Line = ""
		foreach ($Process in $ProcSection.SelectNodes("ProcessCollection/Process"))
		{
			$Displayed++
			if ($Displayed -lt $MAXITEMS_TO_DISPLAY) {
				$ProcessName = $Process.Name.get_InnerText()
				$Display = $Process.ValueDisplay.get_InnerText()
				$Value = $Process.Value.get_InnerText()
				$GraphColorStart = $Process.GraphColorStart.get_InnerText()
				$GraphColorEnd = $Process.GraphColorEnd.get_InnerText()
				
				#if ($MaxValue -eq $null) 
				#{
				#	$MaxValue = ([int] $Value * 1.2)
				#}
				
				$Graph = $ProcGraph -replace "{MaxValue}", "$MaxValue" -replace "{ValueDisplay}", "$Display" -replace "{Value}", "$Value" -replace "{GraphColorStart}", "$GraphColorStart" -replace "{GraphColorEnd}", "$GraphColorEnd"
				$Line += "<table><tr><td width=`"120px`">$ProcessName</td><td> $Graph</td></tr></table>"
			}
		}
		add-member -inputobject $Item_Summary  -membertype noteproperty -name $ProcSectionTitle -value $Line
	}

	add-member -inputobject $Item_Summary -membertype noteproperty -name "More Information" -value ("For more information, please open the file <a href= `"`#" + $OutputFile + "`">" + $OutputFile + "</a>.")

	$Item_Summary | ConvertTo-Xml2 | update-diagreport -id ("50_ProcSummary") -name "Processes Summary" -verbosity informational

	$RootCauseXMLFilename = ($ComputerName + "_ProcessesPerfInfoRootCauses.XML")
	if (Test-Path ($RootCauseXMLFilename))
	{ 
		$RootCauseDetectedHash = @{}
		[xml] $XMLRootCauses = Get-Content -Path $RootCauseXMLFilename
		Foreach ($RootCauseDetected in $XMLRootCauses.SelectNodes("/Root/RootCause"))
		{
			$InformationCollected = @{}
			$ProcessName = $null
			switch ($RootCauseDetected.name)
			{
				"RC_HighHandleCount"
				{
					$InformationCollected = @{"Process Name" = $RootCauseDetected.param1; 
											  "Process ID" = $RootCauseDetected.param2;
											  "Current Handle Count" = $RootCauseDetected.CurrentValue}
					$ProcessName = $RootCauseDetected.param1
					$PublicURL = "http://blogs.technet.com/b/markrussinovich/archive/2009/09/29/3283844.aspx"
				}
				
				"RC_KernelMemoryPerformanceIssue"
				{
					$InformationCollected = @{"Kernel Tag Name" = $RootCauseDetected.param1; 
											  "Pool Memory Type" = $RootCauseDetected.param2;
											  "Current Allocated (MB)" = $RootCauseDetected.CurrentValue;
											  "Current Allocated (%)" = ($RootCauseDetected.ExpectedValue + "%")}
					$PublicURL = "http://blogs.technet.com/b/askperf/archive/2008/04/11/an-introduction-to-pool-tags.aspx"
				}
				"RC_LowSysPTEs"
				{
					$InformationCollected = @{"Current SysPTEs count" = $RootCauseDetected.CurrentValue}; 			
					$PublicURL = "http://blogs.technet.com/b/askperf/archive/2008/05/16/troubleshooting-server-hangs-part-four.aspx"
				}
				
				"RC_LowVirtualMemory"
				{
					$InformationCollected = @{"Committed Bytes In Use (%)" = $RootCauseDetected.CurrentValue};
					$TopProcesses = Get-Process | Sort-Object -Property VM -Descending | Select-Object -First 3
					$X = 1
					foreach ($Process in $TopProcesses)
					{
						$InformationCollected += @{"Top Process [$X] Memory Usage" = ($Process.Name + " (ID " + $Process.Id.ToString() + "): " + (FormatBytes $Process.VirtualMemorySize64))};
						$X++
					}
					$PublicURL = "http://blogs.technet.com/b/askperf/archive/2008/01/25/an-overview-of-troubleshooting-memory-issues.aspx"
				}			
			}
		
			if ($RootCauseDetectedHash.ContainsKey($RootCauseDetected.name) -eq $false) 
			{
				$RootCauseDetectedHash += @{$RootCauseDetected.name = $true}
			}
			
			Write-GenericMessage -RootCauseID $RootCauseDetected.name -Verbosity $RootCauseDetected.Type -InformationCollected $InformationCollected -ProcessName $ProcessName -PublicContentURL $PublicURL -Visibility 4 -MessageVersion 2
		}
		foreach ($RootCause in $RootCauseDetectedHash.get_Keys())
		{
			Update-DiagRootCause -Id $RootCause -Detected $true
		}
	}
}
else
{
	"[ProcessInfo] - Skipped execution as $OutputXMLFileName already exists"  | WriteTo-StdOut
}
# SIG # Begin signature block
# MIIa3gYJKoZIhvcNAQcCoIIazzCCGssCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFJqPlf4G8X/k70OLbEacBerg
# nM+gghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTOMIIEygIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIHnMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSGn2qMOZQ1CV1i
# 8+CYS6pJqTzkmzCBhgYKKwYBBAGCNwIBDDF4MHagXIBaAEMAVABTAF8ATgBlAHQA
# dwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAFQAUwBfAFAA
# cgBvAGMAZQBzAHMASQBuAGYAbwAuAHAAcwAxoRaAFGh0dHA6Ly9taWNyb3NvZnQu
# Y29tMA0GCSqGSIb3DQEBAQUABIIBACNnA1o6oqcANXdpAA/0cheCols7F00ful5+
# PigtxFWKjRpnCbJ9+ECO1MHMt304d/0LXpEJy9pYPi13Yf9S0sYVOCFJl1Il0pwz
# mpJdsP7H4gMMtB5c/URDrzQ8Or4ZuOobrOVfPb/8P7bRm253rBSKoUAYPnblrhxN
# ZXP38ApJIxchIQZAEzsuHPp2fmGPIjU3hJ7wNzZ1Yl2fJ26uwJAWazOAAQTh1XJJ
# 5w7Xba6zCLxfXe9aKYkF0e3yadtTBDTbH9iRbwAmnhFT7+47yRWQ53I8Eu+fLOLR
# OuSwTGVrIC/Or74r1Jg2kj73q0Wl15x3HB4DNNeEZkBBV7z6fSShggIoMIICJAYJ
# KoZIhvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# AhMzAAAAWu0v9OQgmT86AAAAAABaMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAxODA4NDBaMCMGCSqG
# SIb3DQEJBDEWBBQ66UX7plKsdSbKmwhCPYJ5KL/NyTANBgkqhkiG9w0BAQUFAASC
# AQB3o6o1TX7UZ0ZzrDPJZZ6i+eoC3v4j9/aGTIsiHjq9BrykPCcBOS6/0snHzcva
# Y6lQL92k0F4TDJOhL7wiGYYSg27zWHG1yr+vjc1LNNkLdZ6As7SoDkf7EAdl+fnu
# X/lsIiOFxCBA+3qt2fL0eptyjOb6j0zQl4vxG0TdLA9of8YS8sIeXJr3jaJMnirp
# 9unaxVQHGhUsUmTUu4xvv9+HFmrgRq3YQbAdYDS533nLpZpm6E5h/y2qirCPrU9G
# nFzokTFxYhTORpNGbgkhNYCfUJ6Fwo+tg2PlCOvrXLj3/+JPnI+Lr0SleWN4pU10
# PskN5lLyTXvMjPnJ11ueozBh
# SIG # End signature block
