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
	
#region Connection
$bConnected = $false
if ((-Not $Server) -and (-Not $DefaultVIServers)) {
    Write-Host "`nNo server connected or passed by parameter.`nExiting..."
    Exit 2
} elseif (($Server) -and (-Not $DefaultVIServers)) {
    Write-Host "`nConnecting to $Server..."
    try {
        Connect-VIServer $Server -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Unable to connect to VIServer $($Server).`nExit"
        Exit 2
    }
} elseif ((-Not $Server) -and ($DefaultVIServers)) {
    Write-Host "`nConnection detected on $($DefaultVIServer.Name) as default."
    $Server = $DefaultVIServer.Name
} elseif ($Server -and $DefaultVIServers) {
    if ($Server -ne $($DefaultVIServer.Name)) {
        Write-Host "`nConnection detected on server $($DefaultVIServer.Name).`nConnecting to $Server..."
        try {
            Connect-VIServer $Server -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Unable to connect to VIServer $($Server).`nExit"
            Exit 2
        }
    } else {
        $bConnected = $true
    }
}

if (-Not ($DefaultVIServers | Where-Object {$_.Name -eq $Server})) {
    Write-Host "`nUnable to connect to $Server.`nExiting..."
    Exit 2
}
#endregion

#region Retrieving $VMHost
try {
	$oVMHost = Get-VMHost -Name $VMHost -ErrorAction Stop
} catch {
	Write-Host "Cannot be found $VMHost.`nExit"
	Exit 2
}
#endregion

#region Change state
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
#endregion

#region Disconnecting
if (-Not $bConnected) {
	Write-Host "`nDisconnecting from VIServer"
    Disconnect-VIServer $Server -Confirm:$false
}
#endregion
