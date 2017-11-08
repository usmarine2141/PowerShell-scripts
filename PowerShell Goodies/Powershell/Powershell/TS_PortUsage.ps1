#************************************************
# TS_PortUsage.PS1
# Version 1.0.1
# Date: 07-10-2009
# VBScript by Craig Landis (clandis@microsoft.com) and Clint Huffman (clinth@microsoft.com)
# PS1 by Andret Teixeira
# Description: This script outputs the number of unique local TCP ports in use (above the starting 
#              port) for each IP address and process on this computer. High numbers of unique 
#              local ports in use may reveal ephemeral port exhaustion which can cause failures
#              in applications and OS components that use TCP. If a large number of these ports
#              are in use then a warning is displayed. (Current version only writes to text file)
#************************************************
#Last Updated Date: 06-28-2012
#Updated By: Vincent Ke     v-zuke@microsoft.com
#Description: Import the logic of PortUsage.VBS in order to remove the calling to that external VB Script.
#************************************************

Param($Prefix = '', $Suffix = '')
if($debug -eq $true){[void]$shell.popup("Run TS_PortUsage.ps1")}

Import-LocalizedData -BindingVariable PortUsageStrings
Write-DiagProgress -Activity $PortUsageStrings.ID_PortUsage -Status $PortUsageStrings.ID_PortUsageObtaining

$RuleApplicable = $false
$PublicContent = "http://blogs.technet.com/askds/archive/2008/10/29/port-exhaustion-and-you-or-why-the-netstat-tool-is-your-friend.aspx"
$Visibility = "4"
$InformationCollected = new-object PSObject


$OutputFile = join-path $pwd.path ($ComputerName + "_" + $Prefix + "PortUsage" + $Suffix + ".txt")

#******************Variables****************************
$Script:DefaultStartPort = 0
$Script:DefaultNumberOfPorts = 0
$Script:StartPort = 1025
$Script:NumberOfPorts = 0
$Script:IsVistaOr2008 = $false

$Script:MaxUserPort = $null
$Script:MaxUserPortDefined = $true
$Script:TcpTimedWaitDelay = $null
$Script:TcpTimedWaitDelayDefault = 120
$Script:TcpTimedWaitDelayDefined = $true
$Script:ReservedPorts = $null
$Script:TcpipPort = $null
$Script:DcTcpipPort = $null
$Script:RPCTcpipPortAssignment = $null
$Script:top3Processes = $null

$Script:htLocalAddress = @{}
$Script:htProcessName = @{}
$Script:htPortProcess = @{}

$Script:EphemeralPort80 = $false
$Script:EphemeralPort50 = $false

$newline = "`r`n"
$MORE_INFORMATION = " **** Your computer may be running out of ephemeral ports ****" + $newline + $newline +
	" For more information see the following articles: " + $newline + $newline +
	" Avoiding TCP/IP Port Exhaustion" + $newline + 
	" http://msdn2.microsoft.com/en-us/library/aa560610.aspx" + $newline + $newline + 
	" When you try to connect from TCP ports greater than 5000 you receive the error WSAENOBUFS (10055)" + $newline + 
	" http://support.microsoft.com/kb/196271"

$ADDITIONAL_INFORMATION = " Additional Information:" + $newline +
	" =======================" + $newline + $newline + 
	" MaxUserPort" + $newline +
	" http://technet.microsoft.com/en-us/library/cc758002.aspx" + $newline + $newline +
	" TcpTimedWaitDelay" + $newline + 
	" http://technet.microsoft.com/en-us/library/cc757512.aspx" + $newline + $newline + 
	" ReservedPorts" + $newline + 
	" http://support.microsoft.com/kb/812873" + $newline + $newline + 
	" DCTcpipPort & TCP/IP Port" + $newline + 
	" http://support.microsoft.com/kb/224196" + $newline + $newline + 
	" RPC TCP/IP Port Assignment" + $newline + 
	" http://support.microsoft.com/kb/319553" + $newline + $newline + 
	" Port Exhaustion blog post" + $newline + 
	" http://blogs.technet.com/askds/archive/2008/10/29/port-exhaustion-and-you-or-why-the-netstat-tool-is-your-friend.aspx"


#************************************************
# Data Gathering
#************************************************

function AppliesToSystem {
	if( (($OSVersion.Major -eq 5) -and ($OSVersion.Minor -eq 2)) -or	#Windows Server 2003
	    (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 0)) -or 	#Vista, 2008
		(($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 1)) -or	#Win7, 2008 R2
		(($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 2)) ) {	#Win8, 2012
		return $true
	}
	else {
		return $false
	}
}

#check the machine is server media or not
function isServerMedia {
	$Win32OS = Get-WmiObject -Class Win32_OperatingSystem
	
	if (($Win32OS.ProductType -eq 3) -or ($Win32OS.ProductType -eq 2)) { #Server Media
		return $true
	}
	else {
		return $false
	}
}

function GetTcpPortRange() {
	#get default tcp port range
	if( (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 0)) -or    #Vista/Server 2008  
		(($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 1)) -or	#Win7, 2008 R2
		(($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 2)) ) {	#Win8, 2012
		$Script:DefaultStartPort = 49152
		$Script:DefaultNumberOfPorts = 16384
		$Script:IsVistaOr2008 = $true
	}
	else {
		$Script:DefaultStartPort = 1025
		$Script:DefaultNumberOfPorts = 3976
		$Script:IsVistaOr2008 = $false
	}
	
	if($Script:IsVistaOr2008) {
		#get actual tcp port range

		$CommandLineToExecute = $Env:windir + "\system32\cmd.exe /c netsh interface ipv4 show dynamicportrange tcp"
		"Running $CommandLineToExecute" | WriteTo-StdOut -shortformat
		$content = Invoke-Expression $CommandLineToExecute
		"Finished $CommandLineToExecute" | WriteTo-StdOut -shortformat

		#because the output of netsh will be localized, so we can't use "Start Port", etc. instead, we use the line number to select string.
		#In english language, the output is like:
		#
		#Protocol tcp Dynamic Port Range
		#---------------------------------
		#Start Port      : 1025
		#Number of Ports : 64510
		#
		if($content.Length -ge 4)	
		{
			$line = $content[3]
			if(($line -ne $null) -and ($line.IndexOf(':') -ge 0)) {
				$Script:StartPort = [int]$line.Split(':')[1].Trim()
			}
			$line = $content[4]
			if(($line -ne $null) -and ($line.IndexOf(':') -ge 0)) {
				$Script:NumberOfPorts = [int]$line.Split(':')[1].Trim()
			}
		}
	}
}

function GetRegistryValues() {
	$tcpParamsKey = "HKLM:SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
	$ntdsParamsKey = "HKLM:SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
    $ntfrsParamsKey = "HKLM:SYSTEM\CurrentControlSet\Services\NTFRS\Parameters"
	
	if(Test-Path $tcpParamsKey) {
		$properties = Get-ItemProperty -Path $tcpParamsKey
		$Script:MaxUserPort = $properties.MaxUserPort
		$Script:TcpTimedWaitDelay = $properties.TcpTimedWaitDelay
		$Script:ReservedPorts = $properties.ReservedPorts
	}
	
	if(Test-Path $ntdsParamsKey) {
		$properties = Get-ItemProperty -Path $ntdsParamsKey
		$Script:TcpipPort = $properties.{TCP/IP Port}
		$Script:DcTcpipPort = $properties.{DCTcpipPort}
	}
	
	if(Test-Path $ntfrsParamsKey) {
		$Script:RPCTcpipPortAssignment = (Get-ItemProperty -Path $ntfrsParamsKey).{RPC TCP/IP Port Assignment}
	}
	
	if($Script:MaxUserPort -eq $null) {
		$Script:MaxUserPort = 5000
		$Script:MaxUserPortDefined = $false
	}
	if(-not $Script:IsVistaOr2008) {
		$Script:NumberOfPorts = $Script:MaxUserPort - 1024
	}
	
	if($Script:TcpTimedWaitDelay -eq $null) {
		$Script:TcpTimedWaitDelay = 120
		$Script:TcpTimedWaitDelayDefined = $false
	}

	if($Script:StartPort -eq 0) {
		$Script:StartPort = $Script:DefaultStartPort
	}
	if($Script:NumberOfPorts -eq 0) {
		$Script:NumberOfPorts = $Script:DefaultNumberOfPorts
	}
}

# Get Processes and get the related service names for svchost process 
function GetProcessWithSvcService() {
	"Obtaining win32 service list" | WriteTo-StdOut -shortformat
	$svc = Get-WmiObject win32_service | sort ProcessId | group-Object ProcessId 

	"Obtaining process list" | WriteTo-StdOut -shortformat
	$ps = @(Get-Process | sort Id) 

	"Add service group to each process" | WriteTo-StdOut -shortformat
	$i=0
	$j=0
	while($i -lt $ps.count -and $j -lt $svc.count) { 
		if($ps[$i].Id -lt $svc[$j].Name) { 
			$i++;
			continue;
		}
		if($ps[$i].id -gt $svc[$j].Name) {
			$j++;
			continue;
		}
   		if($ps[$i].id -eq $svc[$j].Name) {
			$ps[$i] | add-Member NoteProperty service $Svc[$j].group;
			$i++;
			$j++;
		}
	}
	return $ps;
}

function GetProcessNameWithSvcService($process) {
	$services = ""
	foreach($item in $process.service) {
		if($services -ne "") {
			$services += ", "
		}
		$services += $item.Name
	}
	if($services -ne "") {
		$services = "{" + $services + "}"
	}
	return $process.ProcessName + $services
}

function GetTcpPortUsage() {
	"Running netstat -ano -p tcp" | WriteTo-StdOut -shortformat
	$CommandLineToExecute = $Env:windir + "\system32\cmd.exe /c netstat -ano -p tcp"
	$content = Invoke-Expression $CommandLineToExecute | Select-String "TCP"

	$processes = GetProcessWithSvcService
	
	"Format process information" | WriteTo-StdOut -shortformat
	$regex = [regex]"[^\s]+"
	foreach($line in $content) {
		#data format: 
		# TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1056
		# TCP    [::]:135               [::]:0                 LISTENING       1056
		$arr = $regex.Matches($line) | Select-Object -Property Value
		$localIPAddress = $arr[1].Value
		$localIP = $localIPAddress.Substring(0, $localIPAddress.LastIndexOf(':')).Trim('[', ']')
		$localPort = $localIPAddress.Substring($localIPAddress.LastIndexOf(':') + 1)
		$processid = $arr[4].Value
		$process = $processes | Where-Object { $_.Id -eq $processid }
		if($process -ne $null) {
			if($process.ProcessName -eq "svchost") {
				$processName = GetProcessNameWithSvcService($process)
			}
			else {
				$processName = $process.ProcessName
			}
			$processNameWithPID = $processName + ' [' + $process.Id + ']'
		}
		else {
			$processName = ""
			$processNameWithPID = ""
		}
		
		$Script:htPortProcess[$localPort] = $processName
		if(([int]$localPort) -ge $Script:StartPort) {	#The original VBS use localPort > startPort, I think it's a defect and should be localPort >= startPort, because afterwards it will show data: " Local Address : Number Of Ports Above " & intStartPort - 1
			$Script:htLocalAddress[$localIP]++
			$Script:htProcessName[$processNameWithPID]++
		}
	}
}

function GetDfsrConfigData() {
	"Get DFSR machine configuration data" | WriteTo-StdOut -shortformat
	$content = ""
	$rpcPortAssignments = Get-WmiObject -query "SELECT RpcPortAssignment FROM DfsrMachineConfig" -namespace "root\MicrosoftDFS" -ErrorAction SilentlyContinue
	if($rpcPortAssignments -ne $null) {
		$content += $newline + $newline + " DFSR RPC Port Assignment"
    	$content += $newline + " ===================================================================="
		foreach($item in $rpcPortAssignments) {
			$itemRPCPort = $item.RpcPortAssignment
			if($itemRPCPort -eq 0) {
				$content += $newline+ $newline + " No static RPC port is defined for DFSR (RpcPortAssignment = " + $itemRPCPort + ")."
			}
			elseif($itemRPCPort -eq 5722) {
				$content += $newline + $newline + " DFSR is using the static RPC port " + $itemRPCPort + " (RpcPortAssignment = " + $itemRPCPort + ")."
            	$content += $newline + $newline + " Windows Server 2008 R2 and Windows Server 2008 domain controllers use port 5722 by default for DFSR. See Bemis 2015519 for more information."
			}
			else {
				$content += $newline + $newline + " DFSR is using the static RPC port " + $itemRPCPort + " (RpcPortAssignment = " + $itemRPCPort + ")."
			}
		}
		
		$content += $newline + $newline + " Related registry values:"
		$content += $newline + " ========================"
		$content += $newline + $newline + "  HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
		if($Script:IsVistaOr2008) {
			$content += $newline + "    MaxUserPort = (value has no effect on Vista/2008)"
			$content += $newline + "    ReservedPorts = (value has no effect on Vista/2008)"
		}
		else {
			if($Script:MaxUserPortDefined) {
				$content += $newline + "    MaxUserPort = " + $Script:MaxUserPort + " (default is 5000)"
			}
			else {
				$content += $newline + "    MaxUserPort = <value not set> (default value of 5000 is in effect)"
			}
			if(($Script:ReservedPorts -eq $null) -or ($Script:ReservedPorts.Length -eq 0)) {
				$content += $newline + "    ReservedPorts = <value not set>"
			}
			else {
				$content += $newline + "    ReservedPorts = " + [string]::Join($newline + "                    ", $Script:ReservedPorts)
			}
		}
		if($Script:TcpTimedWaitDelayDefined) {
			$content += $newline + "    TcpTimedWaitDelay = " + $Script:TcpTimedWaitDelay + " (default is " + $Script:TcpTimedWaitDelayDefault + ")"
		}
		else {
			$content += $newline + "    TcpTimedWaitDelay = <value not set> (default of " + $Script:TcpTimedWaitDelayDefault + " is in effect)"
		}
		
		$content += $newline + $newline + "  HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
	    if($Script:TcpipPort -eq $null) {
			$content += $newline + "    TCP/IP Port = <value not set>"
		}
	    else {
	    	$content += $newline + "    TCP/IP Port = " + $Script:TcpipPort
		}
	    if($Script:DcTcpipPort -eq $null) {
			$content += $newline + "    DCTcpipPort = <value not set>"
		}
		else {
	    	$content += $newline + "    DCTcpipPort = " + $Script:DcTcpipPort
	    }
		$content += $newline + $newline + "  HKLM\SYSTEM\CurrentControlSet\Services\NTFRS\Parameters"
	    if($Script:RPCTcpipPortAssignment -eq $null) {
			$content += $newline + "    RPC TCP/IP Port Assignment = <value not set>"
		}
		else {
	    	$content += $newline + "    RPC TCP/IP Port Assignment = " + $Script:RPCTcpipPortAssignment
	    }
	}
	return $content
}

function OutputTCPPortUsageToFile() {
	"Output TCP port information" | WriteTo-StdOut -shortformat
	$content = "This script outputs the number of unique local TCP ports in use (above the starting port) for each IP address and process on this computer. High numbers of unique local ports in use may reveal ephemeral port exhaustion which can cause failures in applications and OS components that use TCP. If a large number of these ports are in use then a warning is displayed." + $newline + $newline
	
	#1: Local Address Information
	$content += " Local Address : Number Of Ports Above " + ($Script:StartPort - 1) + $newline
	$content += " ===========================================" + $newline
	
	# Set thresholds to check for - 50% and 80%
    $fiftyPercentOfEphemeralPorts = $Script:NumberOfPorts * 0.5
    $eightyPercentOfEphemeralPorts = $Script:NumberOfPorts * 0.8
	$criticalMessage = " ** CRITICAL: More than 80% of local ports in use. Possible ephemeral port (outbound port) exhaustion.**"
	$warningMessage = " ** WARNING: More than 50% of local ports in use. Possible high amount of ephemeral port (outbound port) usage.**"
	$localPortCount = 0
	
	foreach($key in $Script:htLocalAddress.Keys) {
		$value = $Script:htLocalAddress[$key]
		$localPortCount += $value
		$content += "  " + $key + " : " + $value
		if($value -gt $eightyPercentOfEphemeralPorts) {
			$Script:EphemeralPort80 = $true
			$content += $criticalMessage
		}
		elseif($value -gt $fiftyPercentOfEphemeralPorts) {
			$Script:EphemeralPort50 = $true
			$content += $warningMessage
		}
		$content += $newline
	}
	
	#2: Process name and number of ports used for each process
	$content += $newline + " Process Name [PID] : Number of Ports Above " + ($Script:StartPort - 1) + " (sorted descending)" + $newline
    $content += " ====================================================================" + $newline
	$sortedProcesses = $Script:htProcessName.GetEnumerator() | Sort-Object Value -descending
	$Script:top3Processes = $sortedProcesses | Select-Object -First 3
	foreach($item in $sortedProcesses) {
		#$value = $Script:htProcessName[$key]
		$content += "  " + $item.key + " : " + $item.value + $newline
	}
	$content += $newline
	$usedPortPercentage = "{0:P1}" -f ($localPortCount / $Script:NumberOfPorts)
	$content += " **** Total local ports in use: " + $localPortCount + " of " + $Script:NumberOfPorts + " (" + $usedPortPercentage + ") ****" + $newline
	if($Script:EphemeralPort80 -or $Script:EphemeralPort50) {
		$content += $newline + $MORE_INFORMATION
	}
	$content +=  $newline + " Start Port      : " + $Script:StartPort + " (default is " + $Script:DefaultStartPort + ")"
	$content +=  $newline + " Number of Ports : " + $Script:NumberOfPorts + " (default is " + $Script:DefaultNumberOfPorts + ")"

	#3: Each port and its using process
	$content +=  $newline + $newline + " Process Name: Listening Port Number (includes all ports 0-65535)"
    $content +=  $newline + " ====================================================================" + $newline
	$sortedPortProcesses = $Script:htPortProcess.GetEnumerator() | Sort-Object Value
	foreach($item in $sortedPortProcesses) {
		$content += "  " + $item.value + " : " + $item.key + $newline
	}
	
	#4 WMI DFSR config info
	if( (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 0)) -or	#Vista, See: http://msdn.microsoft.com/en-us/library/windows/desktop/dd405482(v=vs.85).aspx
		(isServerMedia)) {
		$content += GetDfsrConfigData
	}

	$content += $newline + $newline + $ADDITIONAL_INFORMATION

	"Write info to output file" | WriteTo-StdOut -shortformat
	Set-Content $OutputFile $content
	CollectFiles -filesToCollect $OutputFile -fileDescription "Ephemeral Port usage" -SectionDescription "Port Usage"
}

# **************
# Detection Logic
# **************
if(AppliesToSystem) {
	$RuleApplicable = $true
	
	GetTcpPortRange
	GetRegistryValues
	GetTcpPortUsage
	OutputTCPPortUsageToFile

	if(($Script:EphemeralPort80 -or $Script:EphemeralPort50) -and
	   ($Script:top3Processes -ne $null) -and ($Script:top3Processes.Length -eq 3)) {
		$InformationCollected | add-member -membertype noteproperty -name "Process Name [1]" -value $Script:top3Processes[0].Key
		$InformationCollected | add-member -membertype noteproperty -name "Number of ports [1]" -value $Script:top3Processes[0].Value
		$InformationCollected | add-member -membertype noteproperty -name "Process Name [2]" -value $Script:top3Processes[1].Key
		$InformationCollected | add-member -membertype noteproperty -name "Number of ports [2]" -value $Script:top3Processes[1].Value
		$InformationCollected | add-member -membertype noteproperty -name "Process Name [3]" -value $Script:top3Processes[2].Key
		$InformationCollected | add-member -membertype noteproperty -name "Number of ports [3]" -value $Script:top3Processes[2].Value
	}
}

# *********************
# Root Cause processing
# *********************
if ($RuleApplicable)
{
	if ($Script:EphemeralPort80) {
		$RootCauseName = "RC_EphemeralPort80Check"
		$Verbosity = "Error"
		$Title = $PortUsageStrings.ID_EphemeralPortDesc -replace "%XXX%", "80%"
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL $PublicContent -InformationCollected $InformationCollected -Verbosity $Verbosity -Visibility $Visibility -SolutionTitle $Title -SDPFileReference $OutputFile
	}
	elseif($Script:EphemeralPort50) {
		$RootCauseName = "RC_EphemeralPort50Check"
		$Verbosity = "Warning"
		$Title = $PortUsageStrings.ID_EphemeralPortDesc -replace "%XXX%", "50%"
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL $PublicContent -InformationCollected $InformationCollected -Verbosity $Verbosity -Visibility $Visibility -SolutionTitle $Title -SDPFileReference $OutputFile
	}
	else {	# Green Light
		$RootCauseName = "RC_EphemeralPort50Check"
		Update-DiagRootCause -id $RootCauseName -Detected $false
	}
}


# SIG # Begin signature block
# MIIa2gYJKoZIhvcNAQcCoIIayzCCGscCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU56gRYwVLPVURSDX6Ny0DsMjd
# jL2gghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTKMIIExgIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIHjMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSosZrwWn7rLDrT
# 7nT6jAWR0Em7zjCBggYKKwYBBAGCNwIBDDF0MHKgWIBWAEMAVABTAF8ATgBlAHQA
# dwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAFQAUwBfAFAA
# bwByAHQAVQBzAGEAZwBlAC4AcABzADGhFoAUaHR0cDovL21pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAWFqEdTBnIysSclrpaMBnQ2Dje5uEwvnkP3LiMbEd
# nMVBXZVipFz7yqYYxiE8GUQUs9qLPDRMmHtx5IRn6iwThXGtszZYo7FKn49cYPqn
# kC7TyMBYsmaHUgH+e6hUApScpH+e3KjNzV1R49hn1GaoCu9JpaGwvQCw5TxaPXqP
# sngQNE9s1WsgLdVx35z5ng8nk87BP1hrVCvfsAi4MpRe4yrE4HJ5AEhzNGyT/iol
# DdPdj8NJvLpoIQONANVr6W/3mu2jo/bS2ypL2hPO+dZEYhJsoMFizR/ZsrIFLGwd
# UVixILOk8lq4uVUw/rTRbEZjXcZr/EPpfDNwMyBVdqnCjKGCAigwggIkBgkqhkiG
# 9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMA
# AABa7S/05CCZPzoAAAAAAFowCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTAyMDE4MDg0MFowIwYJKoZIhvcN
# AQkEMRYEFBtUuH83RDldznzXXmP57pNp8eo+MA0GCSqGSIb3DQEBBQUABIIBALIJ
# qEd/5ZefiuaLGhxyhi0zsYXrtL/X3Nq3ceUWuk9xXtxiJpQeh6XVU8BA+qPDW6Zb
# +l4if608kBbF0wj8ImzZm4QMzQ5uFjzFAXe02qx5wB+SG/d/juAx2SjSCmsWsjm2
# ddE1atBuHtsZ+VJpzFjtkEYUidw5gUCDTQrrJomw0RFH8LrpZvjjv3xJJXnNhMsl
# 1pKsdnieDP9L7HQZwvRX49fSZXaE3Pekwxxte7x206LFdloAy+yW0SjLyYshTUiC
# tdRzaitL8SK+RquCADKL+kLz2XXeo5W0hSfFXiZso377dmlYao50KD/62BZAilLz
# PwKTHlrZFsim8J/68eE=
# SIG # End signature block
