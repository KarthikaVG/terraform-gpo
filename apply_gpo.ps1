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

    $GPOName = "CIS Benchmark - Password Policy-latest"
    $domainDN = (Get-ADDomain).DistinguishedName  # e.g., dc=corp,dc=local

    # Create or get existing GPO
    $gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO-latest"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Link GPO to domain root
    New-GPLink -Name $GPOName -Target $domainDN -Enforced $true

    Write-Host "Linking GPO to domain root: $domainDN"

    # Password policies
    Write-Host "Setting password policy registry values..."

    $basePath = "HKLM\System\CurrentControlSet\Control\Lsa"

    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "MinimumPasswordLength" -Type Dword -Value 14
    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "MaximumPasswordAge" -Type Dword -Value 30
    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "MinimumPasswordAge" -Type Dword -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "PasswordComplexity" -Type Dword -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "PasswordHistorySize" -Type Dword -Value 24
    Set-GPRegistryValue -Name $GPOName -Key "$basePath" -ValueName "LockoutBadCount" -Type Dword -Value 5

    Write-Host "Password policy registry values set in GPO."

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "GPO created and password policy applied successfully."
Stop-Transcript
