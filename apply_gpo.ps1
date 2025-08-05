# Start logging
Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check for Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

try {
    Import-Module GroupPolicy -ErrorAction Stop
    $GPOName = "CIS Benchmark - Password Policy-latest"

    $existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $existingGPO) {
        $existingGPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO-latest"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Set password policies in the GPO
    Write-Host "Applying password policies to GPO..."

    Set-GPOption -Name $GPOName -MinimumPasswordLength 14
    Set-GPOption -Name $GPOName -MaximumPasswordAge 30
    Set-GPOption -Name $GPOName -MinimumPasswordAge 1
    Set-GPOption -Name $GPOName -PasswordComplexity Enabled
    Set-GPOption -Name $GPOName -PasswordHistorySize 24
    Set-GPOption -Name $GPOName -LockoutBadCount 5
    Set-GPOption -Name $GPOName -ResetLockoutCount 15
    Set-GPOption -Name $GPOName -LockoutDuration 15

    Write-Host "Password policies successfully configured in the GPO."

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
