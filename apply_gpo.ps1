Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

Write-Host "`n=== CIS Benchmark GPO Automation Started ==="
Write-Host "Running as: $(whoami)"

# Check for Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "Script must be run as Administrator"
    Stop-Transcript
    exit 1
}

# Load required modules
Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

# Define GPO name
$GPOName = "CIS Benchmark - Password Policy-final"

# Create or reuse GPO
$GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $GPO) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Password Policy Automation"
    Write-Host "Created new GPO: $GPOName"
} else {
    Write-Host "GPO already exists: $GPOName"
}

# Link GPO to domain root
$DomainDN = (Get-ADDomain).DistinguishedName
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPO.DisplayName }

if (-not $link) {
    New-GPLink -Name $GPO.DisplayName -Target $DomainDN -LinkEnabled Yes
    Write-Host "Linked GPO to domain: $DomainDN"
} else {
    Write-Host "GPO already linked"
}

# Set link order to highest priority (1)
Set-GPLink -Name $GPO.DisplayName -Target $DomainDN -Order 1
Write-Host "GPO Link Order set to 1"

# Apply password policy as registry keys (CIS-style)
Write-Host "Applying CIS password registry settings..."

Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "LimitBlankPasswordUse" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "DisableDomainCreds" -Type DWord -Value 1
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MaximumPasswordAge" -Type DWord -Value 30
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MinimumPasswordLength" -Type DWord -Value 14
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "PasswordComplexity" -Type DWord -Value 1

Write-Host "Registry-based CIS policies applied."

# Force GPO update
gpupdate /force | Out-Null
Write-Host "Group Policy refreshed"

Write-Host "`n=== CIS GPO Automation Completed ==="
Stop-Transcript
