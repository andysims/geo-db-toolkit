param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("portal","agol")]
    [string]$Source,

    [switch]$ExportCsv,
        [string]$ExportPath                # optional output location
)

$envData = @{}

Get-Content -Path "$PSScriptRoot\.env" |
    Where-Object { $_ -match "=" -and $_ -notmatch "^\s*#" } |
    ForEach-Object {
        $parts = $_ -split "=", 2
        $key = $parts[0].Trim()
        $val = $parts[1].Trim()
        $envData[$key] = $val
    }

$prefix = if ($Source -eq "portal") { "portal" } else { "agol" }

$BaseUrl  = $envData["${prefix}_url"]
$Username = $envData["${prefix}_username"]
$Password = $envData["${prefix}_password"]


if (-not $BaseUrl -or -not $Username -or -not $Password) {
    Write-Error "Missing required environment variables for prefix '$prefix'."
    exit 1
}

# Token
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
    username = $Username
    password = $Password
    client   = "requestip"
    f        = "json"
}

$Token = $tokenResponse.token

if (-not $Token) {
    Write-Error "Failed to generate token."
    exit 1
}

# ----------
# PAGINATION
# ----------
$AllUsers = @()
$start = 1

Write-Host "$BaseUrl/sharing/rest/portals/self/users"
while ($true) {
    $page = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self/users" -Body @{
        f     = "json"
        token = $Token
        start = $start
        num   = 100
    }

    if ($page.users) {
        $AllUsers += $page.users
    }

    if ($page.nextStart -eq -1) {
        break
    }

    $start = $page.nextStart
}

# Filters stale users
$cutoff = (Get-Date).AddYears(-1)

Write-Host "Fetching users...`n"
$Filtered = foreach ($u in $AllUsers) {
    $created = if ($u.created) { [DateTimeOffset]::FromUnixTimeMilliseconds($u.created).DateTime } else { $null }
    $lastLogin = if ($u.lastLogin -and $u.lastLogin -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($u.lastLogin).DateTime } else { $null }

    if (-not $u.idpUsername) { continue }

    $isStale = $false
    if ($lastLogin) {
        if ($lastLogin -le $cutoff) { $isStale = $true }
    } else {
        $isStale = $true
    }

    if ($isStale) {
        $contentInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/content/users/$($u.username)" -Body @{
            f     = "json"
            token = $Token
        }

        $itemCount = ($contentInfo.items | Measure-Object).Count

        $groupInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$($u.username)" -Body @{
            f     = "json"
            token = $Token
        }

        $groupCount = ($groupInfo.groups | Measure-Object).Count

        [PSCustomObject]@{
            Username      = $u.username
            FirstName     = $u.firstName
            LastName      = $u.lastName
            FullName      = $u.fullName
            Email         = $u.email
            IdpUsername   = $u.idpUsername
            Role          = $u.role
            UserType      = $u.userType
            UserLicense   = $u.userLicenseType
            Created       = if ($created) { $created.ToString("yyyy-MM-dd HH:mm") } else { "" }
            LastLogin     = if ($lastLogin) { $lastLogin.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
            ContentCount  = $itemCount
            GroupCount    = $groupCount
        }
    }
}

$Sorted = $Filtered | Sort-Object Created, LastLogin
$Sorted | Format-Table -AutoSize

if ($ExportCsv) {
    $date = (Get-Date).ToString("yyyyMMdd")
    $file = "stale_${Source}_users_${date}.csv"
    $Sorted | Export-Csv -NoTypeInformation -Path $file
    Write-Host "Exported to $file"
}
