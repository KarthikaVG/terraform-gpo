Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

Write-Host ""
Write-Host "CIS GPO Automation Starting"
Write-Host "Running as: $(whoami)"

# Check for Administrator privilege
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

# Import necessary modules
Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

# Define GPO name
$GPOName = "CIS Benchmark - Password Policy-latest"

# Create GPO if not exists
$existing = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO"
    Write-Host "Created new GPO: $GPOName"
} else {
    $GPO = $existing
    Write-Host "GPO already exists: $GPOName"
}

# Link to domain root with Link Order 1
$DomainDN = (Get-ADDomain).DistinguishedName
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPO.DisplayName }

if (-not $link) {
    New-GPLink -Name $GPO.DisplayName -Target $DomainDN -LinkEnabled Yes
    Write-Host "Linked GPO to domain: $DomainDN"
} else {
    Write-Host "GPO already linked to domain root"
}

# Set GPO Link Order = 1
Set-GPLink -Name $GPO.DisplayName -Target $DomainDN -Order 1
Write-Host "GPO link order set to 1"

# Apply CIS-aligned account policies
Write-Host "Applying CIS Benchmark account policies..."

Set-GPAccountPolicy -Name $GPOName `
  -MinimumPasswordLength 14 `
  -MaximumPasswordAge 30 `
  -MinimumPasswordAge 1 `
  -PasswordComplexity Enabled `
  -PasswordHistorySize 24 `
  -LockoutBadCount 5 `
  -ResetLockoutCount 15 `
  -LockoutDuration 15

Write-Host "Password and lockout policies applied to GPO: $GPOName"

# Force Group Policy update
gpupdate /force | Out-Null
Write-Host "Group Policy refreshed"

Write-Host ""
Write-Host "CIS GPO Automation Completed Successfully"
Stop-Transcript
