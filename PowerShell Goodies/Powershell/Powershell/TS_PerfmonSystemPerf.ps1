#************************************************
# TS_PerfmonSystemPerf.ps1
# Version 2.0.1
# Date: 2-05-2011
# Author: Andre Teixeira - andret@microsoft.com
# Description: This script obtains a 1 minute performance monitor based on the inbox 
#              'System Performance' data collector set. It also list the summary on results report.
#              For Windows XP/2003, script generates a simple data collection using basic counters
#************************************************

PARAM([int]$NumberOfSeconds = 60, [switch]$DoNotCollectPerfmonFiles, [string] $DataCollectorSetXMLName = "SystemPerformance.xml", [switch] $DoNotShowTOPProcesses, $ShowProcessesInReport = $null, [string] $ProcessesSectionTitle=$null, $CollectPerfmonDataFrom=$null)

#Arguments only work on WinVista+ OSs. On pre-Win7, this will only collect a 60 sec perfmon with basic counters

Import-LocalizedData -BindingVariable PerfMonCollectorStrings
Write-DiagProgress -Activity $PerfMonCollectorStrings.ID_PerfMonSystemPerf -Status $PerfMonCollectorStrings.ID_PerfMonSystemPerfRunning

$ProcGraph   = "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"GraphValue`" class=`"vmlimage`" style=`"width:320px;height:15px;vertical-align:middle`" coordsize=`"{MaxValue},100`" title=`"{ValueDisplay}`"><v:rect class=`"vmlimage`" style=`"top:1;left:1;width:{MaxValue};height:100`" strokecolor=`"#336699`"><v:fill type=`"gradient`" angle=`"0`" color=`"#C4CCC7`" color2=`"white`" /></v:rect><v:rect class=`"vmlimage`" style=`"top:2;left:1;width:{Value};height:99`" strokecolor=`"{GraphColorEnd}`"><v:fill type=`"gradient`" angle=`"270`" color=`"{GraphColorStart}`" color2=`"{GraphColorEnd}`" /></v:rect><v:rect style=`"top:-70;left:{TextStartPos};width:{MaxValue};height:50`" filled=`"false`" stroked=`"false`" textboxrect=`"top:19;left:1;width:{MaxValue};height:30`"><v:textbox style=`"color:{TextColor};`" inset=`"20px, 10px, 28px, 177px`">{ValueDisplay}</v:textbox></v:rect></v:group></span>"
$Image = @{
		"Red" = "<font face=`"Webdings`" color=`"Red`">n </font>";
		"Yellow" = "<font face=`"Webdings`" color=`"Orange`">n </font>";
		"Green" = "<font face=`"Webdings`" color=`"Green`">n </font>";
		}

Function Run-DataCollectorSetFromXML(
	[string] $Name,
	[string] $PathToXML,
	[string] $DestinationFolder,
	[int] $NumberOfSecondsToRun = 60,
	$PerfMonCollectorStrings)
{
	if (Test-Path $PathToXML) 
	{
		[xml] $DataCollectorXML = Get-Content $PathToXML

		$DataCollectorXML.DataCollectorSet.RootPath = $DestinationFolder
		$DataCollectorXML.DataCollectorSet.Duration = $NumberOfSecondsToRun.ToString()

		$DataCollectorSet = New-Object -ComObject PLA.DatacollectorSet

		if ($DataCollectorSet -is [System.__ComObject])
		{
			$Error.Clear()
			
			$DataCollectorSet.SetXml($DataCollectorXML.Get_InnerXML()) | Out-Null
			$DataCollectorSet.Commit($Name, $null , 0x0003) | Out-Null
			$DataCollectorSet.Query($Name,$null) | Out-Null
			$DataCollectorSet.start($false) | Out-Null
			
			If (($DataCollectorSet -ne $null) -and ($Error.Count -eq 0))
			{
			
				Start-Sleep -Seconds $NumberOfSecondsToRun
				
				Write-DiagProgress -Activity $PerfMonCollectorStrings.ID_PerfMonSystemPerf -Status $PerfMonCollectorStrings.ID_PerfMonSystemPerfObtaining
				
				if ($DataCollectorSet.Status -eq 1) {$DataCollectorSet.Stop($false)}
				
				$retries = 0
				do 
				{
					$retries++
					Start-Sleep -Milliseconds 500
				} while (($DataCollectorSet.Status -ne 0) -and ($retries -lt 1800) -and ($DataCollectorSet.Status -ne $null)) #Wait for up to 15 minutes for the report to finish
			
				"Retries: $retries. Maximum retries: 1800. DataCollectorSet.Status: " + ($DataCollectorSet.Status) | WriteTo-StdOut -ShortFormat
			
				$OutputLocation = $DataCollectorSet.OutputLocation
			
				$DataCollectorSet.Delete()
		
				Write-DiagProgress -Activity $PerfMonCollectorStrings.ID_PerfMonSystemPerf -Status $PerfMonCollectorStrings.ID_PerfMonSystemPerfAnalyzing
				
				Return $OutputLocation
			} 
			else 
			{
				"An error has ocurred to create the following Data Collector Set:"  | WriteTo-StdOut -ShortFormat
				"Name: $Name"  | WriteTo-StdOut -ShortFormat
				"XML: $PathToXML"  | WriteTo-StdOut -ShortFormat
			}
		}
		else
		{
			"[DataCollectorSet is Null] An error has ocurred to create the following Data Collector Set:" | WriteTo-StdOut -ShortFormat
			"Name: $Name"  | WriteTo-StdOut -ShortFormat
			"XML: $PathToXML"  | WriteTo-StdOut -ShortFormat
		}

	} else {
		$PathToXML + " does not exist. Exiting..."  | WriteTo-StdOut -ShortFormat
	}
}

Function Get-StringTranslation([xml] $ReportXML, [string] $Value) 
{
	if ($Value.Length -gt 0)
	{
		$TranslatedString = $ReportXML.SelectSingleNode("//String[@ID='$Value']").Get_InnerText()
		if ($TranslatedString -ne $null) 
		{
			$TranslatedString
		} else {
			$Value
		}
	}
	else
	{
		return ""
	}
}

Function Add-SummaryToReport([string] $PathToXML, [boolean] $AddHighCPUProcesses = $true, [switch] $DoNotAddURLForPerfmonFiles, $ShowProcessesInReport, $ProcessesSectionTitle)
{
	#Open the PLA report.xml, obtain the header and add this information to the WTP Report
	if (Test-Path $PathToXML)
	{
		[xml] $ReportXML = Get-Content $PathToXML

		#Summary (Resource Overview) and Warnings
		foreach ($Table in $ReportXML.SelectNodes("/Report/Section[@name='advice']/Table"))
		{
			$Item_Summary = new-object PSObject
			$HTMTable  = $null
			#Resource Overview
			if ($Table.name -eq "sysHealthSummary") { 
				[Array] $Header = $null
				
				foreach ($Item in $Table.SelectNodes("Header"))
				{
					#$Header += "<tr>"
					foreach ($Data in $Item.SelectNodes("Data")) 
					{
						if ($Data.name -ne $null)
						{
						#if ($Data.name -ne "SysHealthComponentHdr") {
							$DataDisplayValue = Get-StringTranslation -ReportXML $ReportXML -Value $Data.name
							$Header += $DataDisplayValue
						#}
						}
					}
					#$Header += "</tr>"
				}
				
				foreach ($Item in $Table.SelectNodes("Item"))
				{
					$HTMTable += "<table>"
					$x = -1
					foreach ($Data in $Item.SelectNodes("Data")) 
					{	
						$x++
						if ($Data.name -eq "component") {
							$Component = Get-StringTranslation -ReportXML $ReportXML -Value $Data.Get_InnerText()
						} else {
							$DataDisplayValue = ""
							if ($Data.HasAttribute("img"))
							{
								$img = $Data.img
								$DataDisplayValue += $Image.$img
							}
		
							if ($Data.HasAttribute("translate")) 
							{
								#Need to translate String
								$DataDisplayValue += Get-StringTranslation -ReportXML $ReportXML -Value $Data.Get_InnerText()
							} else {
								$DataDisplayValue += $Data.Get_InnerText()
							}						
							
							if ($Data.HasAttribute("units")) 
							{
								$DataDisplayValue += $Data.units
							}	
							
							$HTMTable += "<tr><td>" + $Header[$x] + "</td><td>" + $DataDisplayValue + "</td></tr>"
						}
					}
					$HTMTable += "</table>"
					if ($HTMTable -ne $null) {
						add-member -inputobject $Item_Summary  -membertype noteproperty -name $Component -value $HTMTable
					}
					$HTMTable = $null
				}
			}
			
			
			if ($Table.name -eq "warning")
			{
				if ($Table.ChildNodes.Count -gt 0) 
				{
					#There is a warning on the report. Flag the Root Cause.
					
					$XMLFileName = [System.IO.Path]::GetFullPath("..\PerfmonReport.XML")
					
					"There are one or more alerts on perfmon xml file. RC_PerformanceMonitorWarning will be set. Report saved to $XMLFileName" | WriteTo-StdOut					
					$RootCauseDetected = $true
					#Make a copy of Perfmon XML file so the Resolver can display Warning information.
					$ReportXML.Save($XMLFileName)
				}
			}
		}
		
		if ($RootCauseDetected)
		{
			Update-DiagRootCause -Id "RC_PerformanceMonitorWarning" -Detected $true -Parameter @{"XMLFileName"=$XMLFileName}
		}
		
		#CPU
		$ID =  (Get-StringTranslation -ReportXML $ReportXML -Value $Table.ParentNode.name)
		$Item_Summary | ConvertTo-Xml2 | update-diagreport -id ("10_$ID") -name "Performance Monitor Overview" -verbosity informational

		if ($AddHighCPUProcesses -or ($ShowProcessesInReport -ne $null)) {
			$Processes = @()
			$MaxValue = 0
			foreach ($Item in $ReportXML.SelectNodes("/Report/Section[@name='tracerptCpusection']/Table[@name='imageStats']/Item[Data[@name='image']]"))
			{
				$ProcessName = $Item.SelectSingleNode("Data[@name='image']").Get_InnerText()
				[int]  $ProcessID = $Item.SelectSingleNode("Data[@name='pid']").Get_InnerText()
				[double] $ProcessCPU = $Item.SelectSingleNode("Data[@name='cpu']").Get_InnerText()
				$MaxValue += $Item.SelectSingleNode("Data[@name='cpu']").Get_InnerText()
				if ($ProcessID -ne 0) { #Skip Idle
					$process = @{ProcessName = $ProcessName; ProcessID = $ProcessID; ProcessCPU = $ProcessCPU}
					$Processes = $Processes + $process
				}
			}
		}
		
		if ($AddHighCPUProcesses) {
			
			$TopCPU_Summary = new-object PSObject
			
			foreach ($Process in $Processes | Sort-Object -Property {$_.ProcessCPU} -Descending | Select-Object -First 3)
			{
			
				$ValueDisplay = ("{0:N1}" -f $Process.ProcessCPU + "%")
				$GraphValue = $Process.ProcessCPU
				if (($GraphValue/$MaxValue) -lt .15)
				{
					$TextStartPos = $GraphValue
					$TextColor = "Gray"
				} else {
					$TextStartPos = 1
					$TextColor = "white"
				}
				
				$Graph = $ProcGraph -replace "{MaxValue}", "$MaxValue" -replace "{ValueDisplay}", "$ValueDisplay" -replace "{Value}", $GraphValue -replace "{GraphColorStart}", "#00336699" -replace "{GraphColorEnd}", "#00538CC6" -replace "{TextStartPos}", $TextStartPos -replace "{TextColor}", $TextColor
				add-member -inputobject $TopCPU_Summary -membertype noteproperty -name ($Process.get_Item("ProcessName") + " (PID " + $Process.get_Item("ProcessID") + ")") -value $Graph
			}
			
			#if (-not $DoNotAddURLForPerfmonFiles.IsPresent)
			#{
				#add-member -inputobject $TopCPU_Summary -membertype noteproperty -name "More Information" -value "For the information, please open the <a href= `"`#" + $OutputFile + "`">" + "Performance Monitor Report</a>."
			#}
			
			$TopCPU_Summary | ConvertTo-Xml2 | update-diagreport -id ("11_TopCPUProcesses") -name "Process Monitor Top Processes (CPU)" -verbosity informational
		}

		if ($ShowProcessesInReport -ne $null)
		{
			$ShowProcesses_Summary = new-object PSObject
			$ProcessAdded = $false
			foreach ($Process in $Processes | Sort-Object -Property {$_.ProcessCPU} -Descending)
			{
				$ShowProcess = $false
				foreach ($processToShow in $ShowProcessesInReport)
				{
					if (($processToShow -like ($Process.ProcessName + "*")) -or ($processToShow -eq $Process.ProcessID))
					{
						$ShowProcess = $true
					}
				}
				
				if ($ShowProcess)
				{	
					$ProcessAdded = $true
					$ValueDisplay = ("{0:N1}" -f $Process.ProcessCPU + "%")
					$GraphValue = $Process.ProcessCPU
					if (($GraphValue/$MaxValue) -lt .15)
					{
						$TextStartPos = $GraphValue
						$TextColor = "Gray"
					} else {
						$TextStartPos = 1
						$TextColor = "white"
					}
					
					$Graph = $ProcGraph -replace "{MaxValue}", "$MaxValue" -replace "{ValueDisplay}", "$ValueDisplay" -replace "{Value}", $GraphValue -replace "{GraphColorStart}", "#00336699" -replace "{GraphColorEnd}", "#00538CC6" -replace "{TextStartPos}", $TextStartPos -replace "{TextColor}", $TextColor
					add-member -inputobject $ShowProcesses_Summary -membertype noteproperty -name ($Process.get_Item("ProcessName") + " (PID " + $Process.get_Item("ProcessID") + ")") -value $Graph
				}
			}
			if ($ProcessAdded -eq $true)
			{
			$ShowProcesses_Summary | ConvertTo-Xml2 | update-diagreport -id ("11_CPUProcesses") -name $ProcessesSectionTitle -verbosity informational	
			}	
		}
	}
	else
	{
		"Error: $PathToXML does not exist" | WriteTo-StdOut
	}
}

Function AddPropertiestoXMLNode($WMIObject, $XMLNode)
{
	Foreach ($WMIProperty in $WMIObject | Get-Member -type *Property | Where-Object {$_.Name.StartsWith("__") -eq $false})
	{
		$PropertyValue = $WMIObject.($WMIProperty.Name)
		if ($PropertyValue -ne $null)
		{
			$XMLNode.SetAttribute($WMIProperty.Name.ToString(),$PropertyValue.ToString())
		}
		else
		{
			$XMLNode.SetAttribute($WMIProperty.Name.ToString(),'')
		}
	}
	return $XMLNode
}

Function CleanACLOnPerfmonFolder($DestinationFolderName)
{
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $Error[0]
		$Error.Clear()
		continue
	}
	
	$Error.Clear()	
	$SysmonAccount = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysmonLog").ObjectName
	if ($SysmonAccount -ne $null)
	{
		"Performance Monitor Account: [$SysmonAccount]. Setting permissions to output folder" | WriteTo-StdOut
		
		$FullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
		$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ObjectInherit, "ContainerInherit"
		$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None

		$objType =[System.Security.AccessControl.AccessControlType]::Allow 
		
		$rule=new-object System.Security.AccessControl.FileSystemAccessRule($SysmonAccount,$FullControl,$InheritanceFlag, $PropagationFlag, $objType)

		$ACL = Get-Acl $DestinationFolderName
		$ACL.SetAccessRule($rule)

		Set-Acl -Path $DestinationFolderName -AclObject $ACL
	}
	else
	{
		"Error: Unable to find account name for SysmonLog. Folder permissions will not be set" | WriteTo-StdOut
	}
}

Function DumpBasicSysInfoToXML($OutputFileName)
{
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $Error[0]
		$Error.Clear()
		continue
	}
	$Error.Clear()
	
	#Collect Win32_OperatingSystem and Win32_ComputerSystem classes for use with Cave/Perfmon plug-in
	
	[xml] $OutputXML = "<WmiDataCollection><WmiData ClassName=`"Win32_ComputerSystem`"><Record MachineName=`"$Computername`"/></WmiData><WmiData ClassName=`"Win32_OperatingSystem`"><Record MachineName=`"$Computername`"/></WmiData></WmiDataCollection>"
	
	$CSWMI = Get-WmiObject Win32_ComputerSystem
	$CSNode = $OutputXML.WmiDataCollection.SelectSingleNode("WmiData[@ClassName='Win32_ComputerSystem']/Record[@MachineName='$Computername']")
	
	$CSNode = AddPropertiestoXMLNode -WMIObject $CSWMI -XMLNode $CSNode
	
	$OSWMI = Get-WmiObject Win32_OperatingSystem
	$OSNode = $OutputXML.WmiDataCollection.SelectSingleNode("WmiData[@ClassName='Win32_OperatingSystem']/Record[@MachineName='$Computername']")
	
	$OSNode = AddPropertiestoXMLNode -WMIObject $OSWMI -XMLNode $OSNode
	
	$OutputXML.Save($OutputFileName)
}

#********************************
#     Script Starts Here
#********************************

$DestinationFolderName = Join-Path $PWD.Path "Perfmon"
if ((Test-Path ($DestinationFolderName)) -ne $true) { md $DestinationFolderName } 

if ($OSVersion.Major -ge 6) #Vista+
{
	if ($CollectPerfmonDataFrom -eq $null) #We need to run a Data Collector Set
	{
		$DataCollectorName = "CTS Performance Troubleshooter"
		
		if (Test-Path (Join-Path $PWD.Path $DataCollectorSetXMLName))
		{
			$DataCollectorSetXMLName = (Join-Path $PWD.Path $DataCollectorSetXMLName)
		}
		
		if ([System.IO.File]::Exists($DataCollectorSetXMLName))
		{
			$DataCollectorSetXMLName = [System.IO.Path]::GetFullPath($DataCollectorSetXMLName)
			
			$DataCollectorSetPath = Run-DataCollectorSetFromXML -Name $DataCollectorName -DestinationFolder $DestinationFolderName -PathToXML ($DataCollectorSetXMLName) -NumberOfSecondsToRun $NumberOfSeconds -PerfMonCollectorStrings $PerfMonCollectorStrings
			if ($DataCollectorSetPath.Count -gt 0)
			{
				$DataCollectorSetPath = $DataCollectorSetPath[$DataCollectorSetPath.Count -1]
			}
			if($debug -eq $true){[void]$shell.popup("DCS Path: $DataCollectorSetPath")}
			
		} else {
			"ERROR: $DataCollectorSetXMLName was not found !!" | WriteTo-StdOut
		}
		
	} else {
		$DataCollectorSetPath = $CollectPerfmonDataFrom
		$DestinationFolderName = $CollectPerfmonDataFrom
	}

	if (-not $DoNotCollectPerfmonFiles.IsPresent) 
	{
		Add-SummaryToReport -PathToXML ([System.IO.Path]::Combine($DataCollectorSetPath, "Report.XML")) -AddHighCPUProcesses (-not $DoNotShowTOPProcesses.IsPresent) -ShowProcessesInReport $ShowProcessesInReport -ProcessesSectionTitle $ProcessesSectionTitle
		
		CollectFiles -filesToCollect "$DestinationFolderName\report.html" -renameOutput $true -fileDescription "Performance Monitor Report" -sectionDescription "System Performance Monitor"
		CollectFiles -filesToCollect "$DestinationFolderName\*.blg" -renameOutput $true -fileDescription "Performance Monitor Log" -sectionDescription "System Performance Monitor"

	} else {
		Add-SummaryToReport -PathToXML ([System.IO.Path]::Combine($DataCollectorSetPath, "Report.XML")) -AddHighCPUProcesses (-not $DoNotShowTOPProcesses.IsPresent) -DoNotAddURLForPerfmonFiles -ShowProcessesInReport $ShowProcessesInReport -ProcessesSectionTitle $ProcessesSectionTitle
	}

}
else
{
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $Error[0]
		$Error.Clear()
		continue
	}
	$Error.Clear()
	
	# Windows Server 2003/ Windows XP - run via Logman
	
	$PerfmonCounters = @"
\Cache\*
\Memory\*
\Network Interface(*)\*
\Objects\*
\Paging File(*)\*
\PhysicalDisk(*)\*
\Process(*)\*
\Processor(*)\*
\Redirector\*
\Server Work Queues(*)\*
\Server\*
\System\*
\LogicalDisk(*)\*
"@
	$PerfmonConfigPath = Join-Path $DestinationFolderName "PerfMonCounters.Config"
	$PerfmonCounters | Out-File $PerfmonConfigPath -Encoding "ASCII"
	
	$OutputFileName = Join-Path $DestinationFolderName ($ComputerName + "_Perfmon.blg")
	
	CleanACLOnPerfmonFolder $DestinationFolderName
	
	$CounterLogName = "SDPPerfmon_" + (Get-Random)
	
	"Starting logman and waiting for one minute..." | WriteTo-StdOut -ShortFormat

	$CommandToRun = "logman.exe create counter -n $CounterLogName -cf `"$PerfmonConfigPath`" -f bincirc -max 512 -si 3 -rf 00:01:00 -v mmddhhmm -o `"$OutputFileName`""
	RunCMD -commandToRun $CommandToRun -collectFiles $false
	
	sleep -Seconds 61
	
    "Stopping Perfmon Counter Log." | WriteTo-StdOut -ShortFormat
    Write-DiagProgress -Activity $PerfMonCollectorStrings.ID_PerfMonSystemPerf -Status $PerfMonCollectorStrings.ID_PerfMonSystemPerfObtaining
	
	$CommandToRun = "logman.exe stop $CounterLogName"
	RunCMD -commandToRun $CommandToRun -collectFiles $false

	sleep -Seconds 3
	
	$CommandToRun = "logman.exe delete -n $CounterLogName"
	RunCMD -commandToRun $CommandToRun -collectFiles $false
	
	CollectFiles -filesToCollect "$DestinationFolderName\*.blg" -fileDescription "Performance Monitor Log" -sectionDescription "Performance Monitor Logs"
}

$BasicMachineInfoXMLPath = Join-Path $PWD.Path "MachineInfo.xml"
DumpBasicSysInfoToXML $BasicMachineInfoXMLPath 
CollectFiles -filesToCollect $BasicMachineInfoXMLPath -renameOutput $true -fileDescription "Machine basic configuration XML" -sectionDescription "Additional Files" -Verbosity Debug

# SIG # Begin signature block
# MIIa9AYJKoZIhvcNAQcCoIIa5TCCGuECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqMHeqmilFKkSN55GgWVlTwGD
# 88KgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNwwggTY
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfUwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFG3W
# xlZFDU45Em6Qgfjy4A83mzHgMIGUBgorBgEEAYI3AgEMMYGFMIGCoGiAZgBDAFQA
# UwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwA
# XwBUAFMAXwBQAGUAcgBmAG0AbwBuAFMAeQBzAHQAZQBtAFAAZQByAGYALgBwAHMA
# MaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQBzeAWx
# xJ7+Ze6Hx/JAeh/++4kUU1r3bf4ILHzZsIH14+S70CcBJAWIyzd7VpREf3Ru1USH
# N3q0eGMO6oK0zjiSpKCWm5RBo3EuD/V6O07NIIb9+IwGCP3aRhewH0sHTBrf4PQf
# P7N9QcY+ndKYVBEde0LbkeDOcS1Kg/KXDpTg7TFruDWW1U74qrKe4x2+YusDSWev
# DzJE5+yyonKlerYQgM4VEZJK/wHNgMO1GEEajRK8TlJDG7dLZWkc97tvyeNYd6sE
# rdfeNspoiZorRuzTYUtzAF7mP2e9o8yeLr7P5/86tOfNyUDTRBylUvq5Bwcr4aEQ
# DeNGPDFa2b1bhyXboYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAAEyh6E3MtHR7OwAAAAAATDAJBgUr
# DgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMTQxMDIwMTgwODQwWjAjBgkqhkiG9w0BCQQxFgQUquXOhBkspD2xfEeXz6Pp
# Qta2ufUwDQYJKoZIhvcNAQEFBQAEggEARfBa5swwFx2z7AS+CgEwqTHxycPoXlgo
# QWhACSp1ff4GqMKAW3f91JJDjlw8fZ1SzEXfxEdOYiQmQXKg0jemrK9NkTuvwoEI
# NoOuIVuwedyE44LHYO2Gyh0XJDjTmUKrcPcZ1irmDgTN/9kL2KtkjMQ/bFRaAGgU
# Bh3xIxpWudYj4tV+iqVvBL+gNJAWaHrvvZYFfC3FSUV5XCGzJk08f6RkkDUEFHjQ
# 0V7XllFfRweqbZCniP1xP8VT7LqC77gpfXYGCELJg/6Ah3tZ5waEglygdo0066Tp
# P9b/BteeQPE1NQfmt2K/chTV1YTV/knP2m7Bha1FWWJEjqyCp6LZlQ==
# SIG # End signature block
