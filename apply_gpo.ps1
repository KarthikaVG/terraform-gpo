Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check for Admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

try {
    Import-Module GroupPolicy -ErrorAction Stop
    Import-Module ActiveDirectory -ErrorAction Stop

    $GPOName = "CIS Benchmark - Password Policy-latest"
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $targetOU = $domainDN

    # Create or reuse the GPO
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via automation"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link to domain only if not already linked
    $existingLinks = (Get-GPInheritance -Target "DC=$($domain.Name),DC=$($domain.Forest)") | Select-Object -ExpandProperty GpoLinks
    $linked = $existingLinks | Where-Object { $_.DisplayName -eq $GPOName }
    if (-not $linked) {
        New-GPLink -Name $GPOName -Target $targetOU -Enforced:$true
        Write-Host "GPO linked to domain."
    } else {
        Write-Host "GPO is already linked to domain."
    }

    # Write password policies
    $inf = @"
[Unicode]
Unicode=yes

[System Access]
MinimumPasswordLength = 14
MaximumPasswordAge = 30
MinimumPasswordAge = 1
PasswordHistorySize = 24
PasswordComplexity = 1
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 15
"@

    $infPath = "$PSScriptRoot\PasswordPolicy.inf"
    $inf | Out-File -Encoding ASCII -FilePath $infPath -Force

    $gptPath = "\\$($domain.DNSRoot)\SYSVOL\$($domain.DNSRoot)\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    Copy-Item $infPath -Destination "$gptPath\GptTmpl.inf" -Force

    Write-Host "Password policy written to SYSVOL."

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "GPO applied successfully and visible in GPMC."
Stop-Transcript
