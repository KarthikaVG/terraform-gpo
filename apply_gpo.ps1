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

    # Apply password/account policies to the GPO using correct registry keys
    Write-Host "Applying password policies to GPO..."

    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "MinimumPasswordLength" -Type DWord -Value 14
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "PasswordHistorySize" -Type DWord -Value 24
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "PasswordComplexity" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "MinimumPasswordAge" -Type DWord -Value 1
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "MaximumPasswordAge" -Type DWord -Value 30
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "LockoutBadCount" -Type DWord -Value 5
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "LockoutDuration" -Type DWord -Value 15
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SAM\SAM\Domains\Account" -ValueName "ResetLockoutCount" -Type DWord -Value 15

    Write-Host "Password policies successfully configured in the GPO."

    $targetOU = "DC=mydomain,DC=local"
    New-GPLink -Name $GPOName -Target $targetOU -Enforced Yes -ErrorAction SilentlyContinue

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
