Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

Write-Host ""
Write-Host "CIS GPO Automation Starting"
Write-Host "Running as: $(whoami)"

# Check if running as Administrator
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

# Define GPO
$GPOName = "CIS Benchmark - Password Policy-Demo"

# Check or create GPO
$gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GPOName -Comment "CIS Benchmark Password Policy for Demonstration"
    Write-Host "Created GPO: $GPOName"
} else {
    Write-Host "GPO already exists: $GPOName"
}

# Link GPO to domain root with highest priority
$DomainDN = (Get-ADDomain).DistinguishedName
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPOName }

if (-not $link) {
    New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes
    Write-Host "Linked GPO to domain: $DomainDN"
} else {
    Write-Host "GPO already linked to domain root"
}

# Set GPO Link Order = 1
Set-GPLink -Name $GPOName -Target $DomainDN -Order 1
Write-Host "GPO link order set to 1"

# Apply password policies via registry keys
Write-Host "Applying CIS password policies via registry values..."

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

# Apply account lockout policies
Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "LockoutBadCount" -Type DWord -Value 5

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "ResetLockoutCount" -Type DWord -Value 15

Set-GPRegistryValue -Name $GPOName `
  -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
  -ValueName "LockoutDuration" -Type DWord -Value 15

Write-Host "CIS password and lockout policies successfully applied to GPO: $GPOName"

# Refresh policy
gpupdate /force | Out-Null

Write-Host ""
Write-Host "CIS GPO Automation Completed Successfully"
Stop-Transcript
