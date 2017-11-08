PARAM ($WorkingPath = $PWD.Path, $SchemaXMLPath = 'ConfigXPLSchema.xml')

## Initializing Variables

$ComputerName = $Env:COMPUTERNAME
[xml] $SchemaXML = $null

$DiscoveryReportXMLPath = Join-Path $WorkingPath ($ComputerName + '_DiscoveryReport.xml')

$StatusXMLPath =  Join-Path $WorkingPath ($ComputerName + '_DiscoveryStatus.xml')

$DebugLogXMLPath =  Join-Path $WorkingPath ($ComputerName + '_DiscoveryDebugLog.xml')
[XML] $DebugLogXML = "<root/>"

$CXPExecutionLog = Join-Path $WorkingPath ($ComputerName + '_DiscoveryExecutionLog.log')

$DiscoveryExecution_Summary = New-Object PSObject

$DiscoveryScriptContents = ''

$script:GlobalDataTypes = $null
$script:GlobalGenericDataTypes = $null


#####################
# General Functions #
#####################

#Log Exceptions to Debug Report XML
Filter Log-CXPWriteLine
{
	param (
		$InputObject,
		[switch]$IsError,
		[switch]$IsWarning,
		[switch]$Debug,
		[System.Management.Automation.InvocationInfo] $InvokeInfo = $MyInvocation
		)
	BEGIN
	{
		$WhatToWrite = @()
		if ($InputObject -ne  $null)
		{
			$WhatToWrite  += $InputObject
		} 
		
		if((($Debug) -and ($Host.Name -ne "Default Host") -and ($Host.Name -ne "Default MSH Host")) -or ($Host.Name -eq 'PowerGUIScriptEditorHost') -or ($Host.Name -like '*PowerShell*'))
		{
			if($Color -eq $null)
			{
				$Color = [ConsoleColor]::Gray
			}
			elseif($Color -isnot [ConsoleColor])
			{
				$Color = [Enum]::Parse([ConsoleColor],$Color)
			}
			if ($IsWarning.IsPresent)
			{
				$BackGroundColor = [ConsoleColor]::DarkYellow
			}
			$scriptName = [System.IO.Path]::GetFileName($InvokeInfo.ScriptName)
		}
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
				$WhatToWrite = "(Object not correctly formatted. The object of type Microsoft.PowerShell.Commands.Internal.Format.FormatEntryData is not valid or not in the correct sequence)"
			}
		}
	}
	END
	{
		$separator = "`r`n"
		$WhatToWrite = [string]::Join($separator,$WhatToWrite)
		
		while($WhatToWrite.EndsWith("`r`n"))
		{
			$WhatToWrite = $WhatToWrite.Substring(0,$WhatToWrite.Length-2)
		}
		
		if ($Warning.IsPresent)
		{
			$WhatToWrite = "[Warning] $WhatToWrite"
		}
		
		if((($Host.Name -ne "Default Host") -and ($Host.Name -ne "Default MSH Host")) -or ($Host.Name -eq 'PowerGUIScriptEditorHost'))
		{
			$output = "[$([DateTime]::Now.ToString(`"s`"))] [$($scriptName):$($MyInvocation.ScriptLineNumber)]: $WhatToWrite"

			if($IsError.Ispresent)
			{
				$Host.UI.WriteErrorLine($output)
			}
			else
			{
			
				If (($BackgroundColor -ne $null) -and ($Color -ne $null))
				{
					$output | Write-Host -ForegroundColor $Color -BackgroundColor $BackgroundColor
				}
				elseif ($Color -ne $null)
				{
					$output | Write-Host -ForegroundColor $Color
				}
				else
				{
					$output | Write-Host 
				}
			}
		}
		else
		{
             "[ConfigXPL] [" + (Get-Date -Format "T") + " " + $ComputerName + " - " + [System.IO.Path]::GetFileName($InvokeInfo.ScriptName) + " - " + $InvokeInfo.ScriptLineNumber.ToString().PadLeft(4) + "] $WhatToWrite" | Out-File -FilePath $CXPExecutionLog -append -ErrorAction SilentlyContinue 
		}
	}
}


Filter Log-CXPWriteXML
(
	[XML] $XML,
	[string] $Id,
	[string] $Name,
	[string] $Verbosity = "Debug"
)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Log-CXPWriteXML]" -InvokeInfo $MyInvocation
		$Error.Clear()
		return
	}


	if ($XML -eq $null) {$XML = $_}
	
	if ($XML -eq $null) 
	{
		throw ('XML argument is empty or null')
	}
	
	if (([string]::IsNullOrEmpty($Id)) -or ([string]::IsNullOrEmpty($Name)))
	{
		throw ('Either $Id or $Name are empty. XML entry will not be logged to report: ' + $XML.get_OuterXml())
	}
	
	[System.Xml.XmlElement] $XMLElement = $DebugLogXML.CreateElement("Detail")
	
	$XMLElement.SetAttribute("id", $Id)
	$XMLElement.SetAttribute("name", $Name)
	$XMLElement.SetAttribute("verbosity", $Verbosity)
	
	$XMLElement.set_InnerXml($XML.get_DocumentElement().get_OuterXml())
	
	$x = $DebugLogXML.DocumentElement.AppendChild($XMLElement)
	$DebugLogXML.Save($DebugLogXMLPath)
}

#Log Exceptions to Debug Report XML
Filter Log-CXPException
(
	[string] $ScriptErrorText, 
	[System.Management.Automation.ErrorRecord] $ErrorRecord = $null,
	[System.Management.Automation.InvocationInfo] $InvokeInfo = $null
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
		
		"[Log-CXPException] Error: " + $_.Exception.Message + " [" + $Line + "].`r`n" + $_.StackTrace | Log-CXPWriteLine
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
	
	$Error_Summary | ConvertTo-Xml | Log-CXPWriteXML -id ("ScriptError_" + (Get-Random)) -name "Script Error $ScriptDisplay" -verbosity "Debug"
	"[Log-CXPException] An error was logged to Debug Report: " + [string]::Join(" / ", $Error_Summary_TXT) | Log-CXPWriteLine -InvokeInfo $InvokeInfo -IsError
	$Error_Summary | fl * | Out-String | Log-CXPWriteLine -Debug -IsError -InvokeInfo $InvokeInfo
}

#Write Execution Status to Status XML
Filter Set-CXPExecutionStatus
{
	param ($InputObject,
	[switch] $IsWarning,
	[switch] $IsError)
	
	if ($InputObject -eq $null) { $InputObject=$_ }
	if ($IsWarning.IsPresent) 
	{
		$StatusType = "Warning"
	}
	elseif ($IsError.IsPresent)
	{
		$StatusType = "Error"
	}
	else
	{
		$StatusType = "Informational"
	}
	
	[XML] $StatusXML = 	"<root>" + 
						"<StatusMessage>$InputObject</StatusMessage>" + 
						"<StatusType>$StatusType</StatusType>" + 
						"<Time>" + (Get-Date).ToFileTime() +  "</Time>"+
						"</root>"
	
	"Status: [$StatusType] $InputObject" | Log-CXPWriteLine -InvokeInfo $MyInvocation
	
	$StatusXML.Save($StatusXMLPath)
}

Function OpenSchemaXML($SchemaXMLPath)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[OpenSchemaXML] Path = $SchemaXMLPath"
		return $false
	}
	
	if (Test-Path $SchemaXMLPath)
	{
		[xml] $script:SchemaXML = Get-Content $SchemaXMLPath
		$script:GlobalDataTypes = $script:SchemaXML.SelectSingleNode('/Schema/SystemObjects/DataTypes')
		$script:GlobalGenericDataTypes = $script:SchemaXML.SelectSingleNode('/Schema/SystemObjects/GenericDataTypes')
		return $true
	}
	else
	{
		"File Not Found: $SchemaXMLPath" | Log-CXPWriteLine -IsError
		return $false
	}
}

Function Get-RootDiscoverySet
{
	return $SchemaXML.Schema.Root.Trim()
}

Function Get-DiscoverySetLinks([string] $DiscoverSetGuid)
{
	return ($SchemaXML.SelectNodes("/Schema/DiscoverySet[@Guid='$DiscoverSetGuid']/Entities/Entity[@Type='Section']/DiscoverySetLink") | % {$_.Guid})
}


Function Check-FunctionExist ($FunctionName, [ref] $ScriptContents)
{
	if ($ScriptContents.Value -match "Function $FunctionName")
	{
		return $true
	}
	else
	{
		"[Check-FunctionExist] Discovery function $FunctionName could not be found" | Log-CXPWriteLine -IsError
		$ScriptFunction = $null
	}
}

Function Get-ChildEntityNodes ([string] $GUID, [ref] $DiscoverySetNode)
{
	$ChildEntities = @()
	Foreach ($EntityNode in ($DiscoverySetNode.Value).SelectNodes("Entities/Entity[(@Parent = `'$GUID`')]"))
	{
		#If Entity is a Section, look at the child of the section instead
		if ($EntityNode.Type -eq 'Section')
		{
			$ChildEntities += Get-ChildEntityNodes -GUID $EntityNode.Guid -DiscoverySetNode ($DiscoverySetNode)
		}
		else
		{
			$ChildEntities += $EntityNode
		}
	}
	return $ChildEntities
}

Function Get-EntityNode ([ref] $DiscoverySetNode, [string] $EntityGuid)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-EntityNode]"
		return $null
	}
	
	$DiscoverySetNodeValue = $DiscoverySetNode.Value
	if ($DiscoverySetNodeValue -is [System.Xml.XmlLinkedNode])
	{
		return $DiscoverySetNodeValue.SelectSingleNode("Entities/Entity[@Guid = '$EntityGuid']")
	}
	else
	{
		"Unknown type of DiscoverySetNode: " + $DiscoverySetNode.GetType().Name | Log-CXPWriteLine -IsError
		return $null
	}
}

Function Get-GenericTypeNode([string] $GenericTypeName)
{
	 $SchemaXML.SelectSingleNode("Schema/SystemObjects/GenericDataTypes/GenericDataType[@Name = '$GenericTypeName']")
}

Function Validate-GenericTypeArguments ([string] $GenericType, $EntityGenericTypeInputArguments, $EntityNode)
{
	$GenericTypeNode = Get-GenericTypeNode -GenericTypeName $GenericType
	if ($GenericTypeNode -ne $null)
	{
		#If GenericClass has a functionName, then always return $true as the arguments will be built at run time
		if ($EntityNode.FunctionName -eq $null)
		{
			ForEach ($RequiredArgument in $GenericTypeNode.GenericDataTypeInputArguments.Argument |  Where-Object {$_.Required -eq "true"})
			{
				if (($EntityGenericTypeInputArguments.GenericTypeInputArgumentValue | foreach {$_.Name}) -notcontains $RequiredArgument.Name)
				{
					"There is a Required Argument for $GenericType that is missing: " + $RequiredArgument.Name | Log-CXPWriteLine -IsError
					return $false
				}
			}
		}
		return $true
	}
	else
	{
		"Unable to find GenericType $GenericType" | Log-CXPWriteLine -IsError
		return $false
	}
}

Function Get-GenericTypeFunctionName ([string] $GenericType)
{
	$GenericTypeNode = Get-GenericTypeNode -GenericTypeName $GenericType
	if ($GenericTypeNode -ne $null)
	{
		return $GenericTypeNode.FunctionName
	}
	else
	{
		"Unable to find GenericType $GenericType" | Log-CXPWriteLine -IsError
		return $null
	}
}

Function Convert-PSObjectToHashTable([PSObject] $PSObject)
{
	$HT = @{}
	foreach($p in $ExecutionResults.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
	{
		$HT += {$p.Name = $p.Value}
	}
	return $HT 
}

Function Run-GenericClassGetArguments($EntityName, $FunctionName, [Hashtable] $ArgumentList = @{})
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Run-GenericClassGetArguments] Expression: $($MyInvocation.Line)"
		continue
	}
	
	$Error.Clear()
	
	if (-not [string]::IsNullOrEmpty($FunctionName))
	{
		"[Run-GenericClassGetArguments]: Obtaining GenericClass arguments for [$EntityName] via GetArguments function $FunctionName" | Log-CXPWriteLine
		
		$ScriptTimeStarted = Get-Date
		
		$ExecutionResults = Invoke-Expression $FunctionName

		$TimeToRun = (New-TimeSpan $ScriptTimeStarted)
				
		"[Run-GenericClassGetArguments]: Finished GetArguments for [$EntityName]" | Log-CXPWriteLine

		if ($TimeToRun.Seconds -gt 3)
		{
			"$FunctionName took " + $TimeToRun.Seconds + " seconds to complete" | Log-CXPWriteLine -IsWarning
		}
		
		
		if ($ExecutionResults -is [HashTable])
		{
			$ReturnObject = $ExecutionResults
		}
		elseif ($ExecutionResults -is [PSObject])
		{
			$ReturnObject = (Convert-PSObjectToHashTable $ExecutionResults)
		}
		elseif (($ExecutionResults -ne $null) -and ([string]::IsNullOrEmpty($ExecutionResults) -eq $false))
		{
			"$FunctionName returned a " + $ExecutionResults.GetType().FullName + " and the expected is a HashTable or PSObject. Return value will be ignored " | Log-CXPWriteLine -IsError
			return $ArgumentList
		}
		else
		{
			return $ArgumentList
		}
		
		$ArgumentList.GetEnumerator() | ForEach-Object -Process {
			$Key = $_.Key
			if ($ReturnObject.ContainsKey($Key))
			{
				"[Run-GenericClassGetArguments] Argument $($Key) containing [$($_.Value)] is being overwritten to " + $ReturnObject.get_Item($Key) + " by GetArguments Function" | Log-CXPWriteLine
			}
			else
			{
				$ReturnObject += $_
			}
		}
		
		return $ReturnObject
	}
	else
	{
		"[Run-GenericClassGetArguments] [" + [System.IO.Path]::GetFileName($MyInvocation.ScriptName) + " - " + $MyInvocation.ScriptLineNumber.ToString() + '] - Error: a null expression was sent to Run-GenericClassGetArguments' | Log-CXPWriteLine -IsError
	}
}

Function Get-DiscoveryCommandLine($EntityType, $EntityName, $EntityFunctionName, $EntityGuid, [ref] $DiscoverySetNode, [ref] $DiscoveryScriptContents)
{
	$CommandLine = @()
	$InputArgumentsLine = @()
	$ResultsVariableName = $EntityName.replace(".", "").replace(" ","") + "Results"
	$EntityNode = Get-EntityNode -DiscoverySetNode $DiscoverySetNode -EntityGuid $EntityGuid
	$ArgumentCommandLine = ''

	if ($EntityType -eq 'GenericClass')
	{
		if ($EntityNode -ne $null)
		{
			$GenericType = $EntityNode.GenericType
			$GenericTypeInputArgumentsValues = $EntityNode.GenericTypeInputArgumentValues
			$GenericClassFunctionName = $EntityNode.FunctionName
		
			If (Validate-GenericTypeArguments -GenericType $GenericType -EntityGenericTypeInputArguments $GenericTypeInputArgumentsValues -EntityNode $EntityNode)
			{
				$GenericTypeFunctionName = Get-GenericTypeFunctionName -GenericType $GenericType
				$GetArgumentsFunctionName = ('$' + $GenericTypeFunctionName + 'ArgumentList').Replace('-','')
				
				$CommandLine += $GetArgumentsFunctionName + ' = @{}'
				
				foreach ($Argument in $GenericTypeInputArgumentsValues.GenericTypeInputArgumentValue)
				{
					$CommandLine += $GetArgumentsFunctionName + ' += @{"' + $Argument.Name + "`" = `'" + $Argument.Value + "`'}"
				}
				
				if ($GenericClassFunctionName -ne $null)
				{
					$CommandLine += $GetArgumentsFunctionName + ' = Run-GenericClassGetArguments -EntityName "' + $EntityNode.Name + '" -FunctionName "' + $GenericClassFunctionName + '" -ArgumentList ' + $GetArgumentsFunctionName
				}
				
				$ArgumentCommandLine += " -Entity `'" + $EntityGuid + "`' -DiscoverySet `'" + $DiscoverySetNode.Value.Guid + "`' -ArgumentList " + $GetArgumentsFunctionName
			}
			else
			{
				return
			}
		}
		else
		{
			"Unable to find GenericyClass: $EntityName [$EntityGuid]" | Log-CXPWriteLine -IsError
			return
		}
	}

	$CommandLine += ('$' + "$ResultsVariableName = Run-DiscoveryFunction $EntityFunctionName" + $ArgumentCommandLine)
	
	if ($ParentResultsID -ne $null)
	{
		$ParentCmdLine = ' -ParentID ' + $ParentResultsID
	}
	else
	{
		$ParentCmdLine = ''
	}
	
	$CommandLine += "Write-DiscoveryInfo -InputObject $" + $ResultsVariableName + " -DiscoverySet '" + $DiscoverySetNode.Value.Guid + "' -Entity '" + $EntityGuid + "'" + $ParentCmdLine
	
	[array] $ChildEntitites = Get-ChildEntityNodes -GUID $EntityGuid -DiscoverySetNode $DiscoverySetNode
	if ($ChildEntitites.Count -gt 0)
	{
		foreach ($ChildEntity in $ChildEntitites)
		{
			if ($ChildEntity -ne $null)
			{
				$EntityType = $ChildEntity.Type
				if ($EntityType -eq 'Class')
				{
					$EntityFunctionName = $ChildEntity.FunctionName
				}
				else
				{
					$EntityFunctionName = Get-GenericTypeFunctionName -GenericType $ChildEntity.GenericType
				}
				$CommandLine += Get-DiscoveryCommandLine -EntityType $EntityType -EntityName $ChildEntity.Name -EntityFunctionName $EntityFunctionName -EntityGuid $ChildEntity.Guid -DiscoverySetNode $DiscoverySetNode -DiscoveryScriptContents $DiscoveryScriptContents 
			}
		}
	}
	
	return $CommandLine
}

Function Get-DiscoverySetNode (
	[string] $DiscoverySetGuid
	)
{
	return $SchemaXML.SelectSingleNode("/Schema/DiscoverySet[@Guid='" + $DiscoverySetGuid + "']")
}

Function Get-CommandLineForEntity($EntityNode, $DiscoverySetNode)
{
	$EntityType = $EntityNode.Type
	if ($EntityType -eq 'Class')
	{
		$EntityFunctionName = $EntityNode.FunctionName
	}
	elseif ($EntityType -eq 'GenericClass')
	{
		$EntityFunctionName = Get-GenericTypeFunctionName -GenericType $EntityNode.GenericType
	}
	
	$EntityName = $EntityNode.Name
	$EntityGuid = $EntityNode.Guid
	
	if (($EntityType -ne 'Class') -or (Check-FunctionExist -FunctionName $EntityFunctionName -ScriptContents ([ref] $DiscoveryScriptContents)))
	{
		$CommandLine += Get-DiscoveryCommandLine -EntityType $EntityType -EntityName $EntityName -EntityFunctionName $EntityFunctionName -EntityGuid $EntityGuid -DiscoverySetNode ([ref] $DiscoverySetNode) -DiscoveryScriptContents ([ref] $DiscoveryScriptContents)
	}
	else
	{
		"[Build-DiscoveryScript] DiscoverySet [$DiscoverySetName] Function for Class [$EntityName] Not Found: " + $EntityFunctionName + ". Discovery will not be executed against this DiscoverySet" | Log-CXPWriteLine -IsError
	}
	return $CommandLine
}

Function Get-AllSectionChildNodes ($DiscoverySetNode, $SectionGuid)
{
	$ChildNodes = @()
	Foreach ($EntityChildNode in (Get-ChildEntityNodes -DiscoverySetNode ([ref] $DiscoverySetNode) -GUID $SectionGuid))
	{
		if ($EntityChildNode.Type -eq 'Section')
		{
			$ChildNodes += Get-AllSectionChildNodes $DiscoverySetNode $SectionGuid
		}
		else
		{
			$ChildNodes += $EntityChildNode
		}
	}
	return $ChildNodes
}

Function Build-DiscoveryScript ($DiscoverySetGuid)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Build-DiscoveryScript]"
		return $false
	}
	
	"Preparing to run DiscoverySet [$DiscoverySetGuid]" | Set-CXPExecutionStatus
	
	$DiscoverySetNode = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverySetGuid
	
	if ($DiscoverySetNode -ne $null)
	{
		$DiscoverySetScriptName = $DiscoverySetNode.Script
		$DiscoverySetName = $DiscoverySetNode.Name
		
		"Obtaining Information about DiscoverySet $DiscoverySetName" | Set-CXPExecutionStatus
		$DiscoveryScriptPath = (Join-Path $WorkingPath $DiscoverySetScriptName)
		if (Test-Path $DiscoveryScriptPath)
		{
			$DiscoveryScriptContents = Get-Content $DiscoveryScriptPath
		
			$Results = @()
			foreach ($line in $DiscoveryScriptContents.GetEnumerator())
			{
				# Remove the signature block from the script contents
				if ($line -eq '# SIG # Begin signature block')
				{
					break
				}
				else
				{
					$Results += $line
				}
			}
			
			#$Results += ". `"" + $DiscoveryScriptPath + "`""
			
			Foreach ($EntityNode in $DiscoverySetNode.SelectNodes("Entities/Entity[not (@Parent)]"))
			{
				if ($EntityNode.Type -ne 'Section')
				{
					$Results += Get-CommandLineForEntity $EntityNode $DiscoverySetNode
				}
				else
				{
					$ChildNodes = Get-AllSectionChildNodes -DiscoverySetNode $DiscoverySetNode -SectionGuid $EntityNode.Guid
					Foreach ($ChildEntityNode in $ChildNodes)
					{
						$Results += Get-CommandLineForEntity -EntityNode $ChildEntityNode -DiscoverySetNode $DiscoverySetNode
					}
				}
			}
			
			Foreach ($SectionNode in $DiscoverySetNode.SelectNodes("Entities/Entity[@DiscoverySetLink]"))
			{
				"[Build-DiscoveryScript] DiscoverySet [$DiscoverySetName] Section [$EntityName] contains an EntityLink with Entity " + $SectionNode.DiscoverySetLink | Log-CXPWriteLine
				$Results += Build-DiscoveryScript -DiscoverySetGuid $SectionNode.DiscoverySetLink
			}

			return $Results
		}
		else
		{
			"[Build-DiscoveryScript] DiscoverySet [$DiscoverySetName] Script File Not Found: " + $DiscoveryScriptPath + ". Discovery will not be executed against this DiscoverySet" | Log-CXPWriteLine -IsError
			Return $null
		}
	}
	else
	{
		"[Build-DiscoveryScript] Unable to locate DiscoverySet [$DiscoverySetGuid]. Discovery will not be executed against this DiscoverySet" | Log-CXPWriteLine -IsError
		Return $null
	}
}

Function Get-ParentEntity ([ref] $DiscoverySetNode, [ref] $EntityNode)
{
	$EntityParentGUID = $EntityNode.Value.Parent
	If (-not( [string]::IsNullOrEmpty($EntityParentGUID)))
	{
		if ($DiscoverySetNode.Value -is [System.String])
		{
			$DiscoverySetNode.Value = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverySetNode
		}
		
		$ParentNode = $DiscoverySetNode.Value.SelectSingleNode("Entities/Entity[@Guid='" + $EntityParentGUID + "']")
		if ($ParentNode -ne $null)
		{
			if ($ParentNode.Type -ne 'Section')
			{
				return $EntityParentGUID
			}
			else
			{
				return Get-ParentEntity -DiscoverySetNode $DiscoverySetNode -EntityNode ([ref] $ParentNode)
			}
		}
		else
		{
			"Unable to find parent for Entity " + $EntityNode.Name + "[" +$EntityNode.Guid + "]: Parent [$EntityParentGUID]"
		}
	}
	else
	{
		return $null
	}
}

Function Write-DiscoveryInfo 
{
	param (
		$InputObject,
		[String] $DiscoverySet,
		[string] $Entity,
		$ParentID = $null,
		[System.Management.Automation.InvocationInfo] $InvokeInfo = $MyInvocation)
	BEGIN
	{
		$DiscoverySetNode = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverySet
		
		$EntityNode = Get-EntityNode -DiscoverySetNode ([ref] $DiscoverySetNode) -EntityGuid $Entity
		if ($EntityNode -eq $null)
		{
			"[Write-DiscoveryInfo] Unable to find Entity [$EntityNode]" | Log-CXPWriteLine -IsError
			return $null
		}
		else
		{
			$ParentEntity = Get-ParentEntity -DiscoverySet ([ref] $DiscoverySetNode) -EntityNode ([ref] $EntityNode)
		}
	}
	PROCESS
	{
		if ($_ -ne $null)
		{
			if ($InputObject -eq $null) { $InputObject=@() }
			$InputObject += $_
		}
	}
	END
	{
		if ($InputObject -ne $null)
		{
			if (($InputObject -is [array]) -and ($InputObject.Count -gt 0) -and (($InputObject[0] -is [PSObject]) -or ($InputObject[0] -is [Hashtable])) -or ($InputObject -is [PSObject]) -or ($InputObject -is [Hashtable]))
			{
				$MemberId = Write-DataEntityMember -InputObject $InputObject -EntityNode $EntityNode -ParentEntity $ParentEntity -ParentMember $ParentID -DiscoverySet $DiscoverySet
			}
			elseif ($InputObject -is [array])
			{
				if ($InputObject.Count -gt 0)
				{
					"[Write-DiscoveryInfo] InputObject is not one of the acceptable types. Entity: [$Entity]. Inputobject Type: [Array] of " + ($InputObject[0].GetType().FullName) | Log-CXPWriteLine -IsError
				}
			}
			else
			{
				("[Write-DiscoveryInfo] InputObject is not one of the acceptable types. Entity: [$Entity]. Inputobject Type: " + ($InputObject.GetType().FullName)) | Log-CXPWriteLine -IsError
			}
			return $MemberId
		}
		else
		{
			"[Write-DiscoveryInfo] Skipping entity $Entity as inputobject is null" | Log-CXPWriteLine
		}
	}
}

Function Get-ParentMemberNode ([string] $ParentEntity, [string] $Xpath)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-ParentMemberNode] ParentEntity: $ParentEntity - XPath: $Xpath"
		return $null
	}
	
	$ParentMemberNodes = $DiscoveryReportXML.SelectNodes("/Root/DiscoverySetData[@ComputerName='" + $Env:ComputerName +"']/EntityData[@Entity=`'" + $ParentEntity + "`']/Data/Member[$xpath]")
	return $ParentMemberNodes
}

#Return The Parent Member of a InputObjectMember
Function Get-ParentMember($InputObject, $EntityNode, $DiscoverySet, $InputObjectMember)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-ParentMember] XPath: $Xpath"
		return $null
	}
	
	$ParentMemberID = $null
		#Check if There are InputArguments and if so, the item has a parent
	if ($EntityNode.InputArguments -ne $null)
	{
		$ParentEntity = Get-ParentEntity -DiscoverySetNode ([ref] $DiscoverySet) -EntityNode ([ref] $EntityNode)
		$XpathArray = @()
		$QueryKeyValuePairs = @{}
		$EntityNode.InputArguments.InputArgument | ForEach-Object -Process {
			$ArgumentName = $_.Name
			$ParentProperty = $_.OutputProperty
			$ArgumentValue = $InputObjectMember.$ArgumentName

			if ($ArgumentValue -ne $null)
			{
				if (($ArgumentValue -is [string]) -and (-not $ArgumentValue.Contains("'")) -or ($ArgumentValue -isnot [string]))
				{
					$XpathArray += "($ParentProperty = `'" + $ArgumentValue + "`')"
					$QueryKeyValuePairs += @{$ParentProperty = $ArgumentValue}
				}
				else
				{
					"Argument [$ArgumentName] contains single quotes, which is not supported. Current Value: [$ArgumentValue]" | Log-CXPWriteLine -IsError
				}
			}
		}
		
		if ($XpathArray.Count -gt 0)
		{
			$Xpath = [string]::Join(" and ", $XpathArray)
		}
		else
		{
			#Try to see if there is one single parent member. If so, use this member as the default parent
			#"Unable to locate parent data member for data member of entity " + $EntityNode.Name + " [" + $EntityNode.Guid + "] as no arguments were returned. Below a list of arguments required for the class: `n`r" + ($EntityNode.InputArguments.InputArgument | Select-Object Name | fl | Out-String) + "`n`r`n`rAnd below is the list of properties returned by the first object: " + ($InputObjectMember | Select-Object -First 1 | fl | Out-String) | Log-CXPWriteLine -Debug
			$Xpath = '*'
		}
	}
	else
	{
		$ParentEntity = Get-ParentEntity -DiscoverySetNode ([ref] $DiscoverySet) -EntityNode ([ref] $EntityNode)
		$Xpath = '*'
	}
	
	if ($ParentEntity -ne $null)
	{
		$ParentMemberNode = Get-ParentMemberNode -ParentEntity $ParentEntity -XPath $Xpath
			
		if ($ParentMemberNode -is [System.Xml.XmlElement])
		{
			$ParentMemberID = $ParentMemberNode.ID
		}
		elseif ($ParentMemberNode -eq $null)
		{
			if ($QueryKeyValuePairs.Count -gt 0)
			{
				$QueryUsedDisplay = "Below is the filter used: `n`r" + ($QueryKeyValuePairs | fl | Out-String) 
			}
			"[Get-ParentMember] Unable to locate parent data member for data member of entity " + $EntityNode.Name + " [" + $EntityNode.Guid + "] Member will be ignored. " + $QueryUsedDisplay | Log-CXPWriteLine -Debug -IsWarning
		}
		elseif ($ParentMemberNode -is [System.Xml.XmlNodeList])
		{
			if ($QueryKeyValuePairs.Count -gt 0)
			{
				$QueryUsedDisplay = "Below is the filter used: `n`r" + ($QueryKeyValuePairs | fl | Out-String) 
			}
			"[Get-ParentMember] When locating parent data member for data member of entity " + $EntityNode.Name + " [" + $EntityNode.Guid + "] " + $ParentMemberNode.Count + " members were found and entry will be ignored. " + $QueryUsedDisplay  | Log-CXPWriteLine -IsError
		}
	}
	
	return $ParentMemberID
}

#Generic function to create a node with its properties added from an object
Function Get-EntityDataNode($InputObject, $EntityNode, $DiscoverySet, $ElementTypeName)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-EntityDataNode] Entity: $($EntityNode.Name)"
		continue
	}
	
	[System.Xml.XmlElement] $DataNode = $DiscoveryReportXML.CreateElement($ElementTypeName)
	
	$ParentMemberID = $null
	Foreach ($InputObjectMember in $InputObject)
	{
		#Check if there are InputArguments. Each member need a different parent
		if ($EntityNode.InputArguments -ne $null)
		{
			$ParentMemberID = Get-ParentMember -InputObject $InputObject -EntityNode $EntityNode -InputObjectMember $InputObjectMember -DiscoverySet $DiscoverySet
		}
		#If InputArguments are not used it means all members share a single parent
		elseif ($ParentMemberID -eq $null)
		{
			$ParentMemberID = Get-ParentMember -InputObject $InputObject -EntityNode $EntityNode -InputObjectMember $InputObjectMember -DiscoverySet $DiscoverySet
		}
		
		$ParentEntity = ''
		if (($ParentMemberID -eq $null) -and ($EntityNode.Parent -ne $null))
		{
			$ParentEntity = Get-ParentEntity -DiscoverySetNode ([ref] $DiscoverySet) -EntityNode ([ref] $EntityNode)
		}
		
		if (($ParentMemberID -ne $null) -or ($EntityNode.Parent -eq $null) -or ($ParentEntity -eq $null))
		{
			$MemberDataNode = $DiscoveryReportXML.CreateElement("Member")
			$X = $MemberDataNode.SetAttribute("ID", [Guid]::NewGuid())
			if ($ParentMemberID -ne $null)
			{
				$MemberDataNode.SetAttribute("ParentMemberID", $ParentMemberID)
			}
			
			$EntityNode.Properties.Property | ForEach-Object -Process {
				$PropertyName = $_.Name
				$PropertyDataType = $_.DataType
				$PropertyOrder = $_.Order
			
				if ($InputObjectMember.$PropertyName -ne $null)
				{
					#Check for Data Type Formats
					$DataTypeInfo = $Script:GlobalDataTypes.DataType | Where-Object {$_.Name -eq $PropertyDataType}
					if ($DataTypeInfo -ne $null)
					{
						#Check if the type from the return object is of the allowed Type in PowerShell. For example, check if a specific property is a numeric value
						if (($InputObjectMember.$PropertyName -as $DataTypeInfo.PSTypeName) -ne $null)
						{
							$MemberDataElement = $DiscoveryReportXML.CreateElement($PropertyName)
							$X = $MemberDataElement.set_InnerText($InputObjectMember.$PropertyName)
							$MemberDataElement.SetAttribute('Order', $PropertyOrder)
							
							#Special Types Handling: Registry Values, Files etc
							$PropertyDataTypeFormat = $_.DataTypeFormat
							
							if ($PropertyDataTypeFormat -ne $null)
							{
								$DataTypeInfo = $Script:GlobalDataTypes.DataType | Where-Object {$_.Name -eq $PropertyDataType}
								
								#Check if a function needs to be called to format the item. If so, call the function.
								$DataTypeFormatFunctioName = ($DataTypeInfo.DataTypeFormats.DataTypeFormat | Where-Object {$_.Name -eq $PropertyDataTypeFormat}).FunctionName
								if (-not ([string]::IsNullOrEmpty($DataTypeFormatFunctioName)))
								{
									#Obtain Formatted Value
									trap [Exception] 
									{
										Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-EntityDataNode] Running function $DataTypeFormatFunctioName for Entity $($EntityNode.Name)"
										Continue
									}
									
									$CommandToRun = $DataTypeFormatFunctioName + " `'" + ($InputObjectMember.$PropertyName) + "`'"
									$Error.Clear()
									$returnValue = Invoke-Expression $CommandToRun
									
									if ($returnValue -ne $null)
									{
										#[System.Xml.XmlElement] $FormatedValue = $DiscoveryReportXML.CreateElement('FormattedValue')
										#$FormatedValue.SetAttribute('Value', $returnValue)
										$MemberDataElement.SetAttribute('FormattedValue', $returnValue)
										#$X = $MemberDataElement.AppendChild($FormatedValue)
									}
									elseif ($Error.Count -gt 0)
									{
										"[Get-EntityDataNode] Unable to properly format to $($PropertyDataTypeFormat) the value $($InputObjectMember.$PropertyName). Property Name: $PropertyName Entity $($EntityNode.Name). Error: " + $Error[0].Exception.get_Message()  | Log-CXPWriteLine -IsError
									}
								}
							}
							else
							{
								"[Get-EntityDataNode] Unable to find Data Type Information for Property $($PropertyName): $PropertyDataTypeFormat - Value: $($InputObjectMember.$PropertyName). Entity " + $EntityNode.Name | Log-CXPWriteLine -IsError
							}
							
							$X = $MemberDataNode.AppendChild($MemberDataElement)
						}
						elseif ($TypeConflictExceptionLogged -eq $null)
						{
							"[Get-EntityDataNode] Property $($PropertyName) cannot be converted to [" + $DataTypeInfo.PSTypeName + "] as it contains a [" + $InputObjectMember.$PropertyName.GetType().FullName + "] - Current Value: $($InputObjectMember.$PropertyName) - Entity " + $EntityNode.Name | Log-CXPWriteLine -IsError
							$TypeConflictExceptionLogged = $true
						}
					}
					elseif ($MissingDataTypeExceptionLogged -eq $null)
					{
						"[Get-EntityDataNode] Unable to find Data Type Information for ($PropertyDataType). This is defined on " + $EntityNode.Name | Log-CXPWriteLine -IsError
						$MissingDataTypeExceptionLogged = $true
					}
				}
			}
			$X = $DataNode.AppendChild($MemberDataNode)
		}
		
	}
	
	return $DataNode
}

Function Write-DataEntityMember($InputObject, $EntityNode, $ParentEntity = $null, $ParentMember = $null, $DiscoverySet)
{

	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Write-DataEntityMember]"
		return
	}

	$DiscoverySetDataNode = $DiscoveryReportXML.SelectSingleNode("/Root/DiscoverySetData[(@DiscoverySet = `'$DiscoverySetGuid`') and (@ComputerName = `'$($Env:COMPUTERNAME)`')]")
	if ($DiscoverySetDataNode -eq $null)
	{
		[System.Xml.XmlElement] $DiscoverySetDataNode = $DiscoveryReportXML.CreateElement("DiscoverySetData")
		$X = $DiscoverySetDataNode.SetAttribute('DiscoverySet', $DiscoverySet)
		$X = $DiscoverySetDataNode.SetAttribute('ComputerName', $Env:COMPUTERNAME)
		$X = $DiscoveryReportXML.SelectSingleNode("/Root").AppendChild($DiscoverySetDataNode)
	}
	
	#if (($ParentMember -ne $null) -and ($ParentEntity -ne $null))
	#{
	#	$ParentNode = $DiscoverySetDataNode.SelectSingleNode(".//EntityData[(@Entity=`'" + $ParentEntity + "`')]/Member[@ID=`"" + $ParentMember + "`"]")
	#}
	
	if ($ParentNode -eq $null)
	{
		$ParentNode = $DiscoverySetDataNode
	}
	
	#Check if Entity already exists on Discovery Report XML
	#$EntityDataNode = $ParentNode.SelectSingleNode(".//EntityData[(@Entity=`'" + $EntityNode.Guid + "`')]")
	
	#if ($EntityDataNode -eq $null)
	#{
		#If not, create the Entity data node		
		[System.Xml.XmlElement] $EntityDataNode = $DiscoveryReportXML.CreateElement("EntityData")
		$X = $EntityDataNode.SetAttribute('Entity', $EntityNode.Guid)
		$X = $EntityDataNode.SetAttribute('Version', $EntityNode.Version)
		$X = $ParentNode.AppendChild($EntityDataNode)
	#}

	#$MemberID = [Guid]::NewGuid()
	#[System.Xml.XmlElement] $EntityDataMemberNode = $DiscoveryReportXML.CreateElement("Member")
	#$EntityDataMemberNode.SetAttribute("ID", $MemberID)
	#$X = $EntityDataNode.AppendChild($EntityDataMemberNode)

	$DataElement = Get-EntityDataNode -EntityNode $EntityNode -InputObject $InputObject -ElementTypeName 'Data' -DiscoverySet $DiscoverySet
	
	$X = $EntityDataNode.AppendChild($DataElement)
	return $MemberID
}

#Get a list of arguments for a GenericType based on their current argument list and default values
Function Get-GenericTypeArgumentHashTable ($GenericTypeNode, $ArgumentList)
{
	$Error = $false
	$GenericTypeName = $GenericTypeNode.Name
	$GenericTypeArgumentsTable = @{}
	$GenericTypeNode.GenericDataTypeInputArguments.Argument | ForEach-Object -Process {
		$ArgumentName = $_.Name
		if ($ArgumentList.ContainsKey($ArgumentName))
		{
			$GenericTypeArgumentsTable += @{$ArgumentName = $ArgumentList.get_Item($ArgumentName)}
		}
		elseif(-not ([string]::IsNullOrEmpty($_.DefaultValue)))
		{
			$GenericTypeArgumentsTable += @{$ArgumentName = $_.DefaultValue}
		}
		elseif($_.Required -eq 'true')
		{
			"Argument $ArgumentName is a required argument to [$GenericTypeName] GenericType and it was not set. Please set this value in Authoring Tool" | Log-CXPWriteLine -IsError
			$Error = $true
		}
	}
	
	$ArgumentList.GetEnumerator() | ForEach-Object -Process {
		$ArgumentName = $_.Key
		$ArgumentValue = $_.Value
		if ($GenericTypeNode.GenericDataTypeInputArguments.SelectSingleNode("Argument[@Name=`'$ArgumentName`']") -eq $null)
		{
			"Argument $ArgumentName containing [$ArgumentValue] is not defined in GenericType [$GenericTypeName] and will be ignored " | Log-CXPWriteLine -IsWarning
		}
	}
	
	if (-not $Error)
	{
		return $GenericTypeArgumentsTable
	}
	else
	{
		return $null
	}
}

Function Get-GenericWMIClass ($Entity, $DiscoverySet, [hashtable] $ArgumentList)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-GenericWMIClass] Entity: $($Entity) - WMIClassName: $($WMIClassName)"
		continue
	}
	
	$GenericTypeNode = Get-GenericTypeNode "WMIClass"
	
	$GenericTypeArgumentsTable = Get-GenericTypeArgumentHashTable -GenericTypeNode $GenericTypeNode -ArgumentList $ArgumentList
	
	if ($GenericTypeArgumentsTable -ne $null)
	{
		$GenericTypeArgumentsTable.GetEnumerator() | ForEach-Object -Process {
			$ArgumentName = $_.Name
			New-Variable -Name $ArgumentName -Value $GenericTypeArgumentsTable.get_Item($ArgumentName)
		}
	}
	else
	{
		return $null
	}
	
	$DiscoverySetNode = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverySet
	$EntityNode = Get-EntityNode -EntityGuid $Entity -DiscoverySetNode ([ref] $DiscoverySetNode)
	
	$EntityProperties = $EntityNode.Properties.Property
	
	$ReturnObject = @()
	$WmiObject = Get-WmiObject -Class $WMIClassName -Namespace $NameSpace -Filter $Filter
	
	if ($WmiObject -ne $null)
	{
		foreach ($WmiObjectMember in $WmiObject)
		{
			$DataValues = @{}
			$WMIProperties = ($WmiObjectMember.Properties | % { $_.Name })
			Foreach ($EntityProperty in $EntityProperties)
			{		
				$PropertyName = $EntityProperty.Name
				if ($WMIProperties -contains $PropertyName)
				{
					$DataValues += @{$PropertyName = $WmiObjectMember.$PropertyName}
				}
				elseif ($ExceptionLogged = $null)
				{
					"[Get-GenericWMIClass] Definition of $($EntityNode.Name) contains property $PropertyName, however WMI Class $WMIClassName does not have this property" | Log-CXPWriteLine
					$ExceptionLogged = $true
				}
			}
			$ReturnObject += $DataValues 
		}
	}
	else
	{
		"[Get-GenericWMIClass] Nothing was returned by $WMIClassName on NameSpace $NameSpace ($Filter). This WMI Class is defined on class $($EntityNode.Name)" | Log-CXPWriteLine
	}
	return $ReturnObject
}

#Get a list of required properties for system objects like folder, file and registry
Function Get-SystemObjectPropertyList($TypeName)
{
	switch ($TypeName)
	{
		'Folder'
		{
			@('FullName', 'Name', 'CreationTime', 'LastWriteTime', 'RelativePath')
		}
		'File'
		{
			@('Name', 'Extension', 'FullName', 'Length', 'CreationTime', 'LastWriteTime', 'RelativePath')
		}
		'FileVersionInfo'
		{
			@('CompanyName', 'FileBuildPart', 'FileDescription', 'FileMajorPart', 'FileMinorPart', 'FilePrivatePart', 'FileVersion', 'InternalName', 'Language', 'ProductName', 'OriginalFilename', 'ProductVersion')
		}
		'RegistryKey'
		{
			@{'FullName' = 'Name'; 'Name' = 'PSChildName'; 'SubKeyCount' = 'SubKeyCount'; 'ValueCount'= 'ValueCount', 'RelativePath'}
		}
		'RegistryValue'
		{
			@('Name', 'Type', 'Data')
		}
	}
}

#Obtain a XML node for a 'System Object' (Folder/ File/ Registry)
Function Get-SystemObjectNode($Object, $TypeName, $RootQualifier)
{
	$PropertyList = Get-SystemObjectPropertyList -TypeName $TypeName
						
	[System.Xml.XmlElement] $ObjectNode = $DiscoveryReportXML.CreateElement($TypeName)
	
	if ($PropertyList -is [array])
	{
		$PropertyList | ForEach-Object -Process {
			trap [Exception] 
			{
				Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-SystemObjectNode] FullPath: $CurrentFullPath - Property: $PropertyName")
				Continue
			}
			$PropertyName = $_
			if (($PropertyName -ne 'Name') -or ($Object.$PropertyName -ne ($RootQualifier + '\')))
			{
				
				$ObjectNode.SetAttribute($PropertyName, $Object.$PropertyName)
			}
			else
			{
				$ObjectNode.SetAttribute($PropertyName, $RootQualifier)
			}
		}
	}
	elseif ($PropertyList -is [HashTable])
	{
		$PropertyList.GetEnumerator() | ForEach-Object -Process {
			trap [Exception] 
			{
				Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-SystemObjectNode] FullPath: $CurrentFullPath - Property: $PropertyName")
				Continue
			}
			$PropertyName = $_.Key
			$ObjectPropertyName = $_.Value
			$ObjectNode.SetAttribute($PropertyName, (Convert-RootRegistryString $Object.$ObjectPropertyName))
		}
	}
	return $ObjectNode 
	
}

Function Convert-RegistryString ($RegistryString)
{
	$RegistryString -replace "HKLM\\", "HKLM:\" -replace "HKCU\\", "HKCU:\" -replace "HKU\\", "Registry::HKEY_USERS\" -replace "HKEY_LOCAL_MACHINE\\", "HKLM:\" -replace "HKEY_CURRENT_USER\\", "HKCU:\" -replace "HKEY_USERS\\", "Registry::HKEY_USERS\"
}

Function Convert-RootRegistryString($RootRegkey)
{
	switch ($RootRegkey)
	{
		"HKEY_CURRENT_USER"{"HKCU:"; break;}
      	"HKEY_LOCAL_MACHINE" {"HKLM:"; break;}
      	"HKEY_USERS" {"HKU:"; break;}
      	default {$RootRegkey}
    }
}

Function Get-RegistryKeyInfo ($Entity, $DiscoverySet, [HashTable] $ArgumentList)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-RegistryKeyInfo] Entity: $Entity - DiscoverySet: $DiscoverySet - Path: $Path")
		Continue
	}
	
	$GenericTypeNode = Get-GenericTypeNode "RegistryKey"
	$GenericTypeArgumentsTable = Get-GenericTypeArgumentHashTable -GenericTypeNode $GenericTypeNode -ArgumentList $ArgumentList
	
	if ($GenericTypeArgumentsTable -ne $null)
	{
		$GenericTypeArgumentsTable.GetEnumerator() | ForEach-Object -Process {
			$ArgumentName = $_.Name
			New-Variable -Name $ArgumentName -Value $GenericTypeArgumentsTable.get_Item($ArgumentName)
		}
	}
	else
	{
		return
	}
	
	if ($FullName -ne $null)
	{
		$PSRegKeyName = Convert-RegistryString $FullName
	}
	
	if (-not (Test-path $PSRegKeyName))
	{
		"[Get-RegistryKeyInfo] $PSRegKeyName does not exists Entity: [$Entity] DiscoverySet [$DiscoverySet]." | Log-CXPWriteLine
		return
	}
	
	[array] $AllRegKeys = $PSRegKeyName
	
	if ($Recursive -ne "False")
	{
		trap [Exception]
		{
			Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-RegistryKeyInfo] Enumerating subkeys of $PSRegKeyName - Entity: [$Entity] DiscoverySet [$DiscoverySet]")
			Continue
		}
		
		$AllRegKeys += Get-ChildItem $PSRegKeyName -Recurse | Where-Object {$_.PSIsContainer -eq $true} | % {$_.PSPath}
	}
	
	
	Foreach ($RegKeyName in $AllRegKeys)
	{
		trap [Exception] 
		{
			Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-FolderInfo] Enumerating $($Folder)\$($Filter) - Entity: [$Entity] DiscoverySet [$DiscoverySet]")
			Continue
		}
		
		$ParentRegistryKeyNode = Get-DirectoryNode -DirectoryPath $RegKeyName -TypeName 'Registry'		
		$RegValues = Get-ItemProperty -Path $RegKeyName		
		Write-RegValue -ParentKeyNode $ParentRegistryKeyNode -RegKeyPSObject $RegValues -Filter $Filter
	}
}

#Obtain RelativePaths using Replacement Strings
Function Get-RelativePath ($Path)
{
	trap [Exception] 
	{
		continue
	}
	
	if ($RelativePaths.Count -gt 0)
	{
		$RelativePaths | ForEach-Object -Process {
			$RelativePathVariable = Get-Variable $_ -ErrorAction SilentlyContinue
			if ((($RelativePathVariable.Value -is [string]) -and (-not [string]::IsNullOrEmpty($RelativePathVariable.Value))) -or
				(($RelativePathVariable.Value -is [array]) -and ($RelativePathVariable.Value.Count -gt 0)))
			{
				foreach ($RelativePathValue in $RelativePathVariable.Value)
				{
					$Path = $Path -replace $RelativePathValue.Replace('\', '\\'), ("%" + $RelativePathVariable.Name + "%")
				}
			}
		}
	}
	return $Path
}

Function GetRegistryValueTypeName($RegValueData)
{
	$TypeString = ""
	
	if($RegValueData -is [System.Management.Automation.PSNoteProperty])
	{
		$TypeString = $RegValueData.TypeNameOfValue
	}
	else
	{
		$TypeString = $RegValueData.GetType().FullName
	}
	
	switch ($TypeString)
	{
		"System.String" {"REG_SZ"; break;}
	    "System.Int32" {"REG_DWORD"; break;}
	    "System.Int64" {"REG_QWORD"; break;}
	    "System.String[]" {"REG_MULTI_SZ"; break;}
	    "System.Byte[]" {"REG_BINARY"; break;}
	    default {"Unknown type"}
	}
}

Function Write-RegValue ($FullPath, $ParentKeyNode, $RegKeyPSObject, $Filter)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Write-RegValue] Writing $FullPath / $ValueName / $KeyName")
		Continue
	}
	
	if ($FullPath -ne $null)
	{
		$ValueName = Split-Path -Path $FullPath -Leaf
		$RegistryKeyName = Convert-RegistryString (Split-Path -Path $FullPath)
		
		if (Test-Path $RegistryKeyName)
		{
			$ParentKeyNode = Get-DirectoryNode -DirectoryPath $RegistryKeyName -TypeName 'Registry'
		}
		else
		{
			"[Write-RegValue] $FullPath does not exist." | Log-CXPWriteLine -Debug
		}		
		
		if ($ParentKeyNode -ne $null)
		{
			$RegValueData = (Get-ItemProperty $KeyName -Name $ValueName).$ValueName
			$RegValueDataType = GetRegistryValueTypeName $RegValueData
			
			$RegCustomObject = New-Object 'PSObject'
			$RegCustomObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $ValueName
			$RegCustomObject | Add-Member -MemberType NoteProperty -Name "Data" -Value $RegValueData
			$RegCustomObject | Add-Member -MemberType NoteProperty -Name "DataType" -Value $RegValueDataType
			
			[System.Xml.XmlElement] $ValueNode = Get-SystemObjectNode -TypeName 'RegistryValue' -Object $RegCustomObject
			
			$ExistingValueNode = $ParentKeyNode.SelectSingleNode("RegistryValue[@Name='$($ValueName)']")
			if ($ExistingValueNode)
			{
				$X = $ParentKeyNode.ReplaceChild($ValueNode, $ExistingValueNode)
			}
			else
			{
				$X = $ParentKeyNode.AppendChild($ValueNode)
			}
		}
		else
		{
			"[Write-RegValue] Unable to create Registry Structure for Key: [$RegistryKeyName]. Value Name: [$RegistryValueName]" | Log-CXPWriteLine -Debug
		}
	}
	elseif (($RegKeyPSObject -is [PSObject]) -and ($ParentKeyNode -is [System.Xml.XmlElement]))
	{
		$RegPropertiesToExclude = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')
		foreach($RegValue in $RegValues.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}) 
		{
			If ((([string]::IsNullOrEmpty($Filter)) -or ($RegValue.Name -like $Filter)) -and ($RegPropertiesToExclude -notcontains $RegValue.Name))
			{		
				$RegCustomObject = New-Object 'PSObject'
				
				$RegCustomObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $RegValue.Name
				$RegCustomObject | Add-Member -MemberType NoteProperty -Name "Type" -Value (GetRegistryValueTypeName -RegValueData $RegValue)
				
				if($RegValue.Value -is [System.String[]])
				{
					$RegValue.Value = [string]::Join("\0", $RegValue.Value)
				}
				$RegCustomObject | Add-Member -MemberType NoteProperty -Name "Data" -Value $RegValue.Value
				
				[System.Xml.XmlElement] $ValueNode = Get-SystemObjectNode -TypeName 'RegistryValue' -Object $RegCustomObject
				$ExistingValueNode = $ParentKeyNode.SelectSingleNode("RegistryValue[@Name='$($RegValue.Name)']")
				if ($ExistingValueNode)
				{
					$X = $ParentKeyNode.ReplaceChild($ValueNode, $ExistingValueNode)
				}
				else
				{
					$X = $ParentKeyNode.AppendChild($ValueNode)
				}
			}
			elseif ([string]::IsNullOrEmpty($Filter))
			{
				$RegValue.Name + "\" + $RegValue.Value + " skipped due filter [$Filter] used Entity: $Entity - DiscoverySet: $DiscoverySet" | Log-CXPWriteLine -Debug
			}
		}
	}
}

Function Get-FolderInfo ($Entity, $DiscoverySet, [HashTable] $ArgumentList)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-FolderInfo] Entity: $Entity - DiscoverySet: $DiscoverySet - Path: $Path")
		Continue
	}
	
	$GenericTypeNode = Get-GenericTypeNode "Folder"
	$GenericTypeArgumentsTable = Get-GenericTypeArgumentHashTable -GenericTypeNode $GenericTypeNode -ArgumentList $ArgumentList
	
	if ($GenericTypeArgumentsTable -ne $null)
	{
		$GenericTypeArgumentsTable.GetEnumerator() | ForEach-Object -Process {
			$ArgumentName = $_.Name
			New-Variable -Name $ArgumentName -Value $GenericTypeArgumentsTable.get_Item($ArgumentName)
		}
	}
	else
	{
		return $null
	}
	
	if (-not ([System.IO.Directory]::Exists($Path)))
	{
		#Check if the path is a file. In this case, strip the file from the path
		if ([System.IO.File]::Exists($Path))
		{
			"[Get-DirectoryNode] $DirectoryPath is a file. Removing file from path..." | Log-CXPWriteLine
			$Path = [System.IO.Path]::GetDirectoryName($Path)
		}
		else
		{
			"[Get-DirectoryNode] $DirectoryPath does not exists Entity: [$Entity] DiscoverySet [$DiscoverySet]." | Log-CXPWriteLine
			return $null
		}
	}
	
	
	[array] $AllFolders = $Path
	
	if ($Recursive -eq $true)
	{
		trap [Exception] 
		{
			Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-FolderInfo] Enumerating subfolders of $Path - Entity: [$Entity] DiscoverySet [$DiscoverySet]")
			Continue
		}
		
		$AllFolders += [System.IO.Directory]::EnumerateDirectories($Path, '*.*', [System.IO.SearchOption]::AllDirectories)
	}
	
	Foreach ($Folder in $AllFolders)
	{
		trap [Exception] 
		{
			Log-CXPException -ErrorRecord $_ -ScriptErrorText ("[Get-FolderInfo] Enumerating $($Folder)\$($Filter) - Entity: [$Entity] DiscoverySet [$DiscoverySet]")
			Continue
		}
		
		$FolderNode = Get-DirectoryNode -DirectoryPath $Folder -TypeName 'FileSystem'
		if ($FolderNode -ne $null)
		{
			$Files = [System.IO.Directory]::EnumerateFiles($Folder, $Filter, [System.IO.SearchOption]::TopDirectoryOnly)
			
			ForEach ($FileName in $Files)
			{
				Write-FileInfo -Path $FileName -FolderName $Folder -ParentFolderNode $FolderNode
			}
			
		}
	}
	
}

#Return a XML Node for a File or a Registy Key
Function Get-DirectoryNode ($DirectoryPath, $TypeName)
{

	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-DirectoryNode] Path: $DirectoryPath"
		Continue
	}

	switch ($TypeName)
	{
		'Registry' {$DirectoryTypeName = 'RegistryKey'}
		default {$DirectoryTypeName = 'Folder'}
	}
	
	if ($TypeName -eq 'FileSystem')
	{
		if (-not ([System.IO.Directory]::Exists($DirectoryPath)))
		{
			#Check if the path is a file. In this case, strip the file from the path
			if ([System.IO.File]::Exists($DirectoryPath))
			{
				"[Get-DirectoryNode] $DirectoryPath is a file. Removing file from path..." | Log-CXPWriteLine
				$FolderParts = [System.IO.Path]::GetDirectoryName($DirectoryPath)
			}
			else
			{
				"[Get-DirectoryNode] $DirectoryPath does not exists. Entry not created" | Log-CXPWriteLine
				return $null
			}
		}
	}
	
	$FolderParts = $DirectoryPath.Split([System.IO.Path]::DirectorySeparatorChar)
	
	$RootQualifier = Split-Path $DirectoryPath -Qualifier
	$DirectoryNode = $null
	
	$TopLevelDirectoryNode = $DiscoveryReportXML.SelectSingleNode("/Root/$($TypeName)Data[@ComputerName=`'" + $Env:COMPUTERNAME + "`']")
	if ($TopLevelDirectoryNode -eq $null)
	{
		[System.Xml.XmlElement] $TopLevelDirectoryNode = $DiscoveryReportXML.CreateElement(($TypeName + "Data"))
		$TopLevelDirectoryNode.SetAttribute('ComputerName', $Env:COMPUTERNAME)
		$RootNode = $DiscoveryReportXML.SelectSingleNode('/Root')
		$X = $RootNode.AppendChild($TopLevelDirectoryNode)
	}
	
	$RootQualifierNode = $TopLevelDirectoryNode.SelectSingleNode("Root[translate(@Name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')=`'" + $RootQualifier.ToLower() + "`']")
	
	if ($RootQualifierNode -eq $null)
	{
		[System.Xml.XmlElement] $RootQualifierNode = $DiscoveryReportXML.CreateElement("Root")
		$X = $RootQualifierNode.SetAttribute('Name', $RootQualifier)
		$X = $TopLevelDirectoryNode.AppendChild($RootQualifierNode)
	}
	else
	{
		$XPath = ''
		$FolderParts | ForEach-Object -Process {
			if ($_ -eq $RootQualifier)
			{
				$XPath += $DirectoryTypeName  + "[@Name=`'" + $RootQualifier + "`']"
			}
			else
			{
				$XPath += "/" + $DirectoryTypeName  + "[translate(@Name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')=`'" + $_.ToLower() + "`']"
			}
		}
		
		$DirectoryNode = $RootQualifierNode.SelectSingleNode($XPath)
	}
	$XPath = ''
	if ($DirectoryNode -eq $null)
	{
		$ParentNode = $RootQualifierNode
		$CurrentFullPath = $RootQualifier
		$FolderParts | ForEach-Object -Process {
			if ($_ -eq $RootQualifier)
			{
				$CurrentFolder = "\"
			}
			else
			{
				$CurrentFolder = $_
			}

			$CurrentFullPath = Join-Path $CurrentFullPath $CurrentFolder 

			$XPath = $DirectoryTypeName + "[translate(@Name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')=`'" + $CurrentFolder.ToLowerInvariant() + "`']"			
			$DirectoryNode = $ParentNode.SelectSingleNode($XPath)
			
			if ($DirectoryNode -eq $null)
			{
				trap [Exception] 
				{
					Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-DirectoryNode] FullPath: $CurrentFullPath"
					Continue
				}
				
				$Object = (Get-Item $CurrentFullPath -Force)
				
				if ($Object -ne $null)
				{
					$DirectoryNode = Get-SystemObjectNode -Object $Object -TypeName $DirectoryTypeName -RootQualifier $RootQualifier
					if ($DirectoryNode -ne $null)
					{
						$DirectoryNode.SetAttribute('RelativePath', (Get-RelativePath -Path $DirectoryNode.FullName))
						$X = $ParentNode.AppendChild($DirectoryNode)
					}
				}
			}
			
			$ParentNode = $DirectoryNode
		}
	}
	
	return $DirectoryNode
}

Function Get-FileVersionInfo($FileObject, [Ref] $FileNode)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Write-FileVersionInfo] Path: " + $FileObject.FullPath
		return
	}
	
	$FilePropertiesNode = $FileNode.Value
	if (($FileObject -is [System.IO.FileInfo]) -and ($FilePropertiesNode -is [System.Xml.XmlElement]))
	{
		$FileVersionInfo = $FileObject.VersionInfo
		#Fill out with known properties
		$FileVersionInfoNode = Get-SystemObjectNode -TypeName 'FileVersionInfo' -Object $FileVersionInfo
		
		if ($FileVersionInfoNode -ne $null)
		{		
			#LDRGDR
			#For LDR/GDR, we first see if the file version matches the OS version
			if (($FileVersionInfo.FileBuildPart -ge 6000) -and ($FileVersionInfo.FileMajorPart -eq $OSVersion.Major) -and ($FileVersionInfo.CompanyName -eq 'Microsoft Corporation'))
			{
				$Branch = $null
				#Check if the current version of the file is GDR or LDR:
				if (($FileVersionInfo.FilePrivatePart.ToString().StartsWith(16)) -or 
					($FileVersionInfo.FilePrivatePart.ToString().StartsWith(17)) -or
					($FileVersionInfo.FilePrivatePart.ToString().StartsWith(18)))
				{
					$Branch = 'GDR'
				}
				elseif (($FileVersionInfo.FilePrivatePart.ToString().StartsWith(20)) -or 
					($FileVersionInfo.FilePrivatePart.ToString().StartsWith(21)) -or
					($FileVersionInfo.FilePrivatePart.ToString().StartsWith(22)))
				{
					$Branch = 'LDR'
				}
				### Missing: Need to calculate Branch for XP and 2K3
				if ($Branch)
				{
					$FileVersionInfoNode.SetAttribute('Branch', $Branch)
				}
			}
			$X = $FilePropertiesNode.AppendChild($FileVersionInfoNode)
		}
	}
	else
	{
		'[Write-FileVersionInfo] Either $FileObject is not a fileinfo or $FileNode is not a XMLElement' | Log-CXPWriteLine -IsWarning
		'                        $FileObject type : ' + $FileObject.GetType().BaseType | Log-CXPWriteLine
		'                        $FileNode type   : ' + $FileNode.GetType().BaseType | Log-CXPWriteLine
	}
}

Function Write-FileInfo ($Path, $FolderName, $ParentFolderNode)
{
	if ([System.IO.File]::Exists($Path))
	{
		if (($FolderName -eq $null) -or ($ParentFolderNode -eq $null))
		{
			#Check if file information already exist		
			$FolderName = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($Path))
			
			$ParentFolderNode = Get-DirectoryNode $FolderName 'FileSystem'
		}
		
		if ($ParentFolderNode -ne $null)
		{
		
			trap [Exception] 
			{
				Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Write-FileInfo] Path: $Path"
				Continue
			}
			
			#$FileObject = (Get-Item $Path -Force)
			$FileObject = [System.IO.FileInfo] $Path
				
			if ($ParentFolderNode.SelectSingleNode("File[translate(@Name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='$($FileObject.Name.ToLowerInvariant())']") -eq $null)
			{					
				$FileNode = Get-SystemObjectNode -Object $FileObject -TypeName 'File'
				if ($FileNode -ne $null)
				{
					#$FileNode.RelativePath = Get-RelativePath -Path $FileNode.FullName
					$FileNode = $ParentFolderNode.AppendChild($FileNode)
					
					if ($FileObject.VersionInfo.ProductVersion -ne $null)
					{
						Get-FileVersionInfo -FileObject $FileObject -FileNode ([ref] $FileNode)
					}
					
					$X = $ParentFolderNode.AppendChild($FileNode)
				}
			}
		}
		else
		{
			"[Write-FileInfo] Unable to create Folder Structure for file: [$Path]. Parent Folder Name: [$FolderName]" | Log-CXPWriteLine -IsWarning
		}
	}
	else
	{
		if ([System.IO.Directory]::Exists($Path))
		{
			"[Write-FileInfo] Error: [$Path] is a folder not a file. Entry not created" | Log-CXPWriteLine -IsWarning
		}
		else
		{
			"[Write-FileInfo] Error: File $Path does not exist. Entry not created" | Log-CXPWriteLine -IsWarning
		}
	}
}



function ConvertTo-ScriptBlock 
{
   param ([string]$string)
   [scriptblock] $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($string)
   Return $ScriptBlock 
}

Function SaveSchemaOnReport($DiscoveryReportXML)
{
	$SchemaNodeOnReport = $DiscoveryReportXML.SelectSingleNode('/Root/Schema')
	
	if ($SchemaNodeOnReport -ne $null)
	{
		$DiscoveryReportXML.Root.RemoveChild($SchemaNodeOnReport)
	}
	
	[System.Xml.XmlElement] $SchemaNodeOnReport = $DiscoveryReportXML.CreateElement("Schema")
	
	if ($script:SchemaXML -ne $null)
	{
		$SchemaNodeOnReport.Set_InnerXML($script:SchemaXML.Schema.get_OuterXML()) | Out-Null
		$X = $DiscoveryReportXML.Root.AppendChild($SchemaNodeOnReport)
		return $DiscoveryReportXML
	}
	else
	{
		"Unable to open Schema XML" | Log-CXPWriteLine -IsError
		return $null
	}
}

Function Get-DiscoveryReportXML([string] $Path)
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Get-DiscoveryReportXML] Path: $Path"
		return $false
	}
	
	#Make sure Schema XML is opened
	if ($script:SchemaXML -eq $null) 
	{
		$SchemaOpened = OpenSchemaXML -SchemaXMLPath $SchemaXMLPath
	}
	
	$Now = ((Get-Date).ToString([System.Globalization.CultureInfo]::InvariantCulture))
	if (-not (Test-Path $Path)) 
	{
		#DiscoveryReport does not Exist. Create a new one and stamp the schema in the results.
		"DiscoveryReport does not exist. Creating a new report" | Log-CXPWriteLine
		[xml] $XML = "<Root TimeCreated=`"$($Now)`"/>"
	}
	else
	{
		"DiscoveryReport already exists at $($Path). Using existing DiscoveryReport" | Log-CXPWriteLine
		[xml] $XML = (Get-Content -Path $Path)
		$XML.Root.SetAttribute('TimeUpdated', $Now)
	}
	
	if ((SaveSchemaOnReport $XML) -ne $null)
	{
		return $XML
	}
	else
	{
		return $null
	}
}

Function WriteDiscoveryExecutionSummary
{
	if ($DiscoveryExecution_Summary -ne $null)
	{
		$DiscoveryExecution_Summary | ConvertTo-Xml | write
	}
}


Filter FormatBytes 
{
	param ($bytes,$precision='0')
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[FormatBytes] - Bytes: $bytes / Precision: $precision" -InvokeInfo $MyInvocation
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

Function GetAgeDescription($TimeSpan) 
{
	$Age = $TimeSpan

	if ($Age.Days -gt 0) 
	{
		$AgeDisplay = $Age.Days.ToString()
		if ($Age.Days -gt 1) 
		{
			$AgeDisplay += " Days"
		}
		else
		{
			$AgeDisplay += " Day"
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
				$AgeDisplay += " Hours"
			}
			else
			{
				$AgeDisplay += " Hour"
			}
		}
		if ($Age.Minutes -gt 0) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.Minutes.ToString()
			if ($Age.Minutes -gt 1)
			{
				$AgeDisplay += " Minutes"
			}
			else
			{
				$AgeDisplay += " Minute"
			}
		}		
		if ($Age.Seconds -gt 0) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.Seconds.ToString()
			if ($Age.Seconds -gt 1) 
			{
				$AgeDisplay += " Seconds"
			}
			else
			{
				$AgeDisplay += " Second"
			}
		}
		if (($Age.TotalSeconds -lt 1)) 
		{
			if ($AgeDisplay.Length -gt 0) {$AgeDisplay += " "}
			$AgeDisplay += $Age.TotalSeconds.ToString()
			$AgeDisplay += " Seconds"
		}	
	}
    Return $AgeDisplay
}



Function Run-DiscoveryFunction
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Run-DiscoveryFunction] Expression: $($MyInvocation.Line)" -InvokeInfo $MyInvocation
		continue
	}
	
	$Error.Clear()

	$line = [regex]::Split($MyInvocation.Line.Trim(),'Run-DiscoveryFunction ')[1]

	if (-not [string]::IsNullOrEmpty($line))
	{
		"[Run-DiscoveryFunction]: Starting $line" | Log-CXPWriteLine
		$ScriptTimeStarted = Get-Date
		
		invoke-expression $line
		
		$TimeToRun = (New-TimeSpan $ScriptTimeStarted)
		
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
		
		$lineExecutionTimeDisplay = $line
		$x=0
		while ($DiscoveryExecution_Summary.$lineExecutionTimeDisplay -ne $null)
		{
			$x++
			$lineExecutionTimeDisplay = $line + " [$x]"
		}
		
	    $DiscoveryExecution_Summary | add-member -membertype noteproperty -name $lineExecutionTimeDisplay -value (GetAgeDescription $TimeToRun)
		
		"[Run-DiscoveryFunction]: Finished $line" | Log-CXPWriteLine

		if ($TimeToRun.Seconds -gt 20)
		{
			"$line took " + $TimeToRun.Seconds + " seconds to complete" | Log-CXPWriteLine -IsWarning
		}
	}
	else
	{
		"[Run-DiscoveryFunction] [" + [System.IO.Path]::GetFileName($MyInvocation.ScriptName) + " - " + $MyInvocation.ScriptLineNumber.ToString() + '] - Error: a null expression was sent to Run-DiscoveryFunction' | Log-CXPWriteLine -IsError
	}
}

Function Save-DiscoveryReport()
{
	trap [Exception] 
	{
		Log-CXPException -ErrorRecord $_ -ScriptErrorText "[Save-DiscoveryReport] Path: $DiscoveryReportXMLPath"
		return
	}
	#### Add Encoding
	$DiscoveryReportXML.Save($DiscoveryReportXMLPath)
	"[Save-DiscoveryReport] Discovery report saved to $DiscoveryReportXMLPath" | Log-CXPWriteLine
}

#Remove any DiscoverySetData from the DiscoveryReport to avoid duplicating data from a previous execution
Function Remove-DiscoverySetResultsFromReport($DiscoverySetGuid)
{
	$DiscoverySetData = $DiscoveryReportXML.SelectSingleNode("/Root/DiscoverySetData[(@DiscoverySet = `'$DiscoverySetGuid`') and (@ComputerName = `'$($Env:COMPUTERNAME)`')]")
	if ($DiscoverySetData -ne $null)
	{
		
		"Data from DiscoverySet $DiscoverySetGuid already existed in the report. Removing it."  | Log-CXPWriteLine
		#$DiscoverySetData.RemoveAll()
		$X = $DiscoveryReportXML.Root.RemoveChild($DiscoverySetData)
	}
}

Function Get-DiscoverySetRelativePaths($DiscoverSetGuid)
{
	$DiscoverySetNode = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverSetGuid
	$RelativePathsNode = $DiscoverySetNode.RelativePaths
	$RelativePathVars = @()
	if ($RelativePathsNode -ne $null)
	{
		$RelativePathVars = $RelativePathsNode.RelativePath | % {$_.Name}
	}
	Return $RelativePathVars
}

# Execute a DiscoverySet and return all child DiscoverySets
Function Run-DiscoverySet ([String] $DiscoverySetGuid)
{
	$ScriptContents = Build-DiscoveryScript $DiscoverySetGuid
	$ScriptBlock = ConvertTo-ScriptBlock ($ScriptContents -join "`r`n")
	$DiscoverySetNode = Get-DiscoverySetNode -DiscoverySetGuid $DiscoverySetGuid
	"[Run-DiscoverySet] Starting DiscoverySet Execution for $($DiscoverySetNode.Name) [$DiscoverySetGuid]" | Log-CXPWriteLine
	Remove-DiscoverySetResultsFromReport $DiscoverySetGuid
	New-Variable -Name Discovery -Scope Global -Force -Value $true
	$RelativePathVarNames = Get-DiscoverySetRelativePaths $DiscoverySetGuid
	if ($RelativePathVarNames.Count -gt 0)
	{
		New-Variable -Name RelativePaths -Scope Script -Force -Value $RelativePathVarNames
	}
	
	$ScriptBlock.InvokeReturnAsIs()
	Remove-Variable -Name Discovery -Scope Global
	if ($RelativePaths.Count -gt 0)
	{
		Remove-Variable -Name RelativePaths -Scope Script
	}
	
	"[Run-DiscoverySet] Finished DiscoverySet Execution for $($DiscoverySetNode.Name) [$DiscoverySetGuid]" | Log-CXPWriteLine
	Save-DiscoveryReport
}

"[Starting Discovery]" | Log-CXPWriteLine
$DiscoveryReportXML = Get-DiscoveryReportXML -Path $DiscoveryReportXMLPath
if ($Discovery -ne $null)
{
	Remove-Variable -Name Discovery -Scope Global
}
"[Starting Discovery] End Discovery" | Log-CXPWriteLine
# SIG # Begin signature block
# MIIa6AYJKoZIhvcNAQcCoIIa2TCCGtUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUF5Ja4hZvgDgGct+bPOyAmpYV
# K2igghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
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
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNAwggTM
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggekwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFXx
# Txz6z8c7k0DqVKT6RN9cY17EMIGIBgorBgEEAYI3AgEMMXoweKBegFwAQwBUAFMA
# XwBOAGUAdAB3AG8AcgBrAGkAbgBnAF8ATQBhAGkAbgBfAGcAbABvAGIAYQBsAF8A
# VQB0AGkAbABzAF8ARABpAHMAYwBvAHYAZQByAHkALgBwAHMAMaEWgBRodHRwOi8v
# bWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQANlt0j3W4BWpXqmnpcB8Kw
# MtkesBe8TD2BFegpx9E7V5eP8xKyRIs4DCWp0wGliig7qzcAdymQ2Z2sk0yUSgJI
# +FYuac0zcVZrf89TGGC6igO8hXukgGEyuFnMAB2LQTiA5peBYx2m1i3cojujIJXN
# N3FiRIEMGL1f+9iQyQbSn/yRAXXsxt6X2mR/ECFNTbTqXb4RITVOHjG0vS1+YQ6m
# 0oj4JHO5DwtZCfZsyNckaWce2WMIfc9PM2/r5kC422OC4waLpzXMuXrrh5LEJYfq
# 3Ogxkl19DYBsu8vnZzZAp5G/RugYXX5U138mY5y+OCcHMAh+hlESRFytCrTNLVM9
# oYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQQITMwAAAEyh6E3MtHR7OwAAAAAATDAJBgUrDgMCGgUAoF0wGAYJ
# KoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQxMDIwMTgw
# ODQxWjAjBgkqhkiG9w0BCQQxFgQUEfdd9uaCuzGlIvVn/dNLweSeQP0wDQYJKoZI
# hvcNAQEFBQAEggEAMQ+bYdbZZvokeNX+1NlWF7JFroqoNMRN39gOE1BjpBeEd7hO
# cefUKB6cXN/3Iz4mmeuGwGosfv8yFOLyIlQ46CiiQ0F5FNPn9GqIM4gYIxAuCGXa
# Ad1xFHVy50mA0ZhZz/k3mh7RISHzSS6SjRjLMcUGfJMnZhJdDalBwMobqi1f3S+B
# 7OMP+ANkl8QWvBgNUjWM5lw6WMdJcClEIjSmtBUB17Tdd6nuEkPSEgJuUZClZJxJ
# rQsgR1f/NsM0XIwp9dRl/QNA5d7ne84ve5WSFmJzH4BIFQV7bRnUwIpILE0GNH3s
# u5kW2TWRnh3TSoKy00YuhmDAGzh1Jp6XtwpY/A==
# SIG # End signature block
