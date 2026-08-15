<#
.SYNOPSIS
    Role mining over a synthetic identity population.

.DESCRIPTION
    Generates a realistic set of identities with departments, titles, and the
    kind of messy, accreted entitlements real directories accumulate, then mines
    that population to PROPOSE role-based access control (RBAC) roles:

      - Discovers common entitlement patterns by department/title
      - Proposes candidate roles that would cover the majority of access
      - Flags over-provisioning (entitlements a user has that their peers do not)
      - Reports coverage: how much standing access a role model would replace

    This demonstrates role DESIGN (mining existing access to build roles),
    not just role assignment. It is the analysis an IGA program runs before
    rolling out RBAC.

    Read-only analysis. Generates its own data. Makes no directory changes.

.PARAMETER Population
    Number of synthetic identities to generate (default 1000).

.PARAMETER OverProvisionThreshold
    An entitlement held by fewer than this fraction of a peer group is flagged
    as potential over-provisioning (default 0.15 = 15%).

.EXAMPLE
    .\Invoke-RoleMining.ps1 -Population 1000
#>

[CmdletBinding()]
param(
    [int]$Population = 1000,
    [double]$OverProvisionThreshold = 0.15
)

# ---------------------------------------------------------------------------
# 1. Generate a realistic synthetic population
# ---------------------------------------------------------------------------
$departments = @{
    "Finance"     = @("Analyst","Senior Analyst","Manager","Controller","AP Clerk")
    "Engineering" = @("Engineer","Senior Engineer","Staff Engineer","Eng Manager","SRE")
    "Sales"       = @("Rep","Senior Rep","Account Exec","Sales Manager","SDR")
    "HR"          = @("Generalist","Recruiter","HR Manager","HRBP")
    "IT"          = @("Support","Sysadmin","IAM Analyst","IT Manager","Security Analyst")
    "Legal"       = @("Counsel","Paralegal","Legal Manager")
    "Marketing"   = @("Coordinator","Specialist","Marketing Manager","Content Lead")
    "Operations"  = @("Coordinator","Ops Analyst","Ops Manager","Logistics")
}

# Baseline (birthright) entitlements everyone gets
$birthright = @("app-email","app-sso-portal","net-vpn","dir-domain-users")

# Department-driven entitlements (the "should be a role" patterns)
$deptEntitlements = @{
    "Finance"     = @("app-erp","app-expense","fs-finance-share","app-billing")
    "Engineering" = @("app-git","app-ci","cloud-dev","app-jira","app-pagerduty")
    "Sales"       = @("app-crm","app-quoting","fs-sales-share")
    "HR"          = @("app-hris","fs-hr-share","app-ats")
    "IT"          = @("app-itsm","priv-admin-console","app-monitoring")
    "Legal"       = @("app-clm","fs-legal-share","app-esign")
    "Marketing"   = @("app-cms","app-analytics","fs-marketing-share")
    "Operations"  = @("app-wms","fs-ops-share","app-scheduling")
}

# Title-driven extras (manager-level access)
$titleEntitlements = @{
    "Manager"    = @("app-approvals","report-team-dashboard")
    "Controller" = @("app-approvals","app-gl-admin")
    "IAM Analyst"= @("priv-identity-console","app-cert-campaigns")
}

Write-Host "`nGenerating $Population synthetic identities..." -ForegroundColor Cyan
$rand = [System.Random]::new(42)   # fixed seed = reproducible
$identities = for ($i = 1; $i -le $Population; $i++) {
    $dept  = $departments.Keys   | Get-Random -Count 1
    $title = $departments[$dept] | Get-Random -Count 1

    $ent = [System.Collections.Generic.HashSet[string]]::new()
    $birthright             | ForEach-Object { [void]$ent.Add($_) }
    $deptEntitlements[$dept]| ForEach-Object { [void]$ent.Add($_) }
    foreach ($k in $titleEntitlements.Keys) {
        if ($title -like "*$k*") { $titleEntitlements[$k] | ForEach-Object { [void]$ent.Add($_) } }
    }

    # Inject realistic MESS: ~12% of users carry a stray entitlement from
    # another department (access that accreted from a transfer or one-off request)
    if ($rand.NextDouble() -lt 0.12) {
        $otherDept = $deptEntitlements.Keys | Get-Random -Count 1
        $stray = $deptEntitlements[$otherDept] | Get-Random -Count 1
        [void]$ent.Add($stray)
    }

    [PSCustomObject]@{
        User        = "user{0:D4}" -f $i
        Department  = $dept
        Title       = $title
        Entitlements= $ent
    }
}

# ---------------------------------------------------------------------------
# 2. Mine candidate roles by department
# ---------------------------------------------------------------------------
Write-Host "Mining entitlement patterns by department...`n" -ForegroundColor Cyan

$candidateRoles = foreach ($dept in ($identities.Department | Sort-Object -Unique)) {
    $members = $identities | Where-Object Department -eq $dept
    $count   = $members.Count

    # Count how many members hold each entitlement
    $freq = @{}
    foreach ($m in $members) {
        foreach ($e in $m.Entitlements) {
            if (-not $freq.ContainsKey($e)) { $freq[$e] = 0 }
            $freq[$e]++
        }
    }

    # An entitlement held by >=85% of the department is a strong role candidate
    $coreEnt = $freq.GetEnumerator() |
        Where-Object { ($_.Value / $count) -ge 0.85 } |
        Sort-Object Value -Descending |
        Select-Object -ExpandProperty Key

    [PSCustomObject]@{
        ProposedRole = "role-$($dept.ToLower())-base"
        Department   = $dept
        Members      = $count
        CoreEntitlements = ($coreEnt -join ", ")
        EntitlementCount = $coreEnt.Count
    }
}

# ---------------------------------------------------------------------------
# 3. Detect over-provisioning (entitlements peers do not share)
# ---------------------------------------------------------------------------
$overProvisioned = foreach ($dept in ($identities.Department | Sort-Object -Unique)) {
    $members = $identities | Where-Object Department -eq $dept
    $count   = $members.Count
    $freq = @{}
    foreach ($m in $members) { foreach ($e in $m.Entitlements) {
        if (-not $freq.ContainsKey($e)) { $freq[$e] = 0 }; $freq[$e]++
    }}
    foreach ($m in $members) {
        foreach ($e in $m.Entitlements) {
            if (($freq[$e] / $count) -lt $OverProvisionThreshold) {
                [PSCustomObject]@{ User=$m.User; Department=$dept; Title=$m.Title; StrayEntitlement=$e }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Report
# ---------------------------------------------------------------------------
$totalEnt = ($identities | ForEach-Object { $_.Entitlements.Count } | Measure-Object -Sum).Sum
$roleCoveredEnt = ($candidateRoles | ForEach-Object { $_.EntitlementCount * $_.Members } | Measure-Object -Sum).Sum
$coverage = [math]::Round(($roleCoveredEnt / $totalEnt) * 100, 1)

Write-Host "=== ROLE MINING REPORT ===" -ForegroundColor Green
Write-Host ("Population              : {0} identities" -f $Population)
Write-Host ("Departments             : {0}" -f ($identities.Department | Sort-Object -Unique).Count)
Write-Host ("Total entitlement grants: {0}" -f $totalEnt)
Write-Host ("Proposed base roles     : {0}" -f $candidateRoles.Count)
Write-Host ("Access covered by roles : {0}%" -f $coverage) -ForegroundColor Yellow
Write-Host ""
Write-Host "--- PROPOSED ROLES ---" -ForegroundColor Cyan
$candidateRoles | Format-Table ProposedRole, Members, EntitlementCount, CoreEntitlements -AutoSize -Wrap

Write-Host "--- OVER-PROVISIONING (entitlements <$([int]($OverProvisionThreshold*100))% of peers hold) ---" -ForegroundColor Cyan
Write-Host ("Flagged grants: {0}  (these are candidates for review/removal)`n" -f $overProvisioned.Count) -ForegroundColor Yellow
$overProvisioned | Select-Object -First 15 | Format-Table User, Department, StrayEntitlement -AutoSize
if ($overProvisioned.Count -gt 15) { Write-Host ("... (+{0} more)" -f ($overProvisioned.Count - 15)) -ForegroundColor DarkGray }

Write-Host "`nInterpretation:" -ForegroundColor Green
Write-Host "  A role model built from these $($candidateRoles.Count) base roles would replace ~$coverage% of" 
Write-Host "  standing individual grants with role membership. The over-provisioned"
Write-Host "  grants are exactly what an access certification campaign should target."
Write-Host "  No identities were modified - this is analysis only.`n" -ForegroundColor DarkGray
