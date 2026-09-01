<#
.SYNOPSIS
    Automates a secure end-of-life decommissioning workflow for a Windows endpoint.

.DESCRIPTION
    This script demonstrates a repeatable, auditable process for decommissioning a
    company-owned Windows device:
      1. Verifies the device is encrypted (BitLocker) before wipe/reassignment.
      2. Exports a snapshot of basic asset information (hostname, serial number,
         last logged-on user) for the asset register.
      3. Disables the corresponding computer object in Active Directory and moves
         it to a "Disabled Computers" organizational unit.
      4. Appends a timestamped entry to a CSV audit log recording who performed
         the decommission and which asset was processed.

    This is a sanitized, generic example written for portfolio purposes. It contains
    no real hostnames, credentials, or organization-specific values. Replace every
    placeholder (wrapped in <...>) with values appropriate to your own environment
    before running it, and test in a non-production OU first.

.PARAMETER ComputerName
    The hostname of the device being decommissioned.

.PARAMETER Technician
    The name or ID of the person performing the decommission (for the audit log).

.PARAMETER DisabledOU
    Distinguished name of the Active Directory OU where decommissioned computer
    objects are moved.

.PARAMETER AuditLogPath
    Path to the CSV file used as the audit trail.

.EXAMPLE
    .\Invoke-SecureDeviceDecommission.ps1 -ComputerName "<HOSTNAME>" -Technician "M. Sampieri" `
        -DisabledOU "OU=Disabled Computers,DC=<yourdomain>,DC=<tld>" -AuditLogPath "C:\Logs\decommission-log.csv"

.NOTES
    Author:  Marco Sampieri
    Purpose: Portfolio / demonstration script.
    Requires: ActiveDirectory PowerShell module, BitLocker module, and appropriate
              delegated permissions in AD.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ComputerName,

    [Parameter(Mandatory = $true)]
    [string]$Technician,

    [Parameter(Mandatory = $true)]
    [string]$DisabledOU,

    [Parameter(Mandatory = $false)]
    [string]$AuditLogPath = ".\decommission-log.csv"
)

function Test-BitLockerEncrypted {
    param([string]$Computer)
    try {
        $status = Get-BitLockerVolume -CimSession $Computer -MountPoint "C:" -ErrorAction Stop
        return ($status.VolumeStatus -eq "FullyEncrypted")
    }
    catch {
        Write-Warning "Could not query BitLocker status for '$Computer'. Assuming NOT encrypted. $_"
        return $false
    }
}

function Export-AssetSnapshot {
    param([string]$Computer)
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $Computer -ErrorAction Stop
        $bios = Get-CimInstance -ClassName Win32_BIOS -ComputerName $Computer -ErrorAction Stop
        [PSCustomObject]@{
            Hostname       = $Computer
            SerialNumber   = $bios.SerialNumber
            LastLoggedUser = $cs.UserName
            SnapshotDate   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
    catch {
        Write-Warning "Could not collect asset snapshot for '$Computer'. $_"
        $null
    }
}

function Move-ComputerToDisabledOU {
    param([string]$Computer, [string]$TargetOU)
    try {
        $adComputer = Get-ADComputer -Identity $Computer -ErrorAction Stop
        Disable-ADAccount -Identity $adComputer -WhatIf:$WhatIfPreference
        Move-ADObject -Identity $adComputer.DistinguishedName -TargetPath $TargetOU -WhatIf:$WhatIfPreference
        Write-Host "AD object for '$Computer' disabled and moved to '$TargetOU'." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to disable/move AD object for '$Computer'. $_"
        return $false
    }
}

function Write-AuditLogEntry {
    param($Snapshot, [string]$Tech, [bool]$AdSuccess, [string]$LogPath)
    $entry = [PSCustomObject]@{
        Timestamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Technician     = $Tech
        Hostname       = $Snapshot.Hostname
        SerialNumber   = $Snapshot.SerialNumber
        LastLoggedUser = $Snapshot.LastLoggedUser
        AdDisabled     = $AdSuccess
    }
    $entry | Export-Csv -Path $LogPath -Append -NoTypeInformation -Encoding UTF8
    Write-Host "Audit log entry written to '$LogPath'." -ForegroundColor Cyan
}

# --- Main workflow ---

Write-Host "Starting decommission workflow for '$ComputerName'..." -ForegroundColor Yellow

if (-not (Test-BitLockerEncrypted -Computer $ComputerName)) {
    Write-Warning "Device '$ComputerName' does not appear to be fully encrypted. Review before proceeding with certified data destruction."
}

$snapshot = Export-AssetSnapshot -Computer $ComputerName
if (-not $snapshot) {
    throw "Aborting: could not collect asset information for '$ComputerName'."
}

$adResult = Move-ComputerToDisabledOU -Computer $ComputerName -TargetOU $DisabledOU

Write-AuditLogEntry -Snapshot $snapshot -Tech $Technician -AdSuccess $adResult -LogPath $AuditLogPath

Write-Host "Decommission workflow complete for '$ComputerName'." -ForegroundColor Yellow
