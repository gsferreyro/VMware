<#
		.SYNOPSIS
		Toggle the Maintenance Mode status of a host.

		.DESCRIPTION
		Check the status of the host. If it is in maintenance mode, it removes it from maintenance mode and vice versa.
	
		.EXAMPLE
		.\ToggleMant.ps1 -VMHost 'host'
		Toggle status of 'host'. Before request to connect to a VIServer
		.EXAMPLE
		.\ToggleMant.ps1 -Server 'viserver' -VMHost 'host'
		Toggle status of 'host' on Server 'viserver'

		.NOTES
		Author: Gustavo S. Ferreyro, gsferreyro@gmail.com
        Creation date: 07 March 2021

		This script is provided "AS IS" with no warranty expressed or implied. Run at your own risk.
		This work is licensed under a Creative Commons 1.0 Universal. See LICENCE file
#>

<# 	
	ToDo:
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
		[string]$Server,
	[Parameter(Mandatory)]
		[string]$VMHost
	)
	
# Connect to server
Write-Host "`nConnecting to VIServer"
try {
	if ($Server) {
		$oConnection = Connect-VIServer $Server -ErrorAction Stop
	} else {
		$oConnection = Connect-VIServer -ErrorAction Stop
	}
} catch {
	Write-Host "Unable to connect to VIServer.`nExit"
	Exit 2
}

# Retrieving $VMHost
try {
	$oVMHost = Get-VMHost -Name $VMHost -ErrorAction Stop
} catch {
	Write-Host "Cannot be found $VMHost.`nExit"
	Exit 2
}

if ($oVMHost.ConnectionState -eq "Connected") {
	Write-Host "`nPutting $VMHost into maintenance mode..." -NoNewline
	$oVMHost | Set-VMHost -State Maintenance
	Start-Sleep -s 1
	if ($oVMHost.ConnectionState -eq "Maintenance") {
		Write-Host "...OK. Host in maintenance mode"
	} else {
		Write-Host "...Error. Unable to enter maintenance mode.`nExit"
		Exit 2
	}
} elseif ($oVMHost.ConnectionState -eq "Maintenance") {
	Write-Host "`nExiting $VMHost from maintenance mode..." -NoNewline
	$oVMHost | Set-VMHost -State Connected
	Start-Sleep -s 1
	if ($oVMHost.ConnectionState -eq "Connected") {
		Write-Host "...OK. Exited from maintenance mode"
	} else {
		Write-Host "...Error. Unable to exit maintenance mode.`nExit"
		Exit 2
	}
} else {
	Write-Host "`n$VMHost state: $($oVMHost.ConnectionState).`nExit"
	Exit 2
}

Write-Host "`nCurrent status: $($oVMHost.ConnectionState)"

Write-Host "`nDisconnecting from VIServer"
Disconnect-VIServer $oConnection -Confirm:$false