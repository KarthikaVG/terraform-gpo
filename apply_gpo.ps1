Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

# Check if run as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Script must be run as Administrator."
    Stop-Transcript
    exit 1
}

# Import GroupPolicy module
try {
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Error "GroupPolicy module not found. Please install GPMC tools."
    Stop-Transcript
    exit 1
}

# Set GPO name and domain info
$GPOName = "CIS Benchmark - Password Policy-latest"
$DomainDN = (Get-ADDomain).DistinguishedName
$DomainDNS = (Get-ADDomain).DNSRoot

# Create GPO if not already present
$existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($null -eq $existingGPO) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark-aligned password policy"
    Write-Host "Created GPO: $GPOName"
} else {
    $GPO = $existingGPO
    Write-Host "GPO already exists: $GPOName"
}

# Link GPO to domain root and set Order = 1
try {
    $linked = Get-GPInheritance -Target $DomainDN | Select-Object -ExpandProperty GpoLinks | Where-Object { $_.DisplayName -eq $GPOName }
    if (-not $linked) {
        New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes
        Write-Host "Linked GPO to domain root: $DomainDN"
    } else {
        Write-Host "GPO already linked."
    }

    Set-GPLink -Name $GPOName -Target $DomainDN -Order 1
    Write-Host "Set GPO link order to 1"
} catch {
    Write-Error "Error linking or ordering GPO. $_"
    Stop-Transcript
    exit 1
}

# Inject password policy into GptTmpl.inf
try {
    $GPOGuid = $GPO.Id.Guid
    $secEditPath = "\\$DomainDNS\SYSVOL\$DomainDNS\Policies\{$GPOGuid}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $secEditPath -Force | Out-Null

    $infContent = @"
[System Access]
MinimumPasswordLength = 14
MaximumPasswordAge = 30
MinimumPasswordAge = 1
PasswordComplexity = 1
PasswordHistorySize = 24
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 15
"@

    $infPath = Join-Path $secEditPath "GptTmpl.inf"
    $infContent | Set-Content -Path $infPath -Encoding ascii -Force

    Write-Host "Injected GptTmpl.inf into GPO at: $infPath"
} catch {
    Write-Error "Failed to inject GptTmpl.inf. $_"
    Stop-Transcript
    exit 1
}

# Force group policy refresh
gpupdate /force | Out-Null
Write-Host "Group Policy update completed."

Stop-Transcript
