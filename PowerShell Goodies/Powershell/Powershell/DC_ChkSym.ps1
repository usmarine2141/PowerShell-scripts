PARAM($range="All", $prefix="_sym", $FolderName=$null, $FileMask=$null, $Suffix=$null, $FileDescription = $null, [switch] $Recursive, [switch] $SkipCheckSymExe)

$ProcArc = $Env:PROCESSOR_ARCHITECTURE
$ChkSymExe = "Checksym" + $ProcArc + ".exe"
$IsSkipChecksymExe = ($SkipCheckSymExe.IsPresent)

if (($OSArchitecture -eq 'ARM') -and (-not($IsSkipChecksymExe)))
{
	'Skipping running chksym executable since it is not supported in ' + $OSArchitecture + ' architecture.' | WriteTo-StdOut
	$IsSkipChecksymExe=$true
}
if($IsSkipChecksymExe)
{
	"External chksym executable not be used since $ChkSymExe does not exist" | WriteTo-StdOut -ShortFormat
}

$Error.Clear() | Out-Null 

Import-LocalizedData -BindingVariable LocalsCheckSym -FileName DC_ChkSym

trap [Exception] 
{
	$errorMessage = $Error[0].Exception.Message
	$errorCode = $Error[0].Exception.ErrorRecord.FullyQualifiedErrorId
	$line = $Error[0].InvocationInfo.PositionMessage
	"[DC_ChkSym] Error " + $errorCode + " on line " + $line + ": $errorMessage running dc_chksym.ps1" | WriteTo-StdOut -ShortFormat
	$Error.Clear() | Out-Null 
}

function GetExchangeInstallFolder
{
	If ((Test-Path "HKLM:SOFTWARE\Microsoft\ExchangeServer\v14") -eq $true){
		[System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup).MsiInstallPath)
	} ElseIf ((Test-Path "HKLM:SOFTWARE\Microsoft\Exchange\v8.0") -eq $true) {
		[System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\Exchange\Setup).MsiInstallPath)
	} Else { 
		$null
	}
}

function GetDPMInstallFolder
{
	if ((Test-Path "HKLM:SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup") -eq $true)
	{
		return [System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup).InstallPath)
	}
	else
	{
		return $null
	}
}

Function FileExistOnFolder($PathToScan, $FileMask, [switch] $Recursive) 
{
	trap [Exception] {
	
		$ErrorStd = "[FileExistOnFolder] The following error ocurred when checking if a file exists on a folder:`n" 
		$errorMessage = $Error[0].Exception.Message
		$errorCode = $Error[0].Exception.ErrorRecord.FullyQualifiedErrorId
		$line = $Error[0].InvocationInfo.PositionMessage
		"$ErrorStd Error " + $errorCode + " on line " + $line + ": $errorMessage`n   Path: $PathToScan`n   FileMask: $FileMask" | WriteTo-StdOut -ShortFormat
		 $error.Clear
		 continue
	}
	
	$AFileExist = $false
	
	if (Test-Path $PathToScan)
	{
		foreach ($mask in $FileMask) {
			if ($AFileExist -eq $false) {
				if ([System.IO.Directory]::Exists($PathToScan)) {
					if ($Recursive.IsPresent)
					{
						$Files = [System.IO.Directory]::GetFiles($PathToScan, $mask,[System.IO.SearchOption]::AllDirectories)
					} else {
						$Files = [System.IO.Directory]::GetFiles($PathToScan, $mask,[System.IO.SearchOption]::TopDirectoryOnly)
					}
					$AFileExist = ($Files.Count -ne 0)
				}
			}
		}
	}
	return $AFileExist
}

Function GetAllRunningDriverFilePath([string] $DriverName)
{
	$driversPath = "HKLM:System\currentcontrolset\services\"+$DriverName
	if(Test-Path $driversPath)
	{
		$ImagePath = (Get-ItemProperty ("HKLM:System\currentcontrolset\services\"+$DriverName)).ImagePath
	}
	
	if($ImagePath -eq $null)
	{
		$driversPath = "system32\drivers\"+$DriverName+".sys"
		$ImagePath = join-path $env:windir $driversPath
		if(-not(Test-Path $ImagePath))
		{
			$Driver.Name + "not exist in the system32\drivers\"| WriteTo-StdOut -ShortFormat
		}
	}
	else
	{
		if($ImagePath.StartsWith("\SystemRoot\"))
		{
			$ImagePath = $ImagePath.Remove(0,12)
		}
		elseif($ImagePath.StartsWith("\??\"))
		{
			$ImagePath = $ImagePath.Remove(0,14)
		}
		$ImagePath = join-path $env:windir $ImagePath	
	}
	
	return $ImagePath
}

Function PrintTXTCheckSymInfo([PSObject]$OutPut, $StringBuilder, [switch]$S, [switch]$R)
{	
	if($OutPut.Processes -ne $null)
	{
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append("[PROCESSES] - Printing Process Information for "+$OutPut.Processes.Count +" Processes.`r`n")
		[void]$StringBuilder.Append("[PROCESSES] - Context: System Process(es)`r`n")
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		
		Foreach($Process in $OutPut.Processes)
		{
			$Index = 1
			[void]$StringBuilder.Append("-----------------------------------------------------------`r`n")
			[void]$StringBuilder.Append("Process Name ["+$Process.ProcessName.ToUpper()+".EXE] - PID="+$Process.Id +" - "+ $Process.Modules.Count +" modules recorded`r`n")
			[void]$StringBuilder.Append("-----------------------------------------------------------`r`n")
			foreach($mod in $Process.Modules)
			{
				if($mod.FileName -ne $null)
				{
					[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $mod.FileName+"]`r`n")
					if($R.IsPresent)
					{
						$FileItem = Get-ItemProperty $mod.FileName
						[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
						[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
						[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
						[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n")
						[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
						[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")
					
					}	
				
					if($S.IsPresent)
					{
						
					}
					[void]$StringBuilder.Append("`r`n")
					$Index+=1
				}
			}	
		}
	}
	
	if($OutPut.Drivers -ne $null)
	{		
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append( "[KERNEL-MODE DRIVERS] - Printing Module Information for "+$OutPut.Drivers.Count +" Modules.`r`n")
		[void]$StringBuilder.Append( "[KERNEL-MODE DRIVERS] - Context: Kernel-Mode Driver(s)`r`n")
		[void]$StringBuilder.Append( "*******************************************************************************`r`n")
		$Index = 1
		Foreach($Driver in $OutPut.Drivers)
		{		
			$DriverFilePath = GetAllRunningDriverFilePath $Driver.Name	
			[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $DriverFilePath+"]`r`n")
						
			if($R.IsPresent)
			{
				$FileItem = Get-ItemProperty $DriverFilePath
				if(($FileItem.VersionInfo.CompanyName -ne $null) -and ($FileItem.VersionInfo.CompanyName -ne ""))
				{
					[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
				}
				
				if(($FileItem.VersionInfo.FileDescription -ne $null) -and ($FileItem.VersionInfo.FileDescription.trim() -ne ""))
				{
					[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
				}
				
				if(($FileItem.VersionInfo.ProductVersion -ne $null) -and ($FileItem.VersionInfo.ProductVersion -ne ""))
				{
					[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
				}
				
				if(($FileItem.VersionInfo.FileVersion -ne $null) -and ($FileItem.VersionInfo.FileVersion -ne ""))
				{
					[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n"	)
				}
				[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
				[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")
			}
			
			if($S.IsPresent)
			{

			}
			
			[void]$StringBuilder.Append("`r`n")
			$Index+=1
		}
	}
	
	if($OutPut.Files -ne $null)
	{
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append("[FILESYSTEM MODULES] - Printing Module Information for "+$OutPut.Files.Count +" Modules.`r`n")
		[void]$StringBuilder.Append("[FILESYSTEM MODULES] - Context: Filesystem Modules`r`n")
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		$Index = 1
		Foreach($File in $OutPut.Files)
		{
			[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $File+"]`r`n")
			if($R.IsPresent)
			{	
				$FileItem = Get-ItemProperty $File
				if(($FileItem.VersionInfo.CompanyName -ne $null) -and ($FileItem.VersionInfo.CompanyName -ne ""))
				{
					[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
				}
				
				if(($FileItem.VersionInfo.FileDescription -ne $null) -and ($FileItem.VersionInfo.FileDescription.trim() -ne ""))
				{
					[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
				}
				
				if(($FileItem.VersionInfo.ProductVersion -ne $null) -and ($FileItem.VersionInfo.ProductVersion -ne ""))
				{
					[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
				}
				
				if(($FileItem.VersionInfo.FileVersion -ne $null) -and ($FileItem.VersionInfo.FileVersion -ne ""))
				{
					[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n"	)
				}
				[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
				[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")	
			}	
				
			if($S.IsPresent)
			{
						
			}
			[void]$StringBuilder.Append("`r`n")
			$Index+=1
		}			
	}
}

Function PrintCSVCheckSymInfo([PSObject]$OutPut, $StringBuilder, [switch]$S, [switch]$R)
{
	[void]$StringBuilder.Append("Create:,"+[DateTime]::Now+"`r`n")
	[void]$StringBuilder.Append("Computer:,"+ $ComputerName+"`r`n`r`n")

	if($OutPut.Processes -ne $null)
	{	
		[void]$StringBuilder.Append("[PROCESSES]`r`n")
		[void]$StringBuilder.Append(",Process Name,Process ID,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($Process in $OutPut.Processes)
		{
			if($Process.Modules -ne $null)
			{
				foreach($mod in $Process.Modules)
				{						
					if($mod.FileName -ne $null)
					{
						[void]$StringBuilder.Append("," +$Process.Name+".EXE,"+$Process.Id+",")
						[void]$StringBuilder.Append( $mod.FileName+",")
						if($S.IsPresent)
						{
							[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
						}
						else
						{
							[void]$StringBuilder.Append("SYMBOLS_No,,,,,,,,,")
						}
						
						if($R.IsPresent)
						{
							$FileItem = Get-ItemProperty $mod.FileName
							[void]$StringBuilder.Append( "("+$FileItem.VersionInfo.ProductVersion.Replace(",",".")+"	),("+$FileItem.VersionInfo.FileVersion.Replace(",",".")+"	),"+$FileItem.VersionInfo.CompanyName.Replace(",",".")+","+$FileItem.VersionInfo.FileDescription.Replace(",",".")+","+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
						}
						else
						{
							[void]$StringBuilder.Append( ",,,,,,,,,,,,`r`n")
						}
					}
				}
			}	
		}
	}
	
	if($OutPut.Drivers -ne $null)
	{
		[void]$StringBuilder.Append("[KERNEL-MODE DRIVERS]`r`n")
		[void]$StringBuilder.Append(",,,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($Driver in $OutPut.Drivers)
		{		
			$DriverFilePath = GetAllRunningDriverFilePath $Driver.Name	
			[void]$StringBuilder.Append(",,," +$DriverFilePath+",")
			if($S.IsPresent)
			{
				[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
			}
			else
			{
				[void]$StringBuilder.Append("SYMBOLS_NO,,,,,,,,,")
			}
						
			if($R.IsPresent)
			{
				$DriverItem = Get-ItemProperty $DriverFilePath
				if($DriverItem.VersionInfo.ProductVersion -ne $null)
				{
					[void]$StringBuilder.Append("("+$DriverItem.VersionInfo.ProductVersion.Replace(",",".")+"),("+$DriverItem.VersionInfo.FileVersion.Replace(",",".")+"),"+$DriverItem.VersionInfo.CompanyName.Replace(",",".")+","+$DriverItem.VersionInfo.FileDescription.Replace(",",".")+","+$DriverItem.Length+",,,"+$DriverItem.LastWriteTime+",,,,,`r`n")
				}
				else
				{
					[void]$StringBuilder.Append(",,,,"+$DriverItem.Length+",,,"+$DriverItem.LastWriteTime+",,,,,`r`n")
				}
			}
			else
			{
				[void]$StringBuilder.Append(",,,,,,,,,,,,`r`n")
			}	
		}
	}
	
	if($OutPut.Files -ne $null)
	{	
		[void]$StringBuilder.Append("[FILESYSTEM MODULES]`r`n")
		[void]$StringBuilder.Append(",,,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($File in $OutPut.Files)
		{						
			[void]$StringBuilder.Append(",,," +$File+",")
			if($S.IsPresent)
			{
				[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
			}
			else
			{
				[void]$StringBuilder.Append("SYMBOLS_NO,,,,,,,,,")
			}
						
			if($R.IsPresent)
			{
				$FileItem = Get-ItemProperty $File
				if($FileItem.VersionInfo.ProductVersion -ne $null)
				{
					[void]$StringBuilder.Append("("+$FileItem.VersionInfo.ProductVersion.Replace(",",".")+"	),("+$FileItem.VersionInfo.FileVersion.Replace(",",".")+"	),"+$FileItem.VersionInfo.CompanyName.Replace(",",".")+","+$FileItem.VersionInfo.FileDescription.Replace(",",".")+","+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
				}
				else
				{
					[void]$StringBuilder.Append(",,,,"+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
				}
			}
			else
			{
				[void]$StringBuilder.Append(",,,,,,,,,,,,`r`n")
			}	
		}
	}
}



#check the system information
# P ---- get the process information, can give a * get all process infor or give a process name get the specific process
# D ---- get the all local running drivers infor
# F ---- search the top level folder to get the files
# F2 ---- search the all level from folder, Recursive
# S ---- get Symbol Information
# R ---- get the Version and File-System Information
# O2 ---- Out the result to the file
Function PSChkSym ([string]$PathToScan="", [array]$FileMask = "*.*", [string]$O2="", [String]$P ="", [switch]$D, [switch]$F, [switch]$F2, [switch]$S,  [switch]$R)
{
	trap [Exception] {
	
		$ErrorStd = "[PSChkSym] The following error ocurred when getting the file from a folder:`n" 
		$errorMessage = $Error[0].Exception.Message
		$errorCode = $Error[0].Exception.ErrorRecord.FullyQualifiedErrorId
		$line = $Error[0].InvocationInfo.PositionMessage
		"$ErrorStd Error " + $errorCode + " on line " + $line + ": $errorMessage`n   Path: $PathToScan`n   FileMask: $FileMask" | WriteTo-StdOut -ShortFormat
		 $error.Clear
		 continue
	}	

	$OutPutObject = New-Object PSObject
	$SbCSVFormat = New-Object -TypeName System.Text.StringBuilder
	$SbTXTFormat = New-Object -TypeName System.Text.StringBuilder
	[void]$SbTXTFormat.Append("***** COLLECTION OPTIONS *****`r`n")
	
	if($P -ne "")
	{
		[void]$SbTXTFormat.Append("Collect Information From Running Processes`r`n")
		if($P -eq "*")
		{
			[void]$SbTXTFormat.Append("    -P *     (Query all local processes) `r`n")
			
			$Processes = [System.Diagnostics.Process]::GetProcesses()
		}
		else
		{
			[void]$SbTXTFormat.Append("    -P $P     (Query for specific process by name) `r`n" )
			
			$Processes = [System.Diagnostics.Process]::GetProcessesByName($P)
		}
	}
	
	if($D.IsPresent)
	{
		[void]$SbTXTFormat.Append("    -D     (Query all local device drivers) `r`n")
		Add-Type -assemblyname System.ServiceProcess
		$DeviceDrivers = [System.ServiceProcess.ServiceController]::GetDevices() | where-object {$_.Status -eq "Running"}
		#$DeviceDrivers = GetAllRunningDriverFileName
	}
	
	if($F.IsPresent -or $F2.IsPresent)
	{
		[void]$SbTXTFormat.Append("Collect Information From File(s) Specified by the User`r`n")
		[void]$SbTXTFormat.Append("   -F $PathToScan\$FileMask`r`n")
		if($F.IsPresent) 
		{
			Foreach($Mask in $FileMask)
			{
				$Files += [System.IO.Directory]::GetFiles($PathToScan, $Mask,[System.IO.SearchOption]::TopDirectoryOnly)
			}
		}
		else
		{
			Foreach($Mask in $FileMask)
			{
				$Files += [System.IO.Directory]::GetFiles($PathToScan, $Mask,[System.IO.SearchOption]::AllDirectories)
			}
		}
	}
	
	[void]$SbTXTFormat.Append("***** INFORMATION CHECKING OPTIONS *****`r`n")
	if($S.IsPresent -or $R.IsPresent)
	{
		if($S.IsPresent)
		{
			
			[void]$SbTXTFormat.Append("Output Symbol Information From Modules`r`n")
			[void]$SbTXTFormat.Append("   -S `r`n")
		}
		
		if($R.IsPresent)
		{
			[void]$SbTXTFormat.Append("Collect Version and File-System Information From Modules`r`n")
			[void]$SbTXTFormat.Append("   -R `r`n")
		}
	}
	else
	{
		[void]$SbTXTFormat.Append("Output Symbol Information From Modules`r`n")
		[void]$SbTXTFormat.Append("   -S `r`n")
		[void]$SbTXTFormat.Append("Collect Version and File-System Information From Modules`r`n")
		[void]$SbTXTFormat.Append("   -R `r`n")
	}
	
	[void]$SbTXTFormat.Append("***** OUTPUT OPTIONS *****`r`n")
	[void]$SbTXTFormat.Append("Output Results to STDOUT`r`n")
	[void]$SbTXTFormat.Append("Output Collected Module Information To a CSV File`r`n")
	
	if($O2 -ne "")
	{
		$OutFiles = $O2.Split('>')
		[void]$SbTXTFormat.Append("   -O "+$OutFiles[0]+" `r`n")
	}
	
	add-member -inputobject $OutPutObject -membertype noteproperty -name "Processes" -value $Processes
	add-member -inputobject $OutPutObject -membertype noteproperty -name "Drivers" -value $DeviceDrivers
	add-member -inputobject $OutPutObject -membertype noteproperty -name "Files" -value $Files
	
	if(($S.IsPresent -and $R.IsPresent) -or (-not$S.IsPresent -and -not$R.IsPresent))
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -S -R
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -S -R
	}
	elseif($S.IsPresent -and -not$R.IsPresent)
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -S
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -S
	}
	else
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -R
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -R
	}	
	
	foreach($out in $OutFiles)
	{
		if($out.EndsWith("CSV",[StringComparison]::InvariantCultureIgnoreCase))
		{
			$SbCSVFormat.ToString() | Out-File $out -Encoding "utf8"
		}
		else
		{
			if(Test-Path $out)
			{
				$SbTXTFormat.ToString() | Out-File $out -Encoding "UTF8" -Append
			}
			else
			{
				$SbTXTFormat.ToString() | Out-File $out -Encoding "UTF8"
			}
		}
	}
}


Function RunChkSym ([string]$PathToScan="", [array]$FileMask = "*.*", [string]$Output="", [boolean]$Recursive=$false, [string]$Arguments="", [string]$Description="", [boolean]$SkipChksymExe=$false)
{
	if (($Arguments -ne "") -or (Test-Path ($PathToScan))) 
	{
		if ($PathToScan -ne "")
		{
			$eOutput = $Output
			ForEach ($scFileMask in $FileMask){ #
				$eFileMask = ($scFileMask.replace("*.*","")).toupper()
				$eFileMask = ($eFileMask.replace("*.",""))
				$eFileMask = ($eFileMask.replace(".*",""))
				if (($eFileMask -ne "") -and (Test-Path ("$eOutput.*") )) {$eOutput += ("_" + $eFileMask)}
				$symScanPath += ((Join-Path -Path $PathToScan -ChildPath $scFileMask) + ";")
			}
		}
		
		if ($Description -ne "") 
		{
			$FileDescription = $Description
		} else {
			$fdFileMask = [string]::join(";",$FileMask)
			if ($fdFileMask -contains ";") { 
				$FileDescription = $PathToScan + " [" + $fdFileMask + "]"
			} else {
				$FileDescription = (Join-Path $PathToScan $fdFileMask)
			}
		}
	

		if ($Arguments -ne "") 
		{
			$eOutput = $Output
			Write-DiagProgress -Activity $LocalsCheckSym.ID_FileVersionInfo -Status $Description
			if(-not($SkipChksymExe))
			{
				$CommandToExecute = "cmd.exe /c $ChkSymExe $Arguments"
			}
			else
			{
				#calling the method to implement the functionalities
				$Arguments = $Arguments.Substring(0,$Arguments.IndexOf("-O2")+4) +"$Output.CSV>$Output.TXT"
				invoke-expression "PSChkSym  $Arguments"
			}
		}
		else {
			Write-DiagProgress -Activity $LocalsCheckSym.ID_FileVersionInfo -Status ($FileDescription)# + " Recursive: " + $Recursive)
			if ($Recursive -eq $true) {
				$F = "-F2"
				$AFileExistOnFolder = (FileExistOnFolder -PathToScan $PathToScan -FileMask $scFileMask -Recursive) 
			} else {
				$F = "-F"
				$AFileExistOnFolder = (FileExistOnFolder -PathToScan $PathToScan -FileMask $scFileMask)
				
			}
			if ($AFileExistOnFolder) 
			{
				if(-not($SkipChksymExe))
				{
					$CommandToExecute = "cmd.exe /c $ChkSymExe $F `"$symScanPath`" -R -S -O2 `"$eOutput.CSV`" > `"$eOutput.TXT`""
				}
				else
				{
					#calling the method to implement the functionalities
					if($F -eq "-F2")
					{
						PSChkSym -PathToScan $PathToScan -FileMask $FileMask -F2 -S -R -O2 "$eOutput.CSV>$eOutput.TXT"
					}
					else
					{
						PSChkSym -PathToScan $PathToScan -FileMask $FileMask -F -S -R -O2 "$eOutput.CSV>$eOutput.TXT"
					}
				}
			} 
			else 
			{
				"Chksym did not run against path '$PathToScan' since there are no files with mask ($scFileMask) on system" | WriteTo-StdOut -ShortFormat
				$CommandToExecute = ""
			}
		}
		if ($CommandToExecute -ne "") {
			RunCmD -commandToRun $CommandToExecute -sectionDescription "File Version Information (ChkSym)" -filesToCollect ("$eOutput.*") -fileDescription $FileDescription -BackgroundExecution
		}
	}
	else {
		"Chksym did not run against path '$PathToScan' since path does not exist" | WriteTo-StdOut -ShortFormat
	}
}

#Check if using $FolderName or $RangeString
if (($FolderName -ne $null) -and ($FileMask -ne $null) -and ($Suffix -ne $null)) {
	$OutputBase = $ComputerName + $Prefix + $Suffix
	$IsRecursive = ($Recursive.IsPresent)
	RunChkSym -PathToScan $FolderName -FileMask $FileMask -Output $OutputBase  -Description $FileDescription -Recursive $IsRecursive -CallChksymExe $IsSkipChecksymExe
} else {
	[array] $RunChkSym = $null
	Foreach ($RangeString in $range) 
	{
		if ($RangeString -eq "All")	
		{
			$RunChkSym += "ProgramFilesSys", "Drivers", "System32DLL", "System32Exe", "System32SYS", "Spool", "iSCSI", "Process", "RunningDrivers", "Cluster"
		} else {
			$RunChkSym += $RangeString
		}
	}

	switch ($RunChkSym)	{
		"ProgramFilesSys" {
			$OutputBase="$ComputerName$Prefix" + "_ProgramFiles_SYS"
			RunChkSym -PathToScan "$Env:ProgramFiles" -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ComputerName$Prefix" + "_ProgramFilesx86_SYS"
				RunChkSym -PathToScan (${Env:ProgramFiles(x86)}) -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"Drivers" {
			$OutputBase="$ComputerName$Prefix" + "_Drivers"
			RunChkSym -PathToScan "$Env:SystemRoot\System32\drivers" -FileMask "*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			}
		"System32DLL" {
			$OutputBase="$ComputerName$Prefix" + "_System32_DLL"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.DLL" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ComputerName$Prefix" + "_SysWOW64_DLL"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.dll" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"System32Exe" {
			$OutputBase="$ComputerName$Prefix" + "_System32_EXE"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.EXE" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ComputerName$Prefix" + "_SysWOW64_EXE"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.exe" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"System32SYS" {
			$OutputBase="$ComputerName$Prefix" + "_System32_SYS"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.SYS" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ComputerName$Prefix" + "_SysWOW64_SYS"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"Spool" {
			$OutputBase="$ComputerName$Prefix" + "_PrintSpool"
			RunChkSym -PathToScan "$Env:SystemRoot\System32\Spool" -FileMask "*.*" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
		"Cluster" {
			$OutputBase="$ComputerName$Prefix" + "_Cluster"
			RunChkSym -PathToScan "$Env:SystemRoot\Cluster" -FileMask "*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			}
		"iSCSI" {
			$OutputBase="$ComputerName$Prefix" + "_MS_iSNS"
			RunChkSym -PathToScan "$Env:ProgramFiles\Microsoft iSNS Server" -FileMask "*.*" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			$OutputBase="$ComputerName$Prefix" + "_MS_iSCSI"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "iscsi*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			}
		"Process" {
			$OutputBase="$ComputerName$Prefix" + "_Process"
			Get-Process | Format-Table -Property "Handles","NPM","PM","WS","VM","CPU","Id","ProcessName","StartTime",@{ Label = "Running Time";Expression={(GetAgeDescription -TimeSpan (new-TimeSpan $_.StartTime))}} -AutoSize | Out-File "$OutputBase.txt" -Encoding "UTF8" -Width 200
			"--------------------------------" | Out-File "$OutputBase.txt" -Encoding "UTF8" -append
			tasklist -svc | Out-File "$OutputBase.txt" -Encoding "UTF8" -append
			"--------------------------------" | Out-File "$OutputBase.txt" -Encoding "UTF8" -append
			RunChkSym -Output $OutputBase -Arguments "-P * -R -O2 `"$OutputBase.CSV`" >> `"$OutputBase.TXT`"" -Description "Running Processes" -SkipChksymExe $IsSkipChecksymExe
			}
		"RunningDrivers" {
			$OutputBase="$ComputerName$Prefix" + "_RunningDrivers"
			RunChkSym -Output $OutputBase -Arguments "-D -R -S -O2 `"$OutputBase.CSV`" > `"$OutputBase.TXT`"" -Description "Running Drivers" -SkipChksymExe $IsSkipChecksymExe
			}
		"InetSrv" {
			$inetSrvPath = (join-path $env:systemroot "system32\inetsrv")
			$OutputBase = "$ComputerName$Prefix" + "_InetSrv"
			RunChkSym -PathToScan $inetSrvPath -FileMask ("*.exe","*.dll") -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
		}
		"Exchange" {
			$ExchangeFolder = GetExchangeInstallFolder
			if ($ExchangeFolder -ne $null){
				$OutputBase = "$ComputerName$Prefix" + "_Exchange"
				RunChkSym -PathToScan $ExchangeFolder -FileMask ("*.exe","*.dll") -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			} else {
				"Chksym did not run against Exchange since it could not find Exchange server installation folder" | WriteTo-StdOut -ShortFormat
			}
		}
		"DPM" 
		{
			$DPMFolder = GetDPMInstallFolder
			If ($DPMFolder -ne $null)
			{
				$DPMFolder = Join-Path $DPMFolder "bin"
				$OutputBase= "$ComputerName$Prefix" + "_DPM"
				RunChkSym –PathToScan $DPMFolder –FileMask("*.exe","*.dll") –Output $OutputBase –Recursive $true -SkipChksymExe $IsSkipChecksymExe
			} else {
				"Chksym did not run against DPM since it could not find the DPM installation folder" | WriteTo-StdOut -ShortFormat
			}
		}		
	}
}

# SIG # Begin signature block
# MIIa0wYJKoZIhvcNAQcCoIIaxDCCGsACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMH504s9YL63IoPtMy4vOBjea
# khWgghV6MIIEuzCCA6OgAwIBAgITMwAAAFnWc81RjvAixQAAAAAAWTANBgkqhkiG
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
# acjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggTDMIIEvwIBATCBkDB5
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN
# aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAMps1TISNcThVQABAAAAyjAJ
# BgUrDgMCGgUAoIHcMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQMozk6AksUq3iP
# jXs/JhxVuIhyeDB8BgorBgEEAYI3AgEMMW4wbKBSgFAAQwBUAFMAXwBOAGUAdAB3
# AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8ARABDAF8AQwBo
# AGsAUwB5AG0ALgBwAHMAMaEWgBRodHRwOi8vbWljcm9zb2Z0LmNvbTANBgkqhkiG
# 9w0BAQEFAASCAQBssko/xyjBHDAYHNOtwm44EuNiGmPbDJZ0Q7BCcDJFNk0kyjzw
# gHbjJyRNcezmvHjRhHG6j12ul65OTBlyAGwrgOf683ib02D21/sZsZQf5zepJE/e
# PRR1mQlKev4+Ka6YoaZBRSixNO6QuHzxptX+QunxWq2fkrmQOGAyTx+dEk5HqFxz
# J+dFffvaFx1c5aCTy9b3A9W9SRWKCv6Bm3eDqUXE+Lp95J4KgZs0YPfM1tYe8bz3
# VgHHqBLte5uDgpaoHQAxovPuoIW7de6dWfDrT5qV/Bcl6JxuwxbRMKBzQHquWsiV
# cdnJOchfmsVpXWmw2HFiQvUOAUbatrtkM2Q7oYICKDCCAiQGCSqGSIb3DQEJBjGC
# AhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQQITMwAAAFnWc81R
# jvAixQAAAAAAWTAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgwODMwWjAjBgkqhkiG9w0BCQQxFgQU
# zYMpFPZOyfgCIoCfepTM1muMs20wDQYJKoZIhvcNAQEFBQAEggEAAjcURy+3wULM
# aAqiKkav1Hhm61MAXBvPcb0bW5afHlF+0ZjBtY9GYzS84XiD6KZMYczJiE51MKTT
# 6M+FL/Cdosy5yv2nJoRxck9hYm2KekY4uqsE8iyKQKAVIrgsMT9PtTvpg69yUEV2
# 3q9wUxBQxd/5j2WoF/V8uTk7MiURTLfGXI5poTK2IJmT9fqvNNvoO0cT6L1K5NIT
# zYtu59u4OyO2SD4I/AxvMpzSCP8ZJPAPZGDnj3Be+j8owkJ/ObAMT/QCN/IxNbeE
# XXVoFsBqjptZzfDbs2avx7vH2r1+8K+n0gd/CqtU9gbewapVV66FuKqFF2hPSX2p
# 5wZ6olreMA==
# SIG # End signature block
