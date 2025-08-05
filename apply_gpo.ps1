Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check if running as admin
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

    # Create GPO if not exists
    $GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $GPO) {
        $GPO = New-GPO -Name $GPOName -Comment "Password policy GPO created via script"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link to domain
    $targetOU = "DC=" + ($domainParts -join ",DC=")
    New-GPLink -Name $GPOName -Target $targetOU -Enforced Yes

    # Create INF file
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

    # Backup GPO to a temp path
    $tempGpoPath = "$PSScriptRoot\GPOBackup"
    Backup-GPO -Name $GPOName -Path $tempGpoPath -Force

    # Get GUID of backed-up GPO
    $gpoGuid = (Get-ChildItem $tempGpoPath)[0].Name

    # Import INF to GPO using Secedit
    $importCmd = "secedit.exe /configure /db secedit.sdb /cfg `"$infPath`" /quiet"
    Invoke-Expression $importCmd

    # Copy INF manually to SYSVOL for visibility in GPMC
    $gptPath = "\\$domain\SYSVOL\$domain\Policies\{$($GPO.Id)}\MACHINE\Microsoft\Windows NT\SecEdit"
    New-Item -ItemType Directory -Path $gptPath -Force | Out-Null
    Copy-Item -Path $infPath -Destination "$gptPath\GptTmpl.inf" -Force

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
