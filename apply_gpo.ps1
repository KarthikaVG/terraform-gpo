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
    $domainDN = (Get-ADDomain).DistinguishedName

    # Create GPO if it doesn't exist
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link GPO to the domain
    $linkExists = Get-GPLink -Target $domainDN | Where-Object { $_.DisplayName -eq $GPOName }
    if (-not $linkExists) {
        New-GPLink -Name $GPOName -Target $domainDN -Enforced ([Microsoft.GroupPolicy.EnforceLink]::Yes)
        Write-Host "Linked GPO to domain."
    } else {
        Write-Host "GPO already linked to domain."
    }

    # Set password policy using INF file
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

    $gptPath = "\\$env:USERDNSDOMAIN\SYSVOL\$env:USERDNSDOMAIN\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    Copy-Item $infPath -Destination "$gptPath\GptTmpl.inf" -Force

    Write-Host "Password policy applied successfully to GPO and SYSVOL."

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
