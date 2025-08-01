# Apply CIS Benchmark GPO settings

$GPOName = "CIS Benchmark - Password Policy"

# Import the GroupPolicy module
Import-Module GroupPolicy

# Create the GPO
$GPO = New-GPO -Name $GPOName -Comment "CIS Benchmark compliance"

# Set password policy settings
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MaximumPasswordAge" -Type Dword -Value 30
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MinimumPasswordLength" -Type Dword -Value 14
Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "PasswordComplexity" -Type Dword -Value 1

# Force update group policy
gpupdate /force

Write-Output "CIS Benchmark GPO applied successfully."