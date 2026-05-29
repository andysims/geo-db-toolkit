param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("portal", "agol")]
    [string]$Source,

    [Parameter(Mandatory=$true)]
    [string]$Username
)

# ---------------------------------------------------------
# Load .env
# ---------------------------------------------------------
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
    throw ".env file not found at $envPath"
}

$envData = @{}
Get-Content -Path $envPath |
    Where-Object { $_ -match "=" -and $_ -notmatch "^\s*#" } |
    ForEach-Object {
        $parts = $_ -split "=", 2
        $envData[$parts[0].Trim()] = $parts[1].Trim()
    }

$prefix = $Source
$BaseUrl  = $envData["${prefix}_url"]
$UsernameEnv = $envData["${prefix}_username"]
$PasswordEnv = $envData["${prefix}_password"]

if (-not $BaseUrl -or -not $UsernameEnv -or -not $PasswordEnv) {
    throw "Missing required environment variables for prefix '$prefix'."
}

# ---------------------------------------------------------
# Token
# ---------------------------------------------------------
Write-Host "Generating token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
    username = $UsernameEnv
    password = $PasswordEnv
    client   = "requestip"
    f        = "json"
} -ErrorAction Stop

$Token = $tokenResponse.token
if (-not $Token) {
    throw "Failed to generate token."
}

# ---------------------------------------------------------
# Helper: Format epoch
# ---------------------------------------------------------
function Format-Date($ms) {
    if ($ms -and $ms -gt 0) {
        return ([datetime]'1970-01-01').AddMilliseconds($ms).ToString("MM/dd/yyyy hh:mm:ss tt")
    }
    return "Never"
}

# ---------------------------------------------------------
# Fetch user profile
# ---------------------------------------------------------
Write-Host "Fetching user '$Username' from $Source..." -ForegroundColor Cyan

$userUri = "$BaseUrl/sharing/rest/community/users/$Username"
$user = $null

try {
    $user = Invoke-RestMethod -Method Get -Uri $userUri -Body @{
        f     = "json"
        token = $Token
    } -ErrorAction Stop
}
catch {
    Write-Host "User '$Username' does not exist in $Source." -ForegroundColor Yellow
    exit
}

if ($user.error) {
    Write-Host "User '$Username' does not exist in $Source." -ForegroundColor Yellow
    exit
}

# ---------------------------------------------------------
# Fetch orgId
# ---------------------------------------------------------
$portalSelf = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self" -Body @{
    f="json"
    token=$Token
}
$OrgId = $portalSelf.id

# ---------------------------------------------------------
# Fetch group count
# ---------------------------------------------------------
$groupInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$Username" -Body @{
    f     = "json"
    token = $Token
}

$GroupCount = ($groupInfo.groups | Measure-Object).Count

# ---------------------------------------------------------
# Fetch owned content count
# ---------------------------------------------------------
$contentInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/content/users/$Username" -Body @{
    f     = "json"
    token = $Token
}

$ContentCount = ($contentInfo.items | Measure-Object).Count

# ---------------------------------------------------------
# Fetch AGOL License Type (AGOL only)
# ---------------------------------------------------------
$LicenseTypeId = "N/A"
$LicenseTypeName = "N/A"

try {
    $licenseResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$Username/userLicenseType" -Body @{
        f     = "json"
        token = $Token
    }

    if ($licenseResp.id) {
        $LicenseTypeId = $licenseResp.id
        $LicenseTypeName = $licenseResp.name
    }
}
catch {
    # Portal or no license assigned
    $LicenseTypeId = "N/A"
    $LicenseTypeName = "N/A"
}

# ---------------------------------------------------------
# Output
# ---------------------------------------------------------
Write-Host "`nUser Information for '$Username' ($Source)" -ForegroundColor Green
Write-Host "-----------------------------------------------------"
Write-Host "First Name        : $($user.firstName)"
Write-Host "Last Name         : $($user.lastName)"
Write-Host "Email             : $($user.email)"
Write-Host "IdpUsername       : $($user.idpUsername)"
Write-Host "Created           : $(Format-Date $user.created)"
Write-Host "Last Login        : $(Format-Date $user.lastLogin)"
Write-Host "Role              : $($user.role)"
Write-Host "License Type ID   : $LicenseTypeId"
Write-Host "License Type Name : $LicenseTypeName"
Write-Host "Group Count       : $GroupCount"
Write-Host "Owned Content     : $ContentCount"
Write-Host "Org ID            : $OrgId"
Write-Host "Disabled          : $($user.disabled)"
Write-Host "Access            : $($user.access)"
Write-Host "Provider          : $($user.provider)"
Write-Host "Available Credits : $($user.availableCredits)"
Write-Host "Assigned Credits  : $($user.assignedCredits)"
Write-Host ""
