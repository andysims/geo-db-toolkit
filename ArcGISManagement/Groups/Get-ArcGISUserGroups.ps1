param(
    [ValidateSet("portal", "agol")]
    [string]$Source = "portal",

    [string]$Username,
    [string]$Email,
    [string]$LastName,

    [switch]$ExportCsv
)

# ----------
# LOAD .ENV
# ----------
$envData = @{ }

Get-Content -Path "$PSScriptRoot\.env" |
    Where-Object { $_ -match "=" -and $_ -notmatch "^\s*#" } |
    ForEach-Object {
        $parts = $_ -split "=", 2
        $envData[$parts[0].Trim()] = $parts[1].Trim()
    }

if ($Source -eq "portal") {
    $BaseUrl  = $envData["portal_url"]
    $UserEnv  = $envData["portal_username"]
    $PassEnv  = $envData["portal_password"]
}
elseif ($Source -eq "agol") {
    $BaseUrl  = $envData["agol_url"]
    $UserEnv  = $envData["agol_username"]
    $PassEnv  = $envData["agol_password"]
}
else {
    Write-Host "Source must be 'portal' or 'agol'."
    exit
}

# -----------------
# TOKEN GENERATION
# -----------------
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
    username = $UserEnv
    password = $PassEnv
    client   = "referer"
    referer  = $BaseUrl
    f        = "json"
}

if (-not $tokenResponse.token) {
    Write-Host "Token generation failed."
    exit
}

$Token = $tokenResponse.token

# -----------------
# PORTAL SELF (ORG)
# -----------------
$portalSelf = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self" -Body @{
    f="json"
    token=$Token
}
$OrgId = $portalSelf.id

# -----
# FUNCS
# -----

function Format-Epoch($ms) {
    if ($ms -and $ms -gt 0) {
        return ([datetime]'1970-01-01').AddMilliseconds($ms).ToString("MM/dd/yyyy hh:mm:ss tt")
    }
    return ""
}

function Search-Users($query) {
    Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users" -Body @{
        f="json"
        token=$Token
        q=$query
    }
}

function Get-UserProfile($username) {
    $uri = "$BaseUrl/sharing/rest/community/users/$username"
    $body = @{
        f = "json"
        token = $Token
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ErrorAction Stop

        if ($response -is [string] -and $response -match "<html") {
            return @{
                username = $username
                fullName = $username
                firstName = ""
                lastName = ""
                created = $null
                lastLogin = $null
            }
        }

        return $response
    }
    catch {
        return @{
            username = $username
            fullName = $username
            firstName = ""
            lastName = ""
            created = $null
            lastLogin = $null
        }
    }
}

function Get-UserGroups($username) {
    Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$username/groups" -Body @{
        f="json"
        token=$Token
    }
}

# -------------------------
# VALIDATE SEARCH INPUT
# -------------------------
if (-not $Username -and -not $Email -and -not $LastName) {
    Write-Host "Must specify -Username, -Email, or -LastName."
    exit
}

# -------------------------
# USER SEARCH
# -------------------------
$searchQuery = ""

if ($Username) { $searchQuery = "username:$Username orgid:$OrgId" }
elseif ($Email) { $searchQuery = "email:$Email orgid:$OrgId" }
elseif ($LastName) { $searchQuery = "lastname:$LastName orgid:$OrgId" }

$searchResults = Search-Users $searchQuery

if ($searchResults.total -eq 0) {
    Write-Host "No users found."
    exit
}

$userChoice = $null

if ($searchResults.total -eq 1) {
    $userChoice = $searchResults.users[0]
}
else {
    Write-Host "Multiple users found:"
    for ($i = 0; $i -lt $searchResults.users.Count; $i++) {
        Write-Host "$($i+1)) $($searchResults.users[$i].username) | $($searchResults.users[$i].fullName)"
    }
    $selection = Read-Host "Choose a user by number"
    $userChoice = $searchResults.users[$selection - 1]
}

$finalUsername = $userChoice.username

# -------------------------
# FETCH PROFILE
# -------------------------
$profile = Get-UserProfile $finalUsername

$createdString = Format-Epoch $profile.created
$lastLoginString = Format-Epoch $profile.lastLogin

# -------------------------
# FETCH USER GROUPS
# -------------------------
$groupData = Get-UserGroups $finalUsername

$ownedGroups  = $groupData.owner
$adminGroups  = $groupData.admin
$memberGroups = $groupData.member

$totalGroups = $ownedGroups.Count + $adminGroups.Count + $memberGroups.Count

# --------------
# PRINT SUMMARY
# --------------
Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " User Group Membership" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Username        : $($profile.username)"
Write-Host "First Name      : $($profile.firstName)"
Write-Host "Last Name       : $($profile.lastName)"
Write-Host "Created         : $createdString"
Write-Host "Last Login      : $lastLoginString"
Write-Host ""
Write-Host "Total Groups    : $totalGroups"
Write-Host "Groups Owned    : $($ownedGroups.Count)"
Write-Host ""

Write-Host "--- Owned Groups ---" -ForegroundColor Yellow
foreach ($g in $ownedGroups) {
    Write-Host "$($g.title) (ID: $($g.id))"
}
Write-Host ""

Write-Host "--- Admin Groups ---" -ForegroundColor Yellow
foreach ($g in $adminGroups) {
    Write-Host "$($g.title) (ID: $($g.id))"
}
Write-Host ""

Write-Host "--- Member Groups ---" -ForegroundColor Yellow
foreach ($g in $memberGroups) {
    Write-Host "$($g.title) (ID: $($g.id))"
}
Write-Host ""

# ------------------------
# EXPORT CSV (optional)
# ------------------------
if ($ExportCsv) {

    function Clean-FileName([string]$text) {
        return ($text -replace '[^\w\- ]','').Trim()
    }

    $safeUser = Clean-FileName $finalUsername
    $dateTag  = (Get-Date).ToString("yyyyMMdd")

    $DownloadsPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
    $csvPath = "$DownloadsPath\${safeUser}_GroupMembership_${dateTag}.csv"

    $exportRows = @()

    foreach ($g in $ownedGroups) {
        $exportRows += [PSCustomObject]@{
            GroupTitle = $g.title
            GroupId    = $g.id
            Role       = "owner"
        }
    }
    foreach ($g in $adminGroups) {
        $exportRows += [PSCustomObject]@{
            GroupTitle = $g.title
            GroupId    = $g.id
            Role       = "admin"
        }
    }
    foreach ($g in $memberGroups) {
        $exportRows += [PSCustomObject]@{
            GroupTitle = $g.title
            GroupId    = $g.id
            Role       = "member"
        }
    }

    $exportRows | Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host ""
    Write-Host "Exported CSV:" -ForegroundColor Green
    Write-Host $csvPath -ForegroundColor Green
}
