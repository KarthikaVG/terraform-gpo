Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

# Confirm script is running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "You must run this script as Administrator."
    Stop-Transcript
    exit 1
}

Import-Module GroupPolicy

$GPOName = "CIS Benchmark - Password Policy-latest"
$DomainDN = (Get-ADDomain).DistinguishedName  # e.g., DC=mydomain,DC=local

# Step 1: Create the GPO if it doesn't exist
$existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($null -eq $existingGPO) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark-aligned password policy"
    Write-Host "Created new GPO: $GPOName"
} else {
    $GPO = $existingGPO
    Write-Host "GPO already exists: $GPOName"
}

# Step 2: Link the GPO to the domain root
$link = Get-GPLink -Target $DomainDN | Where-Object { $_.GPOName -eq $GPO.DisplayName }
if (-not $link) {
    New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes
    Write-Host "Linked GPO to domain root: $DomainDN"
} else {
    Write-Host "GPO is already linked to the domain root."
}

# Step 3: Apply password policies using Set-GPAccountPolicy
try {
    Set-GPAccountPolicy -Name $GPOName `
        -MinimumPasswordLength 14 `
        -MaximumPasswordAge 30 `
        -PasswordComplexity Enabled `
        -PasswordHistorySize 24 `
        -MinimumPasswordAge 1 `
        -LockoutBadCount 5 `
        -ResetLockoutCount 15 `
        -LockoutDuration 15

    Write-Host "Password policies applied to GPO correctly."
} catch {
    Write-Error "Failed to apply password policy. $_"
    Stop-Transcript
    exit 1
}

gpupdate /force | Out-Null
Write-Host "Group Policy updated successfully."

Stop-Transcript
