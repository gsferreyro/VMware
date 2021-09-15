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
		[string]$vCenter,
	[Parameter(Mandatory=$false)]
		[string]$Datacenter,
	[Parameter(Mandatory=$false)]
		[string]$Cluster,
	[Parameter(Mandatory=$false)]
		[string]$VMHost,
	[Parameter(Mandatory=$false)]
		[string]$VM
    )

$dtStart = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

#region Connection
$bConnected = $false
if ((-Not $vCenter) -and (-Not $DefaultVIServers)) {
    Write-Host "`nNo server connected or passed by parameter.`nExiting..."
    Exit 2
} elseif (($vCenter) -and (-Not $DefaultVIServers)) {
    Write-Host "`nConnecting to $vCenter..."
    Connect-VIServer $vCenter | Out-Null
} elseif ((-Not $vCenter) -and ($DefaultVIServers)) {
    Write-Host "`nConnection detected on $($DefaultVIServer.Name) as default."
    $vCenter = $DefaultVIServer.Name
} elseif ($vCenter -and $DefaultVIServers) {
    if ($vCenter -ne $($DefaultVIServer.Name)) {
        Write-Host "`nConnection detected on server $($DefaultVIServer.Name).`nConnecting to $vCenter..."
        Connect-VIServer $vCenter | Out-Null
    } else {
        $bConnected = $true
    }
}

if (-Not ($DefaultVIServers | Where-Object {$_.Name -eq $vCenter})) {
    Write-Host "`nUnable to connect to $vCenter.`nExiting..."
    Exit 2
}
#endregion

#region Setting up the file
if ($Datacenter) {
    $oFile = ".\DSs_Datacenter_$Datacenter.xlsx"
} elseif ($Cluster) {
    $oFile = ".\DSs_Cluster_$Cluster.xlsx"
} elseif ($VMHost) {
    $oFile = ".\DSs_Host_$VMHost.xlsx"
} elseif ($VM) {
    $oFile = ".\DSs_VM_$VM.xlsx"
} else {
    $oFile = ".\DSs_Server_$vCenter.xlsx"
}

if (Test-Path $oFile) {
    try {
        Remove-Item -Path $oFile -ErrorAction Stop
    } catch {
        Write-Host "The file $oFile could not be deleted. Is $oFile open?`nExiting..."
        Exit 2
    }
}
#endregion

#region Retrieving datastores
if ($Datacenter) {
    Write-Host "Retrieving datastores of Datacenter of $Datacenter"
    $oDSs = Get-Datacenter $Datacenter | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
} elseif ($Cluster) {
    Write-Host "Retrieving datastores of Cluster $Cluster"
    if ($Cluster.ToUpper() -eq "STANDALONE") {
        $oDSs = Get-VMHost | Where-Object {$_.Parent.Name -eq 'host'} | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*" -and $_.Name -notlike "vsan*"} | Select-Object -Unique
    } else {
        $oDSs = Get-Cluster $Cluster | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
    }
} elseif ($VMHost) {
    Write-Host "Retrieving datastores of VMHost $VMHost"
    $oDSs = Get-VMHost $VMHost | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
} elseif ($VM) {
    Write-Host "Retrieving datastores of VM $VM"
    $oDSs = Get-VM $VM | Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
} else {
    Write-Host "Retrieving datastores of Server $vCenter"
    $oDSs = Get-Datastore | Where-Object {$_.Name -notlike "VeeamBackup*" -and $_.Name -notlike "datastore*"} | Select-Object -Unique
}

$i = 0
$nTot = $oDSs.Count
Write-Host "$nTot datastore/s retrieved"

if ($nTot -le 0) {
    Write-Host "No DS found with the parameters entered:"
    Write-Host "vCenter: $vCenter"
    Write-Host "Datacenter: $Datacenter"
    Write-Host "Cluster: $Cluster"
    Write-Host "VMHost: $VMHost"
    Write-Host "VM: $VM"
    Exit 0
}
#endregion

#region Processing datastores
Write-Host "Processing datastore/s"
$dtDSs = @()
$i = 0
foreach ($oDS in $oDSs) {
	$i += 1
	Write-Progress -Activity "Retrieving $oDS" -Status "Progress" -PercentComplete ($i/$oDSs.Count*100)
    $bFound = $false
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
	    $drDSs | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vCenter
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

#region Exporting
$dtDSs | Export-Excel -WorksheetName "Datastores" -Path $oFile -AutoSize -BoldTopRow -AutoFilter
#endregion

#region Disconnecting
if (-Not $bConnected) {
    Disconnect-VIServer $vCenter -Confirm:$false
}
#endregion

#region Reporting times
$dtEnd = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
Write-Host "Completed in $(New-TimeSpan -Start $dtStart -End $dtEnd)"
#endregion