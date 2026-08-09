<#
.SYNOPSIS
    Reconciles Active Directory accounts against the authoritative HR source.

.DESCRIPTION
    Addresses audit finding F-01 (accounts not traceable to an authoritative source)
    and F-06 (accounts created outside the governed provisioning process).

    Compares every enabled AD account against the authoritative HR feed and
    classifies each account as:
      MATCHED     - account exists in HR source, governed
      UNMATCHED   - account has no HR record, requires owner assignment or removal
      MISSING     - HR record exists but no AD account (provisioning gap)

    Read-only by default. Use -ExportPath to write findings to CSV for review.

.PARAMETER HRSourcePath
    Path to the authoritative HR CSV. Must contain a sam_account column.

.PARAMETER SearchBase
    Distinguished name of the OU to audit.

.PARAMETER ExportPath
    Optional. Directory to write reconciliation reports.

.EXAMPLE
    .\Invoke-IdentityReconciliation.ps1 -HRSourcePath "C:\IAM\worknyte_authoritative.csv"

.EXAMPLE
    .\Invoke-IdentityReconciliation.ps1 -HRSourcePath "C:\IAM\hr.csv" -ExportPath "C:\IAM\reports"

.NOTES
    Author : Andrew Symister
    Control: NIST SP 800-53 AC-2 (Account Management)
    Safety : Read-only. Makes no changes to Active Directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$HRSourcePath,

    [Parameter(Mandatory = $false)]
    [string]$SearchBase = "DC=Link3IT,DC=com",

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== IDENTITY RECONCILIATION ===" -ForegroundColor Cyan
Write-Host "Control: NIST SP 800-53 AC-2 | Mode: READ-ONLY`n" -ForegroundColor DarkGray

# --- Load authoritative source -------------------------------------------------
try {
    $hrRecords = Import-Csv -Path $HRSourcePath
}
catch {
    Write-Error "Failed to read HR source: $_"
    exit 1
}

if (-not ($hrRecords | Get-Member -Name 'sam_account')) {
    Write-Error "HR source must contain a 'sam_account' column. Found: $(($hrRecords | Get-Member -MemberType NoteProperty).Name -join ', ')"
    exit 1
}

# Build a lookup for fast comparison (case-insensitive)
$hrLookup = @{}
foreach ($record in $hrRecords) {
    if (-not [string]::IsNullOrWhiteSpace($record.sam_account)) {
        $hrLookup[$record.sam_account.Trim().ToLower()] = $record
    }
}

Write-Host "Authoritative source : $($hrLookup.Count) records" -ForegroundColor White

# --- Load directory population -------------------------------------------------
$adAccounts = Get-ADUser -Filter { Enabled -eq $true } -SearchBase $SearchBase `
    -Properties LastLogonDate, whenCreated, Description, DistinguishedName

Write-Host "Directory (enabled)  : $($adAccounts.Count) accounts`n" -ForegroundColor White

# --- Classify ------------------------------------------------------------------
$results = foreach ($account in $adAccounts) {

    $sam = $account.SamAccountName.ToLower()
    $inHR = $hrLookup.ContainsKey($sam)

    # Heuristic classification to avoid treating service accounts like human ones
    $accountType = switch -Regex ($sam) {
        '^(svc-|msol_|psm)'          { 'Service';  break }
        '(test|temp|placeholder)'    { 'Test';     break }
        '^(soc-|iam-|helpdesk|.*-mgr$|.*-manager$)' { 'Shared/Functional'; break }
        default                      { 'Human' }
    }

    $daysSinceLogon = if ($account.LastLogonDate) {
        [math]::Round((New-TimeSpan -Start $account.LastLogonDate -End (Get-Date)).TotalDays)
    } else { $null }

    [PSCustomObject]@{
        SamAccountName = $account.SamAccountName
        DisplayName    = $account.Name
        AccountType    = $accountType
        Status         = if ($inHR) { 'MATCHED' } else { 'UNMATCHED' }
        LastLogonDate  = $account.LastLogonDate
        DaysInactive   = $daysSinceLogon
        Created        = $account.whenCreated
        OU             = ($account.DistinguishedName -split ',OU=')[1]
        Finding        = if (-not $inHR) { 'F-01 no authoritative record' } else { '' }
    }
}

# --- Provisioning gaps (HR record exists, no AD account) -----------------------
$adSamList = $adAccounts.SamAccountName.ToLower()
$missing = foreach ($key in $hrLookup.Keys) {
    if ($adSamList -notcontains $key) {
        [PSCustomObject]@{
            SamAccountName = $hrLookup[$key].sam_account
            DisplayName    = $hrLookup[$key].full_name
            AccountType    = 'Unknown'
            Status         = 'MISSING'
            LastLogonDate  = $null
            DaysInactive   = $null
            Created        = $null
            OU             = 'N/A'
            Finding        = 'HR record with no AD account (provisioning gap)'
        }
    }
}

$all = @($results) + @($missing)

# --- Summary -------------------------------------------------------------------
$matched   = @($all | Where-Object Status -eq 'MATCHED')
$unmatched = @($all | Where-Object Status -eq 'UNMATCHED')
$missingAc = @($all | Where-Object Status -eq 'MISSING')

Write-Host "--- RESULTS ---" -ForegroundColor Cyan
Write-Host ("  MATCHED   : {0,3}  (governed by authoritative source)" -f $matched.Count)   -ForegroundColor Green
Write-Host ("  UNMATCHED : {0,3}  (F-01 - no HR record)" -f $unmatched.Count)              -ForegroundColor Red
Write-Host ("  MISSING   : {0,3}  (HR record, no account)" -f $missingAc.Count)            -ForegroundColor Yellow

if ($unmatched.Count -gt 0) {
    Write-Host "`n--- UNMATCHED BY TYPE ---" -ForegroundColor Cyan
    $unmatched | Group-Object AccountType | Sort-Object Count -Descending | ForEach-Object {
        Write-Host ("  {0,-18} {1,3}" -f $_.Name, $_.Count) -ForegroundColor Yellow
    }

    Write-Host "`n--- UNMATCHED ACCOUNTS ---" -ForegroundColor Cyan
    $unmatched | Sort-Object AccountType, SamAccountName |
        Format-Table SamAccountName, AccountType, DaysInactive, OU -AutoSize
}

# --- Export --------------------------------------------------------------------
if ($ExportPath) {
    if (-not (Test-Path $ExportPath)) { New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    $all       | Export-Csv -Path (Join-Path $ExportPath "reconciliation-full-$stamp.csv")      -NoTypeInformation
    $unmatched | Export-Csv -Path (Join-Path $ExportPath "reconciliation-unmatched-$stamp.csv") -NoTypeInformation

    Write-Host "`nReports written to: $ExportPath" -ForegroundColor Green
}

Write-Host "`nNo changes were made to Active Directory.`n" -ForegroundColor DarkGray
