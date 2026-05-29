function Get-StaleArcGISUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [string]$ExportPath,          # Optional: folder to export CSVs
        [switch]$ExportCsv            # Optional: export raw CSV in current directory
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
    $Username = $envData["${prefix}_username"]
    $Password = $envData["${prefix}_password"]

    if (-not $BaseUrl -or -not $Username -or -not $Password) {
        throw "Missing required environment variables for prefix '$prefix'."
    }

    # ---------------------------------------------------------
    # Token
    # ---------------------------------------------------------
    Write-Host "Generating token..." -ForegroundColor Cyan
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
        username = $Username
        password = $Password
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

    Write-Host "Total users retrieved: $($AllUsers.Count)" -ForegroundColor Green

    # ---------------------------------------------------------
    # Filter stale users (1 year)
    # ---------------------------------------------------------
    $cutoff = (Get-Date).AddYears(-1)

    $Filtered = foreach ($u in $AllUsers) {
        if (-not $u.idpUsername) { continue }

        $created = if ($u.created) { [DateTimeOffset]::FromUnixTimeMilliseconds($u.created).DateTime } else { $null }
        $lastLogin = if ($u.lastLogin -and $u.lastLogin -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($u.lastLogin).DateTime } else { $null }

        $isStale = $false
        if ($lastLogin) {
            if ($lastLogin -le $cutoff) { $isStale = $true }
        }
        else {
            $isStale = $true
        }

        if (-not $isStale) { continue }

        # Content count
        $contentInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/content/users/$($u.username)" -Body @{
            f     = "json"
            token = $Token
        }

        # Group count
        $groupInfo = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/users/$($u.username)" -Body @{
            f     = "json"
            token = $Token
        }

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
            ContentCount  = ($contentInfo.items | Measure-Object).Count
            GroupCount    = ($groupInfo.groups | Measure-Object).Count
        }
    }

    # ---------------------------------------------------------
    # Add classification
    # ---------------------------------------------------------
    foreach ($u in $Filtered) {
        if ($u.LastLogin -and $u.LastLogin -ne "Never") {
            $loginDate = [datetime]::ParseExact($u.LastLogin, "yyyy-MM-dd HH:mm", $null)
            $u | Add-Member -NotePropertyName LastLoginDate -NotePropertyValue $loginDate
            $u | Add-Member -NotePropertyName DaysSinceLastLogin -NotePropertyValue ((Get-Date) - $loginDate).Days
        }
        else {
            $u | Add-Member -NotePropertyName LastLoginDate -NotePropertyValue $null
            $u | Add-Member -NotePropertyName DaysSinceLastLogin -NotePropertyValue $null
        }
    }

    foreach ($u in $Filtered) {
        if (-not $u.LastLoginDate) {
            $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "Never logged in"
            continue
        }

        $days = $u.DaysSinceLastLogin

        if ($days -ge 730) {
            $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "More than 2 years since last login"
        }
        elseif ($days -ge 548) {
            $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "1.5 to 2 years since last login"
        }
        elseif ($days -ge 365) {
            $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "1 year since last login"
        }
        else {
            $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "Less than 1 year"
        }
    }

    # ---------------------------------------------------------
    # Summary
    # ---------------------------------------------------------
    $totalUsers = $AllUsers.Count
    $totalStale = $Filtered.Count

    $summary = @(
        [PSCustomObject]@{ Category = "Never logged in";                   Count = ($Filtered | Where-Object StaleCategory -eq "Never logged in").Count }
        [PSCustomObject]@{ Category = "1 year since last login";           Count = ($Filtered | Where-Object StaleCategory -eq "1 year since last login").Count }
        [PSCustomObject]@{ Category = "1.5 to 2 years since last login";   Count = ($Filtered | Where-Object StaleCategory -eq "1.5 to 2 years since last login").Count }
        [PSCustomObject]@{ Category = "More than 2 years since last login"; Count = ($Filtered | Where-Object StaleCategory -eq "More than 2 years since last login").Count }
        [PSCustomObject]@{ Category = "Total Stale Users";                 Count = $totalStale }
        [PSCustomObject]@{ Category = "Total Users (all)";                 Count = $totalUsers }
    )

    # Add percentages — all expressed as % of total users in the source
    foreach ($item in $summary) {
        if ($item.Category -eq "Total Users (all)") {
            $item | Add-Member -NotePropertyName Percent -NotePropertyValue "100%"
        }
        elseif ($totalUsers -gt 0) {
            $item | Add-Member -NotePropertyName Percent -NotePropertyValue ("{0:P1}" -f ($item.Count / $totalUsers))
        }
        else {
            $item | Add-Member -NotePropertyName Percent -NotePropertyValue "N/A"
        }
    }

    # ---------------------------------------------------------
    # Output
    # ---------------------------------------------------------
    Write-Host "`nSummary Report" -ForegroundColor Cyan
    $summary | Format-Table -AutoSize

    # ---------------------------------------------------------
    # Exports
    # ---------------------------------------------------------
    if ($ExportCsv) {
        $date = (Get-Date).ToString("yyyyMMdd")
        $exportDir = if ($ExportPath) { $ExportPath } else { (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path }

        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }

        $summaryCsv = Join-Path $exportDir "${Source}_staleusers_summary_${date}.csv"
        $detailCsv  = Join-Path $exportDir "${Source}_staleusers_${date}.csv"

        $summary | Export-Csv -NoTypeInformation -Path $summaryCsv
        $Filtered | Export-Csv -NoTypeInformation -Path $detailCsv

        Write-Host "Exported CSVs to: $exportDir" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Get-StaleArcGISUsers
