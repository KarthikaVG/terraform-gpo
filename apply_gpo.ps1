# Start logging
Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check admin
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
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue

    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link to domain only if not already linked
    $domainDN = (Get-ADDomain).DistinguishedName
    $existingLinks = (Get-GPInheritance -Target $domainDN).GpoLinks
    $alreadyLinked = $existingLinks | Where-Object { $_.DisplayName -eq $GPOName }

    if (-not $alreadyLinked) {
        New-GPLink -Name $GPOName -Target $domainDN -LinkEnabled Yes -Enforced Yes
        Write-Host "Linked GPO to domain: $domainDN"
    } else {
        Write-Host "GPO already linked to domain. Skipping link step."
    }

    # Write password policy INF content
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

    # Deploy INF to SYSVOL GPT path
    $gptPath = "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    Copy-Item $infPath -Destination "$gptPath\GptTmpl.inf" -Force

    Write-Host "Password policy INF deployed to GPO SYSVOL path."

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "GPO applied successfully"
Stop-Transcript
