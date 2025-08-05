Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

Write-Host ""
Write-Host "CIS GPO Automation Starting"
Write-Host "Running as: $(whoami)"

# Check if run as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

# Load required modules
Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

# GPO name
$GPOName = "CIS Benchmark - Password Policy-final"

# Create GPO if it doesn't exist
$existing = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO"
    Write-Host "Created new GPO: $GPOName"
} else {
    $GPO = $existing
    Write-Host "GPO already exists: $GPOName"
}

# Link to domain root with order 1
$DomainDN = (Get-ADDomain).DistinguishedName
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPO.DisplayName }

if (-not $link) {
    New-GPLink -Name $GPO.DisplayName -Target $DomainDN -LinkEnabled Yes
    Write-Host "Linked GPO to domain: $DomainDN"
} else {
    Write-Host "GPO already linked"
}

# Set Link Order = 1 (overrides others)
Set-GPLink -Name $GPO.DisplayName -Target $DomainDN -Order 1
Write-Host "GPO link order set to 1"

# --- CIS Benchmark Settings using Set-GPRegistryValue ---

# Password Policies
Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
  -ValueName "MinimumPasswordLength" -Type DWord -Value 14

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
  -ValueName "MaximumPasswordAge" -Type DWord -Value 30

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
  -ValueName "MinimumPasswordAge" -Type DWord -Value 1

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
  -ValueName "PasswordComplexity" -Type DWord -Value 1

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
  -ValueName "PasswordHistorySize" -Type DWord -Value 24

# Lockout Policies
Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "LockoutBadCount" -Type DWord -Value 5

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "ResetLockoutCount" -Type DWord -Value 15

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "LockoutDuration" -Type DWord -Value 15

Write-Host "CIS benchmark registry values applied to GPO"

# Force GP update on local machine (optional)
gpupdate /force | Out-Null

Write-Host "Group Policy refreshed"
Write-Host ""
Write-Host "CIS GPO Automation Completed Successfully"

Stop-Transcript
