﻿
$ComputerName = $Env:computername
$OSVersion = [Environment]::OSVersion.Version

$shell = New-Object -comobject WScript.Shell

#RunningUnderWTP Variable is a boolean that identifies if script is running under Windows Troubleshooting Platform (MSDT/MATS)

$IsRunningUnderWTP = (($Host.Name -eq "Default Host") -or ($Host.Name -eq "Default MSH Host"))
$IsRunningUnderEditor = ($Host.Name -eq "PowerGUIScriptEditorHost")

# FirstTimeExecution function
# ---------------------
# Description:
#        When running a diagnostic package and a root cause is found,
#        Script Diagnostic engine runs the main Troubleshooter twice
#        To avoid collecting files for a second time
#        We use the FirstTimeExecution/ EndDataCollection functions.
#        FirstTimeExecution function checks if a file called CTSDiagnostics.txt 
#        exists on TEMP folder. Then checks if the age of the file is less than 45 minutes
#        If the file does not exist or its age is bigger than 45 minutes, the function returns $true.

function FirstTimeExecution()
{
	$FlagFilePath = "$Env:temp\CTSDiagnostics.txt"

	if (Test-Path $FlagFilePath) 
	{
		$FlagFileObj = get-item $FlagFilePath
		$Now = Get-Date
		if ($FlagFileObj.LastWriteTime -gt $Now.addMinutes(-45)) 
		{
			return $false
		}
	} 
	
	switch ($Host.Name)
	{
		"Default Host" {$ClientEngine = "WTP"}
		"Default MSH Host" {$ClientEngine = "MATS"}
		Default {$ClientEngine = $Host.Name}
	}
	
	"[" + (Get-DiagID) + "] Diagnostic Execution Started. (Client engine: $ClientEngine)" | WriteTo-StdOut -InvokeInfo $MyInvocation
	
	if (Test-Path (Join-Path $PWD.Path "ConfigXPLSchema.xml"))
	{
		Start-ConfigXPLDiscovery
	}
	else
	{
		"ConfigXPLSchema.xml not found" | WriteTo-StdOut -ShortFormat
	}

	return $true
}

# SkipSecondExecution function
# ---------------------
# Description:
#        When running a diagnostic package and a root cause is found,
#        Script Diagnostic engine runs the main Troubleshooter twice.
#        This functions is to be used during a Resolver execution.
#        What it does is to write information to a file called CTSDiagnostics.txt
#        The existance and age of this file is checked by FirstTimeExecution function

function SkipSecondExecution()
{
	$FlagFilePath = "$Env:temp\CTSDiagnostics.txt"
	Get-Date | out-file -filepath $FlagFilePath
}

# EndDataCollection function
# ---------------------
# Description:
#        This function should be the last function executed during a CTS Diagnostics.
#        It copies the customized XSL file to the report so it can be visualized when 
#        the ResultsReport.xsl is opened.
#        This function also deletes the file used to flag a first time execution function

Function EndDataCollection([boolean]$DeleteFlagFile=$False)
{
	#Run Script Automatically
	

	"EndDataCollection called" | WriteTo-StdOut -ShortFormat
	Copy-Item .\cts_results.xsl (join-path $pwd.path "result\results.xsl")

	$FlagFilePath = "$Env:temp\CTSDiagnostics.txt"
	if ($DiagProcesses.Count -gt 0)
	{
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_WaitingProcessFinish -Status $UtilsCTSStrings.ID_WaitingProcessFinishDesc
		if (([array](Get-DiagBackgroundProcess -SessionName MonitorDiagExecution)).Count -gt 0)
		{
			"[WARNING] Diagnostic Monitoring sessions exists. Make sure you run .\TS_MonitorDiagExecution.ps1 -EndMonitoring to end each monitoring session." | WriteTo-StdOut -ShortFormat
			"          Killing Diagnostic Monitoring Sessions" | WriteTo-StdOut -ShortFormat
			WaitForBackgroundProcesses -SessionName "MonitorDiagExecution" -MaxBackgroundProcess 0 -OverrideMaxWaitTime 1
		}
		
		if (([array](Get-DiagBackgroundProcess -SessionName ConfigXPLDiscovery)).Count -gt 0)
		{
			"[WARNING] ConfigXPLDiscovery sessions are still running. Killing current sessions in one minute." | WriteTo-StdOut -ShortFormat
			WaitForBackgroundProcesses -SessionName "ConfigXPLDiscovery" -MaxBackgroundProcess 0 -OverrideMaxWaitTime 1
		}
		WaitForBackgroundProcesses 0
	}


	Write-DiagProgress -Activity $UtilsCTSStrings.ID_WaitingProcessingInfo -Status $UtilsCTSStrings.ID_WaitingProcessingInfoDesc

	if ($DeleteFlagFile -eq $true) 
	{
		$DiagFlagFileExist = (Test-Path $FlagFilePath)
		if ($DiagFlagFileExist -eq $true) {
			Remove-Item -path $FlagFilePath
		}
		
		# If there is a Stdout File in the parent folder at this point
		# Copy the contents to the stdout.log located in the current folder
		# This scenario usually occurs when resolvers are writting to the local stdout file.

		if (test-path $StdOutFileName) 
		{
			"Diagnostic Execution Finished" | WriteTo-StdOut -InvokeInfo $MyInvocation
			$ResolverStdoutLog = Join-Path $PWD.Path ([System.IO.Path]::GetFileNameWithoutExtension($StdOutFileName) + "-" + (Get-Random) + ".log")
			Get-Content -Path $StdOutFileName | Out-File $ResolverStdoutLog -Append
			Update-DiagReport -Id "stdout file" -Name "Resolvers StdoutFile" -File $ResolverStdoutLog -Verbosity "Debug"
			Remove-Item -Path $StdOutFileName -Force
		}
		
		$GMReportFileName = [System.IO.Path]::GetFullPath((Join-Path $PWD.Path "..\GenericMessageUpdateDiagReport.xml"))
		if (Test-Path -Path ($GMReportFileName))
		{
			Remove-Item -Path $GMReportFileName -Force
		}
	} 
	else 
	{
		#AutoExecuteScripts
		if (test-path $StdOutFileName) 
		{

			$ExistingStdoutLog = Join-Path $PWD.Path ("results\" + [System.IO.Path]::GetFileName($StdOutFileName))
			if (Test-Path $ExistingStdoutLog)
			{
				Get-Content -Path $StdOutFileName | Out-File ([System.IO.Path]::GetFileName($StdOutFileName)) -Append
			}
			else
			{
				Update-DiagReport -Id "stdout file" -Name "StdoutFile" -File $StdOutFileName -Verbosity "Debug"
			}
			Remove-Item -Path $StdOutFileName -Force
		}
	}
	
	WriteScriptExecutionInformation
}

Function Set-MaxBackgroundProcesses
{
	param([int]$NumberOfProcesses=2,[switch]$Default)
	if($Default)
	{
		"Set-MaxBackgroundProcesses called with -Default" | WriteTo-StdOut -ShortFormat
		Remove-Variable "OverrideMaxBackgroundProcesses" -Scope Global -ErrorAction SilentlyContinue
	}
	else
	{
		"Set-MaxBackgroundProcesses called with NumberOfProcesses = $NumberOfProcesses" | WriteTo-StdOut -ShortFormat
		Set-Variable "OverrideMaxBackgroundProcesses" -Scope Global -Value $NumberOfProcesses
	}
}
# Get-MaxBackgroundProcesses function
# ---------------------
#Calculate the maximum number of diagnostic packages to run in parallel
# This number will take in consideration the number of cores in a computer
# A maximum of n diagnostic parallel processes can run on a computer,
# being n the number of processor cores.

Function Get-MaxBackgroundProcesses
{
	$overrideVal = 0
	if(($global:OverrideMaxBackgroundProcesses -ne $null) -and ($global:OverrideMaxBackgroundProcesses -is [int]))
	{
		$overrideVal = [Math]::Abs(($global:OverrideMaxBackgroundProcesses -as [int]))
	}
	$Win32CS = Get-WmiObject -Class Win32_ComputerSystem
	#Pre-WinVista do not support NumberOfLogicalProcessors:
	$NumberOfCores = $Win32CS.NumberOfLogicalProcessors
	
	if ($NumberOfCores -eq $null)
	{
		$NumberOfCores = $Win32CS.NumberOfProcessors
	}
	
	return [Math]::Max($NumberOfCores,$overrideVal)
}

Filter FormatBytes 
{
	param ($bytes,$precision='0')
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[FormatBytes] - Bytes: $bytes / Precision: $precision" -InvokeInfo $MyInvocation
		continue
	}
	
	if ($bytes -eq $null)
	{
		$bytes = $_
	}
	
	if ($bytes -ne $null)
	{
		$bytes = [double] $bytes
		foreach ($i in ("Bytes","KB","MB","GB","TB")) {
			if (($bytes -lt 1000) -or ($i -eq "TB")){
				$bytes = ($bytes).tostring("F0" + "$precision")
				return $bytes + " $i"
			} else {
				$bytes /= 1KB
			}
		}
	}
}


# CollectFiles function
# ---------------------
# Description:
#        Copy files or folders to report and create a reference on report xml file
# 
# Arguments:
#		filesToCollect: Folder or Files that to be collected (Ex: C:\windows\*.txt)
#		fileDescription: Individual description of the file or folder. 
#		sectionDescription: Section description. Files with the same sectionDescription will be grouped in a single section.
#       renameOutput: Rename output to {$MachineNamePrefix}_Output.ext
#		MachineNamePrefix: It is the output file prefix,The default value is $ComputerName
#       noFileExtensionsOnDescription: Do not add file extension to the file description (Default format is $fileDescription ($FileExtension))
#       Verbosity: Verbosity level for Update-DiagReport (Informational, Warning ,Error or Debug)
# 
# Example:
#       CollectFiles -filesToCollect "C:\Windows\WindowsUpdate.log" -fileDescription "WindowsUpdate Log file" -sectionDescription "Log Files on Windows Folder" 
# 

Function CollectFiles($filesToCollect, 
				[string]$fileDescription="File", 
				[string]$sectionDescription="Section",
				[boolean]$renameOutput=$false,
				[string]$MachineNamePrefix=$ComputerName,
				[switch]$noFileExtensionsOnDescription,
				[string]$Verbosity="Informational",
				[System.Management.Automation.InvocationInfo] $InvokeInfo = $MyInvocation)
{
	$AddToStdout = "[CollectFiles] Collecting File(s):`r`n"
	if ($sectionDescription -ne "Section")
	{
		$AddToStdout += "`r`n          Section    : $sectionDescription" 
	}
	if ($fileDescription -ne "File")
	{
		$AddToStdout += "`r`n          Description: $fileDescription" 
	}

	$AddToStdout += "`r`n          Files      : $filesToCollect`r`n"
	
	$AddToStdout += "                     ----------------------------------"
	$AddToStdout | WriteTo-StdOut -InvokeInfo $InvokeInfo -ShortFormat

	ForEach ($pathFilesToCollect in $filesToCollect) 
	{
		if (($pathFilesToCollect -ne $null) -and (test-path $pathFilesToCollect -ErrorAction SilentlyContinue)) 
		{
			$FilestobeCollected = Get-ChildItem  $pathFilesToCollect
			$FilestobeCollected | ForEach-object -process {
				$FileName = Split-Path $_.Name -leaf
				$FileNameFullPath = $_.FullName
				$FileExtension = $_.extension.ToLower()
				$FilesCollectedDisplay = ''
				if ($noFileExtensionsOnDescription.IsPresent) 
				{
					$ReportDisplayName = $fileDescription
				}
				else 
				{
					$ReportDisplayName = "$fileDescription ($FileExtension)"
				}
				if($debug -eq $true){"CollectFiles:`r`nFile being collected:`r`n    " + $FileNameFullPath + "`r`nSectionDescription:`r`n    $sectionDescription `r`nFileDescription:`r`n    " + $ReportDisplayName | WriteTo-StdOut -DebugOnly}
				if (Test-Path $FileNameFullPath)
				{
					$m = (Get-Date -displayhint time).DateTime.ToString()										
					if (($renameOutput -eq $true) -and (-not $FileName.StartsWith($MachineNamePrefix))) 
					{
							$FileToCollect = $MachineNamePrefix + "_" + $FileName
	                		$FilesCollectedDisplay += "                     | [$m] $FileName to $FileToCollect" | WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'Gray' -ShortFormat -NoHeader
							Copy-Item -Path $FileNameFullPath -Destination $FileToCollect 
					}
					else 
					{
							$FileToCollect = $FileNameFullPath
						$FilesCollectedDisplay += "                     | [$m] $FileName" | WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'Gray' -ShortFormat -NoHeader
					}
							
					$FileToCollectInfo = Get-Item $FileToCollect
					
					if (($FileToCollectInfo.Length) -ge 2147483648)
					{
						$InfoSummary = New-Object PSObject
						$InfoSummary | Add-Member -membertype noteproperty -name $fileDescription -value ("Not Collected. File is too large - " + (FormatBytes -bytes $FileToCollectInfo.Length) + "")
						$InfoSummary | ConvertTo-Xml2 | update-diagreport -id ("CompFile_" + (Get-Random).ToString())  -name $ReportDisplayName -Verbosity "Error"
						"[CollectFiles] Error: $FileToCollect ($fileDescription) will not be collected once it is larger than 2GB. Current File size: " + (FormatBytes -bytes $FileToCollectInfo.Length) | WriteTo-StdOut -InvokeInfo $MyInvocation -IsError
						
					}
					else
					{
						Update-DiagReport -Id $sectionDescription -Name $ReportDisplayName -File $FileToCollect -Verbosity $Verbosity
					}
				}
				else
				{
					(" " * 21) + "[CollectFiles] " + $FileNameFullPath + " could not be found" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat -Color 'DarkYellow'  -NoHeader
				}
			}
			 
		} else {
			(" " * 21) + "[CollectFiles] " + $pathFilesToCollect + ": The system cannot find the file(s) specified" | WriteTo-StdOut -InvokeInfo $MyInvocation  -Color 'DarkYellow' -ShortFormat -NoHeader
		}
	}
	"                     ----------------------------------`r`n" | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -NoHeader -ShortFormat
}


# RunCMD function
# ---------------------
# Description:
#       This function executes a command and (optionally) collects the output file resulting from the command
#       This function is normally used to run a command line application that generates an output.
# 
# Arguments:
#       commandToRun: Command line to be executed (example: "cmd.exe /c ipconfig.exe >> file.txt")
#		filesToCollect: Folder or Files that to be collected (Ex: C:\windows\*.txt). This value can also be an array.
#		fileDescription: Individual description of the file or folder. 
#		sectionDescription: Section description. Files with the same sectionDescription will be grouped in a single section.
#       collectFiles: if $true, the resulting output will be copied to report and a reference to it will be created on report xml (Default=$true)
#       useSystemDiagnosticsObject: If present, run the $commandToRun via .NET System.Diagnostic.Process object instead of PowerShell native invoke-expression
#                                   Use this argument if the resulting output is being generated with extra blank lines (double carriage return)
#       Verbosity: When $collectFiles is true, $Verbosity is the verbosity level for CollectFiles function
#       noFileExtensionsOnDescription: Do not add file extension to the file description (Default format is $fileDescription ($FileExtension))
#       BackgroundExecution: Allows several commands to run in parallel to take advantage of multi-core computers. A maximim of n tasks will be executed at the same time - 
#                            being n the number of cores on a computer. -useSystemDiagnosticsObject will always be true when using this argument.
#       RenameOutput: When used output will follow the standard of %Computername%_Filename.txt
#       DirectCommand: When used in conjunction with useSystemDiagnosticsObject, 'cmd.exe /c' will not be added to the command line.
# 		PostProcessingScript: A script block that will be executed after the process completes.
#Example:
#		RunCMD -commandToRun  "cmd.exe /c ipconfig.exe >> file.txt" -filesToCollect "file.txt" -fileDescription "Ipconfig Output" -sectionDescription "TCP/IP Configuration Information"
# 

Function RunCMD([string]$commandToRun, 
				$filesToCollect = $null, 
				[string]$fileDescription="", 
				[string]$sectionDescription="", 
				[boolean]$collectFiles=$true,
				[switch]$useSystemDiagnosticsObject,
				[string]$Verbosity="Informational",
				[switch]$NoFileExtensionsOnDescription,
				[switch]$BackgroundExecution,
				[boolean]$RenameOutput=$false,
				[switch]$DirectCommand,
				[Scriptblock] $PostProcessingScriptBlock)
{

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[RunCMD (commandToRun = $commandToRun) (filesToCollect = $filesToCollect) (fileDescription $fileDescription) (sectionDescription = $sectionDescription) (collectFiles $collectFiles)]" -InvokeInfo $MyInvocation
		$Error.Clear()
		continue
	}
	
	if ($useSystemDiagnosticsObject.IsPresent) {
		$StringToAdd = " (Via System.Diagnostics.Process)"
	} else {
		$StringToAdd = ""
	}
	
	if ($filesToCollect -eq $null)
	{
		$collectFiles = $false
	}

	if (($BackgroundExecution.IsPresent) -and ($collectFiles -eq $false))
	{
		"[RunCMD] Warning: Background execution will be ignored since -collectFiles is false" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
	}
	
	if ($BackgroundExecution.IsPresent)
	{
		$StringToAdd += " (Background Execution)"
	}
	$StringToAdd += " (Collect Files: $collectFiles)"
	
	"[RunCMD] Running Command" + $StringToAdd + ":`r`n `r`n                      $commandToRun`r`n" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat

	# A note: if CollectFiles is set to False, background processing is not allowed
	# This is to avoid problems where multiple background commands write to the same file
	if (($BackgroundExecution.IsPresent -eq $false) -or ($collectFiles -eq $false))
	{	
		"--[Stdout-Output]---------------------" | WriteTo-StdOut -InvokeInfo $MyInvocation -NoHeader
		
		if ($useSystemDiagnosticsObject.IsPresent) 
		{
			if ($DirectCommand.IsPresent)
			{
				if ($commandToRun.StartsWith("`""))
				{
					$ProcessName = $commandToRun.Split("`"")[1]
					$Arguments = ($commandToRun.Split("`"",3)[2]).Trim()
				} 
				elseif ($commandToRun.Contains(".exe"))
				# 2. No quote found - try to find a .exe on $commandToRun
				{
					$ProcessName = $commandToRun.Substring(0,$commandToRun.IndexOf(".exe")+4)
					$Arguments = $commandToRun.Substring($commandToRun.IndexOf(".exe")+5, $commandToRun.Length - $commandToRun.IndexOf(".exe")-5)
				}
				else
				{
					$ProcessName = "cmd.exe" 
					$Arguments = "/c `"" + $commandToRun + "`""
				}
				$process = ProcessCreate -Process $ProcessName -Arguments $Arguments
			}
			else
			{
				$process = ProcessCreate -Process "cmd.exe" -Arguments ("/s /c `"" + $commandToRun + "`"")
			}
			$process.WaitForExit()
			$StdoutOutput = $process.StandardOutput.ReadToEnd() 
			if ($StdoutOutput -ne $null)
			{
				($StdoutOutput | Out-String) | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -ShortFormat -NoHeader
			}
			else
			{
				'(No stdout output generated)' | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -ShortFormat -NoHeader
			}
			$ProcessExitCode = $process.ExitCode
			if ($ProcessExitCode -ne 0) 
			{
				"[RunCMD] Process exited with error code " + ("0x{0:X}" -f $process.ExitCode)  + " when running command line:`r`n             " + $commandToRun | WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'DarkYellow'
				$ProcessStdError = $process.StandardError.ReadToEnd()
				if ($ProcessStdError -ne $null)
				{
					"--[StandardError-Output]--------------" + "`r`n" + $ProcessStdError + "--[EndOutput]-------------------------" + "`r`n" | WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'DarkYellow' -NoHeader
				}
			}
		} 
		else 
		{
			if ($commandToRun -ne $null)
			{
				$StdoutOutput = Invoke-Expression $commandToRun
				if ($StdoutOutput -ne $null)
				{
					($StdoutOutput | Out-String) | WriteTo-StdOut -InvokeInfo $MyInvocation -NoHeader
				}
				else
				{
					'(No stdout output generated)' | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -ShortFormat -NoHeader
				}
				$ProcessExitCode = $LastExitCode
				if ($LastExitCode -gt 0)
				{
					"[RunCMD] Warning: Process exited with error code " + ("0x{0:X}" -f $ProcessExitCode) | writeto-stdout -InvokeInfo $MyInvocation -Color 'DarkYellow'
				}
			}
			else
			{
				'[RunCMD] Error: a null -commandToRun argument was sent to RunCMD' | writeto-stdout -InvokeInfo $MyInvocation -IsError
				$ProcessExitCode = 99
			}
		}
		
		"--[Finished-Output]-------------------`r`n" | writeto-stdout -InvokeInfo $MyInvocation -NoHeader -ShortFormat
		
		if ($collectFiles -eq $true) 
		{	
			"[RunCMD] Collecting Output Files... " | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat
			if ($noFileExtensionsOnDescription.isPresent)
			{
				CollectFiles -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -Verbosity $Verbosity -noFileExtensionsOnDescription -renameOutput $renameOutput -InvokeInfo $MyInvocation
			} else {
				CollectFiles -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -Verbosity $Verbosity -renameOutput $renameOutput -InvokeInfo $MyInvocation
			}
		}
		#RunCMD returns exit code only if -UseSystemDiagnosticsObject is used
		if ($useSystemDiagnosticsObject.IsPresent)
		{
			return $ProcessExitCode
		}
	} 
	else 
	{ 	#Background Process
		# Need to separate process name from $commandToRun:
		# 1. Try to identify a quote:
		if ($commandToRun.StartsWith("`""))
		{
			$ProcessName = $commandToRun.Split("`"")[1]
			$Arguments = ($commandToRun.Split("`"",3)[2]).Trim()
		} 
		elseif ($commandToRun.Contains(".exe"))
		# 2. No quote found - try to find a .exe on $commandToRun
		{
			$ProcessName = $commandToRun.Substring(0,$commandToRun.IndexOf(".exe")+4)
			$Arguments = $commandToRun.Substring($commandToRun.IndexOf(".exe")+5, $commandToRun.Length - $commandToRun.IndexOf(".exe")-5)
		}
		else
		{
			$ProcessName = "cmd.exe" 
			$Arguments = "/c `"" + $commandToRun + "`""
		}
		if ($noFileExtensionsOnDescription.isPresent)
		{
			$process = BackgroundProcessCreate -ProcessName $ProcessName -Arguments $Arguments -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -CollectFiles $collectFiles -Verbosity $Verbosity -renameOutput $renameOutput -TimeoutMinutes 15 -PostProcessingScriptBlock $PostProcessingScriptBlock 
		}
		else 
		{
			$process = BackgroundProcessCreate -ProcessName $ProcessName -Arguments $Arguments -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -collectFiles $collectFiles -Verbosity $Verbosity -renameOutput $renameOutput -noFileExtensionsOnDescription -TimeoutMinutes 15 -PostProcessingScriptBlock $PostProcessingScriptBlock
	}
	}

}

Function Run-ExternalPSScript([string]$ScriptPath,  
				$filesToCollect = "", 
				[string]$fileDescription="", 
				[string]$sectionDescription="", 
				[boolean]$collectFiles=$false,
				[string]$Verbosity="Informational",
				[switch]$BackgroundExecution,
				[string]$BackgroundExecutionSessionName = 'Default',
				[int] $BackgroundExecutionTimeOut = 15,
				[switch] $BackgroundExecutionSkipMaxParallelDiagCheck,
				[scriptblock] $BackgroundExecutionPostProcessingScriptBlock)
{

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[RunExternalPSScript (ScriptPath = $ScriptPath) (filesToCollect: $filesToCollect) (fileDescription: $fileDescription) (sectionDescription: $sectionDescription) (collectFiles $collectFiles)]" -InvokeInfo $MyInvocation
		$Error.Clear()
		continue
	}

	if ($BackgroundExecution.IsPresent)
	{
		$StringToAdd += " (Background Execution)"
	}
	
	$StringToAdd += " (Collect Files: $collectFiles)"
	
	if ($collectFiles -and ([string]::IsNullOrEmpty($fileDescription) -or [string]::IsNullOrEmpty($sectionDescription) -or [string]::IsNullOrEmpty($filesToCollect)))
	{
		"[RunExternalPSScript] ERROR: -CollectFiles argument is set to $true but a fileDescription, sectionDescription and/or filesToCollect were not specified`r`n   fileDescription: [$fileDescription]`r`n   sectionDescription: [$sectionDescription]`r`n   filesToCollect: [$filesToCollect]" | WriteTo-StdOut -IsError -InvokeInfo $MyInvocation
	}
	
	"[RunExternalPSScript] Running External PowerShell Script: $ScriptPath $ScriptArgumentCmdLine " + $StringToAdd | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat

	$ScriptPath = [System.IO.Path]::GetFullPath($ScriptPath)
	if (Test-Path $ScriptPath)
	{
		if ((test-path variable:\psversiontable) -and ($OSVersion.Major -gt 5))
		{
			# PowerShell 2.0+/ WinVista+
			$DisablePSExecutionPolicy = "`$context = `$ExecutionContext.GetType().GetField(`'_context`',`'nonpublic,instance`').GetValue(`$ExecutionContext); `$authMgr = `$context.GetType().GetField(`'_authorizationManager`',`'nonpublic,instance`'); `$authMgr.SetValue(`$context, (New-Object System.Management.Automation.AuthorizationManager `'Microsoft.PowerShell`'))"
			$PSArgumentCmdLine = "-command `"& { $DisablePSExecutionPolicy ;" + $ScriptPath + " $ScriptArgumentCmdLine}`""
		}
		else
		{
			# PowerShell 1.0 ($psversiontable variable does not exist in PS 1.0)
			$PSArgumentCmdLine = "-command `"& { invoke-expression (get-content `'" + $ScriptPath + "`'| out-string) }`""
		}
		
		if ($BackgroundExecution.IsPresent -eq $false)
		{	
			$process = ProcessCreate -Process "powershell.exe" -Arguments $PSArgumentCmdLine
			
			"PowerShell started with Process ID $($process.Id)" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
			"--[Stdout-Output]---------------------" | WriteTo-StdOut -InvokeInfo $MyInvocation -NoHeader
			$process.WaitForExit()
			$StdoutOutput = $process.StandardOutput.ReadToEnd() 
			if ($StdoutOutput -ne $null)
			{
				($StdoutOutput | Out-String) | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -ShortFormat -NoHeader
			}
			else
			{
				'(No stdout output generated)' | WriteTo-StdOut -InvokeInfo $InvokeInfo -Color 'Gray' -ShortFormat -NoHeader
			}
			$ProcessExitCode = $process.ExitCode
			
			if (($ProcessExitCode -ne 0) -or ($process.StandardError.EndOfStream -eq $false))
			{
				"[RunExternalPSScript] Process exited with error code " + ("0x{0:X}" -f $process.ExitCode)  + " when running $ScriptPath"| WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'DarkYellow'
				$ProcessStdError = $process.StandardError.ReadToEnd()
				if ($ProcessStdError -ne $null)
				{
					"--[StandardError-Output]--------------" + "`r`n" + $ProcessStdError + "--[EndOutput]-------------------------" + "`r`n" | WriteTo-StdOut -InvokeInfo $MyInvocation -Color 'DarkYellow' -NoHeader
				}
			}
			"--[Finished-Output]-------------------`r`n" | writeto-stdout -InvokeInfo $MyInvocation -NoHeader -ShortFormat	
			
			if ($collectFiles -eq $true) 
			{	
				"[RunExternalPSScript] Collecting Output Files... " | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat
				CollectFiles -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -Verbosity $Verbosity -renameOutput $renameOutput -InvokeInfo $MyInvocation
			}
			return $ProcessExitCode
		} 
		else 
		{ 
			$Process = BackgroundProcessCreate -ProcessName "powershell.exe" -Arguments $PSArgumentCmdLine -filesToCollect $filesToCollect -fileDescription $fileDescription -sectionDescription $sectionDescription -collectFiles $collectFiles -Verbosity $Verbosity -TimeoutMinutes $BackgroundExecutionTimeOut -PostProcessingScriptBlock $BackgroundExecutionPostProcessingScriptBlock -SkipMaxParallelDiagCheck:$BackgroundExecutionSkipMaxParallelDiagCheck -SessionName $BackgroundExecutionSessionName
			return $Process
		}
	}
	else
	{
		"[RunExternalPSScript] ERROR: Script [$ScriptPath] could not be found" | WriteTo-StdOut -IsError -InvokeInfo $MyInvocation
	}
}

Function WaitForBackgroundProcesses($MaxBackgroundProcess = 0, $SessionName = 'AllSessions', $OverrideMaxWaitTime = $null)
{

	$ProcessCloseRequested=New-Object System.Collections.ArrayList
	$BackgroundProcessToWait = [array](Get-DiagBackgroundProcess -SessionName $SessionName)
	
	$ProcessIdNotified = @()
	while (($BackgroundProcessToWait | Measure-Object).Count -gt ($MaxBackgroundProcess))
	{
		if (-not $WaitMSG)
		{
			$ProcessDisplay = ""
			foreach ($Process in $BackgroundProcessToWait)
			{
				[string] $ProcessID = $Process.Id
				$SessionId = $DiagProcessesSessionNames.get_Item($Process.Id)
				$ProcessDisplay += "`r`n    Session Name: $SessionId `r`n"
				$ProcessDisplay += "    Process ID  : $ProcessID `r`n"
				$ProcessDisplay += "    Command Line: " + $Process.StartInfo.FileName + " " + $Process.StartInfo.Arguments + "`r`n"
				$ProcessDisplay += "    Running for : " + (GetAgeDescription -TimeSpan (new-TimeSpan $Process.StartTime)) + "`r`n"				
			}
									
			"[WaitForBackgroundProcesses] Waiting for one background process(es) to finish in session [$SessionName]. Current background processes:`r`n" + $ProcessDisplay | WriteTo-StdOut
			$WaitMSG = $true
		}
		
		$BackgroundProcessToWait = [array](Get-DiagBackgroundProcess -SessionName $SessionName)
		
		if (($BackgroundProcessToWait | Measure-Object).Count -ne 0)
		{
			sleep -Milliseconds 500
		}
	
		#Check for timeout
		foreach ($Process in $BackgroundProcessToWait)
		{
			if($null -eq $Process){continue}
			$ExecutionTimeout = ($DiagProcessesBGProcessTimeout.get_Item($Process.Id))
			if ($OverrideMaxWaitTime -ne $null)
			{
				if ($ProcessIdNotified -notcontains $Process.Id)
				{
					"[WaitForBackgroundProcesses] Overriding process $($Process.Id) [Session $SessionName] time out from $ExecutionTimeout to $OverrideMaxWaitTime minutes." | WriteTo-StdOut 
					$ProcessIdNotified += $Process.Id
				}
				$ExecutionTimeout = ($OverrideMaxWaitTime)
			}
			if ($ExecutionTimeout -ne 0)
			{
				if ((New-TimeSpan -Start $Process.StartTime).Minutes -ge $ExecutionTimeout)
				{
					if (-not $ProcessCloseRequested.Contains($Process.Id))
					{
						[string] $ProcessID = $Process.Id
						$SessionId = $DiagProcessesSessionNames.get_Item($Process.Id)
						$ProcessDisplay = "[WaitForBackgroundProcesses] A process will be terminated due it reached a timeout of $ExecutionTimeout minutes:`r`n"
						$ProcessDisplay += "        Session Name: [$SessionId] `r`n"
						$ProcessDisplay += "        Process ID  : $ProcessID `r`n"
						$ProcessDisplay += "        Start Time  : " + $Process.StartTime + "`r`n"
						$ProcessDisplay += "        Command Line: " + $Process.StartInfo.FileName + " " + $Process.StartInfo.Arguments + "`r`n"
						$ProcessDisplay += "        Running for : " + (GetAgeDescription -TimeSpan (new-TimeSpan $Process.StartTime)) + "`r`n"
						$ProcessDisplay | WriteTo-StdOut
					}
					
					if ($Process.HasExited -eq $false)
					{
						$Process.CloseMainWindow()
						$ProcessCloseRequested.Add($Process.Id)
					}
					
					if ((New-TimeSpan -Start $Process.StartTime).Minutes -gt ($ExecutionTimeout))
					{
						if ($Process.HasExited -eq $false)
						{
							"Killing process " + $Process.Id + " once it did not close orderly after " + ($ExecutionTimeout +1) + " minutes" | WriteTo-StdOut
							$Process.Kill()
						}
					}
				}
			}
		}
	}
	
	if ($WaitMSG) 
	{
		$ProcessDisplay = ""
		foreach ($Process in ($DiagProcesses | Where-Object {$_.HasExited -eq $true}))
		{
			[string] $ProcessID = $Process.Id
			$SessionId = $DiagProcessesSessionNames.get_Item($Process.Id)
			$ProcessDisplay += "`r`n    Session Name: [$SessionId] `r`n"
			$ProcessDisplay += "    Process ID  : $ProcessID `r`n"
			$ProcessDisplay += "    Run time    : " + (GetAgeDescription -TimeSpan (new-TimeSpan -Start $Process.StartTime -End $Process.ExitTime))
		}
		"[WaitForBackgroundProcesses] The following background process(es) finished executing: `r`n" + $ProcessDisplay | WriteTo-StdOut
	}

	#If there are process there were terminated, files needs to be collected
	$NumberofTerminatedProcesses = [array] ($DiagProcesses | Where-Object {$_.HasExited -eq $true})
	
	if (($NumberofTerminatedProcesses | Measure-Object).Count -gt 0)
	{
		CollectBackgroundProcessesFiles
	}

}

# BackgroundProcessCreate function
# ---------------------
# Description:
#       This function creates a process in background. The maximum number of parallel process that can run is the number of cores in a machine.
#       If the maximum number of parallel process are running, BackgroundProcessCreate will wait until one or more processes running in background 
#       finishes running or a timeout is reached.
#       This function is also used by RunCMD when the -Background switch is used.
# Arguments:
#       ProcessName: Path to the process name (Ex: C:\windows\system32\gpresult.exe)
#       Arguments: Arguments passed to the process (Ex: "/h $Computername_GPReport.htm")
#		filesToCollect: Folder or Files that to be collected (Ex: $Computername_GPReport.*). This value can also be an array.
#		fileDescription: Individual description of the files to be colected. 
#		sectionDescription: Section description. Files with the same sectionDescription will be grouped in a single section.
#       Verbosity: Verbosity level for CollectFiles function
#       noFileExtensionsOnDescription: Do not add file extension to the file description (Default format is $fileDescription ($FileExtension))
#       TimeoutMinutes: Timeout for the process execution. By default a process is terminated if it does not finish running after 15 minutes of execution

Function BackgroundProcessCreate([string]$ProcessName, 
								[string]$Arguments,
								$filesToCollect, 
								[string]$fileDescription="", 
								[string]$sectionDescription="", 
								[string]$Verbosity="Informational",
								[switch]$noFileExtensionsOnDescription,
								[boolean]$renameOutput = $true,
								[boolean]$CollectFiles = $true,
								[int] $TimeoutMinutes = 15,
								[scriptblock]$PostProcessingScriptBlock,
								[switch] $SkipMaxParallelDiagCheck,
								[string] $SessionName = 'Default')
{
	if ($MaxParallelDiagProcesses -eq $null)
	{
		#$MaxParallelDiagProcesses = Get-MaxBackgroundProcesses
		Set-Variable -Name MaxParallelDiagProcesses -Value (Get-MaxBackgroundProcesses)
	}
	
	#Wait until there are slots available
	"[BackgroundProcessCreate] Creating background process: [(Session: " + $SessionName+ ") Process: `'" + $ProcessName + "`' - Arguments: `'" + $Arguments + "`']" | WriteTo-StdOut
	$WaitMSG = $false

	if ($SkipMaxParallelDiagCheck.IsPresent -eq $false)
	{
		WaitForBackgroundProcesses -MaxBackgroundProcess $MaxParallelDiagProcesses
	}
	else
	{
		#When SkipMaxParallelDiagCheck is used, increase the number of allowed background processes by 1 while the new process is running
		if ($Global:OverrideMaxBackgroundProcesses -eq $null)
		{
			$Global:OverrideMaxBackgroundProcesses = $MaxParallelDiagProcesses
		}
		$Global:OverrideMaxBackgroundProcesses++
		Set-MaxBackgroundProcesses -NumberOfProcesses $Global:OverrideMaxBackgroundProcesses
	}
	
	#Start process in background
	$Process = ProcessCreate -Process $ProcessName -Arguments $Arguments 

	#Fill out Diagnostic variables so we can use in the future
	[Void] $DiagProcesses.Add($Process)
	$DiagProcessesFileDescription.Add($Process.Id, $fileDescription)
	$DiagProcessesSectionDescription.Add($Process.Id, $sectionDescription)
	$DiagProcessesVerbosity.Add($Process.Id, $Verbosity)
	$DiagProcessesFilesToCollect.Add($Process.Id, $filesToCollect)
	$DiagProcessesAddFileExtension.Add($Process.Id, -not ($noFileExtensionsOnDescription.IsPresent))
	$DiagProcessesBGProcessTimeout.Add($Process.Id, $TimeoutMinutes)
	$DiagProcessesSessionNames.Add($Process.Id, $SessionName)
	if ($SkipMaxParallelDiagCheck.IsPresent)
	{
		$DiagProcessesSkipMaxParallelDiagCheck.Add($Process.Id, $true)
	}

	if($null -ne $PostProcessingScriptBlock)
	{
		if($Process.HasExited)
		{
			"[BackgroundProcessCreate] Process already exited. Running `$PostProcessingScriptBlock" | WriteTo-StdOut -shortformat
			& $PostProcessingScriptBlock
		}
		else
		{
			if((test-path variable:psversiontable) -and ($PSVersionTable.PSVersion.Major -ge 2))
			{
				$Process.EnableRaisingEvents = $true
				$postProcSB = @"
				. .\utils_cts.ps1
				"[Utils_CTS] Running PostProcessingScriptBlock" | WriteTo-StdOut -ShortFormat
				$($PostProcessingScriptBlock.ToString())
"@
				"[BackgroundProcessCreate] Registering an event for process exit and attaching script block. ScriptBlock = `r`n $postProcSB" | WriteTo-StdOut -ShortFormat
				
				$ModifiedSB = [Scriptblock]::Create($postProcSB);
				Register-ObjectEvent -InputObject $Process -EventName "Exited" -Action $ModifiedSB -SourceIdentifier $Process.Id			
			}
			else
			{
				$DiagProcessesScriptblocks.Add($Process.Id, $PostProcessingScriptBlock)
			}
		}
	}
	$DiagProcessesRenameOutput.Add($Process.Id, $renameOutput)
	
	Return $Process
	
}

# Get-DiagID function
# ---------------------
# Description:
#       Return the ID for the current diagnostic package

function Get-DiagID
{
	if (Test-Path ($PWD.Path + "\DiagPackage.diagpkg"))
	{
		[xml] $DiagPackageXML = Get-Content -Path ($PWD.Path + "\DiagPackage.diagpkg")
	}
	if ($DiagPackageXML -ne $null)
	{
		$DiagID = $DiagPackageXML.DiagnosticPackage.DiagnosticIdentification.ID
		if ($DiagID -ne $null)
		{
			return $DiagID
		}
		else
		{
			return "Unknown"
		}
	}
	else
	{
		return "Unknown"
	}
}

#Return an array with process running in a given session
Function Get-DiagBackgroundProcess($SessionName = 'AllSessions')
{
	if ($DiagProcesses.Count -gt 0)
	{
		$RunningDiagProcesses = [array] ($DiagProcesses | Where-Object {$_.HasExited -eq $false})
		if ($RunningDiagProcesses.Count -ne $null)
		{
			if ($SessionName -eq 'AllSessions')
			{
				return ($RunningDiagProcesses)
			}
			else
			{
				$RunningDiagProcessesInSession = @()
				$RunningDiagProcesses | ForEach-Object -Process {
					if (($DiagProcessesSessionNames.get_Item($_.Id) -ne $null) -and ($DiagProcessesSessionNames.get_Item($_.Id) -eq $SessionName))
					{
						$RunningDiagProcessesInSession += $_
					}
				}
				return $RunningDiagProcessesInSession
			}
		}
		else 
		{
			return $null	
		}
	} 
	else 
	{
		return $null
	}
}

# CollectBackgroundProcessesFiles function
# ---------------------
# Description:
#       Collect files from processes which was terminated. Also, update the Processes arrays and hash tables

Function CollectBackgroundProcessesFiles()
{
	Foreach ($DiagnosticProcess in ($DiagProcesses | Where-Object {$_.HasExited -eq $true}))
	{
		$ProcessID = $DiagnosticProcess.Id
		$SessionName = $DiagProcessesSessionNames.get_Item($ProcessID)
		
		if ($DiagnosticProcess.ExitCode -ne 0) 
		{
			$msg = "[CollectBackgroundProcessesFiles] Process $ProcessID [$SessionName] exited with error " + ("0x{0:X}" -f $DiagnosticProcess.ExitCode) + " when running command line:`r`n"
			$msg += "             " + $process.Path + " " + $DiagnosticProcess.StartInfo.Arguments.ToString() 
			$msg | writeto-stdout -Color 'DarkYellow'
			

		}		
		if ($DiagnosticProcess.StandardError) 
		{
			$ProcessStdError = $DiagnosticProcess.StandardError.ReadToEnd()
			if (-not [string]::IsNullOrEmpty($DiagnosticProcess.StandardError)) 
			{
				"--[StandardError-Output]--------------" + "`r`n" + $ProcessStdError + "--[EndOutput]-------------------------" + "`r`n" | writeto-stdout -Color 'DarkYellow' -NoHeader
			}
		}
		if ($DiagnosticProcess.StandardOutput -ne $null)
		{
			$stdoutOutput = $DiagnosticProcess.StandardOutput.ReadToEnd()
			if ($stdoutOutput.Length -gt 0)
			{
				$StdoutOutput = "[CollectBackgroundProcessesFiles] Deferred Stdout output from [" + $DiagnosticProcess.StartInfo.FileName + " " + $DiagnosticProcess.StartInfo.Arguments + "] [$SessionName] execution:`r`n" + ("-" * 80) + "`r`n`r`n" + $stdoutOutput
				$stdoutOutput += "`r`n" + ("-" * 80) 
			} else {
				$stdoutOutput += "[CollectBackgroundProcessesFiles] Command [" + $DiagnosticProcess.StartInfo.FileName + " " + $DiagnosticProcess.StartInfo.Arguments + "] [$SessionName] did not generate any stdout output." 
			}
			$stdoutOutput | writeto-stdout -InvokeInfo $MyInvocation -Color 'DarkYellow'
		}
		
		if ($DiagProcessesFilesToCollect.get_Item($ProcessID) -ne $null)
		{
			$fileDescription = $DiagProcessesFileDescription.get_Item($ProcessID)
			$SectionDescription = $DiagProcessesSectionDescription.get_Item($ProcessID)
			$filesToCollect = $DiagProcessesFilesToCollect.get_Item($ProcessID)
			$Verbosity = $DiagProcessesVerbosity.get_Item($ProcessID)
			$RenameOutput = $DiagProcessesRenameOutput.get_Item($ProcessID)
			$AddFileExtension = $DiagProcessesAddFileExtension.get_Item($ProcessID)
			
			if ((-not [string]::IsNullOrEmpty($filesToCollect)) -and (-not [string]::IsNullOrEmpty($fileDescription)))
			{
				"[CollectBackgroundProcessesFiles] Collecting $fileDescription from process id " + $ProcessID + " [$SessionName]" | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat
				if ($AddFileExtension)
				{
					CollectFiles -fileDescription $fileDescription -filesToCollect $filesToCollect -sectionDescription $SectionDescription -Verbosity $Verbosity -renameOutput $RenameOutput
				} 
				else 
				{
					CollectFiles -fileDescription $fileDescription -filesToCollect $filesToCollect -sectionDescription $SectionDescription -Verbosity $Verbosity -noFileExtensionsOnDescription -renameOutput $RenameOutput
				}
			}
		}
		else
		{
			"[CollectBackgroundProcessesFiles] No files to collect for process id " + $ProcessID + " [$SessionName]" | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat -Color 'DarkYellow'
		}
				
		if ($DiagProcessesSkipMaxParallelDiagCheck.get_Item($ProcessID) -eq $true)
		{
			"[CollectBackgroundProcessesFiles] Restoring number of max background process as process $ProcessID was started with SkipMaxParallelDiagCheck" | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat -Color 'DarkYellow'
			$Global:OverrideMaxBackgroundProcesses--
			Set-MaxBackgroundProcesses -NumberOfProcesses $Global:OverrideMaxBackgroundProcesses
			$DiagProcessesSkipMaxParallelDiagCheck.Remove($ProcessID)
		}
		
		if ($DiagProcessesScriptblocks.get_Item($ProcessID) -ne $Null)
		{
			"[CollectBackgroundProcessesFiles] Executing PostProcessingScriptBlock: `r`n $($DiagProcessesScriptblocks[$ProcessID].ToString())" | writeto-stdout -InvokeInfo $MyInvocation -ShortFormat
			& ($DiagProcessesScriptblocks[$ProcessID]) 
			$DiagProcessesScriptblocks.Remove($ProcessID)
		}
		
		$DiagProcessesFileDescription.Remove($ProcessID)
		$DiagProcessesSectionDescription.Remove($ProcessID)
		$DiagProcessesFilesToCollect.Remove($ProcessID)
		$DiagProcessesVerbosity.Remove($ProcessID)
		$DiagProcessesAddFileExtension.Remove($ProcessID)
		$DiagProcessesBGProcessTimeout.Remove($ProcessID)
		$DiagProcessesRenameOutput.Remove($ProcessID)
		$DiagProcessesSessionNames.Remove($ProcessID)		
		$DiagProcesses.Remove($DiagnosticProcess)
		
	}
}

Function ProcessCreate($Process, $Arguments = "", $WorkingDirectory = $null)
{
	
	"ProcessCreate($Process, $Arguments) called." | WriteTo-StdOut -ShortFormat -DebugOnly
	
	$Error.Clear()
	$processStartInfo  = new-object System.Diagnostics.ProcessStartInfo
	$processStartInfo.fileName = $Process
	if ($Arguments.Length -ne 0) { $processStartInfo.Arguments = $Arguments }
	if ($WorkingDirectory -eq $null) {$processStartInfo.WorkingDirectory = (Get-Location).Path}
	$processStartInfo.UseShellExecute = $false
	$processStartInfo.RedirectStandardOutput = $true
	$processStartInfo.REdirectStandardError = $true
	
	#$process = New-Object System.Diagnostics.Process
	#$process.startInfo=$processStartInfo
	
	$process = [System.Diagnostics.Process]::Start($processStartInfo)
	
	if ($Error.Count -gt 0)
	{
		$errorMessage = $Error[0].Exception.Message
		$errorCode = $Error[0].Exception.ErrorRecord.FullyQualifiedErrorId
		$PositionMessage = $Error[0].InvocationInfo.PositionMessage
		"[ProcessCreate] Error " + $errorCode + " on: " + $line + ": $errorMessage" | WriteTo-StdOut -IsError -InvokeInfo $MyInvocation

		$Error.Clear()
	}

	Return $process
}

# CompressCollectFiles function
# ---------------------
# Description:
#       This function compresses files in a ZIP or CAB file, collecting these files after the ZIP file is created
#       ZIP format is way faster than CAB but - once Shell is used for ZIP files, there is no support for ZIP files on ServerCore
#       Where support for ZIP files is inexistent (like on ServerCore), function will automatically switch to CAB
#
# Arguments:
#		filesToCollect: Folder or Files that to be collected (Ex: C:\windows\*.txt). This value can also be an array.
#       DestinationFileName: Destination name for the zip file (Ex: MyZipFile.ZIP or MyCabFile.CAB)
#		fileDescription: Individual description of the zip file 
#		sectionDescription: Section description.
#       Recursive: Copy files in subfolders
#       renameOutput: Add the %ComputerName% prefix to the ZIP file name - if not existent
#       noFileExtensionsOnDescription: Do not add file extension to the file description (Default format is $fileDescription ($FileExtension))
#       Verbosity: When $collectFiles is true, $Verbosity is the verbosity level for CollectFiles function
#       DoNotCollectFile: If present, function will generate the ZIP file but it will not collect it
#       ForegroundProcess: *Only for CAB files - By default CAB files are compressed in a Background process. Use -ForegroundProcess to force waiting for compression routine to complete before continuing.
#       $NumberOfDays: Do not add files older than $NumberOfDays days to the compressed files
#		$CheckFileInUse:  If present, function will check all files if they are in-used recursively, but it will take more time and may cause some performance issues

Function CompressCollectFiles
{
	PARAM($filesToCollect,
		[string]$DestinationFileName="File.zip",
		[switch]$Recursive,
		[string]$fileDescription="File", 
		[string]$sectionDescription="Section",
		[boolean]$renameOutput=$true,
		[switch]$noFileExtensionsOnDescription,
		[string]$Verbosity="Informational",
		[switch]$DoNotCollectFile,
		[switch]$ForegroundProcess=$false,
		[int]$NumberOfDays=0,
		[switch]$CheckFileInUse
	)

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[CompressCollectFiles]" -InvokeInfo $MyInvocation
		continue
	}

	$FileFormat = [System.IO.Path]::GetExtension($DestinationFileName)
	if ($FileFormat.Length -ne 4) {$FileFormat = ".zip"}
	if (((-not (Test-Path -Path (join-path ([Environment]::SystemDirectory) "shell32.dll"))) -or ((-not (Test-Path -Path (join-path ($Env:windir) "explorer.exe"))))) -and ($FileFormat -eq ".zip"))
	{
		"[CompressCollectFiles] - File format was switched to .CAB once shell components is not present" | WriteTo-StdOut -ShortFormat
		$FileFormat = ".cab"
	}
	
	if ($OSVersion.Major -lt 6) 
	{
		"[CompressCollectFiles] - File format was switched to .CAB once this OS does not support ZIP files" | WriteTo-StdOut -ShortFormat
		$FileFormat = ".cab"
	}

	if ($NumberOfDays -ne 0)
	{
		"[CompressCollectFiles] Restrict files older than $NumberOfDays days" | WriteTo-StdOut -ShortFormat
		$OldestFileDate = (Get-Date).AddDays(($NumberOfDays * -1))
	}

	if (($renameOutput -eq $true) -and (-not $DestinationFileName.StartsWith($ComputerName))) 
	{
		$CompressedFileNameWithoutExtension = $ComputerName + "_" + [System.IO.Path]::GetFileNameWithoutExtension($DestinationFileName)
	} else {
		$CompressedFileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($DestinationFileName)
	}

	if (($FileFormat -eq ".cab") -and ($ForegroundProcess -eq $false) -and ($DoNotCollectFile.IsPresent))
	{
		"[CompressCollectFiles] Switching to Foreground execution as background processing requires file collection and -DoNotCollectFile iscurrently set" | WriteTo-StdOut -ShortFormat
		$ForegroundProcess = $true
	}
	
	$CompressedFileName = ($PWD.Path) + "\" + $CompressedFileNameWithoutExtension + $FileFormat

	if ($FileFormat -eq ".cab")
	{
		#Create DDF File
		$ddfFilename = Join-Path $PWD.Path ([System.IO.Path]::GetRandomFileName())
		
	    ".Set DiskDirectoryTemplate=" + "`"" + $PWD.Path + "`"" | Out-File -FilePath $ddfFilename -Encoding "UTF8";
	    ".Set CabinetNameTemplate=`"" + [IO.Path]::GetFileName($CompressedFileName) + "`""| Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
	 
	    ".Set Cabinet=ON" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
	    ".Set Compress=ON" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
	    ".Set InfAttr=" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
		".Set FolderSizeThreshold=2000000" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
		".Set MaxCabinetSize=0" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
		".Set MaxDiskSize=0" | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
	}

	$ShellGetAllItems = {
	PARAM ($ShellFolderObj, $ZipFileName)
		if ($ShellFolderObj -is "System.__ComObject")
		{
			$ArrayResults = @()
			foreach ($ZipFileItem in $ShellFolderObj.Items())
			{
				$ArrayResults += $ZipFileItem.Path.Substring($ZipFileName.Length + 1)
				
				if ($ZipFileItem.IsFolder)
				{
					$ArrayResults += $ShellGetAllItems.Invoke((new-object -com Shell.Application).NameSpace($ZipFileItem.Path), $ZipFileName)
				}
			}
			return $ArrayResults
		}
	}

	ForEach ($pathFilesToCollect in $filesToCollect) 
	{
		"[CompressCollectFiles] Compressing " + $pathFilesToCollect + " to " + [System.IO.Path]::GetFileName($CompressedFileName) | WriteTo-StdOut -ShortFormat

		if (test-path ([System.IO.Path]::GetDirectoryName($pathFilesToCollect)) -ErrorAction SilentlyContinue) 
		{
			if ($Recursive.IsPresent) 
			{
				if (($pathFilesToCollect.Contains('*') -eq $false) -and ($pathFilesToCollect.Contains('?') -eq $false) -and [System.IO.Directory]::Exists($pathFilesToCollect))
				{
					#If the path looks like a folder and a folder with same name exists, consider that the file is a folder
					$FileExtension = '*.*'
					$RootFolder = $pathFilesToCollect
				}
				else
				{
					$FileExtension = Split-Path $pathFilesToCollect -leaf
					$RootFolder = [System.IO.Path]::GetDirectoryName($pathFilesToCollect)
				}
				if (($FileExtension -eq "*.*") -and ($FileFormat -eq ".zip") -and ($NumberOfDays -eq 0) -and ($CheckFileInUse.IsPresent -eq $false))
				{
					#Optimization to collect subfolders on ZIP files
					$FilestobeCollected = Get-ChildItem -Path $RootFolder
				} 
				else 
				{
					$FilestobeCollected = Get-ChildItem -Path $RootFolder -Include $FileExtension -Recurse
					$FilestobeCollected = $FilestobeCollected | Where-Object {$_.PSIsContainer -eq $false}
				}
			} 
			else 
			{
				#a folder without recurse, or a file without recurse, or an extension filter without recurse
				$FilestobeCollected = Get-ChildItem -Path $pathFilesToCollect | Where-Object {$_.PSIsContainer -eq $false}
			}
			
			if ((($FilestobeCollected -is [array]) -and ($FilestobeCollected.Count -gt 0)) -or ($FilestobeCollected -ne $null))
			{
				if ($NumberOfDays -ne 0)
				{
					$StringFilesExcluded = ''
					Foreach ($FileinCollection in ($FilestobeCollected | Where-Object {$_.LastWriteTime -lt $OldestFileDate}))
					{
						$StringFilesExcluded += (' ' * 10) + '- ' + ($FileinCollection.FullName) + " - Date: " + ($FileinCollection.LastWriteTime.ToShortDateString()) + "`r`n"
					}
					if ($StringFilesExcluded -ne '')
					{
						"Files not included in compressed results as they are older than " + $OldestFileDate.ToShortDateString() + ":`r`n" + $StringFilesExcluded | WriteTo-StdOut -ShortFormat
						$FilestobeCollected = $FilestobeCollected | Where-Object {$_.LastWriteTime -ge $OldestFileDate}
					}
				}
				$IsAnyFileInUse = $false
				if($CheckFileInUse.IsPresent)
				{
					$NotInUseFiles=@()
					foreach($file in $FilestobeCollected)
					{
						if((Is-FileInUse -FilePath ($file.FullName)) -eq $false)
						{
							$NotInUseFiles += $file
						}
						else
						{
							$IsAnyFileInUse = $true
							"[CompressCollectFiles] File " + $file.FullName + " is currently in use - Skipping" | WriteTo-StdOut -ShortFormat
						}
					}
					$FilestobeCollected = $NotInUseFiles
				}
				if (($FileExtension -ne "*.*") -or ($FileFormat -ne ".zip") -or ($NumberOfDays -ne 0) -or  $IsAnyFileInUse)
				{
					$SubfolderToBeCollected = $FilestobeCollected | Select-Object -Unique "Directory" | %{$_."Directory"} #Modified to work on PS 1.0.
				}
				elseif(($CheckFileInUse.IsPresent) -and ($IsAnyFileInUse -eq $false))
				{
					#Means the CheckFileInUse parameter is present but there is no file in used, So get the FilestobeCollected without recurse again
					$FilestobeCollected = Get-ChildItem -Path $RootFolder
				}
			}
			if ((($FilestobeCollected -is [array]) -and ($FilestobeCollected.Count -gt 0)) -or ($FilestobeCollected -ne $null))
			{
				
		 		switch ($FileFormat)
				{
					".zip" 
					{
						#Create file if it does not exist, otherwise just add to the ZIP file name
						$FilesToSkip = @()
						if (-not (Test-Path ($CompressedFileName))) 
						{
							Set-Content $CompressedFileName ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
						}
						else 
						{
							#Need to check file name conflicts, otherwise Shell will raise a message asking for overwrite
							if ($RootFolder -eq $null) {$RootFolder = [System.IO.Path]::GetDirectoryName($pathFilesToCollect)}
							$ZipFileObj = (new-object -com Shell.Application).NameSpace($CompressedFileName)
							$FilesToBeCollectedFullPath = ($FilestobeCollected | %{$_."FullName"})
							$AllZipItems = $ShellGetAllItems.Invoke($ZipFileObj, $CompressedFileName)
							foreach ($ZipFileItem in $AllZipItems)
							{
								$FileNameToCheck = $RootFolder + "\" + $ZipFileItem
								if ($FilesToBeCollectedFullPath -contains $FileNameToCheck)
								{
									if (($FileExtension -eq "*.*") -or ([System.IO.Directory]::Exists($FileNameToCheck) -eq $false)) #Check if it is a folder, so it will not fire a message on stdout.log
									{
										#Error - File Name Conflics exist
										$ErrorDisplay = "[CompressCollectFiles] Error: One or more file name conflicts when compressing files were detected:`r`n"
										$ErrorDisplay += "        File Name   : "+ $FileNameToCheck + "`r`n"
										$ErrorDisplay += "        Zip File    : " + $CompressedFileName + "`r`n"
										$ErrorDisplay += "   File/ Folder will not be compressed."
										$ErrorDisplay | WriteTo-StdOut
									}
									$FilesToSkip += $FileNameToCheck
								}
							}
						}
						
						$ExecutionTimeout = 10 #Time-out for compression - in minutes

						$ZipFileObj = (new-object -com Shell.Application).NameSpace($CompressedFileName)
						$InitialZipItemCount = 0
						
						if (($Recursive.IsPresent) -and (($FileExtension -ne "*.*") -or ($NumberOfDays -ne 0) -or $IsAnyFileInUse))
						{
							#Create Subfolder structure on ZIP files
							#$TempFolder = mkdir -Path (Join-Path $Env:TEMP ("\ZIP" + (Get-Random).toString()))
							$TempFolder = mkdir -Path (Join-Path $PWD.Path ("\ZIP" + [System.IO.Path]::GetRandomFileName()))
							$TempFolderObj = (new-object -com Shell.Application).NameSpace($TempFolder.FullName)
							
							foreach ($SubfolderToCreateOnZip in ($SubfolderToBeCollected | %{$_."FullName"})) #modified to support PS1.0 -ExpandProperty doesn't behave the same in PS 1.0
							{
								$RelativeFolder = $SubfolderToCreateOnZip.Substring($RootFolder.Length)
								if ($RelativeFolder.Length -gt 0)
								{
									$TempFolderToCreate = (Join-Path $TempFolder $RelativeFolder)
									MKDir -Path $TempFolderToCreate -Force | Out-Null
									"Temporary file" |Out-File -FilePath ($TempFolderToCreate + "\_DeleteMe.Txt") -Append #Temporary file just to make sure file isn't empty so it won't error out when using 'CopyHere
								}
							}
							
							#Create subfolder structure on ZIP file:
							
							foreach ($ParentTempSubfolder in $TempFolder.GetDirectories("*.*", [System.IO.SearchOption]::AllDirectories))
							{
								if (($AllZipItems -eq $null) -or ($AllZipItems -notcontains ($ParentTempSubfolder.FullName.Substring($TempFolder.FullName.Length+1))))
								{
									
									$TimeCompressionStarted = Get-Date
									$ZipFileObj = (new-object -com Shell.Application).NameSpace($CompressedFileName + $ParentTempSubfolder.Parent.FullName.Substring($TempFolder.FullName.Length))
									$InitialZipItemCount = $ZipFileObj.Items().Count
									$ZipFileObj.CopyHere($ParentTempSubfolder.FullName, $DontShowDialog)

									do
									{
										sleep -Milliseconds 100
										
										if ((New-TimeSpan -Start $TimeCompressionStarted).Minutes -ge 2)
										{
											$ErrorDisplay = "[CompressCollectFiles] Compression routine will be terminated due it reached a timeout of 2 minutes to create a subfolder on zip file:`r`n"
											$ErrorDisplay += "        SubFolder   : " + $RootFolder + $ParentTempSubfolder.FullName.Substring($TempFolder.FullName.Length) + "`r`n"
											$ErrorDisplay += "        Start Time  : " + $TimeCompressionStarted + "`r`n"
											$ErrorDisplay | WriteTo-StdOut
											$TimeoutOcurred = $true
										}
																
									} while ((-not $TimeoutOcurred) -and ($ZipFileObj.Items().Count -le $InitialZipItemCount))
									
									#$AllZipItems += [System.IO.Directory]::GetDirectories($ParentTempSubfolder.FullName, "*.*", [System.IO.SearchOption]::AllDirectories) | ForEach-Object -Process {$_.Substring($TempFolder.FullName.Length + 1)}
									$AllZipItems  = $ShellGetAllItems.Invoke($ZipFileObj, $CompressedFileName)
								}
							}
						}
						
						if (($ZipFileObj -eq $null) -or ($ZipFileObj.Self.Path -ne $CompressedFileName))
						{
							$ZipFileObj = (new-object -com Shell.Application).NameSpace($CompressedFileName)
						}
					}
				}
		
				$FilestobeCollected | ForEach-object -process {
				
					$FileName = Split-Path $_.Name -leaf
					$FileNameFullPath = $_.FullName
					if ([System.IO.Directory]::Exists($pathFilesToCollect))
					{
						$ParentFolderName = [System.IO.Path]::GetFullPath($pathFilesToCollect)
					}
					else
					{
						$ParentFolderName = [System.IO.Path]::GetDirectoryName($pathFilesToCollect).Length
					}
					
					if (($Recursive.IsPresent) -and ([System.IO.Path]::GetDirectoryName($FileNameFullPath).Length -gt $ParentFolderName.Length))
					{
						$RelativeFolder = [System.IO.Path]::GetDirectoryName($FileNameFullPath).Substring($RootFolder.Length)
					} else {
						$RelativeFolder = ""
						$CurrentZipFolder = ""
					}
					
			 		switch ($FileFormat)
					{
						".zip" 
						{
							$TimeCompressionStarted = Get-Date
							$TimeoutOcurred = $false

							if (($FileExtension -eq "*.*") -and ([System.IO.Directory]::Exists($FileNameFullPath)))
							{
								#Check if folder does not have any file
								if (([System.IO.Directory]::GetFiles($FileNameFullPath, "*.*", [System.IO.SearchOption]::AllDirectories)).Count -eq 0)
								{
									$FilesToSkip += $FileNameFullPath
									"[CompressCollectFiles] Folder $FileNameFullPath will not be compressed since it does not contain any file`r`n"
								}
							}

							if ($RelativeFolder -ne $CurrentZipFolder)
							{
								$ZipFileObj = (new-object -com Shell.Application).NameSpace((join-path $CompressedFileName $RelativeFolder))
								ForEach ($TempFile in $ZipFileObj.Items()) 
								{
									#Remove temporary file from ZIP
									if ($TempFile.Name.StartsWith("_DeleteMe")) 
									{
										$DeleteMeFileOnTemp = (Join-Path $TempFolder.FullName "_DeleteMe.TXT")
										if (Test-Path $DeleteMeFileOnTemp) {Remove-Item -Path $DeleteMeFileOnTemp}
										$TempFolderObj.MoveHere($TempFile)
										if (Test-Path $DeleteMeFileOnTemp) {Remove-Item -Path (Join-Path $TempFolder.FullName "_DeleteMe.TXT")}
									}
								}
								$CurrentZipFolder = $RelativeFolder
							} 
							elseif (($RelativeFolder.Length -eq 0) -and ($ZipFileObj.Self.Path -ne $CompressedFileName))
							{
								$ZipFileObj = (new-object -com Shell.Application).NameSpace($CompressedFileName)
							}
							
							if (($FilesToSkip -eq $null) -or ($FilesToSkip -notcontains $FileNameFullPath))
							{
								"             + " + $FileNameFullPath + " to " + ([System.IO.Path]::GetFileName($CompressedFileName)) + $ZipFileObj.Self.Path.Substring($CompressedFileName.Length) | WriteTo-StdOut -ShortFormat
								$InitialZipItemCount = $ZipFileObj.Items().Count
								$ZipFileObj.CopyHere($FileNameFullPath, $DontShowDialog)
						
								while ((-not $TimeoutOcurred) -and ($ZipFileObj.Items().Count -le $InitialZipItemCount))
								{
									sleep -Milliseconds 200
									
									if ((New-TimeSpan -Start $TimeCompressionStarted).Minutes -ge $ExecutionTimeout)
									{
										$ErrorDisplay = "[CompressCollectFiles] Compression routine will be terminated due it reached a timeout of $ExecutionTimeout minutes:`r`n"
										$ErrorDisplay += "        File Name   : $FileNameFullPath `r`n"
										$ErrorDisplay += "        Start Time  : " + $TimeCompressionStarted + "`r`n"
										$ErrorDisplay | WriteTo-StdOut
										$TimeoutOcurred = $true
									}
															
								} 
							}
						}
						".cab"
						{
							if ($RelativeFolder -ne $CurrentCabFolder)
							{
								$ListOfFilesonDDF += ".Set DestinationDir=`"" + $RelativeFolder + "`"`r`n"
								$CurrentCabFolder = $RelativeFolder
							}
							$ListOfFilesonDDF += "`"" + $FileNameFullPath + "`"`r`n" 
							$StringFilesIncluded += (' ' * 10) + '+ ' + $FileNameFullPath + "`r`n" 
						}
					}
				}	
				#Add condition to check if the $TempFolder actually exists.
				if(($TempFolder -ne $null) -and (Test-Path -Path $TempFolder.FullName)) { Remove-Item -Path $TempFolder.FullName -Recurse }
			} else {
				"[CompressCollectFiles] No files found: $pathFilesToCollect" | WriteTo-StdOut -ShortFormat
			}
		} else {
			"[CompressCollectFiles] Path not found: $pathFilesToCollect" | WriteTo-StdOut -ShortFormat
		}		
	} #ForEach
	
	if (($FileFormat -eq ".zip") -and (Test-Path $CompressedFileName) -and (-not $DoNotCollectFile.IsPresent))
	{
		if ($noFileExtensionsOnDescription.IsPresent)
		{
			CollectFiles -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -renameOutput ($renameOutput -eq $true) -Verbosity $Verbosity -noFileExtensionsOnDescription -InvokeInfo $MyInvocation
		}
		else
		{
			CollectFiles -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -renameOutput ($renameOutput -eq $true) -Verbosity $Verbosity -InvokeInfo $MyInvocation
		}
	}
	
	if ($FileFormat -eq ".cab")
	{					
		if ($ListOfFilesonDDF -ne $null) 
		{
			$ListOfFilesonDDF | Out-File -FilePath $ddfFilename -Encoding "UTF8" -Append;
		    "Files to be included in " + [System.IO.Path]::GetFileName($CompressedFileName) + ":`r`n" + $StringFilesIncluded | WriteTo-StdOut -ShortFormat

			$AddToCommandLine = " > nul"
			
			if ($debug -eq $true)
			{
				"MakeCab DDF Contents: " | WriteTo-StdOut -ShortFormat
				Get-Content $ddfFilename | Out-String | WriteTo-StdOut
				$AddToCommandLine = " > 1.txt & type 1.txt"
			}
			
			if ($ForegroundProcess.IsPresent)
			{
				$commandToRun = ($env:windir + "\system32\cmd.exe /c `"`"" + $env:windir + "\system32\makecab.exe`" /f `"" + $ddfFilename + "`"$AddToCommandLine`"")
				if ($noFileExtensionsOnDescription.IsPresent -eq $true)
				{
					if ($DoNotCollectFile.IsPresent)
					{
						Runcmd -commandToRun $CommandToRun -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity -noFileExtensionsOnDescription -collectFiles $false
					}
					else
					{
						Runcmd -commandToRun $CommandToRun -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity -noFileExtensionsOnDescription
					}
				}
				else
				{
					if ($DoNotCollectFile.IsPresent)
					{
						Runcmd -commandToRun $CommandToRun -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity -collectFiles $false
					}
					else
					{
						Runcmd -commandToRun $CommandToRun -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity
					}
				}
				
				if ($debug -ne $true)
				{
					Remove-Item $ddfFilename
				}
			} 
			else 
			{
				if ($debug -ne $true)
				{
					$AddToCommandLine += " & del `"$ddfFilename`""
				}
				
				$commandToRun = ($env:windir + "\system32\cmd.exe")
				$commandArguments = ("/c `"`"" + $env:windir + "\system32\makecab.exe`" /f `"" + $ddfFilename + "`"$AddToCommandLine`"")
				
				if ($noFileExtensionsOnDescription.IsPresent -eq $true)
				{
					BackgroundProcessCreate -ProcessName $commandToRun -Arguments $commandArguments -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity -noFileExtensionsOnDescription
				} 
				else 
				{
					BackgroundProcessCreate -ProcessName $commandToRun  -Arguments $commandArguments -fileDescription $fileDescription -sectionDescription $sectionDescription -filesToCollect $CompressedFileName -Verbosity $Verbosity -noFileExtensionsOnDescription
				}
			}
		} 
		else 
		{
			"Unable to find files to be collected" | WriteTo-StdOut
			Remove-Item $ddfFilename
		}
	} 
}


function RegQuery(
	$RegistryKeys,
    [string] $OutputFile,
    [string] $fileDescription,
	[string] $sectionDescription="",
    [boolean] $Recursive = $False,
    [boolean] $AddFileToReport = $true,
	[boolean] $Query = $true,
	[boolean] $Export = $false
    )
{

# RegQuery function
# ---------------------
# Description:
#       This function uses reg.exe to export a registry key to a text file. Adding the file to the report.
# 
# Arguments:
#       RegistryKeys: One or more registry keys to be exported (Example: "HKLM\Software\Microsoft\Windows NT")
#		OutputFile: Name of output file. If -Query is $true, you should use a .txt extension. This command will switch it to .reg automatically for -Export $true.
#		fileDescription: Individual description of the Registry Key in the report
#		Recursive: If $true, resulting file contains key and subkeys.
#		sectionDescription: Name of the section (Optional - Default: "Registry Information (Text format)")
#       AddFileToReport: if $true, the resulting output will be added to report and a reference to it will be created on report xml (Default=$true)
# 
#Example:
#		RegQuery -RegistryKeys "HKLM\Software\Microsoft\Windows NT" -OutputFile "$Computername_WinNT.TXT" -fileDescription "Windows NT Reg Key" -sectionDescription "Software Registry keys"
# 

	if ([string]::IsNullOrEmpty($sectionDescription))
	{
		$sectionDescription="Registry Information (Text format)"
	}

	if($debug -eq $true){"Run RegQuery function. `r`n RegistryKeys: $RegistryKeys `r`n OutputFile: $OutputFile `r`n AddFileToReport = $AddFileToReport" | WriteTo-StdOut -DebugOnly}
	$RegKeyExist = $false
	if(($Query -eq $false) -and ($Export -eq $false)){"Either -Query or -Export must be set to `$true" | WriteTo-StdOut -IsError -InvokeInfo $MyInvocation; throw}
	ForEach ($RegKey in $RegistryKeys) {
		$RegKeyString = $UtilsCTSStrings.ID_RegistryKeys
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_ExportingRegistryKeys -Status "$RegKeyString $RegKey" -ErrorAction SilentlyContinue
		$PSRegKey=$RegKey -replace "HKLM\\", "HKLM:\" -replace "HKCU\\", "HKCU:\" -replace "HKU\\", "Registry::HKEY_USERS\"
		
		if (Test-Path $PSRegKey) 
		{
			$RegKeyExist = $true			
			$PSRegKeyObj = Get-Item ($PSRegKey)
			
			if ($PSRegKeyObj -ne $null) 
			{
				$RegExeRegKey = ($PSRegKeyObj.Name -replace "HKEY_USERS\\", "HKU\") -replace "HKEY_LOCAL_MACHINE\\", "HKLM\" -replace "HKEY_CURRENT_USER\\", "HKCU\" -replace "HKEY_CLASSES_ROOT\\", "HKCR\"	
			}
			else 
			{
				$RegExeRegKey = ($RegExeRegKey -replace "HKEY_USERS\\", "HKU\\") -replace "HKEY_LOCAL_MACHINE\\", "HKLM\" -replace "HKEY_CURRENT_USER\\", "HKCU\" -replace "HKEY_CLASSES_ROOT\\", "HKCR\"
			}
			
			if($Export)
			{
				$tmpFile = [System.IO.Path]::GetTempFileName()
				$OutputFile2 = $OutputFile
				if([System.IO.Path]::GetExtension($OutputFile2) -ne ".reg")
				{
					$OutputFile2 = $OutputFile2.Substring(0,$OutputFile2.LastIndexOf(".")) + ".reg"
				}
				$CommandToExecute = "reg.exe EXPORT `"$RegExeRegKey`" `"$tmpFile`" /y" 
				$X = RunCmd -commandToRun $CommandToExecute -collectFiles $false -useSystemDiagnosticsObject
				[System.IO.StreamReader]$fileStream = [System.IO.File]::OpenText($tmpFile)
				if([System.IO.File]::Exists($OutputFile2))
				{
					#if the file already exists, we assume it has the header at the top, so we'll strip those lines off
					$fileStream.ReadLine() | Out-Null 
					$fileStream.ReadLine() | Out-Null 
				}
				$fileStream.ReadToEnd() | Out-File $OutputFile2 -Append 
				$fileStream.Close()
				Remove-Item $tmpFile -ErrorAction SilentlyContinue | Out-Null 
			}
			
			if($Query)
			{
				$CommandToExecute = "reg.exe query `"$RegExeRegKey`""
				if ($Recursive -eq $true) {
					$CommandToExecute = "$CommandToExecute /s"
				}
				
				$CommandToExecute = "$CommandToExecute >> `"$OutputFile`""
				
				"-" * ($RegKey.Length +2) + "`r`n[$RegKey]`r`n" + "-" * ($RegKey.Length +2) | Out-File -FilePath $OutputFile -Append -Encoding Default

				$X = RunCmD -commandToRun $CommandToExecute -collectFiles $false -useSystemDiagnosticsObject
			}
		} 
		else 
		{
			"The registry key $RegKey does not exist" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
		}
		
	}
			
	if ($RegKeyExist -eq $true) 
	{ 
		if ($AddFileToReport -eq $true) 
		{
			if($Query) {Update-DiagReport -Id $sectionDescription -Name $fileDescription -File $OutputFile}
			if($Export){Update-DiagReport -Id $sectionDescription -Name $fileDescription -File $OutputFile2}
		}
	}
}

function RegQueryValue(
	$RegistryKeys,
	$RegistryValues,
	[string] $sectionDescription,
    [string] $OutputFile,
    [string] $fileDescription,
    [boolean] $CollectResultingFile = $True
    )
{
	
	if ([string]::IsNullOrEmpty($sectionDescription))
	{
		$sectionDescription="Registry Information (Text format)"
	}

	if($debug -eq $true){"RegQueryValue:`r`n RegistryKeys: $RegistryKeys `r`n OutputFile: $OutputFile `r`n CollectResultingFile = $CollectResultingFile" | WriteTo-StdOut -DebugOnly}
	$ErrorActionPreference = "SilentlyContinue"
	$RegValueExist = $false
	$CurrentMember = 0
	ForEach ($RegKey in $RegistryKeys) 
	{
	
		$RegKeyString = $UtilsCTSStrings.ID_RegistryValue
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_ExportingRegistryKeys -Status "$RegKeyString $RegKey" -ErrorAction SilentlyContinue
	
		$PSRegKey=$RegKey -replace "HKLM\\", "HKLM:\" 
		$PSRegKey=$PSRegKey -replace "HKCU\\", "HKCU:\"
		if (Test-Path $PSRegKey) {
			$testRegValue = $null
			if ($RegistryValues -is [array]) 
			{
				$RegValue = $RegistryValues[$CurrentMember]
			} else {
				$RegValue = $RegistryValues
			}
			#Test if registry value exists
			$testRegValue = get-itemproperty -name $RegValue -Path $PSRegKey
			if ($testRegValue -ne $null) {
				$RegValueExist = $true
				$CommandToExecute = "$Env:COMSPEC /C reg.exe query `"$RegKey`" /v `"$RegValue`""
				
				$CommandToExecute = "$CommandToExecute >> `"$OutputFile`""
				$RegKeyLen = $RegKey.Length + $RegValue.Length + 3
				"-" * ($RegKeyLen) + "`r`n[$RegKey\$RegValue]`r`n" + "-" * ($RegKeyLen) | Out-File -FilePath $OutputFile -Append
	
				RunCmD -commandToRun $CommandToExecute -collectFiles $false
			} else {
				"        The registry value $RegKey\$RegValue does not exist" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
			}
		$CurrentMember = $CurrentMember +1			
		} else {
			"        The registry key $RegKey does not exist" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
		}
	
	}
			
	if ($RegValueExist-eq $true) 
	{ 
		if ($CollectResultingFile -eq $true) {
			Update-DiagReport -Id $sectionDescription -Name $fileDescription -File $OutputFile
		}
	}
}

#Function RegSave
#----------------
#This function saves a registry key to a registry hive file using reg.exe utility

function RegSave(
	$RegistryKeys,
	[string] $sectionDescription,
    [string] $OutputFile,
    [string] $fileDescription
    )
{

	if ([string]::IsNullOrEmpty($sectionDescription))
	{
		$sectionDescription="Registry Information (Hive format)"
	}

	if($debug -eq $true){"Run RegSave function. `r`n RegistryKeys: $RegistryKeys `r`n OutputFile: $OutputFile `r`n fileDescription: $fileDescription" | WriteTo-StdOut -DebugOnly}
	$ErrorActionPreference = "SilentlyContinue"
	$RegValueExist = $false
	$CurrentMember = 0
	ForEach ($RegKey in $RegistryKeys) {
	
		$RegKeyString = $UtilsCTSStrings.ID_Hive
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_ExportingRegistryKeys -Status "$RegKeyString $RegKey" -ErrorAction SilentlyContinue
	
		$PSRegKey=$RegKey -replace "HKLM\\", "HKLM:\" 
		$PSRegKey=$PSRegKey -replace "HKCU\\", "HKCU:\"
		if (Test-Path $PSRegKey) {
			$CommandToExecute = "$Env:windir\system32\reg.exe save `"$RegKey`" `"$OutputFile`" /y"
			
			RunCmD -commandToRun $CommandToExecute -sectionDescription $sectionDescription -filesToCollect $OutputFile -fileDescription $fileDescription
		} else {
			"[RegSave] The registry key $RegKey does not exist" | WriteTo-StdOut -ShortFormat -Color 'DarkYellow' -InvokeInfo $MyInvocation
		}
		
	}		
}

Function Collect-DiscoveryFiles
{
	$DiscoveryExecutionLog = Join-Path $PWD.Path ($ComputerName + '_DiscoveryExecutionLog.log')
	if (test-path ($DiscoveryExecutionLog))
	{
		Get-Content -Path ($DiscoveryExecutionLog) | WriteTo-StdOut
	}
	else
	{
		"[Collect-DiscoveryFiles] Discovery execution log could not be found at $DiscoveryExecutionLog" | WriteTo-StdOut -ShortFormat
	}
	
	$DiscoveryReport = "$($Computername)_DiscoveryReport.xml"
	
	Collectfiles -filesToCollect $DiscoveryReport  -fileDescription "Config Explorer Discovery Report" -sectionDescription "Config Explorer Files" -Verbosity "Debug"
	Collectfiles -filesToCollect "$($Computername)_DiscoveryDebugLog.xml" -fileDescription "Config Explorer Debug" -sectionDescription "Config Explorer Files" -Verbosity "Debug"

	# Disabling convertion to HTML for now until more meaningful information to be processed
	
#	if ((Test-path $DiscoveryReport) -and (Test-Path 'ConfigExplorerClientView.xslt'))
#	{
#		#Convert XML to HTML	
#		$HTMLFilename = Join-Path $PWD.Path "$($Computername)_DiscoveryReport.htm"
#		[xml] $XSLContent = Get-Content 'ConfigExplorerClientView.xslt'
#
#		$XSLObject = New-Object System.Xml.Xsl.XslTransform
#		$XSLObject.Load($XSLContent)
#		$XSLObject.Transform($DiscoveryReport, $HTMLFilename)
#	    
#		#Remove-Item $XMLFilename
#		"DiscoveryReport converted to " + (Split-Path $HTMLFilename -Leaf) | WriteTo-StdOut -ShortFormat
#		
#		Collectfiles -filesToCollect $HTMLFilename -fileDescription "Configuration Information Report" -sectionDescription "Config Explorer Files"
#		
#	}
}

#For Configuration Explorer: Start Discovery process
Function Start-ConfigXPLDiscovery
{
	if (test-path variable:\psversiontable)
	{
		$DiscoveryXMLPath = (Join-Path $PWD.Path "ConfigXPLSchema.xml")
		if (Test-Path $DiscoveryXMLPath)
		{
			$UtilsDiscoveryPS1Path = join-path $PWD.Path 'run_discovery.ps1'
			if (Test-Path $DiscoveryXMLPath)
			{
				"[ConfigExplorer] Starting Discovery Process in Background" | WriteTo-StdOut -ShortFormat
				Run-ExternalPSScript -ScriptPath $UtilsDiscoveryPS1Path -BackgroundExecution -BackgroundExecutionSkipMaxParallelDiagCheck -Verbosity Debug -collectFiles $false -BackgroundExecutionPostProcessingScriptBlock ({Collect-DiscoveryFiles}) -BackgroundExecutionSessionName "ConfigXPLDiscovery" -BackgroundExecutionTimeOut 5
			}
			else
			{
				"[ConfigExplorer] Unable to find [$DiscoveryXMLPath]. Discovery process aborted" | WriteTo-StdOut -IsError -ShortFormat
			}
		}
		else
		{
			"[ConfigExplorer] Unable to find Discovery XML at [$DiscoveryXMLPath]. Discovery process aborted" | WriteTo-StdOut -IsError -ShortFormat
		}
	}
	else
	{
		"[ConfigExplorer] Configuration Explorer is only supported on PowerShell 2.0 and newer. The current Host Version is " + $Host.Version.ToString() | WriteTo-StdOut -IsError -ShortFormat
	}
}

function Is-FileInUse
{
	param($FilePath)
	
	if(Test-Path $FilePath)
	{
		$Error.Clear() | Out-Null 
		Get-Content -Path $FilePath -TotalCount 1 -ErrorAction SilentlyContinue | Out-Null 
		if($Error.Count -gt 0)
		{
			$Error.Clear() | Out-Null
			return $true
		}
	}
	return $false
}

# WriteTo-StdOut function
# ---------------------
#Author:
#	pcreehan@microsoft.com
#Last Modified:
#	6/16/2011
#Description:
#	This function is dual purposed. When the $Debug variable is set to $true ("debug mode"), it outputs 
#	pipeline input to the $Host, when $Debug is $false or $null ("normal mode"), then it writes the input 
#	to the stdout.log file.
#Arguments:
#	$ObjectToAdd -	Object to add to the output along with any piped in objects
# 	$ShortFormat -	This switch determines whether piped in objects are separated with line breaks or spaces
#	$IsError - 			In debug mode, it will output in Red, in normal mode, has no effect.
#	$Color - 			Sets the Foreground color of the console output. Ignored in normal (not debug) mode.
# 	$DebugOnly - 	Will not write to stdout.log in normal mode.
#	$PassThru - 	Returns the objects passed in as a string. When combined with $DebugOnly, 
#						useful for capturing data that you intend to write to a file
# 	$InvokeInfo -	[System.Management.Automation.InvocationInfo] You can pass in your own invoke info
#						so that script names, resolve correctly. Useful for wrapping functions in a utility .ps1 file
# 	$AdditionaFileName - Write to both stdout output and to an additional log filename
#
#Aliases:
#	Output-Trace
#	Trace
if($null -eq $global:m_WriteCriticalSection) {$global:m_WriteCriticalSection = New-Object System.Object}
function WriteTo-StdOut
{
	param (
		$ObjectToAdd,
		[switch]$ShortFormat,
		[switch]$IsError,
		$Color,
		[switch]$DebugOnly,
		[switch]$PassThru,
		[System.Management.Automation.InvocationInfo] $InvokeInfo = $MyInvocation,
		[string]$AdditionalFileName = $null,
		[switch]$noHeader)
	BEGIN
	{
		$WhatToWrite = @()
		if ($ObjectToAdd -ne  $null)
		{
			$WhatToWrite  += $ObjectToAdd
		} 
		
		if(($Debug) -and ($Host.Name -ne "Default Host") -and ($Host.Name -ne "Default MSH Host"))
		{
			if($Color -eq $null)
			{
				$Color = $Host.UI.RawUI.ForegroundColor
			}
			elseif($Color -isnot [ConsoleColor])
			{
				$Color = [Enum]::Parse([ConsoleColor],$Color)
			}
			$scriptName = [System.IO.Path]::GetFileName($InvokeInfo.ScriptName)
		}
		
		$ShortFormat = $ShortFormat -or $global:ForceShortFormat
	}
	PROCESS
	{
		if ($_ -ne $null)
		{
			if ($_.GetType().Name -ne "FormatEndData") 
			{
				$WhatToWrite += $_ | Out-String 
			}
			else 
			{
				$WhatToWrite = "Object not correctly formatted. The object of type Microsoft.PowerShell.Commands.Internal.Format.FormatEntryData is not valid or not in the correct sequence."
			}
		}
	}
	END
	{
		if($ShortFormat)
		{
			$separator = " "
		}
		else
		{
			$separator = "`r`n"
		}
		$WhatToWrite = [string]::Join($separator,$WhatToWrite)
		while($WhatToWrite.EndsWith("`r`n"))
		{
			$WhatToWrite = $WhatToWrite.Substring(0,$WhatToWrite.Length-2)
		}
		if(($Debug) -and ($Host.Name -ne "Default Host") -and ($Host.Name -ne "Default MSH Host"))
		{
			$output = "[$([DateTime]::Now.ToString(`"s`"))] [$($scriptName):$($MyInvocation.ScriptLineNumber)]: $WhatToWrite"

			if($IsError.Ispresent)
			{
				$Host.UI.WriteErrorLine($output)
			}
			else
			{
				if($Color -eq $null){$Color = $Host.UI.RawUI.ForegroundColor}
				$output | Write-Host -ForegroundColor $Color
			}
			if($global:DebugOutLog -eq $null)
			{
				$global:DebugOutLog = Join-Path $Env:TEMP "$([Guid]::NewGuid().ToString(`"n`")).txt"
			}
			$output | Out-File -FilePath $global:DebugOutLog -Append -Force 
		}
		elseif(-not $DebugOnly)
		{
			[System.Threading.Monitor]::Enter($global:m_WriteCriticalSection)
			
			trap [Exception] 
			{
				WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[Writeto-Stdout]: $WhatToWrite" -InvokeInfo $MyInvocation -SkipWriteToStdout
				continue
			}
			Trap [System.IO.IOException]
			{
				# An exection in this location indicates either that the file is in-use or user do not have permissions. Wait .5 seconds. Try again
				sleep -Milliseconds 500
				WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[Writeto-Stdout]: $WhatToWrite" -InvokeInfo $MyInvocation -SkipWriteToStdout
				continue
			}
			
			if($ShortFormat)
			{
				if ($NoHeader.IsPresent)
				{
				    $WhatToWrite | Out-File -FilePath $StdOutFileName -append -ErrorAction SilentlyContinue 
					 if ($AdditionalFileName.Length -gt 0)
					 {
					 	$WhatToWrite | Out-File -FilePath $AdditionalFileName -append -ErrorAction SilentlyContinue 
					 }
				}
				else
				{
		             "[" + (Get-Date -Format "T") + " " + $ComputerName + " - " + [System.IO.Path]::GetFileName($InvokeInfo.ScriptName) + " - " + $InvokeInfo.ScriptLineNumber.ToString().PadLeft(4) + "] $WhatToWrite" | Out-File -FilePath $StdOutFileName -append -ErrorAction SilentlyContinue 
					 if ($AdditionalFileName.Length -gt 0)
					 {
					 	"[" + (Get-Date -Format "T") + " " + $ComputerName + " - " + [System.IO.Path]::GetFileName($InvokeInfo.ScriptName) + " - " + $InvokeInfo.ScriptLineNumber.ToString().PadLeft(4) + "] $WhatToWrite" | Out-File -FilePath $AdditionalFileName -append -ErrorAction SilentlyContinue 
					 }
				}
			}
			else
			{
				if ($NoHeader.IsPresent)
				{
	                 "`r`n" + $WhatToWrite | Out-File -FilePath $StdOutFileName -append -ErrorAction SilentlyContinue 
					 if ($AdditionalFileName.Length -gt 0)
					 {
					 	"`r`n" + $WhatToWrite | Out-File -FilePath $AdditionalFileName -append -ErrorAction SilentlyContinue 
					 }
				}
				else
				{
	                 "`r`n[" + (Get-Date) + " " + $ComputerName + " - From " + [System.IO.Path]::GetFileName($InvokeInfo.ScriptName) + " Line: " + $InvokeInfo.ScriptLineNumber + "]`r`n" + $WhatToWrite | Out-File -FilePath $StdOutFileName -append -ErrorAction SilentlyContinue 
					 if ($AdditionalFileName.Length -gt 0)
					 {
					 	"`r`n[" + (Get-Date) + " " + $ComputerName + " - From " + [System.IO.Path]::GetFileName($InvokeInfo.ScriptName) + " Line: " + $InvokeInfo.ScriptLineNumber + "]`r`n" + $WhatToWrite | Out-File -FilePath $AdditionalFileName -append -ErrorAction SilentlyContinue 
					 }
				}
			}
			[System.Threading.Monitor]::Exit($global:m_WriteCriticalSection)

		}
		if($PassThru)
		{
			return $WhatToWrite
		}
	}
}

# Get-BarChartString function
# ---------------------
# Description:
#       This function can be used to add bar charts to the report that can be used to visualize percentage or progress
# 
# Arguments:
#       CurrentValue: Current value to be represented in the chart
#		MaxValue: Maximum possible value of the series
#		Size: Chart size (in pixels - default = 300)
#		ValueDisplay: How the value will be shown in the chart (example: 50%)
#		ColorScheme: Color scheme for the chart - valid values are 'Red', 'Blue' and 'Yellow'
# 
#Example:
#		$MSG_Summary = new-object PSObject
#		$Chart = Get-BarChartString -CurrentValue 80 -MaxValue 100 -ValueDisplay "80%" -ColorScheme "Yellow"
#		add-member -inputobject $MSG_Summary -membertype noteproperty -name "Chart" -value $Chart
#		$MSG_Summary | ConvertTo-Xml2 | update-diagreport -id "Msg_x" -name "My charts" -verbosity informational
#

Function Get-BarChartString(
	[Double] $CurrentValue = 50,
	[Double] $MaxValue = 100,
	[int] $Size = 300,
	$ValueDisplay = "",
	$ColorScheme = "Blue"
)
{
	if ($MaxValue -gt 0)
	{
		$ChartBase = "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"GraphValue`" class=`"vmlimage`" style=`"width:" + $Size + "px;height:15px;vertical-align:middle`" coordsize=`"{MaxValue},100`" title=`"{ValueDisplay}`"><v:rect class=`"vmlimage`" style=`"top:1;left:1;width:{MaxValue};height:100`" strokecolor=`"#336699`"><v:fill type=`"gradient`" angle=`"0`" color=`"#C4CCC7`" color2=`"white`" /></v:rect><v:rect class=`"vmlimage`" style=`"top:2;left:1;width:{Value};height:99`" strokecolor=`"{StrokeColorChart}`"><v:fill type=`"gradient`" angle=`"270`" color=`"{GraphColorStart}`" color2=`"{GraphColorEnd}`" /></v:rect><v:rect style=`"top:-70;left:{TextStartPos};width:{MaxValue};height:50`" filled=`"false`" stroked=`"false`" textboxrect=`"top:19;left:1;width:{MaxValue};height:30`"><v:textbox style=`"color:{TextColor};`" inset=`"20px, 10px, 28px, 177px`">{ValueDisplay}</v:textbox></v:rect></v:group></span>"

		switch ($ColorScheme)
		{
			"Red"
			{
				$GraphColorStart = "#9C3033"
				$GraphColorEnd = "#D96265"
				$StrokeColorChart = $GraphColorEnd
			}
			"Yellow"
			{
				$GraphColorStart = "#E6E600"
				$GraphColorEnd = "#FFFFA6"
				$StrokeColorChart = "#C9C9C9"
			}
			Default
			{
				$GraphColorStart = "#336699"
				$GraphColorEnd = "#538CC6"
				$StrokeColorChart = $GraphColorEnd
			}

		}
		if (($CurrentValue/$MaxValue) -lt .135)
		{
			$TextStartPos = $GraphValue
			$TextColor = "Gray"
		} else {
			$TextStartPos = 1
			if ($ColorScheme -ne "Yellow")
			{
				$TextColor = "White"
			}
			else
			{
				$TextColor = "#757575"
			}
		}
		
		return ($ChartBase -replace "{MaxValue}", "$MaxValue" -replace "{ValueDisplay}", "$ValueDisplay" -replace "{Value}", $CurrentValue -replace "{GraphColorStart}", $GraphColorStart -replace "{GraphColorEnd}", $GraphColorEnd -replace "{TextStartPos}", $TextStartPos -replace "{TextColor}", $TextColor -replace "{StrokeColorChart}", $StrokeColorChart)
	}
}

# Get-TSRemote is used to identify when the environment is running under TS_Remote
# The following return values can be returned:
#    0 - No TS_Remote environment
#    1 - Under TS_Remote environment, but running on the local machine
#    2 - Under TS_Remote environment and running on a remote machine

Function Get-TSRemote
{
	if ($global:TS_RemoteLevel -ne $null)
	{
		return $global:TS_RemoteLevel
	}
	else
	{
		return 0
	}
}

Filter WriteTo-ErrorDebugReport
(
	[string] $ScriptErrorText, 
	[System.Management.Automation.ErrorRecord] $ErrorRecord = $null,
	[System.Management.Automation.InvocationInfo] $InvokeInfo = $null,
	[switch] $SkipWriteToStdout
)
{

	trap [Exception] 
	{
		$ExInvokeInfo = $_.Exception.ErrorRecord.InvocationInfo
		if ($ExInvokeInfo -ne $null)
		{
			$line = ($_.Exception.ErrorRecord.InvocationInfo.Line).Trim()
		}
		else
		{
			$Line = ($_.InvocationInfo.Line).Trim()
		}
		
		if (-not ($SkipWriteToStdout.IsPresent))
		{
			"[WriteTo-ErrorDebugReport] Error: " + $_.Exception.Message + " [" + $Line + "].`r`n" + $_.StackTrace | WriteTo-StdOut
		}
		continue
	}

	if (($ScriptErrorText.Length -eq 0) -and ($ErrorRecord -eq $null)) {$ScriptErrorText=$_}

	if (($ErrorRecord -ne $null) -and ($InvokeInfo -eq $null))
	{
		if ($ErrorRecord.InvocationInfo -ne $null)
		{
			$InvokeInfo = $ErrorRecord.InvocationInfo
		}
		elseif ($ErrorRecord.Exception.ErrorRecord.InvocationInfo -ne $null)
		{
			$InvokeInfo = $ErrorRecord.Exception.ErrorRecord.InvocationInfo
		}
		if ($InvokeInfo -eq $null)
		{			
			$InvokeInfo = $MyInvocation
		}
	}
	elseif ($InvokeInfo -eq $null)
	{
		$InvokeInfo = $MyInvocation
	}

	$Error_Summary = New-Object PSObject
	
	if (($InvokeInfo.ScriptName -ne $null) -and ($InvokeInfo.ScriptName.Length -gt 0))
	{
		$ScriptName = [System.IO.Path]::GetFileName($InvokeInfo.ScriptName)
	}
	elseif (($InvokeInfo.InvocationName -ne $null) -and ($InvokeInfo.InvocationName.Length -gt 1))
	{
		$ScriptName = $InvokeInfo.InvocationName
	}
	elseif ($MyInvocation.ScriptName -ne $null)
	{
		$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
	}
	
	$Error_Summary_TXT = @()
	if (-not ([string]::IsNullOrEmpty($ScriptName)))
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Script" -Value $ScriptName 
	}
	
	if ($InvokeInfo.Line -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Command" -Value ($InvokeInfo.Line).Trim()
		$Error_Summary_TXT += "Command: [" + ($InvokeInfo.Line).Trim() + "]"
	}
	elseif ($InvokeInfo.MyCommand -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Command" -Value $InvokeInfo.MyCommand.Name
		$Error_Summary_TXT += "Command: [" + $InvokeInfo.MyCommand.Name + "]"
	}
	
	if ($InvokeInfo.ScriptLineNumber -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Line Number" -Value $InvokeInfo.ScriptLineNumber
	}
	
	if ($InvokeInfo.OffsetInLine -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Column  Number" -Value $InvokeInfo.OffsetInLine
	}

	if (-not ([string]::IsNullOrEmpty($ScriptErrorText)))
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Additional Info" -Value $ScriptErrorText
	}
	
	if ($ErrorRecord.Exception.Message -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Error Text" -Value $ErrorRecord.Exception.Message
		$Error_Summary_TXT += "Error Text: " + $ErrorRecord.Exception.Message
	}
	if($ErrorRecord.ScriptStackTrace -ne $null)
	{
		$Error_Summary | Add-Member -MemberType NoteProperty -Name "Stack Trace" -Value $ErrorRecord.ScriptStackTrace
	}
	
	$Error_Summary | Add-Member -MemberType NoteProperty -Name "Custom Error" -Value "Yes"

	if ($ScriptName.Length -gt 0)
	{
		$ScriptDisplay = "[$ScriptName]"
	}
	
	$Error_Summary | ConvertTo-Xml | update-diagreport -id ("ScriptError_" + (Get-Random)) -name "Script Error $ScriptDisplay" -verbosity "Debug"
	if (-not ($SkipWriteToStdout.IsPresent))
	{
		"[WriteTo-ErrorDebugReport] An error was logged to Debug Report: " + [string]::Join(" / ", $Error_Summary_TXT) | WriteTo-StdOut -InvokeInfo $InvokeInfo -ShortFormat -IsError
	}
	$Error_Summary | fl * | Out-String | WriteTo-StdOut -DebugOnly -IsError
}

Function GetAgeDescription($TimeSpan, [switch] $Localized) {
	$Age = $TimeSpan

	if ($Age.Days -gt 0) 
	{
		$AgeDisplay = $Age.Days.ToString()
		if ($Age.Days -gt 1) 
		{
			if ($Localized.IsPresent)
			{
				$AgeDisplay += " " + $UtilsCTSStrings.ID_Days
			}
			else
			{
				$AgeDisplay += " Days"
			}
		}
		else
		{
			if ($Localized.IsPresent)
			{
				$AgeDisplay += " " + $UtilsCTSStrings.ID_Day
			}
			else
			{
				$AgeDisplay += " Day"
			}
		}
	} 
	else 
	{
		if ($Age.Hours -gt 0) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay = $Age.Hours.ToString()
			if ($Age.Hours -gt 1)
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Hours
				}
				else
				{
					$AgeDisplay += " Hours"
				}
			}
			else
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Hour
				}
				else
				{
					$AgeDisplay += " Hour"
				}
			}
		}
		if ($Age.Minutes -gt 0) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.Minutes.ToString()
			if ($Age.Minutes -gt 1)
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Minutes
				}
				else
				{
					$AgeDisplay += " Minutes"
				}
			}
			else
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Minute
				}
				else
				{
					$AgeDisplay += " Minute"
				}
			}
		}		
		if ($Age.Seconds -gt 0) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.Seconds.ToString()
			if ($Age.Seconds -gt 1) 
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Seconds
				}
				else
				{
					$AgeDisplay += " Seconds"
				}
			}
			else
			{
				if ($Localized.IsPresent)
				{
					$AgeDisplay += " " + $UtilsCTSStrings.ID_Second
				}
				else
				{
					$AgeDisplay += " Second"
				}
			}
		}
		if (($Age.TotalSeconds -lt 1)) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.TotalSeconds.ToString()
			if ($Localized.IsPresent)
			{
				$AgeDisplay += " " + $UtilsCTSStrings.ID_Seconds
			}
			else
			{
				$AgeDisplay += " Seconds"
			}
		}	
	}
    Return $AgeDisplay
}

Function Replace-XMLChars($RAWString)
{
	$RAWString -replace("&", "&amp;") -replace("`"", "&quot;") -Replace("'", "&apos;") -replace("<", "&lt;") -replace(">", "&gt;")
}

Function Run-DiagExpression
{

	$Error.Clear()

	$line = [string]::join(" ", $MyInvocation.Line.Trim().Split(" ")[1..($MyInvocation.Line.Trim().Split(" ").Count)])

	if ($line -ne $null)
	{
		"[Run-DiagExpression]: Starting $line" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
		$ScriptTimeStarted = Get-Date
		Invoke-Expression $line
		if ($ScriptExecutionInfo_Summary.$line -ne $null) 
		{
			$X = 1
			$memberExist = $true
			do {
				if ($ScriptExecutionInfo_Summary.($line + " [$X]") -eq $null) {
					$memberExist = $false
					$line += " [$X]"
				}
				$X += 1
			} while ($memberExist)
		}
	    add-member -inputobject $ScriptExecutionInfo_Summary -membertype noteproperty -name $line -value (GetAgeDescription(New-TimeSpan $ScriptTimeStarted))
		"[Run-DiagExpression]: Finished $line" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
	}
	else
	{
		"[Run-DiagExpression] [" + [System.IO.Path]::GetFileName($MyInvocation.ScriptName) + " - " + $MyInvocation.ScriptLineNumber.ToString() + '] - Error: a null expression was sent to Run-DiagExpression' | writeto-stdout
	}
}

Function Run-DiagExpression10
{

	$Error.Clear()

	trap [Exception] 
	{
		$scriptName = $MyInvocation.ScriptName
		if([string]::IsNullOrEmpty($scriptName)){$scriptName = "(Unknown Script)"}
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText ("[" + (Split-Path $scriptName -Leaf) + "][Run-DiagExpression] $line") -InvokeInfo ($_.Exception.ErrorRecord.InvocationInfo)
		$Error.Clear()
		continue
	}

	if ($MyInvocation.Line -ne $null)
	{
		$line = [string]::join(" ", $MyInvocation.Line.Trim().Split(" ")[1..($MyInvocation.Line.Trim().Split(" ").Count)])
		
		if ($line -ne $null)
		{
			"[Run-DiagExpression]: Starting $line" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
			$ScriptTimeStarted = Get-Date
			Invoke-Expression $line
			if ($ScriptExecutionInfo_Summary.$line -ne $null) 
			{
				$X = 1
				$memberExist = $true
				do {
					if ($ScriptExecutionInfo_Summary.($line + " [$X]") -eq $null) {
						$memberExist = $false
						$line += " [$X]"
					}
					$X += 1
				} while ($memberExist)
			}
		    add-member -inputobject $ScriptExecutionInfo_Summary -membertype noteproperty -name $line -value (GetAgeDescription(New-TimeSpan $ScriptTimeStarted))
			"[Run-DiagExpression]: Finished $line" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
		}
		else
		{
			"[Run-DiagExpression] [" + [System.IO.Path]::GetFileName($MyInvocation.ScriptName) + " - " + $MyInvocation.ScriptLineNumber.ToString() + '] - Error: a null expression was sent to Run-DiagExpression' | writeto-stdout
		}
	}
	else
	{
		"[Run-DiagExpression] [" + [System.IO.Path]::GetFileName($MyInvocation.ScriptName) + " - " + $MyInvocation.ScriptLineNumber.ToString() + '] - Error: a null expression was sent to Run-DiagExpression' | writeto-stdout
	}
}


function Get-MATSTemp()
{
	if (Test-Path("$env:temp\mats-temp\cab*.*"))
	{
		$CABDirs = get-childitem "$env:temp\mats-temp\cab*.*"
		
		if ($CABDirs.count -gt 0)
		{
			$CABDirs = Sort-Object -InputObject $CABDirs -Property LastWriteTime -Descending
			
			return $CabDirs[0].FullName
		}
		else
		{
			return $CABDirs.FullName
		}
	}
}

Function Display-DefaultActivity([switch] $File, [string] $FileName='', [switch] $Rule, [string] $RuleNumber='')
{
	if (($Rule.IsPresent) -or ($RuleNumber.Length -gt 0))
	{
		$InfoToAdd = ''
		if ($RuleNumber.Length -gt 0)
		{
			$InfoToAdd = " (" + $RuleNumber + ")"
		}
		
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_GenericActivityRules -Status ($UtilsCTSStrings.ID_GenericActivityRulesDesc + $InfoToAdd)
	}
	else
	{
		$InfoToAdd = ''
		if ($FileName.Length -gt 0)
		{
			$InfoToAdd = " [" + $FileName + "]"
		}
		
		Write-DiagProgress -Activity $UtilsCTSStrings.ID_GenericActivityFile -Status ($UtilsCTSStrings.ID_GenericActivityFileDesc + $InfoToAdd)
	}
}

# The function below is used to build the global variable $OSArchitecture.
# You can use the $OSArchitecture to define the computer architecture. Current Values are:
# X86 - 32-bit
# AMD64 - 64-bit
# IA64 - 64-bit

Function Get-ComputerArchitecture() 
{ 
	if (($Env:PROCESSOR_ARCHITEW6432).Length -gt 0) #running in WOW 
	{ 
		return $Env:PROCESSOR_ARCHITEW6432 
	} 
	else 
	{ 
		return $Env:PROCESSOR_ARCHITECTURE 
	}
}

function Import-LocalizedData10($BindingVariable, $FileName, $BaseDirectory, $UICulture="en-us")
{	
	$currentCulture = (get-culture).name
	
	if ($FileName -eq $null)
	{
		$FileName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
	}
	
	if ($baseDirectory -eq $null)
	{
		$baseDirectory = $pwd.Path
	}
	
	if ([System.IO.File]::Exists("$BaseDirectory\$CurrentCulture\$filename.psd1"))
	{
		$fullpath = "$BaseDirectory\$CurrentCulture\$Filename.psd1"			
	}
	else
	{
		$fullpath = (Get-MATSTemp) + "\$UIculture\$Filename.psd1"			
	}
	
	if (-not [System.IO.File]::Exists($fullpath))
	{
		$fullpath = "$BaseDirectory\en-us\$Filename.psd1"
	}		
	
	if ([System.IO.File]::Exists($fullpath))
	{
		$stringtable = "" | Select-Object StringTableFileName						# Return object
	        
		$sourceStrings = [System.IO.File]::ReadAllLines($fullpath)					# Array of strings in .PSD1 file
		
		$stringtable.StringTableFileName = $filename								# Place the filename in the stringtable                               
	    
		for ($i = 0; $i -lt $sourceStrings.count; $i++)								# Loop over all strings
		{
			if ($sourceStrings[$i].contains("="))									# Simple check for "xx=yy" pattern
			{
				$stringID = $sourceStrings[$i].Substring(0, $sourceStrings[$i].IndexOf("="))							# Get String ID
				$stringValue = $sourceStrings[$I].SubString($SourceStrings[$i].IndexOf("=")+1)							# Get String Value
	            
				add-member -inputobject $StringTable -membertype noteproperty -name $stringID -value $stringValue		# Add this StringID/Value to the return object
			}
		}	    
	    set-variable -Name $bindingvariable -Value $stringtable -Scope "global"		# 'return' the completed string table
    }
    else
    {
		"File not Found: $fullpath" | WriteTo-StdOut
    }
} # Import-LocalizedData10

# Simple implementation of PowerShell 2.0 add-type cmdlet
function Add-Type10
{
param([string]$TypeDefinition, [Array]$ReferencedAssemblies, [switch]$passthru)

	# Create Provider
	$csprovider = new-object Microsoft.CSharp.CSharpCodeProvider
	
	# Configure the compiler
	$CompilerParams = new-object System.CodeDom.Compiler.CompilerParameters
	$CompilerParams.GenerateInMemory = $true
	
	# Add some default assemblies
	$CompilerParams.ReferencedAssemblies.Add("system.dll") > $null
	$CompilerParams.ReferencedAssemblies.Add([PSObject].assembly.location) > $null
	
	# add user-defined assemblies
	if ($ReferencedAssemblies.count -gt 0)
	{
		for ($i = 0; $i -lt $ReferencedAssemblies.count; $i++)
		{
			[Void]$CompilerParams.ReferencedAssemblies.Add($ReferencedAssemblies[$i])
		}
	}
	
	# compile the code
	$Result = $csprovider.compileAssemblyFromSource($CompilerParams, $TypeDefinition) 
	

    # check for success
	if ($Result.errors.count -gt 0)
	{
		write-error $Result
	}
    else
    {
        if ($passthru)
        {
            $Result.compiledassembly.getexportedtypes()
        }
    }
}

Function Run-LDAPSearch($Filter, $RootDN=$null, $SearchScope='Subtree', $PageSize=0)
{

	$Error.Clear()

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText ("Run-LDAPSearch [" + (Split-Path $MyInvocation.ScriptName -Leaf) + "] - Filter: " + (Replace-XMLChars $Filter) + "RootDN: " + (Replace-XMLChars $RootDN)) -InvokeInfo $MyInvocation
		$Error.Clear()
		continue
	}

	#LDAP Filter Syntax: http://msdn.microsoft.com/en-us/library/aa746475(VS.85).aspx
	#$DomainDN = GetCurrentDomainDN
	
	"[Run-LDAPSearch] Running LDAP Query    : " +  $Filter | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation
	if ($Filter -ne $null)
	{
		$adsiSearcher = New-Object DirectoryServices.DirectorySearcher
		if ($RootDN)
		{
			"        Root DN : " +  $RootDN | WriteTo-StdOut -ShortFormat
			$adsiPartition = New-Object System.DirectoryServices.DirectoryEntry($RootDN)
			$adsiSearcher.SearchRoot = $adsiPartition
		}
		if ($PageSize -ne 0)
		{
			"        Page Size : " +  $PageSize | WriteTo-StdOut -ShortFormat
			$adsiSearcher.PageSize = $PageSize
		}
		
		$adsiSearcher.Filter = $Filter
		$adsiSearcher.SearchScope=$SearchScope
		
		#Run the query
		$ReturnObject = $adsiSearcher.FindAll()
		
		if ($ReturnObject[0].Path -ne $null) 
		{
			"        Path Returned : " +  $ReturnObject[0].Path | WriteTo-StdOut -ShortFormat
		}
		
		if ($ReturnObject -is [System.DirectoryServices.SearchResultCollection])
		{
			if ($ReturnObject[0] -eq $null)
			{
				"        Query returned a null object." | WriteTo-StdOut -ShortFormat
				Return $null
			}
			else
			{
				$ReturnObject | ForEach-Object {return $_}
			}
		}
		elseif ($ReturnObject -is [System.DirectoryServices.SearchResult])
		{
			return $ReturnObject 
		}
		else
		{
			"        Query did not return a SarchResult object." | WriteTo-StdOut -ShortFormat
			"        $ReturnObject" | WriteTo-StdOut -ShortFormat
			return $null
		}
	}
	else
	{
			"        [Run-LDAPSearch] No filter specified." | WriteTo-StdOut -ShortFormat
			return $null
	}
}

## The function below ends diagnostic execution to avoid customer to upload information
#  Currently there is no supported way to do this. The function below kills MSDT/MATS processes so the diagnostic execution finishes
Function Stop-DiagnosticExecution
{
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_
		continue
	}
	
	"[Stop-DiagnosticExecution] called." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
	"[Stop-DiagnosticExecution] called. InvokeInfo: `r`n`r`n" + ($MyInvocation | fl | Out-String) | WriteTo-StdOut
	
    $MsdtProcesses = Get-Process | Where-Object {($_.name -eq "MSDT") -or ($_.name -eq "MATSBOOT") -or ($_.name -eq "MATSWIZ")}

	ForEach ($MSDTProcess in $MsdtProcesses)
	{
	    $MSDTProcess.CloseMainWindow()
		
		"Closing {0}" -f $MSDTProcess.name | WriteTo-StdOut -shortformat
		$MSDTProcessClosed = $MSDTProcess.WaitForExit(1000)
		if(-not $MSDTProcessClosed)
		{
			"Stopping {0}" -f $MSDTProcess.name | WriteTo-StdOut -shortformat
			$MSDTProcess | Stop-Process -ErrorAction SilentlyContinue 
		}
		else
		{
		 	$MSDTProcess | Stop-Process
		}
	}
	
	Get-Process -Id $PID | Stop-Process
}

Function CheckMinimalFileVersion([string] $Binary, $RequiredMajor, $RequiredMinor, $RequiredBuild, $RequiredFileBuild, [switch] $LDRGDR, [switch] $ForceMajorCheck, [switch] $ForceMinorCheck, [switch] $ForceBuildCheck, [switch]$CheckFileExists)
{
	# -LDRGDR switch:
	#    Adds a logic to work with fixes (like Security hotfixes), which both LDR and GDR versions of a binary is deployed as part of the hotfix
	# -ForceMajorCheck switch:
	#    Usually if a fix applies to a specific OS version, the script returns $true. You can force checking the Major version by using this switch
	# -ForceMinorCheck switch:
	#    Usually if a fix applies to a specific Service Pack version, we just return $true. You can ignore always returning $true and making the actual binary check by using this switch
	# -ForceBuildCheck switch:
	#    Usually if a fix applies to a specific OS version, we just return $true. You can ignore always returning $true and making the actual binary check by using this switch.
	
	if (test-path -Path $Binary)

	{
		$StdoutDisplay = ''
		$FileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Binary)
		
		# If the version numbers from the binary is different than the OS version - it means the file is probably not a inbox component. 
		# In this case, set the $ForceMajorCheck, $ForceBuildCheck and $ForceBuildCheck to $true automatically
		
		if (($FileVersionInfo.FileMajorPart -ne $OSVersion.Major) -and ($FileVersionInfo.FileMinorPart -ne $OSVersion.Minor) -and ($FileVersionInfo.FileBuildPart -ne $OSVersion.Build))
		{
			$ForceBuildCheck = $true
			$ForceMinorCheck = $true
			$ForceMajorCheck = $true
		}
		
		if ($ForceMajorCheck)
		{
			$StdoutDisplay = '(Force Major Check)'
		}
		
		if ($ForceMinorCheck)
		{
			$ForceMajorCheck = $true			
			$StdoutDisplay = '(Force Minor Check)'
		}

		if ($ForceBuildCheck)
		{
			$ForceMajorCheck = $true	
			$ForceMinorCheck = $true
			$StdoutDisplay = '(Force Build Check)'
		}
		
		if ((($ForceMajorCheck.IsPresent) -and ($FileVersionInfo.FileMajorPart -eq $RequiredMajor)) -or (($ForceMajorCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileMajorPart -eq $RequiredMajor)))
		{
			if ((($ForceMinorCheck.IsPresent) -and ($FileVersionInfo.FileMinorPart -eq $RequiredMinor)) -or (($ForceMinorCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileMinorPart -eq $RequiredMinor)))
			{
				if (($ForceBuildCheck.IsPresent) -and ($FileVersionInfo.FileBuildPart -eq $RequiredBuild) -or (($ForceBuildCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileBuildPart -eq $RequiredBuild)))
				{
					#Check if -LDRGDR was specified - in this case run the LDR/GDR logic					
					#For Windows Binaries, we need to check if current binary is LDR or GDR for fixes:
					if (($LDRGDR.IsPresent) -and ($FileVersionInfo.FileMajorPart -ge 6) -and ($FileVersionInfo.FileBuildPart -ge 6000))
					{
						#Check if the current version of the file is GDR or LDR:
						if ((($FileVersionInfo.FilePrivatePart.ToString().StartsWith(16)) -and (($RequiredFileBuild.ToString().StartsWith(16)) -or ($RequiredFileBuild.ToString().StartsWith(17)))) -or 
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(17)) -and ($RequiredFileBuild.ToString().StartsWith(17))) -or 
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(18)) -and ($RequiredFileBuild.ToString().StartsWith(18))) -or 
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(20)) -and ($RequiredFileBuild.ToString().StartsWith(20))) -or 
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(21)) -and ($RequiredFileBuild.ToString().StartsWith(21))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(22)) -and ($RequiredFileBuild.ToString().StartsWith(22))) 
							)
						{
							#File and requests are both GDR or LDR - check the version in this case:
							if ($FileVersionInfo.FilePrivatePart -ge $RequiredFileBuild)
							{
								$VersionBelowRequired = $false
							} 
							else 
							{
								$VersionBelowRequired = $true
							}
						}
						else 
						{
							#File is either LDR and Request is GDR - Return true always:
							$VersionBelowRequired = $false
							return $true
						} 
					} 
					elseif ($FileVersionInfo.FilePrivatePart -ge $RequiredFileBuild) #All other cases, perform the actual check
					{
						$VersionBelowRequired = $false
					} 
					else 
					{
						$VersionBelowRequired = $true
					}
				} 
				else 
				{
					if ($ForceBuildCheck.IsPresent)
					{
						$VersionBelowRequired = ($FileVersionInfo.FileBuildPart -lt $RequiredBuild)
					}
					else 
					{
						"[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - Required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a newer Service Pack - OK" | writeto-stdout -shortformat
						return $true
					}
				}
			} 
			else 
			{
				if ($ForceMinorCheck.IsPresent)
				{
					$VersionBelowRequired =  ($FileVersionInfo.FileMinorPart -lt $RequiredMinor)
				} 
				else 
				{
					"[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - and required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a different Operating System Version - OK" | writeto-stdout -shortformat
					return $true
				}
			} 
		} 
		else 
		{
			if ($ForceMajorCheck.IsPresent -eq $false)
			{
				"[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - and required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a different Operating System Version - OK" | writeto-stdout -shortformat
				return $true
			}
			else
			{
				$VersionBelowRequired = ($FileVersionInfo.FileMajorPart -lt $RequiredMajor)
			}
		}
		
		if ($VersionBelowRequired)
		{
			"[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " and required version is $RequiredMajor" + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild | writeto-stdout -shortformat
			return $false
		}
		else 
		{
			"[CheckFileVersion] $StdoutDisplay $Binary version is " + $FileVersionInfo.FileMajorPart + "." + $FileVersionInfo.FileMinorPart + "." + $FileVersionInfo.FileBuildPart + "." + $FileVersionInfo.FilePrivatePart + " and required version is " + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + " - OK" | writeto-stdout -shortformat
			return $true
		}
	}
	else 
	{
		if($CheckFileExists.IsPresent)
		{
			"[CheckFileVersion] $Binary does not exist. Returning 'false' as  -CheckFileExists switch was used" | writeto-stdout -shortformat
			return $false
		}
		return $true
	}
}

# Visibility = 1 - FTE Only
# Visibility = 2 - Partners
# Visibility = 3 - Internal
# Visibility = 4 - Public

#Support Topic IDs can be obtained here: http://sharepoint/sites/diag/scripteddiag/_layouts/xlviewer.aspx?id=/sites/diag/scripteddiag/SDP%2030/Support%20Topics%20UDE%20Table.xlsx

Function Write-GenericMessage
{
PARAM (	[string] $RootCauseID = $null,
		$SolutionTitle = $null,
		$InternalContentURL = $null,
		$PublicContentURL = $null,
		$ProcessName = $null,
		$Component = $null,
		$ModulePath = $null,
		$Verbosity = "Informational",
		$sectionDescription = "Additional Information",
		$AdditionalSDPOnlyInformation = $null,
		$SDPFileReference = $null,
		$InformationCollected = $null,
		$Fixed = $null,
		[int] $Visibility = 3,
		[int] $SupportTopicsID = 0,
		[int] $MessageVersion = 0
		)

	trap [Exception] 
	{ 
		WriteTo-ErrorDebugReport -ErrorRecord $_
		continue
	}			
	#First step is decide if the root cause can be a generic message
	#Meaning - The Resolver ID needs to be a GUID
	if ($RootCauseID -ne $null)
	{
		$HasAdditionalInfo = $False		
		$PluginHasAdditionalInfo = $false
		if($true -eq (Test-Path (Join-Path $PWD.Path "DiagPackage.diagpkg") -ErrorAction SilentlyContinue))
		{
			[xml] $DiagPackageXML = Get-Content -Path (Join-Path $PWD.Path "DiagPackage.diagpkg")
			$RootCauseElement = $DiagPackageXML.SelectSingleNode("//Rootcauses/Rootcause[ID='$RootCauseID']")
		}
		if ($RootCauseElement -ne $null)
		{
			$RootCauseElement.Resolvers | ForEach-Object {$GenericMessageGUID = $_.Resolver.ID}
			# Quickly check to confirm that a given resolver ID is represented by a GUID:
			if (($GenericMessageGUID.Length -eq 36) -and (($GenericMessageGUID.split("-")).Count -eq 5)) 
			{
				$GenericMessage_Summary = New-Object PSObject
				$PluginMessage_Summary = New-Object PSObject
				if (-not [string]::IsNullOrEmpty($SolutionTitle))
				{
					$PluginMessage_Summary | add-member -membertype noteproperty -name "Description" -value $SolutionTitle
					$PluginHasAdditionalInfo = $true
				}
				if (($InternalContentURL -ne $null) -and ($InternalContentURL -like "*//*"))
				{
					$InternalContentURL = Replace-XMLChars $InternalContentURL
					$PluginMessage_Summary | add-member -membertype noteproperty -name "Internal Content" -value "<a href=`"$InternalContentURL`" target=`"_blank`">$InternalContentURL</a>"
					$PluginHasAdditionalInfo = $true
				}
				if (($PublicContentURL -ne $null) -and ($PublicContentURL -like "*//*"))
				{
					$PublicContentURL = Replace-XMLChars $PublicContentURL
					$PluginMessage_Summary | add-member -membertype noteproperty -name "Public Content" -value "<a href=`"$PublicContentURL`" target=`"_blank`">$PublicContentURL</a>"
					$PluginHasAdditionalInfo = $true
				}
				if (($Component -ne $null) -and (($Component -isnot [string]) -or (-not [string]::IsNullOrEmpty($Component))))
				{
					$GenericMessage_Summary | add-member -membertype noteproperty -name "Component" -value $Component
					$HasAdditionalInfo = $true
				}
				if (($ModulePath -ne $null) -and (($ModulePath -isnot [string]) -or (-not [string]::IsNullOrEmpty($ModulePath))))
				{
					$GenericMessage_Summary | add-member -membertype noteproperty -name "Module Path" -value $ModulePath
					$HasAdditionalInfo = $true
				}
		
				if ($AdditionalSDPOnlyInformation -ne $null)
				{
					$GenericMessage_Summary | add-member -membertype noteproperty -name "More Information" -value $AdditionalSDPOnlyInformation
					$HasAdditionalInfo = $true
				}
				
				if ($InformationCollected -ne $null)
				{
					$InfoCollectedTable = ""
					if ($InformationCollected -is [Hashtable])
					{
						$InformationCollected.GetEnumerator() | ForEach-Object -Process { 
								$InfoCollectedTable += "<tr><td name=`"Key`">" + $_.Key + "</td>"
								$InfoCollectedTable += "<td name=`"Separator`">:</td>"
								$InfoCollectedTable += "<td name=`"Value`">" + $_.Value + "</td></tr>"
						}
					}
					elseif ($InformationCollected -is [PSObject])
					{
						foreach($p in $InformationCollected.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
						{
							$InfoCollectedTable += "<tr><td name=`"Key`">" + $p.Name + "</td>"
							$InfoCollectedTable += "<td name=`"Separator`">:</td>"
							$InfoCollectedTable += "<td name=`"Value`">" + $p.Value + "</td></tr>"
						}
					}
					else
					{
						"[Write-GenericMessage] InformationCollected not be added since it is a " + ($InformationCollected.GetType().Name) + ". It is expected a HashTable or a PSObject" | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
					}
					
					if ($InfoCollectedTable.Length -gt 0)
					{
						$InfoCollectedTable = "<table>" + $InfoCollectedTable + "</table>"
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Information Collected" -value $InfoCollectedTable
						$HasAdditionalInfo = $true
					} 
					else 
					{
						"[Write-GenericMessage] InformationCollected not be added since it is null." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
					}

				}
				
				if (-not [string]::IsNullOrEmpty($SDPFileReference))
				{
					if (Test-Path $SDPFileReference)
					{
						$SDPFileReferenceDisplay = Split-Path $SDPFileReference -Leaf
						$PluginMessage_Summary | add-member -membertype noteproperty -name "File Reference" -value ("<a href= `"`#" + $SDPFileReferenceDisplay + "`">" + ($SDPFileReferenceDisplay) + "</a>")
						$PluginHasAdditionalInfo = $true
					}
					else
					{
						"[Write-GenericMessage] File reference not created since file does not exist: $SDPFileReference." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
					}
				}
				
				if (($ModulePath -ne $null) -and (($ModulePath -isnot [string]) -or (-not [string]::IsNullOrEmpty($ModulePath))))
				{
					$GenericMessage_Summary | add-member -membertype noteproperty -name "Module Path" -value $ModulePath
					$HasAdditionalInfo = $true
				}
				
				# When adding 'RootCause' - it is expected that the caller is from a troubleshooter.
				# In this case, save the message to a file to be consumed by the resolver later.
				
				if ($RootCauseID -ne $null)
				{
					#GenericMessage
					
					$GenericMessage_Summary | add-member -membertype noteproperty -name "GenericMessage" -value ""
					if (-not $HasAdditionalInfo)
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Issue Detected" -value "true"
					}
					
					$GenericMessage_XML = $GenericMessage_Summary | ConvertTo-Xml2 
					$GenericMessage_XML.Objects.SetAttribute("GenericMessageType", $Verbosity)
					$GenericMessage_XML.Objects.SetAttribute("MachineName", $ComputerName)
					
					if ($SupportTopicsID -ne 0)
					{
						$GenericMessage_XML.Objects.SetAttribute("SupportTopicsID", $SupportTopicsID)
					}

					if ($MessageVersion -ne 0)
					{
						$GenericMessage_XML.Objects.SetAttribute("Version", $MessageVersion)
					}
					$Culture = (Get-Culture).Name
					$GenericMessage_XML.Objects.SetAttribute("Culture", $Culture)

					
					if (-not (($Visibility -ge 1) -or ($Visibility -le 4)))
					{
						$Visibility = 3
					}
					
					if (($Visibility -eq 4) -and ($PublicContentURL -eq $null))
					{
						$Visibility = 3
						"[Write-GenericMessage] Warning: Setting Visibility to '3' instead of '4' for rule $RootCauseID once PublicContentURL is empty for this rule" | WriteTo-StdOut
					}
					
					$GenericMessage_XML.Objects.SetAttribute("Visibility", $Visibility)
					
					$UpdateDiagReportXMLFilePath = "..\GenericMessageUpdateDiagReport.xml"
					
					if (Test-Path $UpdateDiagReportXMLFilePath) 
					{
						[xml] $xmlUpdateDiagReport = Get-Content $UpdateDiagReportXMLFilePath
					} else {
						$xmlUpdateDiagReport = [xml] "<?xml version=""1.0"" encoding=""UTF-16""?><Root/>"
					}
															
					[System.Xml.XmlElement] $rootElement=$xmlUpdateDiagReport.SelectNodes("/Root").Item(0)
					[System.Xml.XmlElement] $RootCauseElement = $xmlUpdateDiagReport.CreateElement("RootCauseDetected")
					$RootCauseElement.SetAttribute("RootCauseID", $RootCauseID)
					$RootCauseElement.SetAttribute("sectionDescription", $sectionDescription)
					$RootCauseElement.SetAttribute("ScriptName", [System.IO.Path]::GetFileName($MyInvocation.ScriptName))
					$RootCauseElement.SetAttribute("Verbosity", $Verbosity)
					$RootCauseElement.SetAttribute("Processed", "False")
					if ($Fixed -ne $null)
					{
						if ($Fixed -is [Boolean])
						{
							$RootCauseElement.SetAttribute("Fixed", $Fixed)
						}
						else
						{
							"[Write-GenericMessage] Warning: Fixed is set to $Fixed, but the expected type is Boolean. Fixed value was ignored" | WriteTo-StdOut
						}
					}
					$RootCauseElement.set_InnerXml($GenericMessage_XML.Objects.get_OuterXml())
					[Void]$rootElement.AppendChild($RootCauseElement)
					
					if ($PluginHasAdditionalInfo)
					{
						if ($xmlUpdateDiagReport.SelectSingleNode("//PlugInMessage[@RootCauseID='$RootCauseID']") -eq $null)
						{						
							$PluginMessage_XML = $PluginMessage_Summary | ConvertTo-Xml2
							[System.Xml.XmlElement] $RootCauseElement = $xmlUpdateDiagReport.CreateElement("PlugInMessage")						
							$RootCauseElement.SetAttribute("RootCauseID", $RootCauseID)
							
							$RootCauseElement.set_InnerXml($PluginMessage_XML.Objects.get_OuterXml())
							[Void]$rootElement.AppendChild($RootCauseElement)
						}
					}
					$xmlUpdateDiagReport.Save($UpdateDiagReportXMLFilePath)
					"[Write-GenericMessage] GenericMessage created for Root Cause $RootCauseID.`r`n                       Script Name: " +  ([System.IO.Path]::GetFileName($MyInvocation.ScriptName)) + "`r`n                       Line Number: " + $MyInvocation.ScriptLineNumber | WriteTo-StdOut
				} 
				else 
				{
					$GenericMessage_XML = $GenericMessage_Summary | ConvertTo-Xml2 | update-diagreport -id ("Msg_" + (Get-Random)) -name $sectionDescription -verbosity $Verbosity
				}
			}
			else
			{
				"[Write-GenericMessage] Error: Root Cause $RootCauseID cannot be converted to generic message since its Resolver ID is not represented by a string GUID. Resolver ID: $GenericMessageGUID." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
			}
		}
		elseif ($debug -eq $true)
		{
			$MSG = New-Object PSObject
			$MSG | Add-Member -membertype noteproperty -name 'RootCauseID' -value $RootCauseID
			$MSG | Add-Member -membertype noteproperty -name 'SolutionTitle' -value $SolutionTitle
			$MSG | Add-Member -membertype noteproperty -name 'InternalContentURL' -value $InternalContentURL
			$MSG | Add-Member -membertype noteproperty -name 'PublicContentURL' -value $PublicContentURL
			$MSG | Add-Member -membertype noteproperty -name 'ProcessName' -value $ProcessName
			$MSG | Add-Member -membertype noteproperty -name 'Component' -value $Component
			$MSG | Add-Member -membertype noteproperty -name 'ModulePath' -value $ModulePath
			$MSG | Add-Member -membertype noteproperty -name 'Verbosity' -value $Verbosity
			$MSG | Add-Member -membertype noteproperty -name 'Fixed' -value $Fixed
			$MSG | Add-Member -membertype noteproperty -name 'Visibility' -value $Visibility
			$MSG | Add-Member -membertype noteproperty -name 'SupportTopicsID' -value $SupportTopicsID
			$MSG | Add-Member -membertype noteproperty -name 'Culture' -value $Culture
			$MSG | Add-Member -membertype noteproperty -name 'MessageVersion' -value $MessageVersion
			$MSG | Add-Member -membertype noteproperty -name '[SDP] SectionDescription' -value $sectionDescription
			$MSG | Add-Member -membertype noteproperty -name '[SDP] AdditionalSDPOnlyInformation' -value $AdditionalSDPOnlyInformation
			$MSG | Add-Member -membertype noteproperty -name '[SDP] SDPFileReference' -value $SDPFileReference
			$MSG | Add-Member -membertype noteproperty -name 'InformationCollected' -value ($InformationCollected | fl | Out-String)
			"Write-GenericMessage called: " + ($MSG | fl | Out-String) | WriteTo-StdOut -DebugOnly -Color DarkYellow  -InvokeInfo $MyInvocation
		}
		else
		{
			"[Write-GenericMessage] Error: Root Cause $RootCauseID could not be found. Generic Message did not get generated. " | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
		}
	}
	else
	{
		"[Write-GenericMessage] Error: Blank RootCauseID. Generic Message did not get generated." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
	}
}

Function Add-GenericMessage
{
PARAM (	[string] $Id = $null,
		$ProcessName = $null,
		$ModulePath = $null,
		$InformationCollected = $null,
		$MessageContext = $null,
		$Component = $null,
		$SDPSectionDescription = "Additional Information",
		$SDPFileReference = $null,
		$SDPAdditionalInfo = $null,
		$Fixed = $null,
		[switch] $ForcePublicVisibility
		)

	trap [Exception] 
	{ 
		WriteTo-ErrorDebugReport -ErrorRecord $_
		continue
	}			
	#First step is decide if the root cause can be a generic message
	#Meaning - The Resolver ID needs to be a GUID
	if ($Id -ne $null)
	{
		$HasAdditionalInfo = $False		
		$PluginHasAdditionalInfo = $false
		
		if (Test-Path (Join-Path $PWD.Path "DiagPackage.diagpkg"))
		{
			[xml] $DiagPackageXML = Get-Content -Path (Join-Path $PWD.Path "DiagPackage.diagpkg")
			$DiagPackageXMLRootCauseElement= $DiagPackageXML.SelectSingleNode("//Rootcauses/Rootcause[ID=`'" + $Id + "`']")
		}
		
		if ($DiagPackageXMLRootCauseElement -ne $null)
		{
		
			$DiagPackageXMLRootCauseElement.Resolvers | ForEach-Object {$GenericMessageGUID = $_.Resolver.ID}
			
			# Quickly check to confirm that a given resolver ID is represented by a GUID:
			if (($GenericMessageGUID.Length -eq 36) -and (($GenericMessageGUID.split("-")).Count -eq 5)) 
			{

				$UpdateDiagReportXMLFilePath = "..\GenericMessageUpdateDiagReport.xml"
				
				if (Test-Path $UpdateDiagReportXMLFilePath) 
				{
					[xml] $xmlUpdateDiagReport = Get-Content $UpdateDiagReportXMLFilePath
				} 
				else 
				{
					[xml] $xmlUpdateDiagReport =  "<?xml version=""1.0"" encoding=""UTF-16""?><Root/>"
				}
				
				[System.Xml.XmlElement] $xmlUpdateDiagReportRootElement=$xmlUpdateDiagReport.SelectNodes("/Root").Item(0)
				
				$GenericMessage_Summary = New-Object PSObject
				$PluginMessage_Summary = New-Object PSObject
				
				$PluginMessageNode = $DiagPackageXMLRootCauseElement.ExtensionPoint
				
				if ($PluginMessageNode.get_ChildNodes().Count -gt 0)
				{
					## Section: PlugInMessage
					
					#check if PlugInMessage information already exist in the root cause XML. If not, create it
					if ($xmlUpdateDiagReport.SelectSingleNode("//PlugInMessage[@RootCauseID='$Id']") -eq $null)
					{						
						[System.Xml.XmlElement] $xmlUpdateDiagReportRootCauseElement = $xmlUpdateDiagReport.CreateElement("PlugInMessage")						
						$xmlUpdateDiagReportRootCauseElement.SetAttribute("RootCauseID", $Id)
						
						$InternalContentURL = $PluginMessageNode.InternalContentURL
						$PublicContentURL = $PluginMessageNode.PublicContentURL
						$HighLevelLogic = $PluginMessageNode.HighLevelLogic
						$Symptom = $PluginMessageNode.Symptom
						$Visibility = $PluginMessageNode.Visibility
						$SupportTopicsID = $PluginMessageNode.SupportTopicsID
						$MessageVersion = $PluginMessageNode.MessageVersion
						$RootCause = $PluginMessageNode.RootCause
						$AlertType = $PluginMessageNode.AlertType
						
						if ($Symptom -ne $null)
						{
							$PluginMessage_Summary | add-member -membertype noteproperty -name "Symptom" -value $Symptom
							$HasAdditionalInfo = $true
						}
						
						if ($Symptom -ne $null)
						{
							$PluginMessage_Summary | add-member -membertype noteproperty -name "Root Cause" -value $RootCause
							$HasAdditionalInfo = $true
						}
						
						if (($InternalContentURL -ne $null) -and ($InternalContentURL -like "*//*"))
						{
							$InternalContentURL = Replace-XMLChars $InternalContentURL
							$PluginMessage_Summary | add-member -membertype noteproperty -name "Internal Content" -value "<a href=`"$InternalContentURL`" target=`"_blank`">$InternalContentURL</a>"
						}
						
						if (($PublicContentURL -ne $null) -and ($PublicContentURL -like "*//*"))
						{
							$PublicContentURL = Replace-XMLChars $PublicContentURL
							$PluginMessage_Summary | add-member -membertype noteproperty -name "Public Content" -value "<a href=`"$PublicContentURL`" target=`"_blank`">$PublicContentURL</a>"
						}
						
						if ($HighLevelLogic -ne $null)
						{
							$PluginMessage_Summary | add-member -membertype noteproperty -name "Detection Logic" -value $HighLevelLogic
							$HasAdditionalInfo = $true
						}

						if ((-not ($Visibility -as [int])) -or (-not (($Visibility -ge 1) -or ($Visibility -le 4))))
						{
							"[Add-GenericMessage] Unknown visibility: [$($Visibility)] Setting Visibility to '3'" | WriteTo-StdOut
							$Visibility = 3
						}
						
						if ((($Visibility -eq 4) -and ($PublicContentURL -eq $null)) -and (-not $ForcePublicVisibility.IsPresent))
						{
							$Visibility = 3
							"[Add-GenericMessage] Warning: Setting Visibility to '3' instead of '4' for rule $Id once PublicContentURL is empty for this rule" | WriteTo-StdOut -IsError
						}
						elseif (($Visibility -eq 4) -and ($ForcePublicVisibility.IsPresent))
						{
							"[Add-GenericMessage] Forcing setting Visibility '4' for rule $Id which has no PublicContentURL." | WriteTo-StdOut
						}
					
						#Convert Plug-in Message information to XML so we can add attributes that are not visible in SDP report
						
						$PluginMessage_XML = $PluginMessage_Summary | ConvertTo-Xml2

						if (($MessageVersion -as [int]) -and ($MessageVersion -ne 0))
						{
							$PluginMessage_XML.Objects.SetAttribute("Version", $MessageVersion)
						}

						if (($SupportTopicsID -as [int]) -and ($SupportTopicsID -ne 0))
						{
							$PluginMessage_XML.Objects.SetAttribute("SupportTopicsID", $SupportTopicsID)
						}
						
						$SupportedMessageTypes = @('Informational','Error', 'Warning', 'SuperRule', 'BestPractice')
						if ($SupportedMessageTypes -notcontains $AlertType)
						{
							"[Add-GenericMessage] Warning: Alert Type [" + $AlertType + "] not supported. Setting alert type to 'Informational'." | WriteTo-StdOut -IsError
							$AlertType = 'Informational'
						}						
						
						$PluginMessage_XML.Objects.SetAttribute("AlertType", $AlertType)
						$PluginMessage_XML.Objects.SetAttribute("Visibility", $Visibility)
						$Culture = (Get-Culture).Name
						$PluginMessage_XML.Objects.SetAttribute("Culture", $Culture)
						
						$xmlUpdateDiagReportRootCauseElement.set_InnerXml($PluginMessage_XML.Objects.get_OuterXml())
						[Void]$xmlUpdateDiagReportRootElement.AppendChild($xmlUpdateDiagReportRootCauseElement)
						
						"[Add-GenericMessage] Plug-In Rule created for Root Cause $Id .`r`n                       Script Name: " +  (Split-Path ($MyInvocation.ScriptName) -Leaf) + "`r`n                       Line Number: " + $MyInvocation.ScriptLineNumber | WriteTo-StdOut
					
					}
					
					## Section: GenericMessage
					if ($Component -ne $null)
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Component" -value $Component
						$HasAdditionalInfo = $true
					}
					
					if ($ModulePath -ne $null)
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Module Path" -value $ModulePath
						$HasAdditionalInfo = $true
					}
			
					if ($SDPAdditionalInfo -ne $null)
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "More Information" -value $SDPAdditionalInfo
						$HasAdditionalInfo = $true
					}

					if ($InformationCollected -ne $null)
					{
						$InfoCollectedTable = ""
						if ($InformationCollected -is [Hashtable])
						{
							$InformationCollected.GetEnumerator() | ForEach-Object -Process { 
									$InfoCollectedTable += "<tr><td name=`"Key`">" + (Replace-XMLChars $_.Key) + "</td>"
									$InfoCollectedTable += "<td name=`"Separator`">:</td>"
									$InfoCollectedTable += "<td name=`"Value`">" + (Replace-XMLChars $_.Value) + "</td></tr>"
							}
						}
						elseif ($InformationCollected -is [PSObject])
						{
							foreach($p in $InformationCollected.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
							{
								$InfoCollectedTable += "<tr><td name=`"Key`">" + (Replace-XMLChars $p.Name) + "</td>"
								$InfoCollectedTable += "<td name=`"Separator`">:</td>"
								$InfoCollectedTable += "<td name=`"Value`">" + (Replace-XMLChars $p.Value) + "</td></tr>"
							}
						}
						else
						{
							"[Add-GenericMessage] InformationCollected not be added since it is a " + ($InformationCollected.GetType().Name) + ". It is expected a HashTable or a PSObject" | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
						}
						
						if ($InfoCollectedTable.Length -gt 0)
						{
							$InfoCollectedTable = "<table>" + $InfoCollectedTable + "</table>"
							$GenericMessage_Summary | add-member -membertype noteproperty -name "Information Collected" -value $InfoCollectedTable
							$HasAdditionalInfo = $true
						} 
						else 
						{
							"[Add-GenericMessage] InformationCollected not be added since it is null." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
						}
					}
					
					if ($MessageContext -ne $null)
					{
						$MessageContextTable = ""
						if ($MessageContext -is [Hashtable])
						{
							$MessageContext.GetEnumerator() | ForEach-Object -Process { 
									$MessageContextTable += "<tr><td name=`"Key`">" + (Replace-XMLChars $_.Key) + "</td>"
									$MessageContextTable += "<td name=`"Separator`">:</td>"
									$MessageContextTable += "<td name=`"Value`">" + (Replace-XMLChars $_.Value) + "</td></tr>"
							}
						}
						elseif ($MessageContext -is [PSObject])
						{
							foreach($p in $MessageContext.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
							{
								$MessageContextTable += "<tr><td name=`"Key`">" + (Replace-XMLChars $p.Name) + "</td>"
								$MessageContextTable += "<td name=`"Separator`">:</td>"
								$MessageContextTable += "<td name=`"Value`">" + (Replace-XMLChars $p.Value) + "</td></tr>"
							}
						}
						else
						{
							"[Add-GenericMessage] MessageContext not be added since it is a " + ($MessageContext.GetType().Name) + ". It is expected a HashTable or a PSObject" | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
						}
						
						if ($MessageContextTable.Length -gt 0)
						{
							$MessageContextTable = "<table>" + $MessageContextTable + "</table>"
							$GenericMessage_Summary | add-member -membertype noteproperty -name "Message Context" -value $MessageContextTable
							$HasAdditionalInfo = $true
						} 
						else 
						{
							"[Add-GenericMessage] MessageContext not be added since it is null." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
						}
					}
					
					if (-not [string]::IsNullOrEmpty($SDPFileReference))
					{
						if (Test-Path $SDPFileReference)
						{
							$SDPFileReferenceDisplay = Split-Path $SDPFileReference -Leaf
							$GenericMessage_Summary | add-member -membertype noteproperty -name "File Reference" -value ("<a href= `"`#" + $SDPFileReferenceDisplay + "`">" + ($SDPFileReferenceDisplay) + "</a>")
							$HasAdditionalInfo = $true
						}
						else
						{
							"[Add-GenericMessage] File reference not created since file could not be found: $SDPFileReference." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
						}
					}
					
					if (($ModulePath -ne $null) -and (($ModulePath -isnot [string]) -or (-not [string]::IsNullOrEmpty($ModulePath))))
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Module Path" -value $ModulePath
						$HasAdditionalInfo = $true
					}
						
					$GenericMessage_Summary | add-member -membertype noteproperty -name "GenericMessage" -value ""
					
					if (-not $HasAdditionalInfo)
					{
						$GenericMessage_Summary | add-member -membertype noteproperty -name "Issue Detected" -value "true"
					}
					
					$GenericMessage_XML = $GenericMessage_Summary | ConvertTo-Xml2
					$GenericMessage_XML.Objects.SetAttribute("MachineName", $ComputerName)
					
					$GenericMessageNode = $GenericMessage_XML.SelectSingleNode("Objects/Object/Property[@Name='GenericMessage']")
					$GenericMessageNode.SetAttribute("SchemaVersion", 2)

					#Now saves the information in the GenericMessageUpdateDiagReport.xml
					
					[System.Xml.XmlElement] $RootCauseDetectedElement = $xmlUpdateDiagReport.CreateElement("RootCauseDetected")
					$RootCauseDetectedElement.SetAttribute("RootCauseID", $Id)
					$RootCauseDetectedElement.SetAttribute("sectionDescription", $SDPSectionDescription)
					$RootCauseDetectedElement.SetAttribute("ScriptName", (Split-Path ($MyInvocation.ScriptName) -Leaf))
					$RootCauseDetectedElement.SetAttribute("Processed", "False")
					
					if ($Fixed -ne $null)
					{
						if ($Fixed -is [Boolean])
						{
							$RootCauseDetectedElement.SetAttribute("Fixed", $Fixed)
						}
						else
						{
							"[Add-GenericMessage] Warning: Fixed is set to $Fixed, but the expected type is Boolean. Fixed value was ignored" | WriteTo-StdOut
						}
					}
					
					$RootCauseDetectedElement.set_InnerXml($GenericMessage_XML.Objects.get_OuterXml())
					[Void]$xmlUpdateDiagReportRootElement.AppendChild($RootCauseDetectedElement)
					
					$xmlUpdateDiagReport.Save($UpdateDiagReportXMLFilePath)
					
					"[Add-GenericMessage] GenericMessage created for Root Cause $Id.`r`n                       Script Name: " +  (Split-Path ($MyInvocation.ScriptName) -Leaf) + "`r`n                       Line Number: " + $MyInvocation.ScriptLineNumber | WriteTo-StdOut

				}
				else
				{
					"[Add-GenericMessage] Error: Root Cause $RootCauseID cannot be converted to generic message as this rule does not have any item in ExtensionPoint node" | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
				}
			}
			else
			{
				"[Add-GenericMessage] Error: Root Cause $Id cannot be converted to generic message since its Resolver ID is not represented by a string GUID. Resolver ID: $GenericMessageGUID." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
			}
		}
		elseif ($debug -eq $true)
		{
			$MSG = New-Object PSObject
			$MSG | Add-Member -membertype noteproperty -name 'Id' -value $Id
			$MSG | Add-Member -membertype noteproperty -name 'SolutionTitle' -value $SolutionTitle
			$MSG | Add-Member -membertype noteproperty -name 'InternalContentURL' -value $InternalContentURL
			$MSG | Add-Member -membertype noteproperty -name 'PublicContentURL' -value $PublicContentURL
			$MSG | Add-Member -membertype noteproperty -name 'ProcessName' -value $ProcessName
			$MSG | Add-Member -membertype noteproperty -name 'Component' -value $Component
			$MSG | Add-Member -membertype noteproperty -name 'ModulePath' -value $ModulePath
			$MSG | Add-Member -membertype noteproperty -name 'Verbosity' -value $Verbosity
			$MSG | Add-Member -membertype noteproperty -name 'Fixed' -value $Fixed
			$MSG | Add-Member -membertype noteproperty -name 'Visibility' -value $Visibility
			$MSG | Add-Member -membertype noteproperty -name 'SupportTopicsID' -value $SupportTopicsID
			$MSG | Add-Member -membertype noteproperty -name 'Culture' -value $Culture
			$MSG | Add-Member -membertype noteproperty -name 'MessageVersion' -value $MessageVersion
			$MSG | Add-Member -membertype noteproperty -name '[SDP] SDPSectionDescription' -value $sectionDescription
			$MSG | Add-Member -membertype noteproperty -name '[SDP] SDPAdditionalInfo' -value $SDPAdditionalInfo
			$MSG | Add-Member -membertype noteproperty -name '[SDP] SDPFileReference' -value $SDPFileReference
			$MSG | Add-Member -membertype noteproperty -name 'InformationCollected' -value ($InformationCollected | fl | Out-String)
			$MSG | Add-Member -membertype noteproperty -name 'MessageContext' -value ($MessageContext | fl * | Out-String)
			"Add-GenericMessage called: " + ($MSG | fl | Out-String) | WriteTo-StdOut -DebugOnly -Color DarkYellow  -InvokeInfo $MyInvocation
		}
		else
		{
			"[Add-GenericMessage] Error: Root Cause $RootCauseID could not be found. Generic Message did not get generated. " | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
		}
	}
	else
	{
		"[Add-GenericMessage] Error: Blank RootCauseID. Generic Message did not get generated." | WriteTo-ErrorDebugReport -InvokeInfo $MyInvocation
	}
}

Function Consume-GenericMessages()
{
	Write-DiagProgress -Activity $UtilsCTSStrings.ID_ProcessingRC -Status $UtilsCTSStrings.ID_ProcessingRCDesc
	
	$UpdateDiagReportXMLFilePath = "..\GenericMessageUpdateDiagReport.xml"

	if (Test-Path $UpdateDiagReportXMLFilePath) 
	{
		[xml] $xmlUpdateDiagReport = Get-Content $UpdateDiagReportXMLFilePath
		[xml] $DiagPackageXML = Get-Content -Path (Join-Path $PWD.Path "DiagPackage.diagpkg")
		
		$RootCauseProcessed = $false
		$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)

		"Generating Generic Message Information. Script Name: $ScriptName" | WriteTo-StdOut -ShortFormat

		#Root causes are processed in order specified on DiagPackage.diagpkg
		#Navigate though DiagPackage.diagpkg and find the root causes on which the script name is the name of the actual script.
		foreach ($RootCauseElement in $DiagPackageXML.SelectNodes("//Rootcause[Resolvers/Resolver/Script[translate(FileName, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')=`'" + $ScriptName.ToLower() + "`']]"))
		{
			$RootCauseID = $RootCauseElement.ID
			$RootCauseFixed = $null
			
			#Next step is look at the RootCauseArguments if the root cause was not yet processed
			if (-not $RootCauseProcessed)
			{
				foreach ($RootCauseDetectedGenericMessage in $xmlUpdateDiagReport.SelectNodes("/Root/RootCauseDetected[@RootCauseID = `'" + $RootCauseID + "`']"))
				{
					#If Root cause was not yet processed - a script processes only one root cause.
					if (($RootCauseDetectedGenericMessage.Processed -eq "False") -and ($RootCauseDetectedGenericMessage.RootCauseID -eq $RootCauseID))
					{
						"                                        Processing Root Cause: $RootCauseID" | WriteTo-StdOut -ShortFormat

						[xml] $RootCauseDetectedGenericMessage.get_InnerXml() | update-diagreport -id ("Msg_" + (Get-Random)) -name $RootCauseDetectedGenericMessage.sectionDescription -verbosity $RootCauseDetectedGenericMessage.Verbosity
						
						$RootCauseDetectedGenericMessage.SetAttribute("Processed", "True")
						$RootCauseProcessed = $true
						
						if ($RootCauseDetectedGenericMessage.Fixed -ne $null)
						{
							$RootCauseFixed = [Boolean] $RootCauseDetectedGenericMessage.Fixed
						}
					}
				}
				
				if ($RootCauseProcessed)
				{
					#Add the 'More Information' section with plug-in message information
					$PluginMessageNode = $xmlUpdateDiagReport.SelectSingleNode("/Root/PlugInMessage[@RootCauseID = `'" + $RootCauseID + "`']")
					if ($PluginMessageNode -ne $null)
					{
						[xml] $PluginMessageNode.get_InnerXml() | update-diagreport -id ("zzMsg_" + (Get-Random)) -name "More Information" -verbosity "Informational"
					}
				}
			}
			
			if ($RootCauseFixed -ne $null)
			{
				## A root cause was defined to 'Fixed' or 'Not Fixed'
				## In this case, confirm if the root cause has a verifier
				
				if ($RootCauseElement.Verifier.Script -eq $null)
				{
					"[Consume-GenericMessages] Error: Root Cause $RootCauseID was set to " + $RootCauseFixed + " but state will be ignored because the root cause does not have a resolver script." | WriteTo-StdOut -ShortFormat
				}
			}
			
		}
		$xmlUpdateDiagReport.Save($UpdateDiagReportXMLFilePath)
	}
	else
	{
		"[Consume-GenericMessage] Error: $UpdateDiagReportXMLFilePath could not be found. Message not processed" | WriteTo-StdOut -ShortFormat
	}
}

Function Verify-GenericMessagesRootCauses
{
	Write-DiagProgress -Activity $UtilsCTSStrings.ID_ProcessingRC -Status $UtilsCTSStrings.ID_ProcessingRCDesc
	
	$UpdateDiagReportXMLFilePath = "..\GenericMessageUpdateDiagReport.xml"

	if (Test-Path $UpdateDiagReportXMLFilePath)
	{
		[xml] $xmlUpdateDiagReport = Get-Content $UpdateDiagReportXMLFilePath
		[xml] $DiagPackageXML = Get-Content -Path (Join-Path $PWD.Path "DiagPackage.diagpkg")
		
		$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
		$RootCauseProcessed = $false

		#Root causes are processed in order specified on DiagPackage.diagpkg
		#Navigate though DiagPackage.diagpkg and find the root causes on which the script name is the name of the actual script.
		foreach ($RootCauseElement in $DiagPackageXML.SelectNodes("//Rootcause[Verifier/Script[translate(FileName, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')=`'" + $ScriptName.ToLower() + "`']]"))
		{
			$RootCauseID = $RootCauseElement.ID
			$RootCauseFixed = $null
			
			
			#Next step is look at the RootCauseArguments if the root cause was not yet processed
			foreach ($RootCauseDetectedGenericMessage in $xmlUpdateDiagReport.SelectNodes("/Root/RootCauseDetected[@RootCauseID = `'" + $RootCauseID + "`']"))
			{
			
				if ($RootCauseDetectedGenericMessage.Processed -eq $false)
				{
					# This mean that the resolver did not run. In this case, set Detected = $true, otherwise the rsolver it will be skipped
					Update-DiagRootCause -Id $RootCauseID -Detected $true
					return
				}
				
				if ($RootCauseDetectedGenericMessage.Fixed -ne $null)
				{
					$RootCauseFixed = [Boolean] ($RootCauseDetectedGenericMessage.Fixed -eq "True")
				}
			}
			
			if ($RootCauseFixed -ne $null)
			{
				"[Verify-GenericMessagesRootCauses] $RootCauseID was set to Detected = " + (-not $RootCauseFixed) | WriteTo-StdOut -ShortFormat
				Update-DiagRootCause -Id $RootCauseID -Detected (-not $RootCauseFixed)
			}			
		}
	}
	else
	{
		"[Verify-GenericMessagesRootCauses] Error: $UpdateDiagReportXMLFilePath could not be found. Message not processed" | WriteTo-StdOut -ShortFormat
	}
}

Function Queue-EventLogAlert
{
	PARAM($EventLogName = $null, $EventLogId = $null, $EventLogSource = $null, [int] $NumberOfDays = 7, $AlertSectionName = 'Event Log Alert', $AlertAdditionalInformation = $null, [switch] $GenerateRootCause)
	
	if (($EventLogName -eq $null) -or ($EventLogId -eq $null) -or ($EventLogSource -eq $null))
	{
		"[Queue-EventLogAlert] ERROR: One of the required arguments to Queue-EventLogAlert is missing: EventLogName = [$EventLogName], EventLogId = [$EventLogId], EventLogSource = [$EventLogSource]" | WriteTo-StdOut -ShortFormat -InvokeInfo $MyInvocation -IsError
		return 
	}
	
	if ($Global:EventLogAdvisorAlertXML -eq $null)
	{
		[xml] $Global:EventLogAdvisorAlertXML = '<Alerts/>'
	}
		
	$SectionElement = $Global:EventLogAdvisorAlertXML.SelectSingleNode("/Alerts/Section[SectionName = `'$AlertSectionName`']")
	
	if ($SectionElement -eq $null)
	{
		$SectionElement = $Global:EventLogAdvisorAlertXML.CreateElement("Section")
		
		$X = $Global:EventLogAdvisorAlertXML.SelectSingleNode('Alerts').AppendChild($SectionElement)
		$SectionNameElement = $Global:EventLogAdvisorAlertXML.CreateElement("SectionName")
		$X = $SectionNameElement.set_InnerText($AlertSectionName)
		
		$X = $SectionElement.AppendChild($SectionNameElement)
		
		$SectionPriorityElement = $Global:EventLogAdvisorAlertXML.CreateElement("SectionPriority")
		$X = $SectionPriorityElement.set_InnerText(30)
		$X = $SectionElement.AppendChild($SectionPriorityElement)
	}
	
	$SectionAlertElement = $Global:EventLogAdvisorAlertXML.SelectSingleNode("/Alerts/Section[Alert[(EventLog = `'$EventLogName`') and (Source = `'$EventLogSource`') and (ID = `'$EventLogId`')]]")
	if ($SectionAlertElement -eq $null)
	{
		$AlertElement = $Global:EventLogAdvisorAlertXML.CreateElement("Alert")
		$X = $SectionElement.AppendChild($AlertElement)
		
		$AlertElement.Set_InnerXML("<EventLog>$EventLogName</EventLog><Days>$NumberOfDays</Days><Source>$EventLogSource</Source><ID>$EventLogId</ID><AdditionalInformation />")
		if ($AlertAdditionalInformation -ne $null)
		{
			$AlertElement.AdditionalInformation = $AlertAdditionalInformation
		}
		
		if ($GenerateRootCause.IsPresent -eq $false)
		{
			$SkipRootCauseDetectionElement = $Global:EventLogAdvisorAlertXML.CreateElement("SkipRootCauseDetection")
			$X = $SkipRootCauseDetectionElement.Set_InnerText('true')
			$X = $AlertElement.AppendChild($SkipRootCauseDetectionElement)
		}
		
		"[Queue-EventLogAlert] Queuing Event Log Alert for Event log [$EventLogName], Event ID [$EventLogId], Source [$EventLogSource]. GenerateRootCause = " + ($GenerateRootCause.IsPresent) | WriteTo-StdOut -ShortFormat
	}
	else
	{
		if (-not [string]::IsNullOrEmpty($MyInvocation.ScriptName))
		{
			$ScriptName =  (Split-Path $MyInvocation.ScriptName -Leaf) + " "
		}
		"[Queue-EventLogAlert] WARNING: An alert for event log [$EventLogName], Event ID [$EventLogId], Source [$EventLogSource] is already queued. Request from script $ScriptName will be ignored." | WriteTo-StdOut -ShortFormat
	}
}

Function Convert-PSObjectToHTMLTable
{
	Param ($PSObject,[switch] $FistMemberIsHeader)
	
	if ($PSObject -eq $null) {$PSObject=$_}
	
	$HeaderIncluded = $false
	foreach($p in $PSObject.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
	{
		$Name  = $p.Name
		$Value = $p.Value
		if (($FistMemberIsHeader.IsPresent) -and ($HeaderIncluded -eq $false))
		{
			$TableString += "`t<tr><th>$Name</th><th>$Value</th></tr>`r`n"
			$HeaderIncluded = $true
		}
		else
		{
			$TableString += "`t<tr><td>$Name</td><td>$Value</td></tr>`r`n"
		}
	}
	
	return ("<table>`r`n" + $TableString + "</table>")
}

#ConvertTo-Xml2 function
#-------------------------
#  This function is a replacement from ConvertTo-Xml.
#  ConvertTo-Xml replaces HTML tags inside strings limiting the richness of the resulting data
#  For instance, when using ConvertTo-Xml against a string like <b>Text</b>, results on the following:
#  &lt;b&gt;Text&lt;/b&gt;
#  the ConvertTo-Xml2 is our light implementation for ConvertTo-Xml that do not make string conversion.
filter ConvertTo-Xml2
{Param ($object, [switch]$sortObject, [int] $Visibility = 4)

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[ConvertTo-Xml2]" -InvokeInfo $MyInvocation
		$Error.Clear()
		continue
	}

	if ($object -eq $null) {$object=$_}
	
	$typeName = $object.GetType().FullName
	
	if (($Visibility -ge 0) -and ($Visibility -le 3))
	{
		$VisibilityString = 'Visibility="' + $Visibility + '"'
	}
	else
	{
		$VisibilityString = ''
	}
	$XMLString = "<?xml version=`"1.0`"?><Objects $VisibilityString><Object Type=`"$typeName`">" 

	if ((($object.GetType().Name -eq "PSObject") -or ($object.GetType().Name -eq "PSCustomObject")) -and (-not $sortObject.IsPresent) ) 
	{
		foreach($p in $object.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
		{
			$Name  = $p.Name
			$Value = $p.Value    
			$XMLString += "`t<Property Name=`"$Name`">$Value</Property>`r`n"
		}
	} 
	elseif ($object -is [System.String])
	{
		$XMLString += $object
	}
	else
	{
		foreach ($p in $object |Get-Member -type *Property)
		{
			$Name  = $p.Name
			$Value = $Object.$Name    
			$XMLString += "`t<Property Name=`"$Name`">$Value</Property>`r`n"
		}
	}
	$XMLString += "</Object></Objects>"

	[xml] $XMLString
}

#ConvertTo-Xml10 function
#-------------------------
#  This function is a replacement from ConvertTo-Xml for PowerShell 1.0.
filter ConvertTo-Xml10
{Param ($object, [switch]$sortObject)

	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[ConvertTo-Xml10]" -InvokeInfo $MyInvocation
		$Error.Clear()
		continue
	}
	
	if ($object -eq $null) {$object=$_}
	$typeName = $object.PSObject.TypeNames[0]
	$XMLString = "<?xml version=`"1.0`"?><Objects><Object Type=`"$typeName`">" 

	if ((($object.GetType().Name -eq "PSObject") -or ($object.GetType().Name -eq "PSCustomObject")) -and (-not $sortObject.IsPresent) ) 
	{
		foreach($p in $object.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
		{
			$Name  = (Replace-XMLChars $p.Name)
			$Value = (Replace-XMLChars $p.Value)
			$XMLString += "`t<Property Name=`"$Name`">$Value</Property>`r`n"
		}
	} else {
		foreach ($p in $object |Get-Member -type *Property)
		{
			$Name  = (Replace-XMLChars $p.Name)
			$Value = (Replace-XMLChars $Object.$Name)
			$XMLString += "`t<Property Name=`"$Name`">$Value</Property>`r`n"
		}
	}
	$XMLString += "</Object></Objects>"
	[xml] $XMLString
}

#***** Variables below are used internally. Do not use these variables in scripts:
$StdOutFileName = Join-Path -Path ($PWD.Path) -ChildPath "..\stdout.log"

$ScriptExecutionInfo_Summary = New-Object PSObject
$DiagProcesses=New-Object System.Collections.ArrayList
$DiagProcessesFileDescription=@{}
$DiagProcessesSectionDescription=@{}
$DiagProcessesFilesToCollect=@{}
$DiagProcessesVerbosity=@{}
$DiagProcessesAddFileExtension=@{}
$DiagProcessesBGProcessTimeout=@{}
$DiagProcessesRenameOutput=@{}
$DiagProcessesScriptblocks=@{}
$DiagProcessesSkipMaxParallelDiagCheck=@{}
$DiagProcessesSessionNames=@{}
$global:DiagCachedCredentials=@{}

$MaxParallelDiagProcesses=$null

$OSArchitecture = Get-ComputerArchitecture

Function WriteScriptExecutionInformation
{
	if ($ScriptExecutionInfo_Summary -ne $null) {
		$ScriptExecutionInfo_Summary | ConvertTo-Xml | update-diagreport -id ExecutionInformation -name ($ComputerName + " - Execution Time Information") -verbosity Debug
	}
}

Filter Get-Random10() #Create Replacement for Get-Random - since it does not exist on PowerShell 1.0
{
	$X = new-object System.Random
	$X.Next()
}

#Create Replacement for Select-XML - since it does not exist on PowerShell 1.0
function Select-Xml10{
          param([String[]]$Content,
          [string]$Xpath,
          [string[]]$Path,
          [System.Xml.XmlNode[]]$Xml,
          [hashtable]$Namespace)
          
		  $Error.Clear() > $null
          trap [Exception] 
          {
                 $errorMessage = $Error[0].Exception.Message
                 "Error running Select-Xml: $errorMessage" | WriteTo-StdOut
                 $Error[0].InvocationInfo | fl | out-string | WriteTo-StdOut
                 $Error.Clear() > $null
          }


          if(($Namespace -ne $null) -and ($Namespace.Count -gt 0))
          {
                 $nsm = New-Object System.Xml.XmlNamespaceManager -ArgumentList (New-Object Xml.NameTable)
                 foreach($ns in $Namespace.Keys)
                      {
                                      $nsm.AddNamespace($ns,$Namespace[$ns]) > $null
                 }
          }

          $nodestosearch = @()

          if($Content -ne $null)
          {
                 foreach($strContent in $Content)
                      {
                 $xdoc = New-Object System.Xml.XmlDocument
                 $xdoc.LoadXml($Content) > $null
                 $nodestosearch += $xdoc
                 }
          }
          elseif($Xml -ne $null)
          {
                 $nodestosearch+= $Xml
          }
          elseif($Path -ne $null)
          {
		  	foreach($pth in $Path)
			{
				$files = Get-Item -Path $pth
				foreach($fl in $files){
                 if((Test-Path ($fl.FullName)) -eq $true)
                 {
                       $xdoc = New-Object System.Xml.XmlDocument
                       $xdoc.Load($fl.FullName) > $null
                       $nodestosearch += $xdoc
                 }
				}
			}
          }

          foreach($nodexml in $nodestosearch)
          {
                 if($nodexml -eq $null) {continue}

                 if($nsm -ne $null)
                 {
                                      $returnNodes = $nodexml.SelectNodes($Xpath,$nsm)
                 }
                 else
                 {
                      $returnNodes = $nodexml.SelectNodes($Xpath)
                 }
                      $results = @()         
                 foreach($retNode in $returnNodes){
                                $result = New-Object SelectXmlInfo
                          $result.Pattern = $xpath
                          $result.Path = $retNode.BaseURI
                          $result.Node = $retNode
                                $results+=$result
                      }
                 $results
          }
}

#***** 

#Replacement for Checkpoint-Computer since it doesn't exist on PS 1.0.
#Parameters:
#	Description: 		<string> 	a descriptive label for the checkpoint
#	RestorePointType: 	<string> 	one of the values APPLICATION_INSTALL, APPLICATION_UNINSTALL, DEVICE_DRIVER_INSTALL,
#									MODIFY_SETTINGS, or CANCELLED_OPERATION.

Function Checkpoint-Computer10
{
	param([string]$Description = "My Restore Point",[string]$RestorePointType = "APPLICATION_INSTALL")
	
	$restorePointTypes = `
	@{
		"APPLICATION_INSTALL" 				= [UInt32]0;
		"APPLICATION_UNINSTALL" 			= [UInt32]1;
		"DEVICE_DRIVER_INSTALL"			 	= [UInt32]10;
		"MODIFY_SETTINGS"					= [UInt32]12;
		"CANCELLED_OPERATION"			 	= [UInt32]13;
	}
	
	$restorePointTypeValue = [UInt32]0;
	if($restorePointTypes.ContainsKey($RestorePointType))
	{
		$restorePointTypeValue = $restorePointTypes[$RestorePointType]
	}
	
	[System.Management.ManagementScope] $oScope = new-object System.Management.ManagementScope '\\localhost\root\default';
	[System.Management.ManagementPath] $oPath = New-Object System.Management.ManagementPath "SystemRestore";
	[System.Management.ObjectGetOptions] $oGetOp = New-Object System.Management.ObjectGetOptions;
	[System.Management.ManagementClass] $oProcess = New-Object System.Management.ManagementClass($oScope,$oPath,$oGetOp);
	[System.Management.ManagementBaseObject] $oOutParams = $oProcess.CreateRestorePoint($Description,$restorePointTypeValue,100)
	("System Restore completed with return code: {0}" -f $oOutPrams.ReturnValue) | WriteTo-StdOut -DebugOnly
}

Set-Alias -Name Trace -Value WriteTo-StdOut 
Set-Alias -Name Output-Trace -Value WriteTo-StdOut

if ($Host.Version.Major -lt 2) 
{
	#Running PowerShell 1.0
	New-Alias ConvertTo-Xml ConvertTo-Xml10
	New-Alias Get-Random Get-Random10
	New-Alias Import-LocalizedData Import-LocalizedData10
	New-Alias Add-Type Add-Type10
	New-Alias Checkpoint-Computer Checkpoint-Computer10
 	New-Alias -Name "Select-Xml" -Value "Select-Xml10"
	New-Alias -Name "Run-DiagExpression" -Value "Run-DiagExpression10"
	
	$SelectXmlInfoType = @"
	       using System;
	       using System.Xml;
	       public class SelectXmlInfo{
	                 public XmlNode Node;
	                 public string Path;
	                 public string Pattern;
	       }
"@
    Add-Type -ReferencedAssemblies ("System.Xml.dll") -TypeDefinition $SelectXmlInfoType
}

#if (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 0))
#{
#	#Replace stdout.log to stdout-wtp.log so it won't conflict with SDP 2.x stdout.log file
#	$StdOutFileName = Join-Path -Path ($PWD.Path) -ChildPath "..\stdout-wtp.log"
#}

if (($IsRunningUnderWTP) -or ((Get-TSRemote) -ne 0))
{
	Import-LocalizedData -BindingVariable UtilsCTSStrings
}
if ((Test-Path '.\TSRemoteProcessRootCauses.txt') -and (Test-Path '.\utils_Remote.ps1'))
{
	#When running inside TS_Remote, check for a file called TSRemoteProcessRootCauses.txt.
	#If this file exists, it means that machine is processing root causes. In this case, automatically load utils_remote.ps1
	"Auto-loading Utils_Remote.ps1" | WriteTo-StdOut -ShortFormat
	. ./utils_Remote.ps1	
}

#Obtain file version information for files located under Windows folder.
#For Windows Components the ProductVersion and FileVersion properties of a file Version Info is incorrect
#When the FileVersion does not start with the concatenated string({FileMajorPart}.{FileMinorPart}.{FileBuildPart}.{FilePrivatePart}), return the concatenated string
#Else return the FileVersion String
Function Get-FileVersionString(
	[string]$Path)
{
	trap [Exception] 
	{
		WriteTo-ErrorDebugReport -ErrorRecord $_ -ScriptErrorText "[Get-FileVersionString]An error occurred while getting version info on the file $Path"
		continue
	}
	if([System.IO.File]::Exists($Path))
	{
		$fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
		if($fileInfo -ne $null)
		{
			if(($fileInfo.FileMajorPart -ne 0) -or ($fileInfo.FileMinorPart -ne 0) -or ($fileInfo.FileBuildPart -ne 0) -or ($fileInfo.FilePrivatePart -ne 0))
			{
				$concatenatedVersion=$fileInfo.FileMajorPart.ToString() + '.' + $fileInfo.FileMinorPart.ToString() + '.' + $fileInfo.FileBuildPart.ToString() + '.' + $fileInfo.FilePrivatePart.ToString()
				if(($fileInfo.FileVersion -ne $null) -and ($fileInfo.FileVersion.StartsWith($concatenatedVersion)))
				{
					return $fileInfo.FileVersion
				}
				else
				{
					return $concatenatedVersion
				}
			}
			else
			{
				"[Get-FileVersionString] The file $Path is unavailable" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
			}
		}
		else
		{
			"[Get-FileVersionString] The file $Path is unavailable" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
		}
	}
	else
	{
		"[Get-FileVersionString] The file $Path does not exist" | WriteTo-StdOut -InvokeInfo $MyInvocation -ShortFormat
	}
}


# SIG # Begin signature block
# MIIa2wYJKoZIhvcNAQcCoIIazDCCGsgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+bBCLm+LxUv1dq29+Ajp6Nqf
# /66gghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBMMwggS/
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggdwwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFEd7
# 3h+oCbIRbye0c4v+4qknv9fOMHwGCisGAQQBgjcCAQwxbjBsoFKAUABDAFQAUwBf
# AE4AZQB0AHcAbwByAGsAaQBuAGcAXwBNAGEAaQBuAF8AZwBsAG8AYgBhAGwAXwB1
# AHQAaQBsAHMAXwBDAFQAUwAuAHAAcwAxoRaAFGh0dHA6Ly9taWNyb3NvZnQuY29t
# MA0GCSqGSIb3DQEBAQUABIIBAIfovK77fnfzuOILLhtCRg9me17k58V8GcAxD/qq
# 7FmrXF8zfkwmjDG3YU9AFfPLSY4k6BB8a4ejlHqw5lJ+Lur+OV2ITLTJ5G+94SCs
# iYDb+74DYU3zkoZOSI4hELYbPYdB8Oe65qCRccXDzOUGdRHKfJVmR7uScqET6b/U
# DU08ehekZb2dq4+QX+Lj2mJVSgW44De8yfDVh/ObFIQODaDzhh24EE0qB18o9MUP
# L2P/psZUNVBEiU7i0WaWhfBzGFpsWEGe4dUkhiKzPRS7hnqzQJ4PbejqxeVJ4HQo
# Ys+3ipmC2wZBAnZSKl1zgTx1cHecJib06gauU56MiUDNB72hggIoMIICJAYJKoZI
# hvcNAQkGMYICFTCCAhECAQEwgY4wdzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBAhMz
# AAAATKHoTcy0dHs7AAAAAABMMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNDEwMjAxODA4NDFaMCMGCSqGSIb3
# DQEJBDEWBBQKYMDDr921vfVOjxUl4X9oc13s8zANBgkqhkiG9w0BAQUFAASCAQA4
# VLL2XNLeDVhDRt8WP7BtQrgwEghp++JiqHBl+a/Lo07TqyeQm6eFGvfQcs54j1qx
# i+JutnP2XM7mpqKbi5BmzxT+3saoWVkoRnN61q9SvwQj5UEiV/OtklqZtCGo8KFi
# dLJDlpXlX/oZuydujVr160aOnMiamsVFTlcBA4ykdVuIHAx23clQyif9+n8e0LBK
# t2htxGs3fXA+NV12AHXPl6R1RKnoWh4rplNbGWLa+xBMlELg/qUR+/ju/kNnll1g
# JFVcwjfqPT/e/5foiMhfblC3j3gyHyCPp6J+xTutHdyrAHP7JERyNsfwvsahQLOI
# KxK6CE4vCQFwQU1JlH84
# SIG # End signature block
