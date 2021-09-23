<#
		.SYNOPSIS
		Useful functions

		.DESCRIPTION
		Set of commonly used useful functions
	
		.NOTES
		Author: Gustavo S. Ferreyro, gsferreyro@gmail.com
        Creation date: 22 September 2021

		This script is provided "AS IS" with no warranty expressed or implied. Run at your own risk.
		This work is licensed under a Creative Commons 1.0 Universal. See LICENCE file
#>

function Write-Tee {
    <#
            .SYNOPSIS
            Same as Tee-Object function
            .DESCRIPTION
            Writes to the standard output and to the file if $FilePath is sent
    #>
    param (
		[Parameter(Mandatory=$true)]
        [psobject]$InputObject,
		[Parameter(Mandatory=$false)]
        [string]$FilePath,
		[Parameter(Mandatory=$false)]
        [switch]$Append
	)
    $CommandName = $PSCmdlet.MyInvocation.InvocationName
    $ParameterList = (Get-Command -Name $CommandName).Parameters
    $htParams = @{}
    foreach ($Parameter in $ParameterList.GetEnumerator()) {
        try {
            $oVar = Get-Variable $Parameter[0].Key -ErrorAction Stop
            if ($oVar.Value) { $htParams[$Parameter[0].Key] = $oVar.Value }
        } catch {}
    }
    Write-Host $InputObject
    if ($FilePath) { Out-File @htParams }
}