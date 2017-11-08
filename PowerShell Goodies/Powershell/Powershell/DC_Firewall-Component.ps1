#************************************************
# DC_Firewall-Component.ps1
# Version 1.0
# Version 1.1: Altered the runPS function correctly a column width issue.
# Date: 2009, 2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects information about the Windows Firewall.
# Called from: Main Networking Diag
#*******************************************************

param(
		[switch]$before,
		[switch]$after
	)

	
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

Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_CTSFirewall -Status $ScriptVariable.ID_CTSFirewallDescription

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber


function RunNetSH ([string]$NetSHCommandToExecute="")
{
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSFirewall -Status "netsh $NetSHCommandToExecute"
	$NetSHCommandToExecuteLength = $NetSHCommandToExecute.Length + 6
	"-" * ($NetSHCommandToExecuteLength)	| Out-File -FilePath $outputFile -append
	"netsh $NetSHCommandToExecute"			| Out-File -FilePath $outputFile -append
	"-" * ($NetSHCommandToExecuteLength)	| Out-File -FilePath $outputFile -append
	$CommandToExecute = "cmd.exe /c netsh.exe " + $NetSHCommandToExecute + " >> $outputFile "
	RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
}


function RunPS ([string]$RunPScmd="", [switch]$ft)
{
	$RunPScmdLength = $RunPScmd.Length
	"-" * ($RunPScmdLength)		| Out-File -FilePath $OutputFile -append
	"$RunPScmd"  				| Out-File -FilePath $OutputFile -append
	"-" * ($RunPScmdLength)  	| Out-File -FilePath $OutputFile -append
	
	if ($ft)
	{
		# This format-table expression is useful to make sure that wide ft output works correctly
		Invoke-Expression $RunPScmd	|format-table -autosize -outvariable $FormatTableTempVar | Out-File -FilePath $outputFile -Width 500 -append
	}
	else
	{
		Invoke-Expression $RunPScmd	| Out-File -FilePath $OutputFile -append
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
}


$sectionDescription = "Firewall"


#Handle suffix of file name
	if ($before)
	{
		$suffix = "_BEFORE"
	}
	elseif ($after)
	{
		$suffix = "_AFTER"
	}
	else
	{
		$suffix = ""
	}


#W8/WS2012+
if ($bn -gt 9000)
{	
	"[info]: Firewall-Component W8/WS2012+"  | WriteTo-StdOut 

	$outputFile= $Computername + "_Firewall_info_pscmdlets" + $suffix + ".TXT"
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Firewall Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Overview"											| Out-File -FilePath $OutputFile -append
	"----------------------------------------"			| Out-File -FilePath $OutputFile -append
	"Firewall Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
	"   1. Show-NetIPsecRule -PolicyStore ActiveStore"	| Out-File -FilePath $OutputFile -append
	"   2. Get-NetIPsecMainModeSA"						| Out-File -FilePath $OutputFile -append
	"   3. Get-NetIPsecQuickModeSA"						| Out-File -FilePath $OutputFile -append
	"   4. Get-NetFirewallProfile"						| Out-File -FilePath $OutputFile -append
	"   5. Get-NetFirewallRule"							| Out-File -FilePath $OutputFile -append
	"   6. Show-NetFirewallRule"						| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Firewall Powershell Cmdlets"						| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	runPS "Show-NetIPsecRule -PolicyStore ActiveStore"		# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetIPsecMainModeSA"							# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetIPsecQuickModeSA"							# W8/WS2012, W8.1/WS2012R2	# fl				
	runPS "Get-NetFirewallProfile"							# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Get-NetFirewallRule"								# W8/WS2012, W8.1/WS2012R2	# fl
	runPS "Show-NetFirewallRule"							# W8/WS2012, W8.1/WS2012R2	# fl

	CollectFiles -filesToCollect $outputFile -fileDescription "Firewall Information PS cmdlets" -SectionDescription $sectionDescription
}


#WV/WS2008+
if ($bn -gt 6000)
{
	"[info]: Firewall-Component WV/WS2008+"  | WriteTo-StdOut 

	#----------Netsh
	$outputFile = $ComputerName + "_Firewall_netsh_advfirewall" + $suffix + ".TXT"
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Output"					| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Overview"											| Out-File -FilePath $OutputFile -append
	"----------------------------------------"			| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Output"					| Out-File -FilePath $OutputFile -append
	"   1. netsh advfirewall show allprofiles"			| Out-File -FilePath $OutputFile -append
	"   2. netsh advfirewall show allprofiles state"	| Out-File -FilePath $OutputFile -append
	"   3. netsh advfirewall show currentprofile"		| Out-File -FilePath $OutputFile -append
	"   4. netsh advfirewall show domainprofile"		| Out-File -FilePath $OutputFile -append
	"   5. netsh advfirewall show global"				| Out-File -FilePath $OutputFile -append
	"   6. netsh advfirewall show privateprofile"		| Out-File -FilePath $OutputFile -append
	"   7. netsh advfirewall show publicprofile"		| Out-File -FilePath $OutputFile -append
	"   8. netsh advfirewall show store"				| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Output"					| Out-File -FilePath $OutputFile -append
	"========================================"			| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "advfirewall show allprofiles"
	RunNetSH -NetSHCommandToExecute "advfirewall show allprofiles state"
	RunNetSH -NetSHCommandToExecute "advfirewall show currentprofile"
	RunNetSH -NetSHCommandToExecute "advfirewall show domainprofile"
	RunNetSH -NetSHCommandToExecute "advfirewall show global"
	RunNetSH -NetSHCommandToExecute "advfirewall show privateprofile"
	RunNetSH -NetSHCommandToExecute "advfirewall show publicprofile"
	RunNetSH -NetSHCommandToExecute "advfirewall show store"
	CollectFiles -filesToCollect $outputFile -fileDescription "Firewall Advfirewall" -SectionDescription $sectionDescription


	#-----WFAS export
	$filesToCollect = $ComputerName + "_Firewall_netsh_advfirewall-export" + $suffix + ".wfw"
	$commandToRun = "netsh advfirewall export " +  $filesToCollect
	RunCMD -CommandToRun $commandToRun -filesToCollect $filesToCollect -fileDescription "Firewall Export" -sectionDescription $sectionDescription 

	#-----WFAS ConSec rules (all)
	$outputFile = $ComputerName + "_Firewall_netsh_advfirewall-consec-rules" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules Output"					| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules Output"					| Out-File -FilePath $OutputFile -append
	"   1. netsh advfirewall consec show rule all any dynamic verbose"	| Out-File -FilePath $OutputFile -append
	"   2. netsh advfirewall consec show rule all any static verbose"	| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules Output"					| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	# 3/5/2013: Through feedback from Markus Sarcletti, this command has been removed because it is an invalid command:
	#   "advfirewall consec show rule name=all"
	RunNetSH -NetSHCommandToExecute "advfirewall consec show rule all any dynamic verbose"
	RunNetSH -NetSHCommandToExecute "advfirewall consec show rule all any static verbose"
	CollectFiles -filesToCollect $outputFile -fileDescription "Advfirewall ConSec Rules" -SectionDescription $sectionDescription

	
	#-----WFAS ConSec rules (active)
	# 3/5/2013: Through feedback from Markus Sarcletti, adding active ConSec rules
	$outputFile = $ComputerName + "_Firewall_netsh_advfirewall-consec-rules-active" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules (ACTIVE)"					| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules (ACTIVE)"					| Out-File -FilePath $OutputFile -append
	"   1. netsh advfirewall monitor show consec verbose"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall ConSec Rules (ACTIVE)"					| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "advfirewall monitor show consec verbose"
	CollectFiles -filesToCollect $outputFile -fileDescription "Advfirewall ConSec Rules" -SectionDescription $sectionDescription

	
	#-----WFAS Firewall rules (all)
	$outputFile = $ComputerName + "_Firewall_netsh_advfirewall-firewall-rules" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules"							| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules"							| Out-File -FilePath $OutputFile -append
	"   1. netsh advfirewall monitor show consec verbose"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules"							| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "advfirewall firewall show rule name=all"
	CollectFiles -filesToCollect $outputFile -fileDescription "Advfirewall Firewall Rules" -SectionDescription $sectionDescription

	
	#-----WFAS Firewall rules all (active)
	# 3/5/2013: Through feedback from Markus Sarcletti, adding active Firewall Rules
	$outputFile = $ComputerName + "_Firewall_netsh_advfirewall-firewall-rules-active" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules (ACTIVE)"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules (ACTIVE)"				| Out-File -FilePath $OutputFile -append
	"   1. netsh advfirewall monitor show firewall verbose"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh AdvFirewall Firewall Rules (ACTIVE)"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "advfirewall monitor show firewall verbose"
	CollectFiles -filesToCollect $outputFile -fileDescription "Advfirewall Firewall Rules" -SectionDescription $sectionDescription	

	
	
	#-----Netsh WFP	

	#-----Netsh WFP show netevents file=
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-netevents" + $suffix + ".XML"
	$commandToRun = "netsh wfp show netevents file= " +  $outputFile
	RunCMD -CommandToRun $commandToRun -filesToCollect $outputFile -fileDescription "Netsh WFP Show Netevents" -sectionDescription $sectionDescription 
	
	#-----Netsh WFP show BoottimePolicy file=
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-boottimepolicy" + $suffix + ".XML"
	$commandToRun = "netsh wfp show boottimepolicy file= " +  $outputFile
	RunCMD -CommandToRun $commandToRun -filesToCollect $outputFile -fileDescription "Netsh WFP Show BootTimePolicy" -sectionDescription $sectionDescription 

	#-----Netsh wfp show Filters file=
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-filters" + $suffix + ".XML"
	$commandToRun = "netsh wfp show filters file= " +  $outputFile
	RunCMD -CommandToRun $commandToRun -filesToCollect $outputFile -fileDescription "Netsh WFP Show Filters" -sectionDescription $sectionDescription 
	
	#-----Netsh wfp show Options optionsfor=keywords
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-options" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Options"									| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Options"									| Out-File -FilePath $OutputFile -append
	"   1. netsh wfp show options optionsfor=keywords"					| Out-File -FilePath $OutputFile -append
	"   2. netsh wfp show options optionsfor=netevents"					| Out-File -FilePath $OutputFile -append
	"   3. netsh wfp show options optionsfor=txnwatchdog"				| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Options"									| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "wfp show options optionsfor=keywords"
	RunNetSH -NetSHCommandToExecute "wfp show options optionsfor=netevents"
	RunNetSH -NetSHCommandToExecute "wfp show options optionsfor=txnwatchdog"
	CollectFiles -filesToCollect $outputFile -fileDescription "Netsh WFP Show Options" -SectionDescription $sectionDescription

	
	#-----Netsh wfp show Security netevents
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-security-netevents" + $suffix + ".TXT"
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Security Netevents"						| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Security Netevents"						| Out-File -FilePath $OutputFile -append
	"   1. netsh wfp show security netevents"							| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh WFP Show Security Netevents"						| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "wfp show security netevents"
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	CollectFiles -filesToCollect $outputFile -fileDescription "Netsh WFP Show Security NetEvents" -SectionDescription $sectionDescription






	#-----Netsh wfp show State file=
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-state" + $suffix + ".XML"
	$commandToRun = "netsh wfp show state file= " +  $outputFile
	RunCMD -CommandToRun $commandToRun -filesToCollect $outputFile -fileDescription "Netsh WFP Show State" -sectionDescription $sectionDescription 
	
	#-----Netsh wfp show Sysports file=
	$outputFile = $ComputerName + "_Firewall_netsh_wfp-show-sysports" + $suffix + ".XML"
	$commandToRun = "netsh wfp show sysports file= " +  $outputFile
	RunCMD -CommandToRun $commandToRun -filesToCollect $outputFile -fileDescription "Netsh WFP Show Sysports" -sectionDescription $sectionDescription 



	#----------Netsh
	$outputFile = $ComputerName + "_Firewall_netsh_firewall.TXT"	
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh Firewall"											| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"Overview"															| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"				| Out-File -FilePath $OutputFile -append
	"Firewall Netsh Firewall"											| Out-File -FilePath $OutputFile -append
	"   1. netsh firewall show allowedprogram"							| Out-File -FilePath $OutputFile -append
	"   2. netsh firewall show config"									| Out-File -FilePath $OutputFile -append
	"   3. netsh firewall show currentprofile"							| Out-File -FilePath $OutputFile -append
	"   4. netsh firewall show icmpsetting"								| Out-File -FilePath $OutputFile -append
	"   5. netsh firewall show logging"									| Out-File -FilePath $OutputFile -append
	"   6. netsh firewall show multicastbroadcastresponse"				| Out-File -FilePath $OutputFile -append
	"   7. netsh firewall show notifications"							| Out-File -FilePath $OutputFile -append
	"   8. netsh firewall show opmode"									| Out-File -FilePath $OutputFile -append
	"   9. netsh firewall show portopening"								| Out-File -FilePath $OutputFile -append
	"  10. netsh firewall show service"									| Out-File -FilePath $OutputFile -append
	"  11. netsh firewall show state"									| Out-File -FilePath $OutputFile -append
	"===================================================="				| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	"`n"																| Out-File -FilePath $OutputFile -append
	RunNetSH -NetSHCommandToExecute "firewall show allowedprogram"
	RunNetSH -NetSHCommandToExecute "firewall show config"
	RunNetSH -NetSHCommandToExecute "firewall show currentprofile"
	RunNetSH -NetSHCommandToExecute "firewall show icmpsetting"
	RunNetSH -NetSHCommandToExecute "firewall show logging"
	RunNetSH -NetSHCommandToExecute "firewall show multicastbroadcastresponse"
	RunNetSH -NetSHCommandToExecute "firewall show notifications"
	RunNetSH -NetSHCommandToExecute "firewall show opmode"
	RunNetSH -NetSHCommandToExecute "firewall show portopening"
	RunNetSH -NetSHCommandToExecute "firewall show service"
	RunNetSH -NetSHCommandToExecute "firewall show state"
	CollectFiles -filesToCollect $outputFile -fileDescription "Firewall" -SectionDescription $sectionDescription


	
	#----------Registry
	$outputFile= $Computername + "_Firewall_reg_" + $suffix + ".TXT"
	$CurrentVersionKeys =	"HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall",
							"HKLM\SYSTEM\CurrentControlSet\Services\BFE",
							"HKLM\SYSTEM\CurrentControlSet\Services\IKEEXT",
							"HKLM\SYSTEM\CurrentControlSet\Services\MpsSvc",
							"HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess"
	$sectionDescription = "Firewall"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -outputFile $outputFile -fileDescription "Firewall Registry Keys" -SectionDescription $sectionDescription


	#----------EventLogs
	if ( ($suffix -eq "") -or ($suffix -eq "_AFTER") )
	{
		#----------WFAS Event Logs
		$sectionDescription = "Firewall EventLogs"
		#WFAS CSR
		$EventLogNames = "Microsoft-Windows-Windows Firewall With Advanced Security/ConnectionSecurity"
		$Prefix = ""
		$Suffix = "_evt_"
		.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

		#WFAS CSR Verbose
		$EventLogNames = "Microsoft-Windows-Windows Firewall With Advanced Security/ConnectionSecurityVerbose"
		$Prefix = ""
		$Suffix = "_evt_"
		.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

		#WFAS FW
		$EventLogNames = "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall"
		$Prefix = ""
		$Suffix = "_evt_"
		.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix

		#WFAS FW Verbose
		$EventLogNames = "Microsoft-Windows-Windows Firewall With Advanced Security/FirewallVerbose"
		$Prefix = ""
		$Suffix = "_evt_"
		.\TS_GetEvents.ps1 -EventLogNames $EventLogNames -SectionDescription $sectionDescription -Prefix $Prefix -Suffix $Suffix
	}
	
} 
#Windows Server 2003
else
{
	"[info]: Firewall-Component XP/WS2003"  | WriteTo-StdOut 
	#----------Registry
	$outputFile= $Computername + "_Firewall_reg_.TXT"
	$CurrentVersionKeys =	"HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall",
							"HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess"
	$sectionDescription = "Firewall"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -outputFile $outputFile -fileDescription "Firewall Registry Keys" -SectionDescription $sectionDescription
	
	#----------Netsh
	$outputFile = $ComputerName + "_Firewall_netsh.TXT"
	RunNetSH -NetSHCommandToExecute "firewall show allowedprogram"
	RunNetSH -NetSHCommandToExecute "firewall show config"
	RunNetSH -NetSHCommandToExecute "firewall show currentprofile"
	RunNetSH -NetSHCommandToExecute "firewall show icmpsetting"
	RunNetSH -NetSHCommandToExecute "firewall show logging"
	RunNetSH -NetSHCommandToExecute "firewall show multicastbroadcastresponse"
	RunNetSH -NetSHCommandToExecute "firewall show notifications"
	RunNetSH -NetSHCommandToExecute "firewall show opmode"
	RunNetSH -NetSHCommandToExecute "firewall show portopening"
	RunNetSH -NetSHCommandToExecute "firewall show service"
	RunNetSH -NetSHCommandToExecute "firewall show state"
	CollectFiles -filesToCollect $outputFile -fileDescription "Firewall" -SectionDescription $sectionDescription
}

# SIG # Begin signature block
# MIIa9gYJKoZIhvcNAQcCoIIa5zCCGuMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCy+K+WBWLX92mBQYve5ZYMx+
# V2+gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBN4wggTa
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfcwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGhQ
# Iox++GAuKoL7DR8JUAPGc2hqMIGWBgorBgEEAYI3AgEMMYGHMIGEoGqAaABDAFQA
# UwBfAE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwA
# XwBEAEMAXwBGAGkAcgBlAHcAYQBsAGwALQBDAG8AbQBwAG8AbgBlAG4AdAAuAHAA
# cwAxoRaAFGh0dHA6Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAIog
# 2UVMk5nHxYqGOjqCefUqWHhOE8cgAFGNlZeX9h0je+iL9DtZNCPd1zOWY5ddcJRa
# 0WbQ+toGBh3e2npgTyEo8zeDcCpWN9Pj4JqcKU1K0g2sOkK3CIvr6owm+TGMOBOl
# oFLubrZfBBeSlx0uMEpsGSYBH2+ywSTo37LlVyZYQZpV0ZTc9BRNbXFQ39mOrw1P
# sxXI4T7rjaX+ADknXVuEkSPK/DvLxn8Jl9PqkLhgRAXmJ19+nIKOrRs4hZkGnlGT
# aWckjtqvwyNGc7crxerp/z/u/NQz6C8e7LfpVEXtyk1kRPCyQlRiyhOWY/IVpxXk
# Yy4ZXraGuHuEq/vr8T2hggIoMIICJAYJKoZIhvcNAQkGMYICFTCCAhECAQEwgY4w
# dzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMY
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBAhMzAAAATKHoTcy0dHs7AAAAAABMMAkG
# BSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0xNDEwMjAxODA4MzBaMCMGCSqGSIb3DQEJBDEWBBRVLo6StkBQFp84W/1g
# hRBPMC64RTANBgkqhkiG9w0BAQUFAASCAQB2kc2v14HgelcIFOXpPEKPnmgHaO6T
# AISfRoVtsneo9y3m45uuAQ/MNe05mj4HnSM/KY4uBHUVGP4U05b9/glLWJzf1Dwe
# 2DOX2VDFPCuDmnwY5x6a3fD2m7qn8VcB2iRYJIb346ilKrIoAZmRidB1WFxfViBw
# 172Nb+ZnToV+WckERdv7ns3ddunWfewzoF92rIqVwRmXOtWpdivtXJr8lDMvwO+6
# x2AQaQjiE5m3czLVS4E5xQCO+TpMGNMPWNJ23W/846U516MTQTtJQR1F6V0N+0S7
# zp4NbfVL0Se+qkPCqljX3QR+fSly4Lahx+MzpWcpzvp20Cw45TfcML+z
# SIG # End signature block
