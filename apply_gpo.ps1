# Start transcript logging
Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Ensure script is running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

try {
    # Load required module
    Import-Module GroupPolicy -ErrorAction Stop

    $GPOName = "CIS Benchmark - Password Policy-latest"
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue

    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link GPO to domain if not already linked
    $existingLinks = (Get-GPInheritance -Target $domain.DNSRoot).GpoLinks
    if (-not ($existingLinks | Where-Object { $_.DisplayName -eq $GPOName })) {
        New-GPLink -Name $GPOName -Target $domain.DistinguishedName -Enforced:$true
        Write-Host "Linked GPO to domain."
    } else {
        Write-Host "GPO already linked to domain."
    }

    # Prepare SecEdit-compatible INF content
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

    # Export INF
    $infPath = "$PSScriptRoot\PasswordPolicy.inf"
    $inf | Out-File -Encoding ASCII -FilePath $infPath -Force

    # Copy INF to SYSVOL GPT location
    $gptPath = "\\$($domain.DNSRoot)\SYSVOL\$($domain.DNSRoot)\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    Copy-Item $infPath -Destination "$gptPath\GptTmpl.inf" -Force
    Write-Host "INF copied to SYSVOL path."

    # Update policies
    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
