#***************************************************
# DC_InternetExplorer-Component.ps1
# Version 1.0: HKCU and HKLM locations
# Version 1.1.06.07.13: Added "HKU\.DEFAULT" and "HKU\S-1-5-18" locations. [suggestion:johnfern]
# Version 1.2.07.30.14: Added the parsed output of Trusted Sites and Local Intranet to the new _InternetExplorer_Zones.TXT [suggestion:waltere]
# Version 1.3.08.23.14: Added Protected Mode detection for IE Zones. [suggestion:edb]  TFS264121
# Version 1.4.09.04.14: Fixed exception. Corrected syntax for reading registry value by adding "-ErrorAction SilentlyContinue"
# Date: 2009-2014
# Author: Boyd Benson (bbenson@microsoft.com)
# Description: Collects information about Internet Explorer (IE)
# Called from: Networking Diagnostics
#****************************************************

Trap [Exception]
	{
	 # Handle exception and throw it to the stdout log file. Then continue with function and script.
		 $Script:ExceptionMessage = $_
		 "[info]: Exception occurred."  | WriteTo-StdOut
		 "[info]: Exception.Message $ExceptionMessage."  | WriteTo-StdOut 
		 $Error.Clear()
		 continue
	}


$sectionDescription = "Internet Explorer"
	
Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_CTSInternetExplorer -Status $ScriptVariable.ID_CTSInternetExplorerDescription


#----------Registry
$OutputFile= $Computername + "_InternetExplorer_reg_output.TXT"
$CurrentVersionKeys =	"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
						"HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
						"HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
						"HKU\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

RegQuery -RegistryKeys $CurrentVersionKeys -Recursive $true -OutputFile $OutputFile -fileDescription "Internet Explorer registry output" -SectionDescription $sectionDescription




$isServerSku = (Get-WmiObject -Class Win32_ComputerSystem).DomainRole -gt 1
$OutputFile= $Computername + "_InternetExplorer_Zones.TXT"


"===================================================="	| Out-File -FilePath $OutputFile -append
"Internet Explorer Zone Information"					| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"Overview"												| Out-File -FilePath $OutputFile -append
"----------------------------------------------------"	| Out-File -FilePath $OutputFile -append
"   1. IE Enhanced Security Configuration (IE ESC) [Server SKU Only]"		| Out-File -FilePath $OutputFile -append
"   2. IE Protected Mode Configuration for each IE Zone"	| Out-File -FilePath $outputFile -append
"   3. List of Sites in IE Zone2 `"Trusted Sites`""		| Out-File -FilePath $OutputFile -append
"   4. List of Sites in IE Zone1 `"Local Intranet`""	| Out-File -FilePath $OutputFile -append
"===================================================="	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append
"`n"	| Out-File -FilePath $OutputFile -append



"====================================================" 	| Out-File -FilePath $outputFile -append
"IE Enhanced Security Configuration (ESC) [Server SKU Only]" 				| Out-File -FilePath $outputFile -append
"====================================================" 	| Out-File -FilePath $outputFile -append
#detect if IE ESC is enabled/disabled for user/admin
if ($isServerSku -eq $true)
{
	"`n" | Out-File -FilePath $outputFile -append
	# IE ESC is only used on Server SKUs.
	# Detecting if IE Enhanced Security Configuration is Enabled or Disabled
	#  regkey  : HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}
	#  regvalue: IsInstalled
	$regkey="HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
	$adminIEESC = (Get-ItemProperty -path $regkey).IsInstalled
	if ($adminIEESC -eq '0')
	{
		"IE ESC is DISABLED for Admin users." | Out-File -FilePath $outputFile -append
	}
	else
	{
		"IE ESC is ENABLED for Admin users." | Out-File -FilePath $outputFile -append
	}
	#user
	#  regkey  : HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}
	#  regvalue: IsInstalled
	$regkey= "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
	$userIEESC=(Get-ItemProperty -path $regkey).IsInstalled
	if ($userIEESC -eq '0')
	{
		"IE ESC is DISABLED for non-Admin users." | Out-File -FilePath $outputFile -append
	}
	else
	{
		"IE ESC is ENABLED for non-Admin users." | Out-File -FilePath $outputFile -append
	}
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
}
else
{
	"IE ESC is only used on Server SKUs. Not checking status." | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append
	"`n" | Out-File -FilePath $outputFile -append	
}



#added this section 08.23.14
"====================================================" 	| Out-File -FilePath $outputFile -append
"IE Protected Mode Configuration for each IE Zone" 		| Out-File -FilePath $outputFile -append
"====================================================" 	| Out-File -FilePath $outputFile -append
$zone0 = "Computer"
$zone1 = "Local intranet"
$zone2 = "Trusted sites"
$zone3 = "Internet"
$zone4 = "Restricted sites"
$regkeyZonesHKCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones"
$zonesHKCU = Get-ChildItem -path $regkeyZonesHKCU
$regkeyZonesHKLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones"
$zonesHKLM = Get-ChildItem -path $regkeyZonesHKLM

# Regvalue 2500 exists by default in HKLM in each zone, but may not exist in HKCU.
for($i=0;$i -le 4;$i++)
{
	if ($i -eq 0) {"IE Protected Mode for Zone0 `"$zone0`":" 	| Out-File -FilePath $outputFile -append }
	if ($i -eq 1) {"IE Protected Mode for Zone1 `"$zone1`":" 	| Out-File -FilePath $outputFile -append }
	if ($i -eq 2) {"IE Protected Mode for Zone2 `"$zone2`":" 	| Out-File -FilePath $outputFile -append }
	if ($i -eq 3) {"IE Protected Mode for Zone3 `"$zone3`":" 	| Out-File -FilePath $outputFile -append }
	if ($i -eq 4) {"IE Protected Mode for Zone4 `"$zone4`":" 	| Out-File -FilePath $outputFile -append }
	$regkeyZoneHKCU = join-path $regkeyZonesHKCU $i
	$regkeyZoneHKLM = join-path $regkeyZonesHKLM $i
	$regvalueHKCU2500Enabled = $false
	$regvalueHKLM2500Enabled = $false

	If (test-path $regkeyZoneHKCU)
	{
		#Moved away from this since it exceptions on W7/WS2008R2:   $regvalueHKCU2500 = (Get-ItemProperty -path $regkeyZoneHKCU).2500
		$regvalueHKCU2500 = Get-ItemProperty -path $regkeyZoneHKCU -name "2500" -ErrorAction SilentlyContinue		
		if ($regvalueHKCU2500 -eq 0)
		{
			#"IE Protected Mode is ENABLED in HKCU. (RegValue 2500 is set to 0.)"
			$regvalueHKCU2500Enabled = $true
		}
		if ($regvalueHKCU2500 -eq 3)
		{
			#"IE Protected Mode is DISABLED in HKCU. (RegValue 2500 is set to 3.)"
			$regvalueHKCU2500Enabled = $false
		}
	}
	If (test-path $regkeyZoneHKLM)
	{
		#Moved away from this since it exceptions on W7/WS2008R2:   $regvalueHKCU2500 = (Get-ItemProperty -path $regkeyZoneHKLM).2500
		$regvalueHKLM2500 = Get-ItemProperty -path $regkeyZoneHKLM -name "2500" -ErrorAction SilentlyContinue
		if ($regvalueHKLM2500 -eq 0)
		{
			#"IE Protected Mode is ENABLED in HKCU. (RegValue 2500 is set to 0.)"
			$regvalueHKLM2500Enabled = $true
		}
		if ($regvalueHKLM2500 -eq 3)
		{
			#"IE Protected Mode is DISABLED in HKCU. (RegValue 2500 is set to 3.)"
			$regvalueHKLM2500Enabled = $false
		}
	}


	If (($regvalueHKCU2500Enabled -eq $true) -and ($regvalueHKLM2500Enabled -eq $true))
	{
		"  ENABLED (HKCU:enabled; HKLM:enabled)" 	| Out-File -FilePath $outputFile -append
		"`n" | Out-File -FilePath $outputFile -append
	}
	elseif (($regvalueHKCU2500Enabled -eq $true) -and ($regvalueHKLM2500Enabled -eq $false))
	{
		"  DISABLED (HKCU:enabled; HKLM:disabled)" 	| Out-File -FilePath $outputFile -append
		"`n" | Out-File -FilePath $outputFile -append
	}
	elseif (($regvalueHKCU2500Enabled -eq $false) -and ($regvalueHKLM2500Enabled -eq $true))
	{
		"  ENABLED (HKCU:disabled; HKLM:enabled)" 	| Out-File -FilePath $outputFile -append
		"`n" | Out-File -FilePath $outputFile -append
	}
	elseif (($regvalueHKCU2500Enabled -eq $false) -and ($regvalueHKLM2500Enabled -eq $false))
	{
		"  DISABLED (HKCU:disabled; HKLM:disabled)" 	| Out-File -FilePath $outputFile -append
		"`n" | Out-File -FilePath $outputFile -append
	}
}
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append



#Build an array with all registry subkeys of $regkey 
$regkeyZoneMapDomains = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
$regkeyZoneMapEscDomains = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains"
$zoneMapDomains = Get-ChildItem -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
$zoneMapDomainsLength = $zoneMapDomains.length


# Creating psobjects
$ieZoneMapDomainsObj = New-Object psobject
$ieZoneMapEscDomainsObj = New-Object psobject
$ieDomainsTrustedSitesObj = New-Object psobject
$ieEscDomainsTrustedSitesObj = New-Object psobject
$ieDomainLocalIntranetObj = New-Object psobject
$ieEscDomainLocalIntranetObj = New-Object psobject


#Loop through each domain and determine what Zone the domain is in using http or https regvalues
$domainCount=0
$trustedSiteCount=0
$localIntranetCount=0
foreach ($domain in $zoneMapDomains)
{
	$domainCount++
	$domainName = $domain.PSChildName
	
	# Add all domains to $ieZoneMapDomainsObj
	Add-Member -InputObject $ieZoneMapDomainsObj -MemberType NoteProperty -Name "Domain$domainCount" -Value $domainName

	$domainRegkey = $regkeyZoneMapDomains + '\' + $domainName
	$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
	$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https
	$domainSubkeys = Get-ChildItem -path $domainRegkey

	if ($domain.SubKeyCount -ge 1)
	{
		foreach ($subkey in $domainSubkeys)
		{
			$subkeyName = $subkey.PSChildName
			$domainRegkey = $regkeyZoneMapDomains + '\' + $domainName + '\' + $subkeyName
			$fullDomainName = $subkeyName + "." + $domainName
			$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
			$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https

			if ($domainHttp -eq 2)
			{
				$trustedSiteCount++
				# Add trusted sites to the $ieDomainsTrustedSitesObj
				Add-Member -InputObject $ieDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTP" -Value $fullDomainName
			}			
			if ($domainHttps -eq 2)
			{
				$trustedSiteCount++
				# Add trusted sites to the $ieDomainsTrustedSitesObj
				Add-Member -InputObject $ieDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTPS" -Value $fullDomainName	
			}

			if ($domainHttp -eq 1)
			{
				$localIntranetCount++
				# Add Local Intranet to the $ieDomainLocalIntranetObj
				Add-Member -InputObject $ieDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTP" -Value $fullDomainName	
			}
			if ($domainHttps -eq 1)
			{
				$localIntranetCount++
				# Add Local Intranet to the $ieDomainLocalIntranetObj
				Add-Member -InputObject $ieDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTPS" -Value $fullDomainName	
			}
		}
	}
	else
	{
		$fullDomainName = $domainName
		$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
		$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https
		
		if ($domainHttp -eq 2)
		{
			$trustedSiteCount++
			# Add trusted sites to the $ieDomainsTrustedSitesObj
			Add-Member -InputObject $ieDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTP" -Value $fullDomainName				
		}
		if ($domainHttps -eq 2)
		{
			$trustedSiteCount++
			# Add trusted sites to the $ieDomainsTrustedSitesObj
			Add-Member -InputObject $ieDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTPS" -Value $fullDomainName		
		}

		if ($domainHttp -eq 1)
		{
			$localIntranetCount++
			# Add Local Intranet to the $ieDomainLocalIntranetObj
			Add-Member -InputObject $ieDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTP" -Value $fullDomainName	
		}
		if ($domainHttps -eq 1)
		{
			$localIntranetCount++
			# Add Local Intranet to the $ieDomainLocalIntranetObj
			Add-Member -InputObject $ieDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTPS" -Value $fullDomainName	
		}	
	}
}




if ($isServerSku -eq $true)
{
	#Loop through each domain and determine what Zone the domain is in using http or https regvalues
	$zoneMapEscDomains = Get-ChildItem -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains"
	$zoneMapEscDomainsLength = $zoneMapEscDomains.length

	$escDomainCount=0
	$trustedSiteCount=0
	$localIntranetCount=0
	foreach ($domain in $zoneMapEscDomains)
	{
		$escDomainCount++
		$domainName = $domain.PSChildName

		# Add domains to $ieZoneMapEscDomainsObj
		Add-Member -InputObject $ieZoneMapEscDomainsObj -MemberType NoteProperty -Name "EscDomain$escDomainCount" -Value $domainName

		$domainRegkey = $regkeyZoneMapEscDomains + '\' + $domainName
		$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
		$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https
		$domainSubkeys = Get-ChildItem -path $domainRegkey

		if ($domain.SubKeyCount -ge 1)
		{
			foreach ($subkey in $domainSubkeys)
			{
				$subkeyName = $subkey.PSChildName
				$domainRegkey = $regkeyZoneMapEscDomains + '\' + $domainName + '\' + $subkeyName
				$fullDomainName = $subkeyName + "." + $domainName
				$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
				$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https

				if ($domainHttp -eq 2)
				{
					$trustedSiteCount++
					# Add trusted sites to the $ieEscDomainsTrustedSitesObj
					Add-Member -InputObject $ieEscDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTP" -Value $fullDomainName
				}
				if ($domainHttps -eq 2)
				{
					$trustedSiteCount++
					# Add trusted sites to the $ieEscDomainsTrustedSitesObj
					Add-Member -InputObject $ieEscDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTPS" -Value $fullDomainName
				}

				if ($domainHttp -eq 1)
				{
					$localIntranetCount++
					# Add Local Intranet to the $ieEscDomainLocalIntranetObj
					Add-Member -InputObject $ieEscDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTP" -Value $fullDomainName	
				}
				if ($domainHttps -eq 1)
				{
					$localIntranetCount++
					# Add Local Intranet to the $ieEscDomainLocalIntranetObj
					Add-Member -InputObject $ieEscDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTPS" -Value $fullDomainName	
				}		
			}
		}
		else
		{
			$fullDomainName = $domainName
			$domainHttp     = (Get-ItemProperty -path "$domainRegkey").http
			$domainHttps    = (Get-ItemProperty -path "$domainRegkey").https
			
			if ($domainHttp -eq 2)
			{
				$trustedSiteCount++
				# Add trusted sites to the $ieEscDomainsTrustedSitesObj
				Add-Member -InputObject $ieEscDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTP" -Value $fullDomainName	
			}
			if ($domainHttps -eq 2)
			{
				$trustedSiteCount++
				# Add trusted sites to the $ieEscDomainsTrustedSitesObj
				Add-Member -InputObject $ieEscDomainsTrustedSitesObj -MemberType NoteProperty -Name "Website$trustedSiteCount`t: HTTPS" -Value $fullDomainName	
			}

			if ($domainHttp -eq 1)
			{
				$localIntranetCount++
				# Add Local Intranet to the $ieEscDomainLocalIntranetObj
				Add-Member -InputObject $ieEscDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTP" -Value $fullDomainName	
			}
			if ($domainHttps -eq 1)
			{
				$localIntranetCount++
				# Add Local Intranet to the $ieEscDomainLocalIntranetObj
				Add-Member -InputObject $ieEscDomainLocalIntranetObj -MemberType NoteProperty -Name "Website$localIntranetCount`t: HTTPS" -Value $fullDomainName	
			}		
		}
	}
}



"====================================================" 				| Out-File -FilePath $outputFile -append
"List of Sites in IE Zone2 `"Trusted Sites`""						| Out-File -FilePath $outputFile -append
"====================================================" 				| Out-File -FilePath $outputFile -append
if ($isServerSku -eq $true)
{
	"--------------------" 											| Out-File -FilePath $outputFile -append
	"[ZoneMap\Domains registry location]" 							| Out-File -FilePath $outputFile -append
	  "Used when IE Enhanced Security Configuration is Disabled" 	| Out-File -FilePath $outputFile -append
	"--------------------" 											| Out-File -FilePath $outputFile -append
	$ieDomainsTrustedSitesObj | fl									| Out-File -FilePath $outputFile -append
	"`n" 															| Out-File -FilePath $outputFile -append
	"`n" 															| Out-File -FilePath $outputFile -append
	"`n" 															| Out-File -FilePath $outputFile -append
	"--------------------" 											| Out-File -FilePath $outputFile -append
	"[ZoneMap\EscDomains registry location]" 						| Out-File -FilePath $outputFile -append
	"Used when IE Enhanced Security Configuration is Enabled" 		| Out-File -FilePath $outputFile -append
	"--------------------" 											| Out-File -FilePath $outputFile -append
	$ieEscDomainsTrustedSitesObj | fl								| Out-File -FilePath $outputFile -append
}
else
{
	"--------------------" 											| Out-File -FilePath $outputFile -append
	"[ZoneMap\Domains registry location]" 							| Out-File -FilePath $outputFile -append
	"--------------------" 											| Out-File -FilePath $outputFile -append
	$ieDomainsTrustedSitesObj | fl									| Out-File -FilePath $outputFile -append
}
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append




"====================================================" | Out-File -FilePath $outputFile -append
"List of Sites in IE Zone1 `"Local Intranet`"" | Out-File -FilePath $outputFile -append
"====================================================" | Out-File -FilePath $outputFile -append
if ($isServerSku -eq $true)
{
	"--------------------" 										| Out-File -FilePath $outputFile -append
	"[ZoneMap\Domains registry location]" 						| Out-File -FilePath $outputFile -append
	"Used when IE Enhanced Security Configuration is Disabled" 	| Out-File -FilePath $outputFile -append
	"--------------------" 										| Out-File -FilePath $outputFile -append
	$ieDomainLocalIntranetObj | fl								| Out-File -FilePath $outputFile -append
	"`n" 														| Out-File -FilePath $outputFile -append
	"`n" 														| Out-File -FilePath $outputFile -append
	"`n" 														| Out-File -FilePath $outputFile -append
	"--------------------" 										| Out-File -FilePath $outputFile -append
	"[ZoneMap\EscDomains registry location]" 					| Out-File -FilePath $outputFile -append
	"Used when IE Enhanced Security Configuration is Enabled" 	| Out-File -FilePath $outputFile -append
	"--------------------" 										| Out-File -FilePath $outputFile -append
	$ieEscDomainLocalIntranetObj | fl							| Out-File -FilePath $outputFile -append
}
else
{
	"--------------------" 										| Out-File -FilePath $outputFile -append
	"[ZoneMap\Domains registry location]" 						| Out-File -FilePath $outputFile -append
	"--------------------" 										| Out-File -FilePath $outputFile -append
	$ieDomainLocalIntranetObj | fl								| Out-File -FilePath $outputFile -append
}
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append
"`n" | Out-File -FilePath $outputFile -append

CollectFiles -sectionDescription $sectionDescription -fileDescription "IE Zones Information (Trusted Sites and Local Intranet)" -filesToCollect $outputFile





# SIG # Begin signature block
# MIIa/wYJKoZIhvcNAQcCoIIa8DCCGuwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaJgWd4+0vAG3HXF4bt0XqNfi
# fi2gghV6MIIEuzCCA6OgAwIBAgITMwAAAFnWc81RjvAixQAAAAAAWTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTQwNTIzMTcxMzE1
# WhcNMTUwODIzMTcxMzE1WjCBqzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# DTALBgNVBAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjpGNTI4LTM3
# NzctOEE3NjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMZsTs9oU/3vgN7oi8Sx8H4H
# zh487AyMNYdM6VE6vLawlndC+v88z+Ha4on6bkIAmVsW3QlkOOJS+9+O+pOjPbuH
# j264h8nQYE/PnIKRbZEbchCz2EN8WUpgXcawVdAn2/L2vfIgxiIsnmuLLWzqeATJ
# S8FwCee2Ha+ajAY/eHD6du7SJBR2sq4gKIMcqfBIkj+ihfeDysVR0JUgA3nSV7wT
# tU64tGxWH1MeFbvPMD/9OwHNX3Jo98rzmWYzqF0ijx1uytpl0iscJKyffKkQioXi
# bS5cSv1JuXtAsVPG30e5syNOIkcc08G5SXZCcs6Qhg4k9cI8uQk2P6hTXFb+X2EC
# AwEAAaOCAQkwggEFMB0GA1UdDgQWBBRbKBqzzXUNYz39mfWbFQJIGsumrDAfBgNV
# HSMEGDAWgBQjNPjZUkZwCu1A+3b7syuwwzWzDzBUBgNVHR8ETTBLMEmgR6BFhkNo
# dHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNyb3Nv
# ZnRUaW1lU3RhbXBQQ0EuY3JsMFgGCCsGAQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRUaW1l
# U3RhbXBQQ0EuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBBQUA
# A4IBAQB68A30RWw0lg538OLAQgVh94jTev2I1af193/yCPbV/cvKdHzbCanf1hUH
# mb/QPoeEYnvCBo7Ki2jiPd+eWsWMsqlc/lliJvXX+Xi2brQKkGVm6VEI8XzJo7cE
# N0bF54I+KFzvT3Gk57ElWuVDVDMIf6SwVS3RgnBIESANJoEO7wYldKuFw8OM4hRf
# 6AVUj7qGiaqWrpRiJfmvaYgKDLFRxAnvuIB8U5B5u+mP0EjwYsiZ8WU0O/fOtftm
# mLmiWZldPpWfFL81tPuYciQpDPO6BHqCOftGzfHgsha8fSD4nDkVJaEmLdaLgb3G
# vbCdVP5HC18tTir0h+q1D7W37ZIpMIIE7DCCA9SgAwIBAgITMwAAAMps1TISNcTh
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTvMIIE6wIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIIBBzAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUeUbyryyDTyH0
# 4DVmXF38rKlW06IwgaYGCisGAQQBgjcCAQwxgZcwgZSgeoB4AEMAVABTAF8ATgBl
# AHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABfAEQAQwBf
# AEkAbgB0AGUAcgBuAGUAdABFAHgAcABsAG8AcgBlAHIALQBDAG8AbQBwAG8AbgBl
# AG4AdAAuAHAAcwAxoRaAFGh0dHA6Ly9taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEB
# AQUABIIBAFpC+wF4HcTUhf3W8x0D86yS+9MDs0m2KcvxJPBSskC01LdVRS/F2hy6
# TKDQ6odTFJhog3dzz7QHHdBksyXSXlchfZ1i5GksiL9y5OAuf+DE4KvpFfJJfZuJ
# kf5cnjfLx5mydUHdDZFK2539xg2fLMF19lBnxfAqE5I9uyVvkoykelgGpe7QXpaq
# 9NDZS/OSXjEAYLHGInCKyfPiRJUm5dHwhhctEZkluFhrZuHdHOmPyOVzCYUhJquh
# furXpO2PCzO6+4xHlh6sOxhq8a0ai1/mI+glxHIZmlg0I+cy3qI7UMkzGGsjomAZ
# Yp9X6h9+JY8mgOCgg9VpKJf1X2dhqC+hggIoMIICJAYJKoZIhvcNAQkGMYICFTCC
# AhECAQEwgY4wdzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEh
# MB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBAhMzAAAAWdZzzVGO8CLF
# AAAAAABZMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0xNDEwMjAxODA4MzBaMCMGCSqGSIb3DQEJBDEWBBTcRCYS
# PltgZcgPHbsLXQSR/fKH0DANBgkqhkiG9w0BAQUFAASCAQCfFDvkgaW2XDe20cx1
# hXuvv+0D/GlROxuPQjZTCFWrY3LhU19chm9W/py9tsSISLmgL9gidUal3frk5SZg
# o3fuA0UkXnPjdkfSJ0MulKFXm5sBdsTb+Bq+1VqkOMIFQlcz6dt/99bMmPRfysgC
# Bsf4G9vlktaftepm5VzY0uRSMFAUASiVtr35OKzTdtby/pDHssGH4S3be61j3/Z+
# Q65BKw0WchKzzCx2lGkW+mlxANIIrnn6YgknM/mUshvHoFznpCUfchPclYxw9SYu
# v1SSqd/cXZGMT6S5K+8hLCmHjGZupXS1IsJBz+hPnKG4Lo5vOXp/AGP864+YPi0y
# o5bW
# SIG # End signature block
