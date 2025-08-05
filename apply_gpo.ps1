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

    # Check or create GPO
    $existingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
    if (-not $existingGPO) {
        $existingGPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance GPO-latest"
        Write-Host "Created GPO: $GPOName"
    } else {
        Write-Host "GPO already exists: $GPOName"
    }

    # Optional: Link GPO to the domain root or OU
    $targetOU = "DC=mydomain,DC=local"  
    Set-GPLink -Name $GPOName -Target $targetOU -Enforced ([Microsoft.GroupPolicy.EnforceLink]::Yes)
    Write-Host "Linked GPO to $targetOU with Enforced = Yes"

    # Apply password policy settings (example)
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\System\CurrentControlSet\Control\Lsa" -ValueName "LimitBlankPasswordUse" -Type DWord -Value 1

    # Update policy
    gpupdate /force | Out-Null
    Write-Host "Group Policy updated successfully."

} catch {
    Write-Error "An error occurred: $_"
    Stop-Transcript
    exit 1
}

Write-Host "CIS Benchmark GPO applied successfully."
Stop-Transcript
