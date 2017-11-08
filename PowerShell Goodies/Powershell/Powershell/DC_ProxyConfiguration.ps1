#************************************************
# DC_ProxyConfiguration.ps1
# Version 1.0: Proxy Configuration for IE User, WinHTTP, Firewall Client, PAC Files, Network Isolation
# Version 1.1: Added Proxy Configuration for IE System
# Version 1.2 (4/28/14): Edited table of contents. 
# Create date: 12/5/2012
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects Proxy Configuration information from IE, WinHTTP and Forefront Firewall Client.
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
		 # later use return to return the exception message to an object:   return $Script:ExceptionMessage
	}

Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationIEUser -Status $ScriptVariable.ID_CTSProxyConfigurationIEUserDescription

$sectionDescription = "Proxy Configuration Information"
$OutputFile= $Computername + "_ProxyConfiguration.TXT"


#INTRO

	"====================================================" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"Proxy Configuration" 																| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"Overview"			 																| Out-File -FilePath $OutputFile -encoding ASCII -append
	"----------------------------------------------------" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"The Proxy Configuration script shows the proxy configuration of the following:"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  1. IE User Proxy Settings"														| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  2. IE System Proxy Settings" 													| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  3. WinHTTP Proxy Settings"														| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  4. BITS Proxy Settings" 															| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  5. TMG/ISA Firewall Client Settings" 											| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  6. Displays PAC file names and locations"										| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  7. Collects the PAC files on the system into a compressed file."					| Out-File -FilePath $OutputFile -encoding ASCII -append
	"  8. Network Isolation settings" 													| Out-File -FilePath $OutputFile -encoding ASCII -append
	"===================================================="								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"																				| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"																				| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"																				| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"																				| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"																				| Out-File -FilePath $OutputFile -encoding ASCII -append
	

#IE
	#"[info]: Starting Proxy Configuration script" | WriteTo-StdOut
	# Check if ProxySettingsPerUser is set causing the IE settings to be read from HKLM
	if (test-path "HKLM:\Software\Policies\Windows\CurrentVersion\Internet Settings")
	{
		$ieProxyConfigProxySettingsPerUserP = (Get-ItemProperty -path "HKLM:\Software\Policies\Windows\CurrentVersion\Internet Settings").ProxySettingsPerUser
	}
	if (test-path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings")
	{
		$ieProxyConfigProxySettingsPerUserM = (Get-ItemProperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxySettingsPerUser	
	}

	If ( ($ieProxyConfigProxySettingsPerUserP -eq 0) -or ($ieProxyConfigProxySettingsPerUserM -eq 0) )
	{
		#----------determine os architecture
		Function GetComputerArchitecture() 
		{ 
			if (($Env:PROCESSOR_ARCHITEW6432).Length -gt 0) #running in WOW 
			{ 
				$Env:PROCESSOR_ARCHITEW6432 
			} else { 
				$Env:PROCESSOR_ARCHITECTURE 
			} 
		}
		$OSArchitecture = GetComputerArchitecture
		# $OSArchitecture | WriteTo-StdOut

		if ($OSArchitecture -eq "AMD64")
		{
			#IE Proxy Config from HKLM
			$ieProxyConfigAutoConfigURL = (Get-ItemProperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").AutoConfigURL
			$ieProxyConfigProxyEnable   = (Get-ItemProperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
			$ieProxyConfigProxyServer   = (Get-ItemProperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyServer
			$ieProxyConfigProxyOverride = (Get-ItemProperty -path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyOverride
			# Get list of regvalues in "HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
			$ieConnections = (Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections") | Select-Object -ExpandProperty Property
			$regHive = "HKLM (x64)"
		}
		if ($OSArchitecture -eq "x86")
		{
			#IE Proxy Config from HKLM
			$ieProxyConfigAutoConfigURL = (Get-ItemProperty -path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings").AutoConfigURL
			$ieProxyConfigProxyEnable   = (Get-ItemProperty -path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
			$ieProxyConfigProxyServer   = (Get-ItemProperty -path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyServer
			$ieProxyConfigProxyOverride = (Get-ItemProperty -path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyOverride
			
			# Get list of regvalues in "HKLM\Software\WOW6432Node\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
			$ieConnections = (Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\Connections") | Select-Object -ExpandProperty Property
			$regHive = "HKLM (x86)"
		}
	}
	else
	{
		#IE Proxy Config from HKCU
		$ieProxyConfigAutoConfigURL = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").AutoConfigURL
		$ieProxyConfigProxyEnable   = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
		$ieProxyConfigProxyServer   = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyServer
		$ieProxyConfigProxyOverride = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyOverride

		# Get list of regvalues in "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
		$ieConnections = (Get-Item -Path "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections") | Select-Object -ExpandProperty Property
		$regHive = "HKCU"
	}

	#"[info]: ProxyServer array being created" | WriteTo-StdOut	
	#Find all entries in the Proxy Server Array
	if ($ieProxyConfigProxyServer -ne $null)
	{
		$ieProxyConfigProxyServerArray = ($ieProxyConfigProxyServer).Split(';')
		$ieProxyConfigProxyServerArrayLength = $ieProxyConfigProxyServerArray.length
	}
	
	#"[info]: ProxyOverride array being created" | WriteTo-StdOut	
	#Find all entries in Proxy Override Array
	if ($ieProxyConfigProxyOverride -ne $null)
	{
		[array]$ieProxyConfigProxyOverrideArray = ($ieProxyConfigProxyOverride).Split(';')
		$ieProxyConfigProxyOverrideArrayLength = $ieProxyConfigProxyOverrideArray.length
	}
	
	
	


	#"[info]: Starting Proxy Configuration: IE User Settings section" | WriteTo-StdOut
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: IE User Settings (" + $regHive + ")" 	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	
	for($i=0;$ieConnections[$i] -ne $null;$i++)
	{
		#IE Proxy Configuration Array: Detection Logic for each Connection
			[string]$ieConnection = $ieConnections[$i]

		
		# Main UI Checkboxes (3)
			$ieProxyConfigArray = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections").$ieConnection
			[int]$ieProxyConfigUI = $ieProxyConfigArray[8]
			
			
		# Manual Proxy Server setting
			[int]$ieProxyConfigUIManualProxyOffset = 12
			[int]$ieProxyConfigUIManualProxyLength = $ieProxyConfigArray[$ieProxyConfigUIManualProxyOffset]
			[int]$ieProxyConfigUIManualProxyStart = $ieProxyConfigUIManualProxyOffset + 4
			[int]$ieProxyConfigUIManualProxyEnd = $ieProxyConfigUIManualProxyStart + $ieProxyConfigUIManualProxyLength
			# Convert decimal to ASCII string
			[string]$ieProxyConfigUIManualProxyValue = ""
			for ($j=$ieProxyConfigUIManualProxyStart;$j -lt $ieProxyConfigUIManualProxyEnd;$j++)
			{
				[string]$ieProxyConfigUIManualProxyValue = $ieProxyConfigUIManualProxyValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
			}
			# Split on semicolons
			$ieProxyConfigUIManualProxyValueArray = ($ieProxyConfigUIManualProxyValue).Split(';')
			$ieProxyConfigUIManualProxyValueArrayLength = $ieProxyConfigUIManualProxyValueArray.length


		# BypassProxy
			[int]$ieProxyConfigUIBypassProxyOffset = $ieProxyConfigUIManualProxyStart + $ieProxyConfigUIManualProxyLength
			[int]$ieProxyConfigUIBypassProxyLength = $ieProxyConfigArray[$ieProxyConfigUIBypassProxyOffset]
			[int]$ieProxyConfigUIBypassProxyStart  = $ieProxyConfigUIBypassProxyOffset + 4
			[int]$ieProxyConfigUIBypassProxyEnd    = $ieProxyConfigUIBypassProxyStart + $ieProxyConfigUIBypassProxyLength
			# Bypass Proxy Checkbox
			If ($ieProxyConfigUIBypassProxyLength -ne 0)
			{
				#BypassProxy Checked
				$ieProxyConfigUIBypassProxyEnabled = $true
			}
			else
			{
				#BypassProxy Unchecked
				$ieProxyConfigUIBypassProxyEnabled = $false
			}
			# Convert decimal to ASCII string
			[string]$ieProxyConfigUIBypassProxyValue = ""
			for ($j=$ieProxyConfigUIBypassProxyStart;$j -lt $ieProxyConfigUIBypassProxyEnd;$j++)
			{
				[string]$ieProxyConfigUIBypassProxyValue = $ieProxyConfigUIBypassProxyValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
			}
			# Split on semicolons
			$ieProxyConfigUIBypassProxyValueArray = ($ieProxyConfigUIBypassProxyValue).Split(';')
			$ieProxyConfigUIBypassProxyValueArrayLength = $ieProxyConfigUIBypassProxyValueArray.length
			
			
		#AutoConfig
			[int]$ieProxyConfigUIAutoConfigOffset = $ieProxyConfigUIBypassProxyStart + $ieProxyConfigUIBypassProxyLength
			[int]$ieProxyConfigUIAutoConfigLength = $ieProxyConfigArray[$ieProxyConfigUIAutoConfigOffset]
			[int]$ieProxyConfigUIAutoConfigStart  = $ieProxyConfigUIAutoConfigOffset + 4
			[int]$ieProxyConfigUIAutoConfigEnd    = $ieProxyConfigUIAutoConfigStart + $ieProxyConfigUIAutoConfigLength
			# Convert decimal to ASCII string
			[string]$ieProxyConfigUIAutoConfigValue = ""
			for ($j=$ieProxyConfigUIAutoConfigStart;$j -lt $ieProxyConfigUIAutoConfigEnd;$j++)
			{
				[string]$ieProxyConfigUIAutoConfigValue = $ieProxyConfigUIAutoConfigValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
			}
			# Split on semicolons
			$ieProxyConfigUIAutoConfigValueArray = ($ieProxyConfigUIAutoConfigValue).Split(';')
			$ieProxyConfigUIAutoConfigValueArrayLength = $ieProxyConfigUIAutoConfigValueArray.length

			

		If ($ieConnection -eq "DefaultConnectionSettings")
		{

			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"Local Area Network (LAN) Settings" 	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		}
		elseif ($ieConnection -eq "SavedLegacySettings")
		{
			# skipping SavedLegacySettings to trim output
			$i++
			[string]$ieConnection = $ieConnections[$i]
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		}
		else
		{
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
			"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		}
		

		" " + "Automatic Configuration"						| Out-File -FilePath $OutputFile -encoding ASCII -append
		# "Automatically detect settings:
			If ( ($ieProxyConfigUI -eq 9) -or ($ieProxyConfigUI -eq 11) -or ($ieProxyConfigUI -eq 13) -or ($ieProxyConfigUI -eq 15) )
			{
				"  " + "[X] Automatically detect settings:" | Out-File -FilePath $OutputFile -encoding ASCII -append
			}
			else
			{
				"  " + "[ ] Automatically detect settings:" | Out-File -FilePath $OutputFile -encoding ASCII -append
			}
		# "Use automatic configuration script:"
			If ( ($ieProxyConfigUI -eq 5) -or ($ieProxyConfigUI -eq 7) -or ($ieProxyConfigUI -eq 13) -or ($ieProxyConfigUI -eq 15) )
			{
				"  " + "[X] Use automatic configuration script:" | Out-File -FilePath $OutputFile -encoding ASCII -append
				"   " + "     " + "Address: "  | Out-File -FilePath $OutputFile -encoding ASCII -append
				# "   " + "            " + $ieProxyConfigAutoConfigURL
				
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				for ($j=0;$j -le $ieProxyConfigUIAutoConfigValueArrayLength;$j++)
				{
					"    " + "            " + $ieProxyConfigUIAutoConfigValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
				}
			}
			else
			{
				"  " + "[ ] Use automatic configuration script:" | Out-File -FilePath $OutputFile -encoding ASCII -append
				"   " + "     " + "Address: " | Out-File -FilePath $OutputFile -encoding ASCII -append
			}
		" " + "Proxy Server"								| Out-File -FilePath $OutputFile -encoding ASCII -append
		# "Use a proxy server for your LAN (These settings will not apply to dial-up or VPN connections)."
			If ( ($ieProxyConfigUI -eq 3) -or ($ieProxyConfigUI -eq 7) -or ($ieProxyConfigUI -eq 11) -or ($ieProxyConfigUI -eq 15) )
			{
				# MANUAL PROXY (from Connection)
				"  " + "[X] Use a proxy server for your LAN (These settings will not apply " | Out-File -FilePath $OutputFile -encoding ASCII -append
				If ($ieConnection -eq "DefaultConnectionSettings")
				{
					"  " + "    to dial-up or VPN connections)."		| Out-File -FilePath $OutputFile -encoding ASCII -append
				}
				else
				{
					"  " + "    to other connections)."					| Out-File -FilePath $OutputFile -encoding ASCII -append
				}
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"   " + "     Address: and Port:   " | Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				for ($j=0;$j -le $ieProxyConfigUIManualProxyValueArrayLength;$j++)
				{
					"    " + "            " + $ieProxyConfigUIManualProxyValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
				}

				# BYPASS PROXY (from Connection)
				If ($ieProxyConfigUIBypassProxyEnabled -eq $true)
				{
				"    " + "   [X] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"    " + "        Exceptions: "	| Out-File -FilePath $OutputFile -encoding ASCII -append
					"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					for ($j=0;$j -le $ieProxyConfigUIBypassProxyValueArrayLength;$j++)
					{
						"    " + "            " + $ieProxyConfigUIBypassProxyValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
					}
				}
				else
				{
				"    " + "   [ ] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"    " + "        Exceptions: "  							| Out-File -FilePath $OutputFile -encoding ASCII -append
				}
			}
			else
			{
				"  " + "[ ] Use a proxy server for your LAN (These settings will not apply to" | Out-File -FilePath $OutputFile -encoding ASCII -append
				"  " + "    dial-up or VPN connections)."					| Out-File -FilePath $OutputFile -encoding ASCII -append
				"   " + "    Address:Port "									| Out-File -FilePath $OutputFile -encoding ASCII -append
				"    " + "   [ ] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"    " + "        Exceptions: "  							| Out-File -FilePath $OutputFile -encoding ASCII -append
			}
	}





Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationIESystem -Status $ScriptVariable.ID_CTSProxyConfigurationIESystemDescription

	#----------Proxy Configuration: IE System Settings: Initialization
		#"[info]: ProxyConfiguration: IE System Settings: Initialization" | WriteTo-StdOut 	
		$regHive = "HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

	
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 				| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: IE System Settings (" + $regHive + ")" 		| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 				| Out-File -FilePath $OutputFile -encoding ASCII -append


	#----------
	# Verifying HKU is in the psProviderList. If not, add it
	#----------
		#
		# HKU may not be in the psProviderList, so we need to add it so we can reference it
		#
		#"[info]: Checking the PSProvider list because we need HKU" | WriteTo-StdOut
		$psProviderList = Get-PSDrive -PSProvider Registry
		$psProviderListLen = $psProviderList.length
		for ($i=0;$i -le $psProviderListLen;$i++)
		{
			if (($psProviderList[$i].Name) -eq "HKU")
			{
				$hkuExists = $true
				$i = $psProviderListLen
			}
			else
			{
				$hkuExists = $false
			}
		}
		if ($hkuExists -eq $false)
		{
			#"[info]: Creating a new PSProvider to enable access to HKU" | WriteTo-StdOut
			New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
		}

	#----------
	# Verify "\Internet Settings\Connections" exists, if not display message that IE System Context is not configured.
	#   $ieConnectionsCheck and associated code block added 10/11/2013
	#----------
	#$ieConnections = $null
	# Get list of regvalues in "HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"		
	$ieConnectionsCheck = Test-path "HKU:\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
	
	if ($ieConnectionsCheck -eq $true)
	{
		$ieConnections = (Get-Item -Path "Registry::HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections") | Select-Object -ExpandProperty Property
		
		for($i=0;$ieConnections[$i] -ne $null;$i++)
		{
			#IE Proxy Configuration Array: Detection Logic for each Connection
				[string]$ieConnection = $ieConnections[$i]

			#"[info]: Get-ItemProperty on HKU registry location." | WriteTo-StdOut
			# Main UI Checkboxes (3)
				[array]$ieProxyConfigArray = $null
				[array]$ieProxyConfigArray = (Get-ItemProperty -path "HKU:\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections").$ieConnection
				[int]$ieProxyConfigUI = $ieProxyConfigArray[8]
				
			#"[info]: Retrieving manual proxy server setting." | WriteTo-StdOut
			# Manual Proxy Server setting
				[int]$ieProxyConfigUIManualProxyOffset = 12
				[int]$ieProxyConfigUIManualProxyLength = $ieProxyConfigArray[$ieProxyConfigUIManualProxyOffset]
				[int]$ieProxyConfigUIManualProxyStart = $ieProxyConfigUIManualProxyOffset + 4
				[int]$ieProxyConfigUIManualProxyEnd = $ieProxyConfigUIManualProxyStart + $ieProxyConfigUIManualProxyLength
				# Convert decimal to ASCII string
				[string]$ieProxyConfigUIManualProxyValue = ""
				for ($j=$ieProxyConfigUIManualProxyStart;$j -lt $ieProxyConfigUIManualProxyEnd;$j++)
				{
					[string]$ieProxyConfigUIManualProxyValue = $ieProxyConfigUIManualProxyValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
				}
				# Split on semicolons
				$ieProxyConfigUIManualProxyValueArray = ($ieProxyConfigUIManualProxyValue).Split(';')
				$ieProxyConfigUIManualProxyValueArrayLength = $ieProxyConfigUIManualProxyValueArray.length

			#"[info]: Retrieving BypassProxy setting." | WriteTo-StdOut
			# BypassProxy
				[int]$ieProxyConfigUIBypassProxyOffset = $ieProxyConfigUIManualProxyStart + $ieProxyConfigUIManualProxyLength
				[int]$ieProxyConfigUIBypassProxyLength = $ieProxyConfigArray[$ieProxyConfigUIBypassProxyOffset]
				[int]$ieProxyConfigUIBypassProxyStart  = $ieProxyConfigUIBypassProxyOffset + 4
				[int]$ieProxyConfigUIBypassProxyEnd    = $ieProxyConfigUIBypassProxyStart + $ieProxyConfigUIBypassProxyLength
				# Bypass Proxy Checkbox
				If ($ieProxyConfigUIBypassProxyLength -ne 0)
				{
					#BypassProxy Checked
					$ieProxyConfigUIBypassProxyEnabled = $true
				}
				else
				{
					#BypassProxy Unchecked
					$ieProxyConfigUIBypassProxyEnabled = $false
				}
				# Convert decimal to ASCII string
				[string]$ieProxyConfigUIBypassProxyValue = ""
				for ($j=$ieProxyConfigUIBypassProxyStart;$j -lt $ieProxyConfigUIBypassProxyEnd;$j++)
				{
					[string]$ieProxyConfigUIBypassProxyValue = $ieProxyConfigUIBypassProxyValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
				}
				# Split on semicolons
				$ieProxyConfigUIBypassProxyValueArray = ($ieProxyConfigUIBypassProxyValue).Split(';')
				$ieProxyConfigUIBypassProxyValueArrayLength = $ieProxyConfigUIBypassProxyValueArray.length
				
			#"[info]: Retrieving AutoConfig setting." | WriteTo-StdOut			
			#AutoConfig
				[int]$ieProxyConfigUIAutoConfigOffset = $ieProxyConfigUIBypassProxyStart + $ieProxyConfigUIBypassProxyLength
				[int]$ieProxyConfigUIAutoConfigLength = $ieProxyConfigArray[$ieProxyConfigUIAutoConfigOffset]
				[int]$ieProxyConfigUIAutoConfigStart  = $ieProxyConfigUIAutoConfigOffset + 4
				[int]$ieProxyConfigUIAutoConfigEnd    = $ieProxyConfigUIAutoConfigStart + $ieProxyConfigUIAutoConfigLength
				# Convert decimal to ASCII string
				[string]$ieProxyConfigUIAutoConfigValue = ""
				for ($j=$ieProxyConfigUIAutoConfigStart;$j -lt $ieProxyConfigUIAutoConfigEnd;$j++)
				{
					[string]$ieProxyConfigUIAutoConfigValue = $ieProxyConfigUIAutoConfigValue + [CHAR][BYTE]$ieProxyConfigArray[$j]
				}
				# Split on semicolons
				$ieProxyConfigUIAutoConfigValueArray = ($ieProxyConfigUIAutoConfigValue).Split(';')
				$ieProxyConfigUIAutoConfigValueArrayLength = $ieProxyConfigUIAutoConfigValueArray.length

				

			If ($ieConnection -eq "DefaultConnectionSettings")
			{

				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"Local Area Network (LAN) Settings" 	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			}
			elseif ($ieConnection -eq "SavedLegacySettings")
			{
				# skipping SavedLegacySettings to trim output
				$i++
				[string]$ieConnection = $ieConnections[$i]
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			}
			else
			{
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
				"-----Connection:  " + $ieConnection + "-----"		| Out-File -FilePath $OutputFile -encoding ASCII -append
				"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
			}
			

			" " + "Automatic Configuration"						| Out-File -FilePath $OutputFile -encoding ASCII -append
			# "Automatically detect settings:
				If ( ($ieProxyConfigUI -eq 9) -or ($ieProxyConfigUI -eq 11) -or ($ieProxyConfigUI -eq 13) -or ($ieProxyConfigUI -eq 15) )
				{
					"  " + "[X] Automatically detect settings:" | Out-File -FilePath $OutputFile -encoding ASCII -append
				}
				else
				{
					"  " + "[ ] Automatically detect settings:" | Out-File -FilePath $OutputFile -encoding ASCII -append
				}
			# "Use automatic configuration script:"
				If ( ($ieProxyConfigUI -eq 5) -or ($ieProxyConfigUI -eq 7) -or ($ieProxyConfigUI -eq 13) -or ($ieProxyConfigUI -eq 15) )
				{
					"  " + "[X] Use automatic configuration script:" | Out-File -FilePath $OutputFile -encoding ASCII -append
					"   " + "     " + "Address: "  | Out-File -FilePath $OutputFile -encoding ASCII -append
					# "   " + "            " + $ieProxyConfigAutoConfigURL
					
					"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					for ($j=0;$j -le $ieProxyConfigUIAutoConfigValueArrayLength;$j++)
					{
						"    " + "            " + $ieProxyConfigUIAutoConfigValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
					}
				}
				else
				{
					"  " + "[ ] Use automatic configuration script:" | Out-File -FilePath $OutputFile -encoding ASCII -append
					"   " + "     " + "Address: " | Out-File -FilePath $OutputFile -encoding ASCII -append
				}
			" " + "Proxy Server"								| Out-File -FilePath $OutputFile -encoding ASCII -append
			# "Use a proxy server for your LAN (These settings will not apply to dial-up or VPN connections)."
				If ( ($ieProxyConfigUI -eq 3) -or ($ieProxyConfigUI -eq 7) -or ($ieProxyConfigUI -eq 11) -or ($ieProxyConfigUI -eq 15) )
				{
					# MANUAL PROXY (from Connection)
					"  " + "[X] Use a proxy server for your LAN (These settings will not apply " | Out-File -FilePath $OutputFile -encoding ASCII -append
					If ($ieConnection -eq "DefaultConnectionSettings")
					{
						"  " + "    to dial-up or VPN connections)."		| Out-File -FilePath $OutputFile -encoding ASCII -append
					}
					else
					{
						"  " + "    to other connections)."					| Out-File -FilePath $OutputFile -encoding ASCII -append
					}
					"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					"   " + "     Address: and Port:   " | Out-File -FilePath $OutputFile -encoding ASCII -append
					"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					for ($j=0;$j -le $ieProxyConfigUIManualProxyValueArrayLength;$j++)
					{
						"    " + "            " + $ieProxyConfigUIManualProxyValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
					}

					# BYPASS PROXY (from Connection)
					If ($ieProxyConfigUIBypassProxyEnabled -eq $true)
					{
					"    " + "   [X] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					"    " + "        Exceptions: "	| Out-File -FilePath $OutputFile -encoding ASCII -append
						"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
						for ($j=0;$j -le $ieProxyConfigUIBypassProxyValueArrayLength;$j++)
						{
							"    " + "            " + $ieProxyConfigUIBypassProxyValueArray[$j]	| Out-File -FilePath $OutputFile -encoding ASCII -append
						}
					}
					else
					{
					"    " + "   [ ] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					"    " + "        Exceptions: "  | Out-File -FilePath $OutputFile -encoding ASCII -append
					}
				}
				else
				{
					"  " + "[ ] Use a proxy server for your LAN (These settings will not apply to" | Out-File -FilePath $OutputFile -encoding ASCII -append
					"  " + "    dial-up or VPN connections)."					| Out-File -FilePath $OutputFile -encoding ASCII -append
					"   " + "    Address:Port "									| Out-File -FilePath $OutputFile -encoding ASCII -append
					"    " + "   [ ] Bypass proxy server for local addresses"	| Out-File -FilePath $OutputFile -encoding ASCII -append
					"    " + "        Exceptions: "  | Out-File -FilePath $OutputFile -encoding ASCII -append
				}
		}
	}
	

	Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationWinHTTP -Status $ScriptVariable.ID_CTSProxyConfigurationWinHTTPDescription
	#"[info]: ProxyConfiguration: WinHTTP" | WriteTo-StdOut 	
#WinHTTP
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: WinHTTP" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	
	
	Function RunNetSH ([string]$NetSHCommandToExecute="")
	{
		$NetSHCommandToExecuteLength = $NetSHCommandToExecute.Length + 6
		"-" * ($NetSHCommandToExecuteLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"netsh $NetSHCommandToExecute"		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"-" * ($NetSHCommandToExecuteLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		$CommandToExecute = "cmd.exe /c netsh.exe " + $NetSHCommandToExecute + "| Out-File -FilePath $OutputFile -encoding ASCII -append"
		RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
	}
	RunNetSH -NetSHCommandToExecute "winhttp show proxy"





#BITS
	# update for BITS proxy: Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationWinHTTP -Status $ScriptVariable.ID_CTSProxyConfigurationWinHTTPDescription
	#"[info]: ProxyConfiguration: BITS" | WriteTo-StdOut 	

	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: BITS" 									| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append

	function RunBitsAdmin ([string]$BitsAdminCommandToExecute="")
	{
		$BitsAdminCommandToExecuteLength = $BitsAdminCommandToExecute.Length + 6
		"-" * ($BitsAdminCommandToExecuteLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"bitsadmin $BitsAdminCommandToExecute"		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"-" * ($BitsAdminCommandToExecuteLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		$CommandToExecute = "cmd.exe /c bitsadmin.exe " + $BitsAdminCommandToExecute + "| Out-File -FilePath $OutputFile -encoding ASCII -append"
		RunCmD -commandToRun $CommandToExecute  -CollectFiles $false
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	}
	RunBitsAdmin -BitsAdminCommandToExecute " /util /getieproxy localsystem"
	RunBitsAdmin -BitsAdminCommandToExecute " /util /getieproxy networkservice"
	RunBitsAdmin -BitsAdminCommandToExecute " /util /getieproxy localservice"




	

#Firewall Client
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationFirewallClient -Status $ScriptVariable.ID_CTSProxyConfigurationFirewallClientDescription
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: Firewall Client" 						| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append

	#----- Is the Firewall Client installed?
	$processActive = Get-Process fwcagent -ErrorAction SilentlyContinue
	if ($processActive -ne $null)
	{
		"The Firewall Client appears to be installed. Gathering output."	| Out-File -FilePath $OutputFile -encoding ASCII -append
		" "	| Out-File -FilePath $OutputFile -encoding ASCII -append
		" "	| Out-File -FilePath $OutputFile -encoding ASCII -append
		$firewallClientProcessPath = (get-process fwcagent).path
		$firewallClientProcess = $firewallClientProcessPath.substring(0,$firewallClientProcessPath.Length-12) + "fwctool.exe"
		$firewallClientProcess
		$firewallClientArgs  = " printconfig"
		$firewallClientCmd = "`"" + $firewallClientProcess + "`"" + $firewallClientArgs
		$firewallClientCmdLength = $firewallClientCmd.length
		# Output header and command that will be run
		"`n" + "-" * ($firewallClientCmdLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n" + "`"" + $firewallClientProcess + " " + $firewallClientArgs + "`""		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n" + "-" * ($firewallClientCmdLength)	| Out-File -FilePath $OutputFile -encoding ASCII -append
		# Run the command
		$CommandToExecute = "cmd.exe /c " + $firewallClientCmd + " | Out-File -FilePath $OutputFile -encoding ASCII -append"
		RunCmD -commandToRun $CommandToExecute -CollectFiles $false
	}
	else
	{
		"The Firewall Client is not installed."	| Out-File -FilePath $OutputFile -encoding ASCII -append
	}


	
	
	

#PAC files	
	Write-DiagProgress -Activity $ScriptVariable.ID_CTSProxyConfigurationPACFiles -Status $ScriptVariable.ID_CTSProxyConfigurationPACFilesDescription

	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	" Proxy Configuration: PAC Files" 								| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append

	# Where are PAC files referenced?
	# HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad

	#-----PAC files
	#  Outside of SDP    = Inside SDP
	#  "c:\users\bbenson = $env:USERPROFILE + "
	#  "c:\windows       = $env:windir + "
	#
	#-----array*.script and wpad*.dat files in User Profile
	$pacUserProfPath = $env:USERPROFILE + "\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
	# Added Sort-Object to sort the array on creation
	#   | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
	if (Test-Path $pacUserProfPath)
	{
		[array]$pacUserProf = Get-ChildItem $pacUserProfPath  -include array*.script,wpad*.dat -force –recurse | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
		$pacUserProfLen = $pacUserProf.length
		if ($pacUserProfLen -eq $null)  
		{
			$pacUserProfLen = 0
		}
		else
		{
			if ($pacUserProfLen -ne 0)
			{
				[array]$pacArray = [array]$pacUserProf
				$pacArrayLen = $pacArray.length
			}
		}
	}
	#-----array*.script and wpad*.dat files in Windir Sys32
	$pacWindirSys32Path = $env:windir + "\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
	# Added Sort-Object to sort the array on creation
	#   | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
	if (Test-Path $pacWindirSys32Path)
	{
		[array]$pacWindirSys32 = Get-ChildItem $pacWindirSys32Path -include array*.script,wpad*.dat -force -recurse | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
		$pacWindirSys32Len = $pacWindirSys32.length
		if ($pacWindirSys32Len -eq $null)
		{
			$pacWindirSys32Len = 0
		}
		else
		{
			if ($pacWindirSys32Len -ne 0)
			{
				[array]$pacArray = [array]$pacArray + [array]$pacWindirSys32
				$pacArrayLen = $pacArray.length
			}
		}
	}
	#-----array*.script and wpad*.dat files in Windir Syswow64
	$pacWindirSysWow64Path = $env:windir + "\SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
	# Added Sort-Object to sort the array on creation
	#   | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
	if  (Test-Path $pacWindirSysWow64Path)
	{
		[array]$pacWindirSysWow64 = Get-ChildItem $pacWindirSysWow64Path -include array*.script,wpad*.dat -force –recurse  | sort-object -property @{Expression={$_.LastAccessTime}; Ascending=$false}
		$pacWindirSysWow64Len = $pacWindirSysWow64.length
		if ($pacWindirSysWow64Len -eq $null)
		{
			$pacWindirSysWow64Len = 0
		}
		else
		{
			if ($pacWindirSysWow64Len -ne 0)
			{
				[array]$pacArray = [array]$pacArray + [array]$pacWindirSysWow64
				$pacArrayLen = $pacArray.length
			}
		}
	}
	#-----Engineer message indicating where the script searched for the files.
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"Searching for PAC files named wpad*.dat or array*.script in the following locations: " | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"  %userprofile%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"  %windir%\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"  %windir%\SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" | Out-File -FilePath $OutputFile -encoding ASCII -append
		
		# dir "%userprofile%\AppData\Local\Microsoft\Windows\Temporary Internet Files\wpad*.dat" /s
		# dir "%userprofile%\AppData\Local\Microsoft\Windows\Temporary Internet Files\array*.script" /s
		# dir "%windir%\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\wpad*.dat" /s
		# dir "%windir%\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\array*.script" /s
		# dir "%windir%\SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\wpad*.dat" /s
		# dir "%windir%\SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\array*.script" /s


	if ($pacArrayLen -eq $null)
	{
		$pacArrayLen = 0
	}
	#-----Display the array
	if ($pacArrayLen -eq 0)
	{
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"Found " + $pacArrayLen + " PAC files." | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"There are " + $pacArrayLen + " PAC files named wpad*.dat or array*.script located within `"Temporary Internet Files`" for the user and/or the system." | Out-File -FilePath $OutputFile -encoding ASCII -append
	}
	elseif ($pacArrayLen -eq 1)
	{
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"Found " + $pacArrayLen + " PAC file." | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		
		#-----Show FullName, LastWriteTime and LastAccessTime
		for($i=0;$i -lt $pacArrayLen;$i++)
		{
			" " | Out-File -FilePath $OutputFile -encoding ASCII -append
			"[#" + ($i+1) + "]" | Out-File -FilePath $OutputFile -encoding ASCII -append
			"FullName        : " + ($pacArray[$i]).FullName | Out-File -FilePath $OutputFile -encoding ASCII -append
			# "LastWriteTime   : " + ($pacArray[$i]).LastWriteTime | Out-File -FilePath $OutputFile -encoding ASCII -append
			"LastAccessTime  : " + ($pacArray[$i]).LastAccessTime | Out-File -FilePath $OutputFile -encoding ASCII -append
			" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		}
	}
	elseif ($pacArrayLen -gt 1)
	{
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"Found " + $pacArrayLen + " PAC files (in descending showing the most recent LastAccessTime first)" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"--------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		
		#-----Show FullName, LastWriteTime and LastAccessTime
		for($i=0;$i -lt $pacArrayLen;$i++)
		{
			# Sort the array by LastAccessTime
			$pacArray | sort LastAccessTime -Descending
			
			# Text Output with no sorting
			" " | Out-File -FilePath $OutputFile -encoding ASCII -append
			"[#" + ($i+1) + "]" | Out-File -FilePath $OutputFile -encoding ASCII -append
			"FullName        : " + ($pacArray[$i]).FullName | Out-File -FilePath $OutputFile -encoding ASCII -append
			#"LastWriteTime   : " + ($pacArray[$i]).LastWriteTime | Out-File -FilePath $OutputFile -encoding ASCII -append
			"LastAccessTime  : " + ($pacArray[$i]).LastAccessTime | Out-File -FilePath $OutputFile -encoding ASCII -append
			" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		}
	}

	If ($pacArrayLen -gt 0)
	{
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		" " | Out-File -FilePath $OutputFile -encoding ASCII -append
		"------------------------" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"Collecting PAC files" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"------------------------" | Out-File -FilePath $OutputFile -encoding ASCII -append

		# Initialize array for PAC files with FullName
		for ($i=0;$i -lt $pacArrayLen;$i++)  { $pacFilesArray += @($i) }
		
		# Create array of PAC Files with FullName
		for ($i=0;$i -lt $pacArrayLen;$i++)
		{
			$pacFilesArray[$i] = "`"" + ($pacArray[$i]).FullName + "`""
			$pacFilesArray[$i]	| Out-File -FilePath $OutputFile -encoding ASCII -append
			#copy to temp dir
			$CommandToExecute = "cmd.exe /c copy " + $pacFilesArray[$i] + " " + $PWD
			RunCmD -commandToRun $CommandToExecute -CollectFiles $false
		}
		# This function fails because of file not found, but I know the file exists. Probably because of [] in name.
		# CollectFiles -filesToCollect $pacFilesArray[$i]
		
		#Collect PAC files
		$destFileName = $env:COMPUTERNAME + "_Proxy-PACFiles.zip"
		# CollectFiles -filesToCollect $pacFilesArray
		$pacFilesWpadDat = join-path $PWD "wpad*.dat"
		$pacFilesArrScript = join-path $PWD "array*.script"
		CompressCollectFiles -filestocollect $pacFilesWpadDat -DestinationFileName $destFileName
		CompressCollectFiles -filestocollect $pacFilesArrScript -DestinationFileName $destFileName
	}





#Network Isolation Policies
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"Network Isolation Policy Configuration (W8/WS2012)" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"====================================================" 			| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	
	
	if (test-path HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation)
	{
		$netIsolationDomainLocalProxies 	= (Get-ItemProperty -path "HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation").DomainLocalProxies
		$netIsolationDomainProxies 			= (Get-ItemProperty -path "HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation").DomainProxies
		$netIsolationDomainSubnets 			= (Get-ItemProperty -path "HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation").DomainSubnets	
		$netIsolationDProxiesAuthoritive 	= (Get-ItemProperty -path "HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation").DProxiesAuthoritive
		$netIsolationDSubnetsAuthoritive 	= (Get-ItemProperty -path "HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation").DSubnetsAuthoritive
		
		"RegKey  : HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegValue: DomainLocalProxies" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegData : " + $netIsolationDomainLocalProxies 		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegValue: DomainProxies" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegData : " + $netIsolationDomainProxies | Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegValue: DomainSubnets" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegData : " + $netIsolationDomainSubnets 				| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegValue: DProxiesAuthoritive" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegData : " + $netIsolationDProxiesAuthoritive 		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegValue: DSubnetsAuthoritive" | Out-File -FilePath $OutputFile -encoding ASCII -append
		"RegData : " + $netIsolationDSubnetsAuthoritive 		| Out-File -FilePath $OutputFile -encoding ASCII -append
		"`n"	| Out-File -FilePath $OutputFile -encoding ASCII -append
	}
	else
	{
		"Network Isolation policies are not configured.  This location does not exist: HKLM:\Software\Policies\Microsoft\Windows\NetworkIsolation" | Out-File -FilePath $OutputFile -encoding ASCII -append
	}

CollectFiles -filesToCollect $OutputFile -fileDescription "Proxy Configuration Information" -SectionDescription $sectionDescription

# SIG # Begin signature block
# MIIa7gYJKoZIhvcNAQcCoIIa3zCCGtsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU88S8sPjzM3BA/QfPSaHypIgc
# Nr6gghV6MIIEuzCCA6OgAwIBAgITMwAAAFrtL/TkIJk/OgAAAAAAWjANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTeMIIE2gIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIH3MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSwbg5keqMjW66i
# mvoE76OjKwaLvzCBlgYKKwYBBAGCNwIBDDGBhzCBhKBqgGgAQwBUAFMAXwBOAGUA
# dAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8ARABDAF8A
# UAByAG8AeAB5AEMAbwBuAGYAaQBnAHUAcgBhAHQAaQBvAG4ALgBwAHMAMaEWgBRo
# dHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQBexB+YgloKhRbQ
# uLdTYn0V3zhIp501giHwtnnahZ9VN4j2IWJUMUaQBLwhWXgjQezhWYe6aewapzjj
# JVFeDHSXebOar0OAIxlJs3jKaeToNma47ELEPPsW4S1jGewivcIIhbYhwvod7b5l
# 8kCluWtfeqM0ipyWxTmsgFDJLwdtANK30V1se9nxRiEUQoDvZUfLh/O8b22ITgT4
# pYPL0OouZRAej72a2y6VtvUHi4aY4KdJl4y4kpsA4KkXGGP6eS2nINH+aMFSU0Aj
# twsGFgWbb6FKaD2Nl+A2W0hpn9Z2d6bvKxthKseNQM1ECotNeMTIIJAG3J1hyrvY
# k46pVgukoYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQQITMwAAAFrtL/TkIJk/OgAAAAAAWjAJBgUrDgMCGgUA
# oF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQx
# MDIwMTgwODM0WjAjBgkqhkiG9w0BCQQxFgQUIZoZBTFUZ19DWde6Dwc2yAsDruIw
# DQYJKoZIhvcNAQEFBQAEggEAgIwAeQLVhSIY2Qg92eAaEQtMxywNvF0TSrM9u+6h
# 4jU1SggmdgP8Z8LGeJiCWL9Lg/+UNaECUax5QqyHnUYaf1BPOC51vr/2rpLFNUMC
# 8laAhTyWub7vZBZz0mw4lPjjMCBg8+3wPcl0En61Wuia2EJiBUXLLOAqGcbG/znt
# wTs5+PK9s19MYIvZwWOO1S+MZf95BDUGrZ9ZRylvSbjg40PwQER2bqQp26gr52wI
# O2Oc2zjF6ZWSyRd29VnJAp/sSgMuSC4imlwf+25dvp6HXBFimIYMem9HiLb32j/N
# vufqgAUWvDE6qQoR74kG7MOU01f/Wc6tqoJIogIpCJIs+Q==
# SIG # End signature block
