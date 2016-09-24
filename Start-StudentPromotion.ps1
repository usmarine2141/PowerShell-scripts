<#
	.SYNOPSIS
		Moves students to a new OU based on the grade level supplied, removes all groups, then assigns to groups based on the grade-level supplied.
	
	.DESCRIPTION
		A description of the file.
	
	.PARAMETER Path
		Full path to a CSV containing Student user account information. Accepts pipeline input that contains the path, either as a string or a PSObject.
		Example command that can be piped:
		
		Get-ChildItem C:\CSV\Parent\Path
		
		Since the resulting object contains a property called "Path" it can be piped directly.
		Otherwise, if the object property containing the path doesn't have the same name, make sure that only that property is passed through the pipeline (e.g. Use Slect-Object)
	
	.PARAMETER Samaccountname (Only use if not using a CSV)
		The Student's username, also known as sAMAccountName in x500/LDAP. This command accepts pipeline input, and requires no additional work if the incoming object
		has a property named "Samaccountname".
	
	.PARAMETER NewGradeLevel (Only use if not using a CSV)
		Specifies the grade level the student is being promoted to. Accepts either the grade number alone or a string beginning with the grade number (e.g 4 and 4th).
		Pre-Kindergarden and Kindergarden are denoted by "PK" and "K" respectively, followed by the number indicating the level. (e.g. PK4 and K2).
	
	.PARAMETER Add
		This is a switch parameter, as such it accepts no arguments. This switch adds the users to the particular student group instead of replacing their group membership. There aren't many use cases at ELH where this is useful except where students need to be added to the CDI-Scholars group.
	
	.EXAMPLE 

		Start-StudentPromotion [-Path(CSV) [C:\\Path\To\CSV.csv]]

		Start-StudentPromotion [-Username(SamaccountName) []] [-Grade(NewGradeLevel) []]

	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2016 v5.2.128
		Created on:   	9/12/2016 16:12
		Created by:   	Scott Carlow
		Organization:
		Filename:
		===========================================================================
#>

# Here we pre-define chinks of the LDAP Paths to the OU's we will use later. This senables
# laziness below

#region LDAP Path definition
$DistroDomain = 'OU=Groups,DC=contoso,DC=com'
$OUElementary = 'OU=Elementary_School,OU=Students,OU=Users,DC=contoso,DC=com'
$OUMiddle = 'OU=Middle_School,OU=Students,OU=Users,DC=contoso,DC=com'
$OUHigh = 'OU=High_School,OU=Students,OU=Users,DC=contoso,DC=com'
#endregion

#region Main function
function Start-StudentPromotion
{
	[CmdletBinding(DefaultParameterSetName = 'Manual',
				   ConfirmImpact = 'Medium',
				   SupportsShouldProcess = $true)]
	param
	(
		[Parameter(ParameterSetName = 'CSV',
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1)]
		[ValidateNotNullOrEmpty()]
		[Alias('CSV')]
		$Path,
		[Parameter(ParameterSetName = 'Manual',
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('Username')]
		$Samaccountname,
		[Parameter(ParameterSetName = 'Manual',
				   Position = 1)]
		[ValidateNotNullOrEmpty()]
		[Alias('Grade')]
		$NewGradeLevel,
		[Parameter(HelpMessage = 'Indicates you want to add the users to the defined student group instead of replacing their group membership.')]
		[switch]$Add
	)
	
	Begin
	{
		if ($Samaccountname)
		{
			$obj = Get-ADUser -identity $Samaccountname
		}
	}
	Process
	{
		if ($pscmdlet.ShouldProcess("Target", "Operation"))
		{
			switch ($PsCmdlet.ParameterSetName)
			{
				'CSV' {
					$script:ImportedUsers = Import-Csv $Path
					foreach ($item in $script:ImportedUsers)
					{
						$user = Get-ADuser -identity $item.samaccountname
						if ($Add = $false)
						{
							Remove-UserGroups -user $user
						}
						Assign-UserGroups $user
					}
				}
				'Manual' {
					if ($Add = $false)
					{
						Remove-UserGroups -user $obj
					}
					Assign-UserGroups $obj
				}
			}
			
		}
	}
	End
	{
		
	}
}
#endregion
#region Removing the existing user groups
function Remove-UserGroups
{
	[CmdletBinding(ConfirmImpact = 'Medium',
				   SupportsShouldProcess = $true)]
	param
	(
		[Parameter(ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true)]
		$user
	)
	
	begin
	{
		if ($script:ImportedUsers -eq $null)
		{
			$script:ImportedUsers = Import-Csv $path
		}
	}
	Process
	{
		if ($pscmdlet.ShouldProcess("Target", "Operation"))
		{
			$Member = Get-ADUser -Identity $user.samaccountname -Properties MemberOf
			$Member.MemberOf | Remove-ADGroupMember -Member $user.samaccountname -Confirm:$false
		}
	}
	end
	{
		
	}
}
#endregion
#region Assign the user groups based on grade, and likewise change the Users OU's
function Assign-UserGroups
{
	[CmdletBinding(ConfirmImpact = 'Medium',
				   SupportsShouldProcess = $true)]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		$user
	)
	
	begin
	{
		if ($script:ImportedUsers -eq $null)
		{
			$script:ImportedUsers = Import-Csv $path
		}
	}
	Process
	{
		if ($pscmdlet.ShouldProcess("Target", "Operation"))
		{
			switch -wildcard ($item.grade)
			{
				"PK*" { add-adgroupmember -Identity "CN=PK Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=PK,$OUElementary"; break }
				
				"K*" { add-adgroupmember -Identity "CN=K Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU-Kindergarten,$OUElementary"; break }
				
				"1*" { add-adgroupmember -Identity "CN=1st Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=1st_Grade,$OUElementary"; break }
				
				"2*" { add-adgroupmember -Identity "CN=2nd Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=2nd_Grade,$OUElementary"; break }
				
				"3*" { add-adgroupmember -Identity "CN=3rd Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=3rd_Grade,$OUElementary"; break }
				
				"4*" { add-adgroupmember -Identity "CN=4th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=4th_Grade,$OUElementary"; break }
				
				"5*" { add-adgroupmember -Identity "CN=5th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=5th_Grade,$OUMiddle"; break }
				
				"6*" { add-adgroupmember -Identity "CN=6th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=6th_Grade,$OUMiddle"; break }
				
				"7*" { add-adgroupmember -Identity "CN=7th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=7th_Grade,$OUMiddle"; break }
				
				"8*" { add-adgroupmember -Identity "CN=8th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=8th_Grade,$OUMiddle"; break }
				
				"9*" { add-adgroupmember -Identity "CN=9th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=9th_Grade,$OUHigh"; break }
				
				"10*" { add-adgroupmember -Identity "CN=10th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=10th_Grade,$OUHigh"; break }
				
				"11*" { add-adgroupmember -Identity "CN=11th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=11th_Grade,$OUHigh"; break }
				
				"12*" { add-adgroupmember -Identity "CN=12th Grade,$DistroDomain" -members $user.samaccountname; Move-ADObject -Identity $User.ObjectGUID -TargetPath "OU=12th_Grade,$OUHigh"; break }
				
				"CDI*" { add-adgroupmember -Identity "CN=CDI-Scholars,$DistroDomain" -members $user.samaccountname; break }
				
			}
		}
	}
}
#endregion