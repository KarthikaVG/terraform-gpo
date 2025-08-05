Start-Transcript -Path "$PSScriptRoot\apply_gpo_log.txt" -Append

# Confirm script is running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "You must run this script as Administrator."
    Stop-Transcript
    exit 1
}

try {
    # Import required module
    Import-Module GroupPolicy -ErrorAction Stop
} catch {
    Write-Error "GroupPolicy module not found. Ensure GPMC is installed on this system."
    Stop-Transcript
    exit 1
}

# Set GPO and domain info
$GPOName = "CIS Benchmark - Password Policy-latest"
$DomainDN = (Get-ADDomain).DistinguishedName  # e.g., DC=mydomain,DC=local

# Create the GPO if it doesn't already exist
$existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if ($null -eq $existingGPO) {
    $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark-aligned password policy"
    Write-Host "Created new GPO: $GPOName"
} else {
    $GPO = $existingGPO
    Write-Host "GPO already exists: $GPOName"
}

# Link the GPO to the domain root if not already linked
try {
    $linked = Get-GPInheritance -Target $DomainDN | Select-Object -ExpandProperty GpoLinks | Where-Object { $_.DisplayName -eq $GPO.DisplayName }
    if (-not $linked) {
        New-GPLink -Name $GPOName -Target $DomainDN -LinkEnabled Yes
        Write-Host "Linked GPO to domain root: $DomainDN"
    } else {
        Write-Host "GPO is already linked to the domain root."
    }

    # Set GPO link order to 1 (highest priority)
    Set-GPLink -Name $GPOName -Target $DomainDN -Order 1
    Write-Host "Set GPO link order to 1 for highest precedence."
} catch {
    Write-Error "Error linking or reordering GPO. $_"
    Stop-Transcript
    exit 1
}

# Create and apply password policy INF file locally (for enforcement on DC)
$infPath = "$PSScriptRoot\CIS_password_policy.inf"

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
"@ | Out-File -FilePath $infPath -Encoding ascii -Force

try {
    secedit /configure /db "$env:windir\security\database\cis.sdb" /cfg $infPath /quiet
    Write-Host "Password policies applied locally via INF (effective on DC)."
} catch {
    Write-Error "Failed to apply INF-based password policy. $_"
    Stop-Transcript
    exit 1
}

# Force group policy update
gpupdate /force | Out-Null
Write-Host "Group Policy updated successfully."

Stop-Transcript
