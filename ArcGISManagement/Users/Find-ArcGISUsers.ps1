param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("portal", "agol")]
    [string]$Source,

    [Parameter(ParameterSetName="Email", Mandatory=$true)]
    [string]$Email,

    [Parameter(ParameterSetName="Username", Mandatory=$true)]
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
# Fetch all users (pagination)
# ---------------------------------------------------------
Write-Host "Fetching users from $Source..." -ForegroundColor Cyan
$AllUsers = @()
$start = 1

while ($true) {
    $page = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self/users" -Body @{
        f     = "json"
        token = $Token
        start = $start
        num   = 100
    } -ErrorAction Stop

    if ($page.users) {
        $AllUsers += $page.users
    }

    if ($page.nextStart -eq -1) { break }
    $start = $page.nextStart
}

# ---------------------------------------------------------
# Filter based on search criteria
# ---------------------------------------------------------
if ($Email) {
    $Matches = $AllUsers | Where-Object { $_.email -eq $Email }
}
elseif ($Username) {
    $Matches = $AllUsers | Where-Object { $_.username -eq $Username }
}

if ($Matches.Count -eq 0) {
    Write-Host "No users found in $Source matching the provided criteria." -ForegroundColor Yellow
    exit
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
# Helper: Fetch AGOL License Type
# ---------------------------------------------------------
function Get-LicenseType($username) {
    $result = @{
        Id   = "N/A"
        Name = "N/A"
    }

    try {
        $resp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$username/userLicenseType" -Body @{
            f     = "json"
            token = $Token
        }

        if ($resp.id) {
            $result.Id   = $resp.id
            $result.Name = $resp.name
        }
    }
    catch {
        # Portal or no license assigned
    }

    return $result
}

# ---------------------------------------------------------
# If exactly one match
# ---------------------------------------------------------
if ($Matches.Count -eq 1) {
    $u = $Matches[0]

    # Fetch license type (AGOL only)
    $license = Get-LicenseType $u.username

    Write-Host "`nUser found in ${Source}:" -ForegroundColor Green
    Write-Host "----------------------------------------"
    Write-Host "First Name       : $($u.firstName)"
    Write-Host "Last Name        : $($u.lastName)"
    Write-Host "Username         : $($u.username)"
    Write-Host "Email            : $($u.email)"
    Write-Host "IdpUsername      : $($u.idpUsername)"
    Write-Host "Created          : $(Format-Date $u.created)"
    Write-Host "Last Login       : $(Format-Date $u.lastLogin)"
    Write-Host "License Type ID  : $($license.Id)"
    Write-Host "License Type Name: $($license.Name)"
    Write-Host ""
    exit
}

# ---------------------------------------------------------
# Multiple matches
# ---------------------------------------------------------
Write-Host "`nMultiple users found ($($Matches.Count)) matching your criteria:" -ForegroundColor Yellow

$Matches |
    ForEach-Object {
        $license = Get-LicenseType $_.username

        [PSCustomObject]@{
            FirstName        = $_.firstName
            LastName         = $_.lastName
            Username         = $_.username
            Email            = $_.email
            IdpUsername      = $_.idpUsername
            Created          = Format-Date $_.created
            LastLogin        = Format-Date $_.lastLogin
            LicenseTypeId    = $license.Id
            LicenseTypeName  = $license.Name
        }
    } |
    Format-Table -AutoSize
