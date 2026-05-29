param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("portal", "agol")]
    [string]$Source,

    [switch]$ExportTxt
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
# Exclude Esri system accounts from ALL metrics
# ---------------------------------------------------------
$allItems = $allItems | Where-Object {
    $_.owner -notmatch '^esri[_\.-]' -and
    $_.owner -notmatch '^esri$' -and
    $_.owner -notmatch '^esri[0-9]'
}

# ---------------------------------------------------------
# Compute Summary Metrics
# ---------------------------------------------------------

# Total content
$TotalContent = $allItems.Count

# My content count
$MyContentCount = ($allItems | Where-Object { $_.owner -eq $UsernameEnv }).Count

# Oldest + newest
$sortedByDate = $allItems | Sort-Object { [datetime]::UnixEpoch.AddMilliseconds($_.created) }

$oldest = $sortedByDate[0]
$newest = $sortedByDate[-1]

$OldestFormatted = ([datetime]::UnixEpoch.AddMilliseconds($oldest.created)).ToString("MM/dd/yyyy hh:mm tt")
$NewestFormatted = ([datetime]::UnixEpoch.AddMilliseconds($newest.created)).ToString("MM/dd/yyyy hh:mm tt")

# Sharing breakdown
$SharingBreakdown = [ordered]@{
    Public  = ($allItems | Where-Object { $_.access -eq "public" }).Count
    Org     = ($allItems | Where-Object { $_.access -eq "org" }).Count
    Shared  = ($allItems | Where-Object { $_.access -eq "shared" }).Count
    Private = ($allItems | Where-Object { $_.access -eq "private" }).Count
}

# Top 5 users by content count
$TopUsers = $allItems |
    Group-Object owner |
    Sort-Object Count -Descending |
    Select-Object -First 10

# Content type breakdown
$ContentTypes = $allItems |
    Group-Object type |
    Sort-Object Count -Descending

# ---------------------------------------------------------
# Build Output Text
# ---------------------------------------------------------
$summary = @()
$summary += "==========================="
$summary += " ArcGIS Content Summary"
$summary += "==========================="
$summary += ""
$summary += "Total Content in Org:  $TotalContent"
$summary += "My Content Count:       $MyContentCount"
$summary += ""
$summary += "Oldest Content:"
$summary += "  $OldestFormatted ($($oldest.id))"
$summary += ""
$summary += "Newest Content:"
$summary += "  $NewestFormatted ($($newest.id))"
$summary += ""
$summary += "Sharing Breakdown:"
foreach ($k in $SharingBreakdown.Keys) {
    $summary += "  $k`:  $($SharingBreakdown[$k])"
}
$summary += ""
$summary += "Top 10 Users by Content Count:"
foreach ($u in $TopUsers) {
    $summary += "  $($u.Name) - $($u.Count)"
}
$summary += ""
$summary += "Content Types:"
foreach ($ct in $ContentTypes) {
    $summary += "  $($ct.Name): $($ct.Count)"
}

$summaryText = $summary -join "`n"

# Print to screen
Write-Host $summaryText

# ---------------------------------------------------------
# Optional TXT Export
# ---------------------------------------------------------
if ($ExportTxt) {
    $downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    $date = (Get-Date).ToString("yyyyMMdd")
    $fileName = "${Source}_ContentSummary_$date.txt"
    $filePath = Join-Path $downloads $fileName

    $summaryText | Out-File -FilePath $filePath -Encoding UTF8

    Write-Host ""
    Write-Host "Summary exported to:"
    Write-Host "  $filePath"
}
