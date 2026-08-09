<#
.SYNOPSIS
    Identifies and optionally disables inactive Active Directory accounts.

.DESCRIPTION
    Addresses audit finding F-02 (inactive accounts remain enabled).

    Finds enabled accounts with no interactive logon within a defined threshold
    and optionally disables them. Service accounts are excluded by default
    because they authenticate non-interactively and do not populate
    LastLogonDate - disabling them on that basis would break production services.

    SAFETY: Runs in report-only mode unless -Remediate is specified.
    Supports -WhatIf so the exact change set can be reviewed before execution.

.PARAMETER InactiveDays
    Number of days without logon before an account is considered stale. Default 90.

.PARAMETER SearchBase
    Distinguished name of the OU to evaluate.

.PARAMETER ExcludeServiceAccounts
    Skip accounts matching service-account naming patterns. Default true.

.PARAMETER Remediate
    Actually disable the identified accounts. Without this switch the script reports only.

.PARAMETER DisabledOU
    Optional. If supplied, disabled accounts are moved to this OU.

.EXAMPLE
    .\Disable-StaleAccounts.ps1
    Report-only. Lists stale accounts, changes nothing.

.EXAMPLE
    .\Disable-StaleAccounts.ps1 -Remediate -WhatIf
    Shows exactly which accounts would be disabled, without doing it.

.EXAMPLE
    .\Disable-StaleAccounts.ps1 -Remediate -DisabledOU "OU=Disabled,DC=Link3IT,DC=com"
    Disables stale accounts and moves them to the Disabled OU.

.NOTES
    Author : Andrew Symister
    Control: NIST SP 800-53 AC-2(3) (Disable Accounts)
    Safety : Report-only by default. Requires explicit -Remediate to change anything.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 730)]
    [int]$InactiveDays = 90,

    [Parameter(Mandatory = $false)]
    [string]$SearchBase = "DC=Link3IT,DC=com",

    [Parameter(Mandatory = $false)]
    [bool]$ExcludeServiceAccounts = $true,

    [Parameter(Mandatory = $false)]
    [switch]$Remediate,

    [Parameter(Mandatory = $false)]
    [string]$DisabledOU,

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

Import-Module ActiveDirectory -ErrorAction Stop

$cutoff = (Get-Date).AddDays(-$InactiveDays)
$mode   = if ($Remediate) { 'REMEDIATE' } else { 'REPORT-ONLY' }

Write-Host "`n=== STALE ACCOUNT REVIEW ===" -ForegroundColor Cyan
Write-Host "Control   : NIST SP 800-53 AC-2(3)" -ForegroundColor DarkGray
Write-Host "Threshold : $InactiveDays days (before $($cutoff.ToString('yyyy-MM-dd')))" -ForegroundColor DarkGray
Write-Host "Mode      : $mode`n" -ForegroundColor $(if ($Remediate) { 'Yellow' } else { 'Green' })

# Service-account naming patterns to protect from inactivity logic
$serviceAccountPattern = '^(svc-|msol_|psm|.*\$$)'

$candidates = Get-ADUser -Filter { Enabled -eq $true } -SearchBase $SearchBase `
    -Properties LastLogonDate, whenCreated, Description, DistinguishedName |
    Where-Object {
        ($null -eq $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff)
    }

# Split protected service accounts out of the remediation set
$serviceAccounts = @($candidates | Where-Object { $_.SamAccountName -match $serviceAccountPattern })
$humanAccounts   = @($candidates | Where-Object { $_.SamAccountName -notmatch $serviceAccountPattern })

$targets = if ($ExcludeServiceAccounts) { $humanAccounts } else { $candidates }

Write-Host "--- POPULATION ---" -ForegroundColor Cyan
Write-Host ("  Stale accounts found      : {0,3}" -f $candidates.Count)       -ForegroundColor White
Write-Host ("  Service accounts (skipped): {0,3}" -f $serviceAccounts.Count)  -ForegroundColor DarkGray
Write-Host ("  In scope for remediation  : {0,3}" -f $targets.Count)          -ForegroundColor Yellow

if ($serviceAccounts.Count -gt 0 -and $ExcludeServiceAccounts) {
    Write-Host "`n  NOTE: Service accounts are excluded because they authenticate" -ForegroundColor DarkGray
    Write-Host "        non-interactively and never populate LastLogonDate." -ForegroundColor DarkGray
    Write-Host "        Validate these separately via a service-account inventory." -ForegroundColor DarkGray
}

if ($targets.Count -eq 0) {
    Write-Host "`nNo accounts require action.`n" -ForegroundColor Green
    return
}

# Build the report objects
$report = foreach ($account in $targets) {
    [PSCustomObject]@{
        SamAccountName = $account.SamAccountName
        DisplayName    = $account.Name
        LastLogonDate  = if ($account.LastLogonDate) { $account.LastLogonDate.ToString('yyyy-MM-dd') } else { 'NEVER' }
        DaysInactive   = if ($account.LastLogonDate) {
                             [math]::Round((New-TimeSpan -Start $account.LastLogonDate -End (Get-Date)).TotalDays)
                         } else { 'N/A' }
        Created        = $account.whenCreated.ToString('yyyy-MM-dd')
        Action         = if ($Remediate) { 'DISABLE' } else { 'REPORT ONLY' }
    }
}

Write-Host "`n--- ACCOUNTS IN SCOPE ---" -ForegroundColor Cyan
$report | Format-Table SamAccountName, DisplayName, LastLogonDate, DaysInactive -AutoSize

# --- Remediation ---------------------------------------------------------------
if ($Remediate) {
    Write-Host "--- REMEDIATION ---" -ForegroundColor Yellow
    $disabled = 0
    $failed   = 0

    foreach ($account in $targets) {
        if ($PSCmdlet.ShouldProcess($account.SamAccountName, "Disable account")) {
            try {
                Disable-ADAccount -Identity $account.DistinguishedName -ErrorAction Stop

                $note = "Disabled $(Get-Date -Format 'yyyy-MM-dd') - AC-2(3) inactivity >$InactiveDays days"
                Set-ADUser -Identity $account.DistinguishedName -Description $note -ErrorAction SilentlyContinue

                if ($DisabledOU) {
                    Move-ADObject -Identity $account.DistinguishedName -TargetPath $DisabledOU -ErrorAction Stop
                }

                Write-Host ("  [OK]   {0}" -f $account.SamAccountName) -ForegroundColor Green
                $disabled++
            }
            catch {
                Write-Host ("  [FAIL] {0} - {1}" -f $account.SamAccountName, $_.Exception.Message) -ForegroundColor Red
                $failed++
            }
        }
    }

    Write-Host "`n  Disabled: $disabled   Failed: $failed" -ForegroundColor Cyan
}
else {
    Write-Host "Report-only mode. Re-run with -Remediate to disable these accounts." -ForegroundColor DarkGray
    Write-Host "Recommended: test first with  -Remediate -WhatIf`n" -ForegroundColor DarkGray
}

# --- Export --------------------------------------------------------------------
if ($ExportPath) {
    if (-not (Test-Path $ExportPath)) { New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $report | Export-Csv -Path (Join-Path $ExportPath "stale-accounts-$stamp.csv") -NoTypeInformation
    Write-Host "Report written to: $ExportPath" -ForegroundColor Green
}

Write-Host ""
