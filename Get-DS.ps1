<#
		.SYNOPSIS
		Export Datastore specific data

		.DESCRIPTION
		Check Datastore of parameters, collecting data and export to a xlsx file in ".\"
	
		.EXAMPLE
		.\Get-DS.ps1 -Datacenter 'datacenter'
		Collects data from the VMHosts's datastores in 'datacenter'
		.EXAMPLE
		.\ToggleMant.ps1 -Server 'viserver' -Cluster 'cluster'
		Collects data from the VMHosts's datastores in 'cluster' of Server 'viserver'
		.EXAMPLE
		.\ToggleMant.ps1 -VMHost 'host'
		Collects data from the VMHosts's datastores
		.EXAMPLE
		.\ToggleMant.ps1 -VM 'vm'
		Collects data from the VMHosts's datastores where 'vm' is running on

		.NOTES
		Author: Gustavo S. Ferreyro, gsferreyro@gmail.com
        Creation date: 03 September 2021

		This script is provided "AS IS" with no warranty expressed or implied. Run at your own risk.
		This work is licensed under a Creative Commons 1.0 Universal. See LICENCE file
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
		[string]$Server,
	[Parameter(Mandatory=$false)]
		[string]$Datacenter,
	[Parameter(Mandatory=$false)]
		[string]$Cluster,
	[Parameter(Mandatory=$false)]
		[string]$VMHost,
	[Parameter(Mandatory=$false)]
		[string]$VM
    )

Import-Module "$PSScriptRoot\utils.psm1" -Force
if (-not (Get-Module -Name utils)) {
    Write-Host "Cannot import module utils, check if available in $($PSScriptRoot). Exiting..."
    Exit 2
}

if (-not (Test-PowerCLI)) {
    Write-Host "$(Get-Error) Please install PowerCLI module. Exiting..."
    Exit 2
}
             
$dtStart = now

#region Connection
if ((-Not $Server) -and (-Not $DefaultVIServers)) {
    Write-Host "$(Get-Error) No server connected or passed by parameter. Exiting..."
    Exit 2
} elseif ($Server) {
    $bConnected = $DefaultVIServers.Name.Contains($Server)
} else {
    $bConnected = $true
    $Server = $DefaultVIServer.Name
}

try {
    Connect-VIServer $Server -ErrorAction Stop | Out-Null
} catch {
    Write-Host "$(Get-Error) Unable to connect to VIServer $($Server). Exiting..."
    Exit 2
}
#endregion

#region Setting up the file
$bExport = $true
if (-Not (Test-Path .\export -PathType Container)) {
    try {
        mkdir -Path ".\export" -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "$(Get-Warn) Cannot create export directory. Check permissions."
        $bExport = $false
    }
}

if ($bExport) {
    if ($Datacenter) {
        $oFile = ".\export\DSs_Datacenter_$Datacenter.xlsx"
    } elseif ($Cluster) {
        $oFile = ".\export\DSs_Cluster_$Cluster.xlsx"
    } elseif ($VMHost) {
        $oFile = ".\export\DSs_Host_$VMHost.xlsx"
    } elseif ($VM) {
        $oFile = ".\export\DSs_VM_$VM.xlsx"
    } else {
        $oFile = ".\export\DSs_Server_$Server.xlsx"
    }

    if (Test-Path $oFile) {
        try {
            Remove-Item -Path $oFile -ErrorAction Stop
        } catch {
            Write-Host "$(Get-Error) The file $oFile could not be deleted. Is $oFile open?"
            Write-Host "$(Get-Error) Exiting..."
            Exit 2
        }
    }
}
#endregion

#region Retrieving datastores
if ($Datacenter) {
    Write-Host "$(Get-Info) Retrieving datastores of Datacenter of $Datacenter"
    $oDSs = Get-Datacenter $Datacenter
} elseif ($Cluster) {
    if ($Cluster.ToUpper() -ne "STANDALONE") {
        Write-Host "$(Get-Info) Retrieving datastores of Cluster $Cluster"
        $oDSs = Get-Cluster $Cluster
    } else {
        Write-Host "$(Get-Info) Retrieving datastores of STANDALONE VMHosts"
        $oDSs = Get-VMHost | Where-Object {$_.Parent.Name -eq 'host'}
    }
} elseif ($VMHost) {
    Write-Host "$(Get-Info) Retrieving datastores of VMHost $VMHost"
    $oDSs = Get-VMHost $VMHost
} elseif ($VM) {
    Write-Host "$(Get-Info) Retrieving datastores of VM $VM"
    $oDSs = Get-VM $VM
} else {
    Write-Host "$(Get-Info) Retrieving datastores of Server $Server"
}
if ($oDSs) {
    $oDSs = $oDSs | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*" -and $_.Name -notlike "vsan*"} | Select-Object -Unique
} else {
    $oDSs = Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
}

$i = 0
$nTot = $oDSs.Count
Write-Host "$($nTot) datastore/s retrieved"

if (-not $nTot) {
    Write-Host "$(Get-Warn) No DS found with the parameters entered:"
    Write-Host "$(Get-Warn) vCenter: $($Server)"
    Write-Host "$(Get-Warn) Datacenter: $($Datacenter)"
    Write-Host "$(Get-Warn) Cluster: $($Cluster)"
    Write-Host "$(Get-Warn) VMHost: $($VMHost)"
    Write-Host "$(Get-Warn) VM: $($VM)"
    Exit 0
}
#endregion

#region Processing datastores
Write-Host "Processing datastore/s"
$dtDSs = @()
$i = 0
foreach ($oDS in $oDSs) {
	$i += 1
	Write-Progress -Activity "Retrieving $($oDS.Name)" -Status "Progress: $($i)/$($nTot)" -PercentComplete ($i/$nTot*100)
    $drDSs = New-Object PSObject

    # Datacenter, Cluster, VMHost, VM o Server, according to parameters entered
    if ($Datacenter) {
	    $drDSs | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $Datacenter
    } elseif ($Cluster) {
	    $drDSs | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $Cluster
    } elseif ($VMHost) {
	    $drDSs | Add-Member -MemberType NoteProperty -Name "VMHost" -Value $VMHost
    } elseif ($VM) {
	    $drDSs | Add-Member -MemberType NoteProperty -Name "VM" -Value $VM
    } else {
	    $drDSs | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $Server
    }

    # Datastore
	$drDSs | Add-Member -MemberType NoteProperty -Name "Datastore" -Value $oDS.Name
    try {
        $oNaa = $oDS.ExtensionData.Info.Vmfs.Extent[0].DiskName
    } catch {
        $oNaa = "Not found"
    }

    # NAA
    $drDSs | Add-Member -MemberType NoteProperty -Name "NAA" -Value $oNaa

    # Number of paths

    if ($oDS.Type -eq "VMFS") {
        $nPaths = ($oDS | Get-ScsiLun -LunType disk | Get-ScsiLunPath | Where-Object {$_.State -eq "Active"} | Select-Object -Unique).Count
    } else {
        $nPaths = $oDS.Type
    }
    $drDSs | Add-Member -MemberType NoteProperty -Name "Paths" -Value $nPaths

    $dtDSs += $drDSs
}
#endregion

#region Exporting to xlsx
if ($bExport) {
    $dtDSs | Export-Excel -WorksheetName "Datastores" -Path $oFile -AutoSize -BoldTopRow -AutoFilter
} else {
    Write-Output $dtDSs
}
#endregion

#region Disconnecting
if (-Not $bConnected) {
	Write-Host "$(Get-Info) Disconnecting from VIServer"
    Disconnect-VIServer $Server -Confirm:$false
}
#endregion

#region Reporting times
$dtEnd = now
Write-Host "$(Get-Info) Completed in $(New-TimeSpan -Start $dtStart -End $dtEnd)"
#endregion