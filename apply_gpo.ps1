Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

try {
    Import-Module GroupPolicy -ErrorAction Stop

    $GPOName = "CIS Benchmark - Password Policy-latest"

    # Get domain name from environment
    $domain = $env:USERDNSDOMAIN
    if (-not $domain) {
        throw "USERDNSDOMAIN environment variable not found. Are you running in a domain-joined machine?"
    }

    # Convert domain to Distinguished Name (DN)
    $domainDN = ($domain -split '\.') | ForEach-Object { "DC=$_" } -join ','

    # Check if GPO exists
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link the GPO to the domain root
    New-GPLink -Name $GPOName -Target $domainDN -Enforced Yes

    # Define password policy
    $infContent = @"
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

    # Save INF file
    $infPath = "$PSScriptRoot\PasswordPolicy.inf"
    $infContent | Out-File -FilePath $infPath -Encoding ASCII -Force

    # Locate GPT folder path
    $gptFolder = "\\$domain\SYSVOL\$domain\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptFolder -Force | Out-Null
    Copy-Item -Path $infPath -Destination "$gptFolder\GptTmpl.inf" -Force

    Write-Host "Password policies applied to SYSVOL for the GPO."

    # Force group policy update
    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
