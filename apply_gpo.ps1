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
    # Import the GroupPolicy module
    Import-Module GroupPolicy -ErrorAction Stop

    $GPOName = "CIS Benchmark - Password Policy-latest"
    $OU = "DC=mydomain,DC=local"  #

    # Create or get the GPO
    $gpo = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $GPOName -Comment "CIS password policy-latest"
        Write-Host "Created new GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Apply registry-based password policies
    Write-Host "Applying password policy registry settings to GPO..."

    $settings = @(
        @{ Key = "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters"; ValueName = "MaximumPasswordAge"; Type = "DWORD"; Data = 30 },
        @{ Key = "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters"; ValueName = "MinimumPasswordAge"; Type = "DWORD"; Data = 1 },
        @{ Key = "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters"; ValueName = "PasswordHistorySize"; Type = "DWORD"; Data = 24 },
        @{ Key = "HKLM\System\CurrentControlSet\Control\Lsa"; ValueName = "PasswordComplexity"; Type = "DWORD"; Data = 1 },
        @{ Key = "HKLM\System\CurrentControlSet\Control\Lsa"; ValueName = "MinimumPasswordLength"; Type = "DWORD"; Data = 14 },
        @{ Key = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"; ValueName = "LockoutBadCount"; Type = "DWORD"; Data = 5 },
        @{ Key = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"; ValueName = "ResetLockoutCount"; Type = "DWORD"; Data = 15 },
        @{ Key = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"; ValueName = "LockoutDuration"; Type = "DWORD"; Data = 15 }
    )

    foreach ($s in $settings) {
        Set-GPRegistryValue -Name $GPOName -Key $s.Key -ValueName $s.ValueName -Type $s.Type -Value $s.Data
    }

    Write-Host "Registry settings applied to GPO."

    # Link the GPO to the domain
    New-GPLink -Name $GPOName -Target $OU -Enforced:$true

    Write-Host "Linked $GPOName to $OU"

    gpupdate /force | Out-Null
    Write-Host "Group Policy updated."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO successfully created and linked."
Stop-Transcript
