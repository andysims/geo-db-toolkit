param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("portal", "agol")]
    [string]$Source,

    [int]$Days = 7,

    [switch]$ExportCsv
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
# Filter by created date
# ---------------------------------------------------------
$cutoff = (Get-Date).AddDays(-$Days)

$recentItems = $allItems | Where-Object {
    $created = [datetime]::UnixEpoch.AddMilliseconds($_.created)
    $created -ge $cutoff
}

# ---------------------------------------------------------
# Format output
# ---------------------------------------------------------
$formatted = $recentItems | Sort-Object {
    [datetime]::UnixEpoch.AddMilliseconds($_.created)
} -Descending | Select-Object @{
        Name="Title"; Expression={ $_.title }
    }, @{
        Name="Owner"; Expression={ $_.owner }
    }, @{
        Name="Created"; Expression={ 
            ([datetime]::UnixEpoch.AddMilliseconds($_.created)).ToString("MM/dd/yyyy hh:mm tt")
        }
    }, @{
        Name="Type"; Expression={ $_.type }
    }, @{
        Name="Access"; Expression={ $_.access }
    }, @{
        Name="ItemId"; Expression={ $_.id }
    }

if ($formatted.Count -eq 0) {
    Write-Host "No new content found in the last $Days days."
    exit
}

# ---------------------------------------------------------
# Print table
# ---------------------------------------------------------
$formatted | Format-Table -AutoSize

# ---------------------------------------------------------
# Optional CSV Export
# ---------------------------------------------------------
if ($ExportCsv) {
    $downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    $date = (Get-Date).ToString("yyyyMMdd")
    $fileName = "${Source}_NewItems_$date.csv"
    $filePath = Join-Path $downloads $fileName

    $formatted | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "CSV exported to:"
    Write-Host "  $filePath"
}
