param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("portal", "agol")]
    [string]$Source,

    [string]$Owner,
    [string]$Title,
    [string]$Id,
    [string]$Type
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
$BaseUrl     = $envData["${prefix}_url"]
$UsernameEnv = $envData["${prefix}_username"]
$PasswordEnv = $envData["${prefix}_password"]

if (-not $BaseUrl -or -not $UsernameEnv -or -not $PasswordEnv) {
    throw "Missing required environment variables for prefix '$prefix'."
}

# ---------------------------------------------------------
# Token Generation
# ---------------------------------------------------------
$tokenUrl = "$BaseUrl/sharing/rest/generateToken"
$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body @{
    username = $UsernameEnv
    password = $PasswordEnv
    client   = "referer"
    referer  = $BaseUrl
    f        = "json"
}

if ($tokenResponse.error) {
    throw "Token generation failed: $($tokenResponse.error.message)"
}

$Token = $tokenResponse.token

# ---------------------------------------------------------
# Get Org Info
# ---------------------------------------------------------
$portalSelfUrl = "$BaseUrl/sharing/rest/portals/self?f=json&token=$Token"
$portalInfo = Invoke-RestMethod -Uri $portalSelfUrl -Method Get

$OrgId = $portalInfo.id

# ---------------------------------------------------------
# Retrieve ALL content (paginated)
# ---------------------------------------------------------
$allItems = @()
$start = 1
$max = 100

do {
    $searchUrl = "$BaseUrl/sharing/rest/search"
    $searchResponse = Invoke-RestMethod -Method Post -Uri $searchUrl -Body @{
        q     = "orgid:$OrgId"
        num   = $max
        start = $start
        f     = "json"
        token = $Token
    }

    $allItems += $searchResponse.results
    $start += $max

} while ($allItems.Count -lt $searchResponse.total)

# ---------------------------------------------------------
# Exclude Esri system accounts
# ---------------------------------------------------------
$allItems = $allItems | Where-Object {
    $_.owner -notmatch '^esri[_\.-]' -and
    $_.owner -notmatch '^esri$' -and
    $_.owner -notmatch '^esri[0-9]'
}

# ---------------------------------------------------------
# Apply Filters
# ---------------------------------------------------------
$filtered = $allItems

if ($Owner) {
    $filtered = $filtered | Where-Object { $_.owner -eq $Owner }
}

if ($Title) {
    $filtered = $filtered | Where-Object { $_.title -match [regex]::Escape($Title) }
}

if ($Id) {
    $filtered = $filtered | Where-Object { $_.id -eq $Id }
}

if ($Type) {
    $filtered = $filtered | Where-Object { $_.type -match [regex]::Escape($Type) }
}

if ($filtered.Count -eq 0) {
    Write-Host "No content found matching the provided criteria."
    exit
}

# ---------------------------------------------------------
# Format Output
# ---------------------------------------------------------
$formatted = $filtered |
    Sort-Object { [datetime]::UnixEpoch.AddMilliseconds($_.created) } -Descending |
    Select-Object @{
        Name="Title"; Expression={ $_.title }
    }, @{
        Name="ItemId"; Expression={ $_.id }
    }, @{
        Name="Created"; Expression={
            ([datetime]::UnixEpoch.AddMilliseconds($_.created)).ToString("MM/dd/yyyy hh:mm tt")
        }
    }, @{
        Name="Modified"; Expression={
            ([datetime]::UnixEpoch.AddMilliseconds($_.modified)).ToString("MM/dd/yyyy hh:mm tt")
        }
    }, @{
        Name="Type"; Expression={ $_.type }
    }, @{
        Name="Access"; Expression={ $_.access }
    }, @{
        Name="Owner"; Expression={ $_.owner }
    }

# ---------------------------------------------------------
# Output Logic
# ---------------------------------------------------------
if ($formatted.Count -eq 1) {
    $formatted | Format-List
} else {
    $formatted | Format-Table -AutoSize
}
