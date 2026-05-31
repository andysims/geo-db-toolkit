param(
    [ValidateSet("portal", "agol")]
    [string]$Source = "portal",

    [Parameter(Mandatory=$true)]
    [string]$GroupId,

    [string]$User,
    [string]$Users,
    [string]$UserList,

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

# ---------------------
# FETCH GROUP METADATA
# ---------------------
try {
    $groupInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/groups/$GroupId" -Body @{
        f="json"
        token=$Token
    }
}
catch {
    Write-Host "Failed to retrieve group information. Check GroupId."
    exit
}

if ($groupInfo.error) {
    Write-Host "Group not found."
    exit
}

$GroupTitle = $groupInfo.title

# -------------------------
# BUILD USERNAME COLLECTION
# -------------------------
$userListFinal = @()

if ($User) {
    $userListFinal += $User.Trim()
}

if ($Users) {
    $Users.Split(",") | ForEach-Object {
        if ($_.Trim()) { $userListFinal += $_.Trim() }
    }
}

if ($UserList) {
    if (-not (Test-Path $UserList)) {
        Write-Host "UserList CSV not found at: $UserList"
        exit
    }

    $csv = Import-Csv -Path $UserList
    foreach ($row in $csv) {
        if ($row.username -and $row.username.Trim()) {
            $userListFinal += $row.username.Trim()
        }
    }
}

if ($userListFinal.Count -eq 0) {
    Write-Host "No users provided. Use -User, -Users, or -UserList."
    exit
}

# Deduplicate
$userListFinal = $userListFinal | Sort-Object -Unique

# -------------------------
# REMOVE USERS FROM GROUP
# -------------------------
$removeUri = "$BaseUrl/sharing/rest/community/groups/$GroupId/removeUsers"

$body = @{
    f     = "json"
    token = $Token
    users = ($userListFinal -join ",")
}

try {
    $removeResponse = Invoke-RestMethod -Method Post -Uri $removeUri -Body $body
}
catch {
    Write-Host "Failed to remove users from group."
    exit
}

$results = $removeResponse.results
$notRemoved = $removeResponse.notRemoved

$successCount = ($results | Where-Object { $_.success -eq $true }).Count
$failCount    = $notRemoved.Count
$totalAttempt = $userListFinal.Count

# --------------
# PRINT SUMMARY
# --------------
Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " Remove Users from Group" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Group Name        : $GroupTitle"
Write-Host "Group ID          : $GroupId"
Write-Host "Attempted         : $totalAttempt"
Write-Host "Successfully Removed: $successCount" -ForegroundColor Green
Write-Host "Failed to Remove  : $failCount" -ForegroundColor Red
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "Failed Users:"
    foreach ($u in $notRemoved) {
        Write-Host "- $u"
    }
}

# ------------------------
# EXPORT CSV (FAILED ONLY)
# ------------------------
if ($ExportCsv -and $failCount -gt 0) {

    function Clean-FileName([string]$text) {
        return ($text -replace '[^\w\- ]','').Trim()
    }

    $safeTitle = Clean-FileName $GroupTitle
    $dateTag   = (Get-Date).ToString("yyyyMMdd")

    $DownloadsPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
    $csvPath = "$DownloadsPath\${safeTitle}_UsersNotRemoved_${dateTag}.csv"

    $notRemoved |
        ForEach-Object { [PSCustomObject]@{ Username = $_ } } |
        Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host ""
    Write-Host "Exported CSV of failed removals:" -ForegroundColor Yellow
    Write-Host $csvPath -ForegroundColor Yellow
}
