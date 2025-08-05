# Start logging
Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# Check if user is Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    Stop-Transcript
    exit 1
}

try {
    # Import GroupPolicy module
    Import-Module GroupPolicy -ErrorAction Stop

    $GPOName = "CIS Benchmark - Password Policy-latest"

    # Check if the GPO already exists
    $existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue

    if ($null -eq $existingGPO) {
        # Create the GPO if it doesn't exist
        $GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO-latest"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Set password policy settings
    Write-Host "Setting password policies..."
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MaximumPasswordAge" -Type Dword -Value 30
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MinimumPasswordLength" -Type Dword -Value 14
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "PasswordComplexity" -Type Dword -Value 1

    Write-Host "Password policy settings applied."

    # Force update group policy
    gpupdate /force | Out-Null
    Write-Host "Group Policy updated successfully."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."

Stop-Transcript
