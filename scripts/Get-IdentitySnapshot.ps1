<#
.SYNOPSIS
    One-command identity triage snapshot for Active Directory (and optionally Entra).

.DESCRIPTION
    Answers the first questions of almost every IAM investigation in a single call:
      - Is the account enabled?
      - When did they last log on?
      - Is it locked out? expired?
      - What groups are they in?
      - When was the object last changed?

    Built from the real triage pattern used before diving into connector logs or
    provisioning workflows: validate the identity object first. Accepts a
    sAMAccountName OR an email address (falls back to -Filter on mail automatically),
    which covers the common case where all you have is an email.

.PARAMETER User
    sAMAccountName, UPN, or email address of the user to inspect.

.PARAMETER ShowGroups
    Expand and list group memberships (default shows the count and first few).

.EXAMPLE
    .\Get-IdentitySnapshot.ps1 -User dokafor

.EXAMPLE
    .\Get-IdentitySnapshot.ps1 -User "dana.okafor@link3it.com" -ShowGroups

.NOTES
    Author : Andrew Symister
    Purpose: Fast, read-only identity triage. Makes no changes.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$User,

    [switch]$ShowGroups
)

Import-Module ActiveDirectory -ErrorAction Stop

# Resolve the account: try -Identity first, fall back to -Filter on mail/UPN
$props = 'Enabled','LastLogonDate','LockedOut','AccountExpirationDate',
         'PasswordLastSet','PasswordExpired','whenCreated','whenChanged',
         'MemberOf','mail','UserPrincipalName','Department','Title'

$account = $null
try {
    $account = Get-ADUser -Identity $User -Properties $props -ErrorAction Stop
}
catch {
    # Not a valid -Identity value (e.g. an email) — search by mail or UPN
    $account = Get-ADUser -Filter "mail -eq '$User' -or userPrincipalName -eq '$User'" -Properties $props -ErrorAction SilentlyContinue
}

if (-not $account) {
    Write-Host "`nNo AD account found for '$User'." -ForegroundColor Red
    Write-Host "Tip: -Identity only accepts sAMAccountName, DN, GUID, or SID." -ForegroundColor DarkGray
    Write-Host "     For an email, this script already falls back to -Filter on mail.`n" -ForegroundColor DarkGray
    return
}

# --- Snapshot ------------------------------------------------------------------
$daysSinceLogon = if ($account.LastLogonDate) {
    [math]::Round((New-TimeSpan -Start $account.LastLogonDate -End (Get-Date)).TotalDays)
} else { 'never' }

Write-Host "`n=== IDENTITY SNAPSHOT ===" -ForegroundColor Cyan
Write-Host ("  Name          : {0}" -f $account.Name)
Write-Host ("  sAMAccountName: {0}" -f $account.SamAccountName)
Write-Host ("  UPN / mail    : {0} / {1}" -f $account.UserPrincipalName, $account.mail)
Write-Host ("  Dept / Title  : {0} / {1}" -f $account.Department, $account.Title)
Write-Host ""

# The four questions
$enabledColor = if ($account.Enabled) { 'Green' } else { 'Red' }
Write-Host ("  Enabled       : {0}" -f $account.Enabled) -ForegroundColor $enabledColor

$lockColor = if ($account.LockedOut) { 'Red' } else { 'Green' }
Write-Host ("  LockedOut     : {0}" -f $account.LockedOut) -ForegroundColor $lockColor

$logonColor = if ($daysSinceLogon -eq 'never' -or $daysSinceLogon -gt 90) { 'Yellow' } else { 'Green' }
Write-Host ("  LastLogon     : {0}  ({1} days ago)" -f $account.LastLogonDate, $daysSinceLogon) -ForegroundColor $logonColor

Write-Host ("  Expires       : {0}" -f $(if ($account.AccountExpirationDate) { $account.AccountExpirationDate } else { 'never' }))
Write-Host ("  Pwd last set  : {0}  (expired: {1})" -f $account.PasswordLastSet, $account.PasswordExpired)
Write-Host ("  Created       : {0}" -f $account.whenCreated)
Write-Host ("  Last changed  : {0}" -f $account.whenChanged)

# Groups
$groups = $account.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' } | Sort-Object
Write-Host ("`n  Groups        : {0} total" -f $groups.Count) -ForegroundColor Cyan
if ($ShowGroups) {
    $groups | ForEach-Object { Write-Host ("    - {0}" -f $_) }
} else {
    $groups | Select-Object -First 5 | ForEach-Object { Write-Host ("    - {0}" -f $_) }
    if ($groups.Count -gt 5) { Write-Host ("    ... (+{0} more; use -ShowGroups)" -f ($groups.Count - 5)) -ForegroundColor DarkGray }
}

# Hybrid reminder
Write-Host "`n  Hybrid note   : this is the ON-PREM view. If this is a synced user," -ForegroundColor DarkGray
Write-Host "                  confirm the Entra state too (Get-MgUser) — disabled" -ForegroundColor DarkGray
Write-Host "                  on-prem does not guarantee disabled in the cloud.`n" -ForegroundColor DarkGray
