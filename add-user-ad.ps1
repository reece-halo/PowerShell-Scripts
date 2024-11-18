# Script created by Reece English on 18/11/2024
# Script is used to add a user to on-premise active directory, add to specified groups and then sync to Azure Active Directory (Entra).

Param(
    [String] $firstName = $null,
    [String] $lastName = $null,
    [String] $samAccountName = $null,
    [Array] $groups = $null,
    [String] $ou = $null,
    [String] $domain = $null,
    [String] $syncToAAD = $null
)

# Define Variables
$password = ConvertTo-SecureString "Password123!" -AsPlainText -Force
$groups = $groups -split ', '

# Logging Configuration
$logDirectory = ".\Scripts"
$logFile = Join-Path $logDirectory "add-user-ad.txt"
$logRetentionMonths = 12

# Function to Log Messages
function Write-Log {
    param (
        [string]$Message,
        [string]$LogType = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$LogType] $Message"
    if ($LogType -eq "ERROR") { Write-Output $logEntry }
    Add-Content -Path $logFile -Value $logEntry
}

# Ensure Log Directory Exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
    Write-Log "Log directory created: $logDirectory"
}

# Script Result Variable
$result = "success"

Write-Log $syncToAAD

# Create the AD User
try {
    Write-Log "Creating user in Active Directory: ${samAccountName}"
    New-ADUser `
        -SamAccountName $samAccountName `
        -UserPrincipalName "${samAccountName}@${domain}" `
        -Name "$firstName $lastName" `
        -GivenName $firstName `
        -Surname $lastName `
        -AccountPassword $password `
        -Enabled $true `
        -Path $ou
    Write-Log "User ${samAccountName} created successfully."
} catch {
    Write-Log "Failed to create user ${samAccountName}: $_" -LogType "ERROR"
    $result = "fail"
}

# Add User to Groups
if ($result -eq "success") {
    foreach ($group in $groups) {
        try {
            Add-ADGroupMember -Identity $group -Members $samAccountName
            Write-Log "Added ${samAccountName} to group ${group}."
        } catch {
            Write-Log "Failed to add ${samAccountName} to group ${group}: $_" -LogType "ERROR"
            $result = "fail"
        }
    }
}

# Force Azure AD Sync
if (($result -eq "success") -and ($syncToAAD -eq "true")) {
    try {
        Write-Log "Forcing Azure AD Sync..."
        Import-Module "C:\Program Files\Microsoft Azure AD Sync\Bin\ADSync" -ErrorAction Stop
        Start-ADSyncSyncCycle -PolicyType Delta
        Write-Log "Azure AD Sync initiated successfully."
    } catch {
        Write-Log "Failed to initiate Azure AD Sync: $_" -LogType "ERROR"
        $result = "fail"
    }
}

# Final Script Status
if ($result -eq "success") {
    Write-Log "Script execution completed successfully."
    return "success"
} else {
    Write-Log "Script execution failed."
    return "fail"
}
