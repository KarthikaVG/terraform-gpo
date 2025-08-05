# Start logging
Start-Transcript -Path "$PSScriptRoot\script_output.txt" -Append

Write-Host "Starting GPO script..."
Write-Host "Running as: $(whoami)"

# To check if user is Administrator
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

   # Apply password policy using INF template via LGPO.exe
   Write-Host "Applying CIS-compliant password policies using LGPO.exe..."

   $infPath = "$PSScriptRoot\password_policy.inf"
   $lgpoPath = "$PSScriptRoot\tools\LGPO.exe"

   if (-Not (Test-Path $lgpoPath)) {
       throw "LGPO.exe not found in tools folder. Make sure it's downloaded and placed at: $lgpoPath"
   }

   & $lgpoPath /g $infPath

   Write-Host "Password policy applied using LGPO.exe."


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
