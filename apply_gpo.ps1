Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

$GPOName = "CIS Benchmark - Password Policy-final"
$DomainDN = (Get-ADDomain).DistinguishedName

# Create GPO if not exists
$existing = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $existing) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO"
    Write-Host "Created GPO: $GPOName"
} else {
    $GPO = $existing
    Write-Host "GPO already exists: $GPOName"
}

# Link to domain root with order 1
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPO.DisplayName }
if (-not $link) {
    New-GPLink -Name $GPO.DisplayName -Target $DomainDN -LinkEnabled Yes
}
Set-GPLink -Name $GPO.DisplayName -Target $DomainDN -Order 1
Write-Host "GPO linked to domain with order 1"

# Write INF to temp
$infPath = "$env:TEMP\cis_password_policy.inf"
@"
[System Access]
MinimumPasswordLength = 14
MaximumPasswordAge = 30
MinimumPasswordAge = 1
PasswordComplexity = 1
PasswordHistorySize = 24
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 15
"@ | Set-Content -Path $infPath -Encoding ascii -Force

# Path to LGPO.exe (adjust if needed)
$lgpoExe = "$PSScriptRoot\tools\LGPO.exe"
if (-not (Test-Path $lgpoExe)) {
    Write-Error "LGPO.exe not found at $lgpoExe"
    Stop-Transcript
    exit 1
}

# Apply policy to domain GPO
Start-Process -FilePath $lgpoExe -ArgumentList "/g `"$infPath`"" -Wait -NoNewWindow
Write-Host "Policy applied using LGPO"

gpupdate /force | Out-Null
Write-Host "Group Policy updated"

Stop-Transcript
