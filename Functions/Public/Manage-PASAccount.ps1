###########
#region ### global:Manage-PASAccount # CMDLETDESCRIPTION : Manages the provided accounts :
###########
function global:Manage-PASAccount
{
    <#
    .SYNOPSIS
    Manages a PASAccount object from the PAS tenant.

    .DESCRIPTION
	Manages a PASAccount object from the PAS tenant. This means that the PAS tenant will attempt
	to immediately rotate the password and after every instance of the password being checked in
	or 1 hour after initial checkout (default lifetime checkout.)

    .PARAMETER Accounts
	The PASAccount objects to manage. Will only accept PASAccount type objects.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object that provides the account target 
	and the results of the manage attempt.

    .EXAMPLE
    C:\PS> Manage-PASAccount -Accounts $PASAccounts
	For the provided PASAccount objects, attempt to manage the account.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Accounts to manage", ParameterSetName = "Account")]
		[PASAccount[]]$Accounts
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# multithreaded get on each account object
	$AllData = $Accounts | ForEach-Object -Parallel {

		# aliasing and reasserting connection and script information
		$account = $_
		$PASConnection         = $using:PASConnection
		$PASSessionInformation = $using:PASSessionInformation

		# for each script in our PAS_PCMScriptBlocks
		foreach ($script in $using:PAS_PCMScriptBlocks)
		{
			# add it to this thread as a script, this makes all classes and functions available to this thread
			. $script.ScriptBlock
		}

		$obj = New-Object PSObject

		$obj | Add-Member -MemberType NoteProperty -Name Account -Value $account.SSName

		Try
		{
			$result = $account.manageAccount()

			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $true
		}
		Catch
		{
			# if an error occurred during the get, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during manageAccount() on PASAccount object.")
			$e.AddExceptionData($_)
			$e.AddData("result",$result)
			$e.AddData("account",$account)
			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $e
		}# Catch
		Finally
		{
			# nulling values to free memory
			$result = $null
			$account = $null
		}

		# return the returner object
		$obj
		
	} |# $Accounts | ForEach-Object -Parallel {
	ForEach-Object -Begin { $i = 0 } -Process { 
			
		$Completed = $($i/($Accounts | Measure-Object | Select-Object -ExpandProperty Count)*100)
		# incrementing result count
		$i++
		# update progress bar
		Write-Progress -Activity "Managing Accounts" -Status ("{0} out of {1} Complete" -f $i,$Accounts.Count) -PercentComplete $Completed
		# returning the result
		$_
	}# | ForEach-Object -Begin { $i = 0 } -Process {

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData
}# function global:Manage-PASAccount
#endregion
###########