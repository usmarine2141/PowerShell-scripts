#************************************************
# DC_SurfacePro3.ps1
# Version 1.0.09.19.14: Created and tested SurfacePro3 scripts from Sep12-19
# Version 1.1.10.07.14: Added the "Operating System and SKU section"
# Version 1.2.10.08.14: Modified Surface Pro 3 "Wifi Driver Version" detection method since the same file version is used for MP67 and MP107. (Testing with two SP3s)
# Version 1.3.10.09.14: Added Surface Pro 3 "Wifi Driver Power Management Settings"
# Version 1.4.10.10.14: Added Surface Pro 3 Binary Versions section
# Version 1.5.10.15.14: Added Surface Pro 3 Secure Boot Configuration section
# Version 1.6.10.16.14: Added Surface Pro 3 WMI classes output
# Date: 2014
# Author: Boyd Benson (bbenson@microsoft.com) working with Scott McArthur (scottmca) and Tod Edwards (tode)
# Description: Collects information about Surface Pro 3.
# Called from: Networking and Setup Diagnostics
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
Write-DiagProgress -Activity $ScriptVariable.ID_SurfacePro3 -Status $ScriptVariable.ID_SurfacePro3Desc

$sectionDescription = "Surface Pro 3"

# detect OS version and SKU
$wmiOSVersion = gwmi -Namespace "root\cimv2" -Class Win32_OperatingSystem
[int]$bn = [int]$wmiOSVersion.BuildNumber
$sku = $((gwmi win32_operatingsystem).OperatingSystemSKU)
$domainRole = (Get-WmiObject -Class Win32_ComputerSystem).DomainRole	# 0 or 1: client; >1: server



Function isOSVersionAffected
{
	if ($bn -ge 9600)
	 {
		return $true
	 }
	 else
	 {
		return $false
	 }
}

Function isSurfacePro3
{
	# Check for: "HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\BIOS"; SystemSKU = Surface_Pro_3
	$regkeyBIOS = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
	If (test-path $regkeyBIOS)
	{
		$regvalueSystemSKUReg = Get-ItemProperty -path $regkeyBIOS -name "SystemSKU" -ErrorAction SilentlyContinue
		$regvalueSystemSKU = $regvalueSystemSKUReg.SystemSKU
		if ($regvalueSystemSKU -eq "Surface_Pro_3")
		{
			return $true
		}
		else
		{
			return $false
		}
	}
}

Function GetOsVerName($bn)
{
	switch ($bn)
	{
		9600  {return "W8.1/WS2012R2"}
		9200  {return "W8/WS2012"}
		7601  {return "W7/WS2008R2 SP1"}
		7600  {return "W7/WS2008R2 RMT"}
	}
}

Function GetOsSkuName($sku)
{
	switch ($sku)
	{
		# GetProductInfo function
		# http://msdn.microsoft.com/en-us/library/ms724358.aspx
		#
		0  {return ""}
		1  {return "Ultimate Edition"}
		2  {return "Home Basic Edition"}
		3  {return "Home Basic Premium Edition"}
		4  {return "Enterprise Edition"}
		5  {return "Home Basic N Edition"}
		6  {return "Business Edition"}
		7  {return "Standard Server Edition"}
		8  {return "Datacenter Server Edition"}
		9  {return "Small Business Server Edition"}
		10 {return "Enterprise Server Edition"}
		11 {return "Starter Edition"}
		12 {return "Datacenter Server Core Edition"}
		13 {return "Standard Server Core Edition"}
		14 {return "Enterprise Server Core Edition"}
		15 {return "Enterprise Server Edition for Itanium-Based Systems"}
		16 {return "Business N Edition"}
		17 {return "Web Server Edition"}
		18 {return "Cluster Server Edition"}
		19 {return "Home Server Edition"}
		20 {return "Storage Express Server Edition"}
		21 {return "Storage Standard Server Edition"}
		22 {return "Storage Workgroup Server Edition"}
		23 {return "Storage Enterprise Server Edition"}
		24 {return "Server For Small Business Edition"}
		25 {return "Small Business Server Premium Edition"} # 0x00000019
		26 {return "Home Premium N Edition"} # 0x0000001a
		27 {return "Enterprise N Edition"} # 0x0000001b
		28 {return "Ultimate N Edition"} # 0x0000001c
		29 {return "Web Server Edition (core installation)"} # 0x0000001d
		30 {return "Windows Essential Business Server Management Server"} # 0x0000001e
		31 {return "Windows Essential Business Server Security Server"} # 0x0000001f
		32 {return "Windows Essential Business Server Messaging Server"} # 0x00000020
		33 {return "Server Foundation"} # 0x00000021
		34 {return "Windows Home Server 2011"} # 0x00000022 not found
		35 {return "Windows Server 2008 without Hyper-V for Windows Essential Server Solutions"} # 0x00000023
		36 {return "Server Standard Edition without Hyper-V (full installation)"} # 0x00000024
		37 {return "Server Datacenter Edition without Hyper-V (full installation)"} # 0x00000025
		38 {return "Server Enterprise Edition without Hyper-V (full installation)"} # 0x00000026
		39 {return "Server Datacenter Edition without Hyper-V (core installation)"} # 0x00000027
		40 {return "Server Standard Edition without Hyper-V (core installation)"} # 0x00000028
		41 {return "Server Enterprise Edition without Hyper-V (core installation)"} # 0x00000029
		42 {return "Microsoft Hyper-V Server"} # 0x0000002a
		43 {return "Storage Server Express (core installation)"} # 0x0000002b
		44 {return "Storage Server Standard (core installation)"} # 0x0000002c
		45 {return "Storage Server Workgroup (core installation)"} # 0x0000002d
		46 {return "Storage Server Enterprise (core installation)"} # 0x0000002e
		47 {return "Starter N"} # 0x0000002f
		48 {return "Professional Edition"} #0x00000030
		49 {return "ProfessionalN Edition"} #0x00000031
		50 {return "Windows Small Business Server 2011 Essentials"} #0x00000032
		51 {return "Server For SB Solutions"} #0x00000033
		52 {return "Server Solutions Premium"} #0x00000034
		53 {return "Server Solutions Premium (core installation)"} #0x00000035
		54 {return "Server For SB Solutions EM"} #0x00000036
		55 {return "Server For SB Solutions EM"} #0x00000037
		55 {return "Windows MultiPoint Server"} #0x00000038
		#not found: 3a
		59 {return "Windows Essential Server Solution Management"} #0x0000003b
		60 {return "Windows Essential Server Solution Additional"} #0x0000003c
		61 {return "Windows Essential Server Solution Management SVC"} #0x0000003d
		62 {return "Windows Essential Server Solution Additional SVC"} #0x0000003e
		63 {return "Small Business Server Premium (core installation)"} #0x0000003f
		64 {return "Server Hyper Core V"} #0x00000040
		 #0x00000041 not found
		 #0x00000042-48 not supported
		76 {return "Windows MultiPoint Server Standard (full installation)"} #0x0000004C
		77 {return "Windows MultiPoint Server Premium (full installation)"} #0x0000004D
		79 {return "Server Standard (evaluation installation)"} #0x0000004F
		80 {return "Server Datacenter (evaluation installation)"} #0x00000050
		84 {return "Enterprise N (evaluation installation)"} #0x00000054
		95 {return "Storage Server Workgroup (evaluation installation)"} #0x0000005F
		96 {return "Storage Server Standard (evaluation installation)"} #0x00000060
		98 {return "Windows 8 N"} #0x00000062
		99 {return "Windows 8 China"} #0x00000063
		100 {return "Windows 8 Single Language"} #0x00000064
		101 {return "Windows 8"} #0x00000065
		102 {return "Professional with Media Center"} #0x00000067
	}	
}



if ((isOSVersionAffected) -and (isSurfacePro3))
{
	$outputFile= $Computername + "_SurfacePro3_info.TXT"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Surface Pro 3 Configuration Information"				| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Overview" 												| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"   1. Operating System and SKU"						| Out-File -FilePath $OutputFile -append
	"   2. Wifi Driver Version"								| Out-File -FilePath $OutputFile -append
	"   3. Wifi Driver Power Management Settings"		 	| Out-File -FilePath $OutputFile -append
	"   4. Firmware Versions"								| Out-File -FilePath $OutputFile -append
	"   5. Connected Standby Status"						| Out-File -FilePath $OutputFile -append
	"   6. Connected Standby Configuration"					| Out-File -FilePath $OutputFile -append
	"   7. Secure Boot Configuration"						| Out-File -FilePath $OutputFile -append
	"   8. WMI Class Information"							| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append


	"[info] Operating System and SKU section" 	| WriteTo-StdOut
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Operating System and SKU"  				| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" 										| Out-File -FilePath $OutputFile -append
	$osVerName = GetOsVerName $bn
	"Operating System Name        : $osVerName" | Out-File -FilePath $OutputFile -append
	"Operating System Build Number: $bn" 		| Out-File -FilePath $OutputFile -append
	$osSkuName = GetOsSkuName $sku
	"Operating System SKU Name    : $osSkuName"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	$WinCVRegKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion"
	If (test-path $WinCVRegKey)
	{
		$ImageNameReg   = Get-ItemProperty -Path $WinCVRegKey -Name ImageName
		$ImageName = $ImageNameReg.ImageName
	}
	
	$WinNTCVRegKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
	If (test-path $WinNTCVRegKey)
	{
		$BuildLabReg    = Get-ItemProperty -Path $WinNTCVRegKey -Name BuildLab
		$BuildLab = $BuildLabReg.BuildLab

		$BuildLabExReg  = Get-ItemProperty -Path $WinNTCVRegKey -Name BuildLabEx 
		$BuildLabEx = $BuildLabExReg.BuildLabEx

		$ProductNameReg = Get-ItemProperty -Path $WinNTCVRegKey -Name ProductName 
		$ProductName = $ProductNameReg.ProductName

		$CurrentBuildReg = Get-ItemProperty -Path $WinNTCVRegKey -Name CurrentBuild 
		$CurrentBuild = $CurrentBuildReg.CurrentBuild

		"Image Name    : $ImageName" | Out-File -FilePath $OutputFile -append		
		"BuildLab      : $BuildLab" | Out-File -FilePath $OutputFile -append
		"BuildLabEx    : $BuildLabEx" | Out-File -FilePath $OutputFile -append
		"ProductName   : $ProductName" | Out-File -FilePath $OutputFile -append
		"CurrentBuild  : $CurrentBuild" | Out-File -FilePath $OutputFile -append
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append



	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Wifi Driver Version" 									| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" 													| Out-File -FilePath $OutputFile -append	
	"[info] Wifi Driver Version section"  | WriteTo-StdOut
	$marvelDriver = join-path $env:windir "\system32\drivers\mrvlpcie8897.sys"
	if (test-path $marvelDriver)
	{
		$marvelDriverInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($marvelDriver)
		$marvelDriverFileBuildPart = $marvelDriverInfo.FileBuildPart
		$marvelDriverProductVersion = $marvelDriverInfo.ProductVersion
		[string]$marvelDriverVersion = [string]$marvelDriverInfo.FileMajorPart + "." + [string]$marvelDriverInfo.FileMinorPart + "." + [string]$marvelDriverInfo.FileBuildPart + "." + [string]$marvelDriverInfo.FilePrivatePart
		# Latest driver (as of 9/9/14): 6.3.9410.0; MP107; DateModified: 8/22/14; Package version online: 15.68.3055.107;
		# Previous driver             : 6.3.9410.0; MP67 ; DateModified: 4/24/14;
		#
		"FileName      : $marvelDriver"					| Out-File -FilePath $OutputFile -append
		"FileVersion   : $marvelDriverVersion"			| Out-File -FilePath $OutputFile -append
		"ProductVersion: $marvelDriverProductVersion"	| Out-File -FilePath $OutputFile -append
		"`n" 											| Out-File -FilePath $OutputFile -append
		
		$marvelDriverProductVersionStartsWithMP = ($marvelDriverProductVersion).StartsWith("MP")
		if ($marvelDriverProductVersionStartsWithMP -eq $true) 
		{
			[int]$marvelDriverProductVersionInt = $marvelDriverProductVersion.Substring(2,$marvelDriverProductVersion.length-2)
		}
		if ($marvelDriverProductVersionInt -gt 107)
		{
			"The driver installed is more recent than the version from 9/9/14." | Out-File -FilePath $OutputFile -append
		}
		elseif ($marvelDriverProductVersionInt -eq 107)
		{
			"The driver installed is the most recent driver (as of 9/9/14)." | Out-File -FilePath $OutputFile -append	
			"Installed: MP107; 6.3.9410.0" | Out-File -FilePath $OutputFile -append
		}
		elseif ($marvelDriverProductVersionInt -eq 67)
		{
			"The driver installed is older than the recommended version." 			| Out-File -FilePath $OutputFile -append
			"The installed driver is MP67 with version 6.3.9410.0." 				| Out-File -FilePath $OutputFile -append
			"The most recent driver (as of 9/9/14) is MP107; 6.3.9410.0." | Out-File -FilePath $OutputFile -append
		}
		else
		{
			"The driver installed is an older version of the driver." 				| Out-File -FilePath $OutputFile -append
		}
		"`n" | Out-File -FilePath $OutputFile -append
		"`n" | Out-File -FilePath $OutputFile -append
		"--------------------------------------" | Out-File -FilePath $OutputFile -append			
		"Please refer to the following article:" 	| Out-File -FilePath $OutputFile -append
		"--------------------------------------" | Out-File -FilePath $OutputFile -append
		"Public Content:"	| Out-File -FilePath $OutputFile -append
		"`"Surface Pro 3 update history`""	| Out-File -FilePath $OutputFile -append
		"http://www.microsoft.com/surface/en-us/support/install-update-activate/pro-3-update-history" 	| Out-File -FilePath $OutputFile -append
	}
	else
	{
		"The driver `"\system32\drivers\mrvlpcie8897.sys`" does not exist on this system." | Out-File -FilePath $OutputFile -append
	}	
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append



	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Wifi Driver Power Management Settings" 				| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" 									| Out-File -FilePath $OutputFile -append	
	"[info] Wifi Driver Version section"	| WriteTo-StdOut
	
	$deviceFound = $false
	$regkeyNicSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
	if (test-path $regkeyNicSettingsPath) 
	{
		if ($marvelDriverProductVersionInt -ge 107)
		{
			$regkeyNicSettings = Get-ItemProperty -Path $regkeyNicSettingsPath
			$regsubkeysNicSettings = Get-ChildItem -Path $regkeyNicSettingsPath -ErrorAction SilentlyContinue
			# using ErrorAction of SilentlyContinue because one subkey, "Properties", cannot be read.

			foreach ($childNicSettings in $regsubkeysNicSettings)
			{
				$childNicSettingsName = $childNicSettings.PSChildName
				if ($childNicSettingsName -eq "Properties")
				{
				}
				else
				{
					$childNicSettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\$childNicSettingsName"
					if (test-path $childNicSettingsPath)
					{
						$networkAdapterComponentId = (Get-ItemProperty -Path $childNicSettingsPath).ComponentId
						if ($networkAdapterComponentId -eq "pci\ven_11ab&dev_2b38&subsys_045e0001")
						{
							$deviceFound = $true
							
							# ConnectedStandby
							$regkeyPower = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
							If (test-path $regkeyPower)
							{
								"[info] Power regkey exists"  | WriteTo-StdOut 
								$regvaluePowerCsEnabled = Get-ItemProperty -path $regkeyPower -name "CsEnabled" -ErrorAction SilentlyContinue
								if ($regvaluePowerCsEnabled -ne $null)
								{
									$regvaluePowerCsEnabled = $regvaluePowerCsEnabled.CsEnabled
									"[info] Connected Standby registry value exists: $regvaluePowerCsEnabled"  | WriteTo-StdOut 
									if ($regvaluePowerCsEnabled -ne 1)
									{
										"Connected Standby is currently DISABLED. This exposes the Power Management tab in the properties of the Wireless NIC."	| Out-File -FilePath $OutputFile -append
										"`n" | Out-File -FilePath $OutputFile -append

										# Power Management Settings
										#  ENABLED  and ENABLED:  PnPCapabilities = 0x0  (0)
										#  ENABLED  and DISABLED:  PnPCapabilities = 0x10 (16)
										#  DISABLED and DISABLED:  PnPCapabilities = 0x18 (24)
										$networkAdapterPnPCapabilities = (Get-ItemProperty -Path $childNicSettingsPath).PnPCapabilities
										if ($networkAdapterPnPCapabilities -eq $null)
										{
											"Setting Name   : `"Allow the computer to turn off this device to save power`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : ENABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"Setting Name   : `"Allow this device to wake the computer`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : ENABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"PnPCapabilities registry value: Does not exist." | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append
										}
										if ($networkAdapterPnPCapabilities -eq 0)
										{
											"Setting Name   : `"Allow the computer to turn off this device to save power`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : ENABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"Setting Name   : `"Allow this device to wake the computer`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : ENABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"PnPCapabilities registry value: $networkAdapterPnPCapabilities" | Out-File -FilePath $OutputFile -append							
										}
										elseif ($networkAdapterPnPCapabilities -eq 16)
										{
											"Setting Name   : `"Allow the computer to turn off this device to save power`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : ENABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"Setting Name   : `"Allow this device to wake the computer`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : DISABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"PnPCapabilities registry value: $networkAdapterPnPCapabilities" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append		
										}
										elseif ($networkAdapterPnPCapabilities -eq 24)
										{
											"Setting Name   : `"Allow the computer to turn off this device to save power`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : DISABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"Setting Name   : `"Allow this device to wake the computer`"" | Out-File -FilePath $OutputFile -append
											"Setting Status : DISABLED" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append	
											"PnPCapabilities registry value: $networkAdapterPnPCapabilities" | Out-File -FilePath $OutputFile -append
											"`n" | Out-File -FilePath $OutputFile -append		
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	



	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Firmware Versions" 									| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"[info] Firmware Versions section"  | WriteTo-StdOut 
	"`n" | Out-File -FilePath $OutputFile -append	
	$regkeySamFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{512B1F42-CCD2-403B-8118-2F54353A1226}"
	If (test-path $regkeySamFirmware)
	{
		$regvalueSamFirmwareFilename = Get-ItemProperty -path $regkeySamFirmware -name "Filename" -ErrorAction SilentlyContinue
		if ($regvalueSamFirmwareFilename -ne $null)
		{
			$regvalueSamFirmwareFilename = $regvalueSamFirmwareFilename.Filename
			$regvalueSamFirmwareFileNameLatest = "SamFirmware.3.9.350.0.cap"
		}
		$regvalueSamFirmwareVersion = Get-ItemProperty -path $regkeySamFirmware -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueSamFirmwareVersion -ne $null)
		{
			$regvalueSamFirmwareVersion = $regvalueSamFirmwareVersion.Version
			"Surface Pro System Aggregator Firmware"									| Out-File -FilePath $OutputFile -append
			"  SamFirmware Installed Version   : $regvalueSamFirmwareFileName"			| Out-File -FilePath $OutputFile -append
			"  SamFirmware Recommended Version : $regvalueSamFirmwareFileNameLatest"	| Out-File -FilePath $OutputFile -append
			if ($regvalueSamFirmwareVersion -lt 50922320)	# Hex 0x03090350
			{
				"  The installed file version is older than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueSamFirmwareVersion -eq 50922320)	# Hex 0x03090350
			{
				"  The installed file version matches the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueSamFirmwareVersion -gt 50922320)	# Hex 0x03090350
			{
				"  The installed file version is newer than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	$regkeyECFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{52D9DA80-3D55-47E4-A9ED-D538A9B88146}"
	If (test-path $regkeyECFirmware)
	{
		$regvalueECFirmwareFileName = Get-ItemProperty -path $regkeyECFirmware -name "FileName" -ErrorAction SilentlyContinue
		if ($regvalueECFirmwareFileName -ne $null)
		{
			$regvalueECFirmwareFileName = $regvalueECFirmwareFileName.FileName
			$regvalueECFirmwareFileNameLatest = "ECFirmware.38.6.50.0.cap"
		}
		$regvalueECFirmwareVersion = Get-ItemProperty -path $regkeyECFirmware -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueECFirmwareVersion -ne $null)
		{
			$regvalueECFirmwareVersion = $regvalueECFirmwareVersion.Version
			"Surface Pro Embedded Controller Firmware"							| Out-File -FilePath $OutputFile -append
			"  ECFirmware Installed Version   : $regvalueECFirmwareFileName"		| Out-File -FilePath $OutputFile -append
			"  ECFirmware Recommended Version : $regvalueECFirmwareFileNameLatest"	| Out-File -FilePath $OutputFile -append
			if ($regvalueECFirmwareVersion -lt 3671632)	# Hex 0x00380650
			{
				"  The installed firmware version is older than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueECFirmwareVersion -eq 3671632)	# Hex 0x00380650
			{
				"  The installed firmware version matches the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueECFirmwareVersion -gt 3671632)	# Hex 0x00380650
			{
				"  The installed firmware version is newer than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	

	$regkeyUEFI = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{5A2D987B-CB39-42FE-A4CF-D5D0ABAE3A08}"
	If (test-path $regkeyUEFI)
	{
		$regvalueUEFIFileName = Get-ItemProperty -path $regkeyUEFI -name "FileName" -ErrorAction SilentlyContinue
		if ($regvalueUEFIFileName -ne $null)
		{
			$regvalueUEFIFileName = $regvalueUEFIFileName.FileName
			$regvalueUEFIFileNameLatest = "UEFI.3.10.250.0.cap"
		}
		
		$regvalueUEFIVersion = Get-ItemProperty -path $regkeyUEFI -name "Version" -ErrorAction SilentlyContinue
		if ($regvalueUEFIVersion -ne $null)
		{
			$regvalueUEFIVersion  = $regvalueUEFIVersion.Version
			"Surface Pro UEFI"										| Out-File -FilePath $OutputFile -append
			"  UEFI Installed Version   : $regvalueUEFIFileName"		| Out-File -FilePath $OutputFile -append
			"  UEFI Recommended Version : $regvalueUEFIFileNameLatest"	| Out-File -FilePath $OutputFile -append
			if ($regvalueUEFIVersion -lt 50987258)	# Hex 0x030a00fa
			{
				"  The installed firmware version is older than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueUEFIVersion -eq 50987258)	# Hex 0x030a00fa
			{
				"  The installed firmware version matches the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
			elseif ($regvalueUEFIVersion -gt 50987258)	# Hex 0x030a00fa
			{
				"  The installed firmware version is newer than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
			}
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append



	$regkeyTouchFirmware = "HKLM:\SYSTEM\CurrentControlSet\Control\FirmwareResources\{E5FFF56F-D160-4365-9E21-22B06F6746DD}"
	$regvalueTouchFirmwareFileName = Get-ItemProperty -path $regkeyTouchFirmware -name "FileName" -ErrorAction SilentlyContinue
	if ($regvalueTouchFirmwareFileName -ne $null)
	{
		$regvalueTouchFirmwareFileName = $regvalueTouchFirmwareFileName.FileName
		$regvalueTouchFirmwareFileNameLatest = "TouchFirmware.426.27.66.0.cap"
	}
	$regvalueTouchFirmwareVersion = Get-ItemProperty -path $regkeyTouchFirmware -name "Version" -ErrorAction SilentlyContinue
	if ($regvalueTouchFirmwareVersion -ne $null)
	{
		$regvalueTouchFirmwareVersion = $regvalueTouchFirmwareVersion.Version
		"Surface Pro Touch Controller Firmware"										| Out-File -FilePath $OutputFile -append
		"  TouchFirmware Installed Version   : $regvalueTouchFirmwareFileName"			| Out-File -FilePath $OutputFile -append
		"  TouchFirmware Recommended Version : $regvalueTouchFirmwareFileNameLatest"	| Out-File -FilePath $OutputFile -append
		if ($regvalueTouchFirmwareVersion -lt 27925314)	# Hex 0x01aa1b42
		{
			"  The installed firmware version is older than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
		}
		elseif ($regvalueTouchFirmwareVersion -eq 27925314)	# Hex 0x01aa1b42
		{
			"  The installed firmware version matches the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
		}
		elseif ($regvalueTouchFirmwareVersion -gt 27925314)	# Hex 0x01aa1b42
		{
			"  The installed firmware version is newer than the firmware update from 09.09.14."	| Out-File -FilePath $OutputFile -append
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"---------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Please refer to the following articles:"	| Out-File -FilePath $OutputFile -append
	"---------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Public Content:"	| Out-File -FilePath $OutputFile -append
	"`"Surface Pro 3, Surface Pro 2, and Surface Pro firmware and driver packs`""	| Out-File -FilePath $OutputFile -append
	"http://www.microsoft.com/en-us/download/details.aspx?id=38826" 	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Internal Content:"	| Out-File -FilePath $OutputFile -append
	"`"2961421 - Surface: How to check firmware versions`""	| Out-File -FilePath $OutputFile -append
	"https://vkbexternal.partners.extranet.microsoft.com/VKBWebService/ViewContent.aspx?scid=B;EN-US;2961421"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	



	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Connected Standby Status" 								| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"[info] Connected Standby Status section"  | WriteTo-StdOut 
	# Check for HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power "CsEnabled" = dword:00000000
	$regkeyPower = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
	If (test-path $regkeyPower)
	{
		"[info] Power regkey exists"  | WriteTo-StdOut 
		$regvaluePowerCsEnabled = Get-ItemProperty -path $regkeyPower -name "CsEnabled" -ErrorAction SilentlyContinue
		if ($regvaluePowerCsEnabled -ne $null)
		{
			$regvaluePowerCsEnabled = $regvaluePowerCsEnabled.CsEnabled
			"[info] Connected Standby registry value exists: $regvaluePowerCsEnabled"  | WriteTo-StdOut 
			if ($regvaluePowerCsEnabled -eq 1)
			{
				"Connected Standby is currently: ENABLED"	| Out-File -FilePath $OutputFile -append
				"CsEnabled = 1"								| Out-File -FilePath $OutputFile -append
			}
			else
			{
				"Connected Standby is currently: DISABLED"	| Out-File -FilePath $OutputFile -append
				"CsEnabled = $regvaluePowerCsEnabled"		| Out-File -FilePath $OutputFile -append
				"CsEnabled should be enabled (set to 1)."	| Out-File -FilePath $OutputFile -append
			}
		}
		"`n" | Out-File -FilePath $OutputFile -append
		"`n" | Out-File -FilePath $OutputFile -append
		
		
		# Checking for Hyper-V
		#
		# Win32_ComputerSystem class
		# http://msdn.microsoft.com/en-us/library/aa394102(v=vs.85).aspx
		#
		"[info] Checking for Windows Optional Feature (client SKUs) or Hyper-V Role (server SKUs)"  | WriteTo-StdOut 
		if ($domainRole -gt 1) 
		{ #Server
			$HyperV = Get-WindowsFeature | Where-Object {($_.installed -eq $true) -and ($_.DisplayName -eq "Hyper-V")}
			If ($HyperV -ne $null)
			{
				"Hyper-V Role: Installed"	| Out-File -FilePath $OutputFile -append
			}
			else
			{
				"Hyper-V Role: Not Installed"	| Out-File -FilePath $OutputFile -append
			}
		}
		else
		{ #Client
			$HypervClient = Get-WindowsOptionalFeature -online | Where-Object {($_.FeatureName -eq "Microsoft-Hyper-V")}
			if ($HyperVClient.State -eq "Enabled")
			{
				"Windows Optional Feature `"Client Hyper-V`": Installed"	| Out-File -FilePath $OutputFile -append
			}
			else
			{
				"Windows Optional Feature `"Client Hyper-V`": Not Installed"	| Out-File -FilePath $OutputFile -append
			}
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"--------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Please refer to the following article:"	| Out-File -FilePath $OutputFile -append
	"--------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Public Content:" | Out-File -FilePath $OutputFile -append
	"`"2973536 - Connected Standby is not available when the Hyper-V role is enabled`"" | Out-File -FilePath $OutputFile -append
	"http://support.microsoft.com/kb/2973536/EN-US" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append



	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Connected Standby Hibernation Configuration" 			| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"[info] Connected Standby Hibernation Configuration section"  | WriteTo-StdOut 
	#
	# Connected Standby Battery Saver Timeout
	#
	"Connected Standby: Battery Saver Timeout"	| Out-File -FilePath $OutputFile -append
	$regkeyCsBsTimeout = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\7398e821-3937-4469-b07b-33eb785aaca1"
	If (test-path $regkeyCsBsTimeout)
	{
		$regvalueCsBsTimeoutACSettingIndexRecommended = 14400
		$regvalueCsBsTimeoutACSettingIndex = Get-ItemProperty -path $regkeyCsBsTimeout -name "ACSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsTimeoutACSettingIndex -ne $null)
		{
			$regvalueCsBsTimeoutACSettingIndex = $regvalueCsBsTimeoutACSettingIndex.ACSettingIndex
			if ($regvalueCsBsTimeoutACSettingIndex -ne $regvalueCsBsTimeoutACSettingIndexRecommended)
			{
				"  ACSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBsTimeoutACSettingIndex" | Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  ACSettingIndex (Current Setting: No Action Needed) = $regvalueCsBsTimeoutACSettingIndex" | Out-File -FilePath $OutputFile -append				
			}
		}
		else
		{
			"  ACSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}
		
		$regvalueCsBsTimeoutDCSettingIndexRecommended = 14400
		$regvalueCsBsTimeoutDCSettingIndex = Get-ItemProperty -path $regkeyCsBsTimeout -name "DCSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsTimeoutDCSettingIndex -ne $null)
		{
			$regvalueCsBsTimeoutDCSettingIndex = $regvalueCsBsTimeoutDCSettingIndex.DCSettingIndex
			if ($regvalueCsBsTimeoutDCSettingIndex -ne $regvalueCsBsTimeoutDCSettingIndexRecommended)
			{
				"  DCSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBsTimeoutDCSettingIndex"			| Out-File -FilePath $OutputFile -append
				#"Connected Standby Battery Saver Timeout: DCSettingIndex (Recommended Setting) = $regvalueCsBsTimeoutDCSettingIndexRecommended"	| Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  DCSettingIndex (Current Setting: No Action Needed) = $regvalueCsBsTimeoutDCSettingIndex"			| Out-File -FilePath $OutputFile -append				
			}
		}
		else
		{
			"Connected Standby Battery Saver Timeout DCSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append



	#
	# Connected Standby Battery Saver Trip Point
	#
	"Connected Standby: Battery Saver Trip Point"	| Out-File -FilePath $OutputFile -append
	$regkeyCsBsTripPoint = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\1e133d45-a325-48da-8769-14ae6dc1170b"
	If (test-path $regkeyCsBsTripPoint)
	{
		$regvalueCsBstpACSettingIndexRecommended = 100
		$regvalueCsBstpACSettingIndex = Get-ItemProperty -path $regkeyCsBsTripPoint -name "ACSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBstpACSettingIndex -ne $null)	
		{
			$regvalueCsBstpACSettingIndex = $regvalueCsBstpACSettingIndex.ACSettingIndex
			if ($regvalueCsBstpACSettingIndex -ne $regvalueCsBstpACSettingIndexRecommended)
			{
				"  ACSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBstpACSettingIndex" | Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  ACSettingIndex (Current Setting: No Action Needed) = $regvalueCsBstpACSettingIndex" | Out-File -FilePath $OutputFile -append
			}
		}
		else
		{
			"Connected Standby Battery Saver Trip Point: ACSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}
		
		
		$regvalueCsBstpDCSettingIndex = Get-ItemProperty -path $regkeyCsBsTripPoint -name "DCSettingIndex" -ErrorAction SilentlyContinue	
		if ($regvalueCsBstpDCSettingIndex -ne $null)	
		{
			$regvalueCsBstpDCSettingIndexRecommended = 100
			$regvalueCsBstpDCSettingIndex = $regvalueCsBstpDCSettingIndex.DCSettingIndex
			if ($regvalueCsBstpDCSettingIndex -ne $regvalueCsBstpDCSettingIndexRecommended)
			{
				"  DCSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBstpDCSettingIndex"  | Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  DCSettingIndex (Current Setting: No Action Needed) = $regvalueCsBstpDCSettingIndex"  | Out-File -FilePath $OutputFile -append
			}
		}
		else
		{
			"Connected Standby Battery Saver Trip Point DCSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}
	}
	else
	{
		"Connected Standby Battery Saver Trip Point registry key does not exist: $regkeyCsBsTripPoint"	| Out-File -FilePath $OutputFile -append
	}
	"`n"	| Out-File -FilePath $OutputFile -append
	"`n"	| Out-File -FilePath $OutputFile -append


	
	#
	# Connected Standby Battery Saver Action
	#
	"Connected Standby: Battery Saver Action"	| Out-File -FilePath $OutputFile -append
	$regkeyCsBsAction = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\e73a048d-bf27-4f12-9731-8b2076e8891f\c10ce532-2eb1-4b3c-b3fe-374623cdcf07"
	If (test-path $regkeyCsBsAction)
	{
		$regvalueCsBsActionACSettingIndex = Get-ItemProperty -path $regkeyCsBsAction -name "ACSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsActionACSettingIndex -ne $null)
		{
			$regvalueCsBsActionACSettingIndexRecommended = 1
			$regvalueCsBsActionACSettingIndex = $regvalueCsBsActionACSettingIndex.ACSettingIndex
			if ($regvalueCsBsActionACSettingIndex -ne $regvalueCsBsActionACSettingIndexRecommended)
			{
				"  ACSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBsActionACSettingIndex"		| Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  ACSettingIndex (Current Setting: No Action Needed) = $regvalueCsBsActionACSettingIndex"		| Out-File -FilePath $OutputFile -append
			}
		}
		else
		{
			"  ACSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}

		$regvalueCsBsActionDCSettingIndex = Get-ItemProperty -path $regkeyCsBsAction -name "DCSettingIndex" -ErrorAction SilentlyContinue
		if ($regvalueCsBsActionDCSettingIndex -ne $null)
		{
			$regvalueCsBsActionDCSettingIndexRecommended = 1
			$regvalueCsBsActionDCSettingIndex = $regvalueCsBsActionDCSettingIndex.DCSettingIndex
			if ($regvalueCsBsActionDCSettingIndex -ne $regvalueCsBsActionDCSettingIndexRecommended)
			{
				"  DCSettingIndex (Current Setting: Not Optimal)      = $regvalueCsBsActionDCSettingIndex"  | Out-File -FilePath $OutputFile -append
			}
			else
			{
				"  DCSettingIndex (Current Setting: No Action Needed) = $regvalueCsBsActionDCSettingIndex"  | Out-File -FilePath $OutputFile -append
			}
		}
		else
		{
			"  DCSettingIndex registry value does not exist."	| Out-File -FilePath $OutputFile -append
		}
	}
	else
	{
		"Connected Standby Battery Saver Action registry key does not exist: $regkeyCsBsAction"	| Out-File -FilePath $OutputFile -append
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"--------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Please refer to the following article:"	| Out-File -FilePath $OutputFile -append
	"--------------------------------------" | Out-File -FilePath $OutputFile -append	
	"Internal Content:" | Out-File -FilePath $OutputFile -append
	"`"Surface Pro 3 does not hibernate after 4 hours in connected standby`""	| Out-File -FilePath $OutputFile -append
	"https://vkbexternal.partners.extranet.microsoft.com/VKBWebService/ViewContent.aspx?scid=KB;EN-US;2998588" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	
	
	#
	# Secure Boot Overview
	# http://technet.microsoft.com/en-us/library/hh824987.aspx
	#
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Secure Boot Configuration" 							| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"[info] Secure Boot section"  | WriteTo-StdOut 

	
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"Secure Boot Status"				| Out-File -FilePath $OutputFile -append
	"  (using Confirm-SecureBootUEFI)"	| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	# Determine if SecureBoot is enabled.
	#
	$secureBootEnabled = $false
	If ((Confirm-SecureBootUEFI) -eq $true)
	{
		$secureBootEnabled = $true
		"Secure Boot: ENABLED"	| Out-File -FilePath $OutputFile -append
	}
	else
	{
		"Secure Boot: DISABLED"	| Out-File -FilePath $OutputFile -append		
	}
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"Secure Boot Policy UEFI"			| Out-File -FilePath $OutputFile -append
	"  (using Get-SecureBootPolicy)"	 	| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	# Determine what policy is in use for SecureBootUEFI with Get-SecureBootPolicy
	#
	if ($secureBootEnabled)
	{
		$GUID = Get-SecureBootPolicy
		$DebugPolicyString = $Guid.Publisher.ToString()
		$DefaultPolicy = "77FA9ABD-0359-4D32-BD60-28F4E78F784B"
		$DefaultPolicyARM = "77FA9ABD-0359-4D32-BD60-28F4E78F784B"
		$DebugPolicy = "0CDAD82E-D839-4754-89A1-844AB282312B"

		"SecureBoot Policy Mode GUID: $DebugPolicyString" | Out-File -FilePath $OutputFile -append
		if($DebugPolicyString -match $DefaultPolicy) {
			"SecureBoot Policy Mode     : PRODUCTION" | Out-File -FilePath $OutputFile -append
		}
		elseif($DebugPolicyString -match $DefaultPolicyARM) {
			"SecureBoot Policy Mode     : PRODUCTION" | Out-File -FilePath $OutputFile -append
		}
		elseif($DebugPolicyString -match $DebugPolicy) {
			"SecureBoot Policy Mode     : DEBUG" | Out-File -FilePath $OutputFile -append
		}
		else {
			"SecureBoot Policy Mode: Invalid Policy $DebugPolicyString" 
		}
	}
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	

	

	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"Secure Boot Policy UEFI"								| Out-File -FilePath $OutputFile -append
	"  Using `"Get-SecureBootUefi –Name PK | fl *`")"		| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	# Get-SecureBootUEFI
	"Get-SecureBootUefi –Name PK | fl *" | Out-File -FilePath $OutputFile -append
	Get-SecureBootUefi –Name PK | fl *	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	

	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"Secure Boot Policy UEFI"								| Out-File -FilePath $OutputFile -append
	"  Using Output of `"Get-SecureBootUEFI -Name PK -OutputFilePath SecureBootPk.tmp`""	| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	Get-SecureBootUEFI -Name PK -OutputFilePath SecureBootPk.tmp
	$pk = (Get-content SecureBootPk.tmp)
	$pk | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	
	

	"===================================================="	| Out-File -FilePath $OutputFile -append
	"WMI Class Information" 								| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	

	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"WMI Class: win32_baseboard"		| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	$baseboard = Get-WmiObject -Class "win32_baseboard"
	$baseboard | fl *   | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"WMI Class: win32_battery"			| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	$battery = Get-WmiObject -Class "win32_battery"
	$battery | fl *   | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	
	
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"WMI Class: win32_bios"				| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	$bios = Get-WmiObject -Class "win32_bios"
	$bios | fl *   | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	
	
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	"WMI Class: win32_computersystem"	| Out-File -FilePath $OutputFile -append
	"------------------------------"	| Out-File -FilePath $OutputFile -append
	$computersystem = Get-WmiObject -Class "win32_computersystem"
	$computersystem | fl *   | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	"`n" | Out-File -FilePath $OutputFile -append	
	

	CollectFiles -filesToCollect $outputFile -fileDescription "Surface Pro 3 Information" -SectionDescription $sectionDescription

	
	
	
	
	
	
	
	


	$outputFile= $Computername + "_SurfacePro3_binary_versions.TXT"

	function componentSection
	{
		param 
		(
			[string]$component
		)
		$columnWidth = 52
		$componentLen = $component.length
		[int]$headerPrefix = 10
		$buffer = ($columnWidth - $componentLen - $headerPrefix)
		"-" * $headerPrefix + $component + "-" * $buffer	| Out-File -FilePath $OutputFile -append
	}


	function fileVersion
	{
		param
		(
			[string]$filename
		)

		$filenameLen = $filename.length
		$filenameExtPosition = $filenameLen - 4
		
		If ($filename.Substring($filenameExtPosition,4) -match ".sys")
		{
			$wmiQuery = "select * from cim_datafile where name='c:\\windows\\system32\\drivers\\" + $filename + "'" 
		}
		elseif ($filename.Substring($filenameExtPosition,4) -match ".dll")
		{
			$wmiQuery = "select * from cim_datafile where name='c:\\windows\\system32\\" + $filename + "'" 
		}
		elseif ($filename -match "explorer.exe")
		{
			$wmiQuery = "select * from cim_datafile where name='c:\\windows\\" + $filename + "'" 
		}
		elseif ($filename.Substring($filenameExtPosition,4) -match ".exe")
		{
			$wmiQuery = "select * from cim_datafile where name='c:\\windows\\system32\\" + $filename + "'" 
		}

		$fileObj = Get-WmiObject -query $wmiQuery
		$filenameLength = $filename.Length
		$columnLen = 35
		if (($filenameLength + 3) -ge ($columnLen))
		{
			$columnLen = $filenameLength + 3
			$columnDiff = $columnLen - $filenameLength
			$columnPrefix = 3
			$fileLine = " " * ($columnPrefix) + $filename + " " * ($columnDiff) + $fileObj.version
		}
		else
		{
			$columnDiff = $columnLen - $filenameLength
			$columnPrefix = 3
			$fileLine = " " * ($columnPrefix) + $filename + " " * ($columnDiff) + $fileObj.version
		}
		
		return $fileLine
	}


	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Surface Pro 3 Binary Versions"							| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Overview"												| Out-File -FilePath $OutputFile -append
	"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
	"   1. Bluetooth"										| Out-File -FilePath $OutputFile -append
	"   3. Keyboards"										| Out-File -FilePath $OutputFile -append
	"   4. Network Adapters"								| Out-File -FilePath $OutputFile -append
	"   5. System Devices"									| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"[info] Surface Pro 3 Binaries"  | WriteTo-StdOut

	"[info] Surface Pro 3 Binaries: Bluetooth"  | WriteTo-StdOut
	#componentSection -component "Bluetooth"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Bluetooth"												| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Marvell AVASTAR Bluetooth Radio Adapter"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Bthport.sys	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Bthusb.sys	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Fsquirt.exe	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Microsoft Bluetooth Enumerator"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Bthenum.sys	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Microsoft Bluetooth LE Enumerator"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename bthLEEnum.sys	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	"[info] Surface Pro 3 Binaries: Human Interface Devices"  | WriteTo-StdOut
	#componentSection -component "Human Interface Devices"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Human Interface Devices"								| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Pen Driver"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename "SurfacePenDriver.sys"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename "WdfCoInstaller01011.dll"	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	"[info] Surface Pro 3 Binaries: Keyboards"  | WriteTo-StdOut	
	#componentSection -component "Keyboards"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Keyboards"												| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Type Cover Filter Device"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Kbdclass.sys	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Kbdhid.sys	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	"[info] Surface Pro 3 Binaries: Network Adapters"  | WriteTo-StdOut
	#componentSection -component "Network Adapters"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"Network Adapters"										| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"ASIX AX88772 USB2.0 to Fast Ethernet Adapter"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Ax88772.sys				| Out-File -FilePath $OutputFile -append
	fileVersion -filename WdfCoInstaller01011.dll	| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# Ax88772.sys; 3.16.8.0
	# WdfCoInstaller01011.dll; 1.11.9200.16384
	"`n" | Out-File -FilePath $OutputFile -append
	"Bluetooth Device (Personal Area Network)"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Bthpan.sys			| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# Bthpan.sys; 6.3.9600.16384
	"`n" | Out-File -FilePath $OutputFile -append
	"Bluetooth Device (RFCOMM Protocol TDI)"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename bthenum.sys			| Out-File -FilePath $OutputFile -append
	fileVersion -filename rfcomm.sys			| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# bthenum.sys; 6.3.9600.16384
	# rfcomm.sys; 6.3.9600.16520
	"`n" | Out-File -FilePath $OutputFile -append
	"Marvell AVASTAR Wireless-AC Network Controller"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Mrvlpcie8897.sys				| Out-File -FilePath $OutputFile -append
	fileVersion -filename Vwifibus.sys					| Out-File -FilePath $OutputFile -append
	fileVersion -filename WiFiCLass.sys					| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# Mrvlpcie8897.sys; MP107
	# Vwifibus.sys; 6.3.9600.16384
	# WiFiCLass.sys; 6.3.9715
	"`n" | Out-File -FilePath $OutputFile -append
	"Microsoft Kernel Debug Network Adapter"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Kdnic.sys				| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# Kdnic.sys; 6.01.00.0000
	"`n" | Out-File -FilePath $OutputFile -append
	"Microsoft Wi-Fi Direct Virtual Adapter"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename Vwifimp.sys			| Out-File -FilePath $OutputFile -append
	# File versions on SurfacePro3 as of 10.10.14: 
	# Vwifimp.sys; 6.3.9600.17111
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append


	"[info] Surface Pro 3 Binaries: System Devices"  | WriteTo-StdOut
	#componentSection -component "System Devices"
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"System Devices"										| Out-File -FilePath $OutputFile -append
	"===================================================="	| Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Accessory Device"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename SurfaceAccessoryDevice.sys	| Out-File -FilePath $OutputFile -append
	#SurfaceAccessoryDevice.sys; 2.0.1012.0
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Cover Telemetry"	| Out-File -FilePath $OutputFile -append
	$filename = "SurfaceCoverTelemetry.dll"
	$wmiQuery = "select * from cim_datafile where name='c:\\windows\\system32\\drivers\\umdf\\" + $filename + "'"
	$fileObj = Get-WmiObject -query $wmiQuery
	$filenameLength = $filename.Length
	$columnLen = 35
	$columnDiff = $columnLen - $filenameLength
	$columnPrefix = 3
	$fileLine = " " * ($columnPrefix) + $filename + " " * ($columnDiff) + $fileObj.version
	$fileLine | Out-File -FilePath $OutputFile -append
	#SurfaceCoverTelemetry.dll (windir\system32\drivers\umdf); 2.0.722.0
	fileVersion -filename WUDFRd.sys	| Out-File -FilePath $OutputFile -append
	#WUDFRd.sys; 6.3.9600.17195
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Display Calibration"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename SurfaceDisplayCalibration.sys	| Out-File -FilePath $OutputFile -append
	#SurfaceDisplayCalibration.sys; 2.0.1002.0
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Home Button"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename SurfaceCapacitiveHomeButton.sys	| Out-File -FilePath $OutputFile -append
	#SurfaceCapacitiveHomeButton.sys; 2.0.358.0
	"`n" | Out-File -FilePath $OutputFile -append
	"Surface Integration"	| Out-File -FilePath $OutputFile -append
	fileVersion -filename SurfaceIntegrationDriver.sys	| Out-File -FilePath $OutputFile -append
	#SurfaceIntegrationDriver.sys; 2.0.1102.0
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append
	"`n" | Out-File -FilePath $OutputFile -append

	CollectFiles -filesToCollect $outputFile -fileDescription "Surface Pro 3 Binaries Information" -SectionDescription $sectionDescription

	
	#----------Registry
	$OutputFile= $Computername + "_SurfacePro3_reg_output.TXT"
	$CurrentVersionKeys =   "HKLM\SYSTEM\CurrentControlSet\Enum\UEFI",
							"HKLM\SYSTEM\CurrentControlSet\Control\Power",
							"HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
	RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "Surface Pro 3 Registry OutpuT" -SectionDescription $sectionDescription
}

# SIG # Begin signature block
# MIIa5gYJKoZIhvcNAQcCoIIa1zCCGtMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUo0cgfQbT25WEdsMdsAi/3msX
# lQCgghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBM4wggTK
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggecwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFPtt
# TZPljezMHeV+S0DrDayU8O/MMIGGBgorBgEEAYI3AgEMMXgwdqBcgFoAQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# RABDAF8AUwB1AHIAZgBhAGMAZQBQAHIAbwAzAC4AcABzADGhFoAUaHR0cDovL21p
# Y3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAEh3HKvfUzhnppm9e9KxEcQ1c
# WfDs/TgdrCiRzRk+mlyTQnWIuvhTRXBBllUtRoUAMvrDkDxLnwPoKeNztJJj5SJm
# oLArY4PYqY2u5r/wufPEEx1pRL4xr5T3Bd8VqM9VZxcRTDpFXVHolvBSIA+yy7f9
# Pmw2LMV0FyyzpLjMYGRwnZSxQhnmDqBV+qT5+KofC19NP6PFV91SxYZ4RcB97p3g
# 0SswviBZyb8iQyo+QdbYyQOY/pZJJk7FWbeTCn/jP4D4UZpq8OoWuxJAu+3fOoMX
# hzWBi8INmZuGnKl/SzDnyO6Yn7AkBlh3+rN6g/owDaG+rdkPuaGvIyu6HRyE/KGC
# AigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4DAhoFAKBdMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0MTAyMDE4MDgz
# NlowIwYJKoZIhvcNAQkEMRYEFP0jLrn/08hN1ZbEFVs2kCWDUhCgMA0GCSqGSIb3
# DQEBBQUABIIBACOwnDFghLWNLNC9LpOypLgCksZQhi8DX8Vz/cvC5TjPqHwT+5b5
# 8qAbUlqCMVUh3LfOdtv3c75kTazBpAypvty9rF9WVjbZp90N2geNHfp8GkWdsTNq
# vMiYeWBkA2L/mtBCfwqk7m+ggdfXFyRuLFmA96fMSadOhTaxdibLhdZPsgHd2RzJ
# e9uXlvUAn7wD++bGAEuQ6KtXkktKK3tL4siG8u5NIdlNG7ADYToBWlNl1heAF+f0
# W7Mvl9QZvkX2Lf1ZMNrVJjS7rp1m/leKHNTkTkS6uvHLcam1z/cymNEQWjNe5dVr
# ez2Z+XB7ICUlbDtjnyzByMLdAKM3IRkoeTs=
# SIG # End signature block
