Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Admin check
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
    $domain = $env:USERDNSDOMAIN
    $domainParts = $domain -split '\.'
    $domainDN = ($domainParts | ForEach-Object { "DC=$_" }) -join ','
    $targetOU = "DC=" + ($domainParts -join ",DC=")

    # Create GPO if not exists
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Check if GPO is already linked
    $existingLinks = Get-GPInheritance -Target $targetOU
    $isLinked = $existingLinks.GpoLinks | Where-Object { $_.DisplayName -eq $GPOName }

    if (-not $isLinked) {
        New-GPLink -Name $GPOName -Target $targetOU -Enforced $true
        Write-Host "Linked GPO to $targetOU"
    } else {
        Write-Host "GPO is already linked to $targetOU"
    }

    # Create INF
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
    $inf | Out-File -Encoding ASCII -FilePath $infPath

    # Ensure SecEdit folder
    $gptPath = "\\$domain\SYSVOL\$domain\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    if (-not (Test-Path $gptPath)) {
        New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    }

    Copy-Item -Path $infPath -Destination "$gptPath\GptTmpl.inf" -Force
    Write-Host "Copied INF to SYSVOL"

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
