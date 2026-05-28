function Get-StaleArcGISUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("portal","agol")]
        [string]$Source,

        [string]$ExportPath,   # optional output directory
        [switch]$ExportCsv     # export the raw stale user list
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
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
        username = $Username
        password = $Password
        client   = "requestip"
        f        = "json"
    }

    $Token = $tokenResponse.token
    if (-not $Token) {
        throw "Failed to generate token."
    }

    # ---------------------------------------------------------
    # Fetch all users (pagination)
    # ---------------------------------------------------------
    $AllUsers = @()
    $start = 1

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

        if ($page.nextStart -eq -1) { break }
        $start = $page.nextStart
    }

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
        $itemCount = ($contentInfo.items | Measure-Object).Count

        # Group count
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

    # ---------------------------------------------------------
    # Classification (Script 2 logic)
    # ---------------------------------------------------------
    foreach ($u in $Filtered) {
        if ($u.LastLogin -and $u.LastLogin -ne "Never") {
            $loginDate = [datetime]$u.LastLogin
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
    $total = $Filtered.Count

    $summary = @(
        [PSCustomObject]@{
            Category = "Never logged in"
            Count    = ($Filtered | Where-Object { $_.StaleCategory -eq "Never logged in" }).Count
            Percent  = if ($total -gt 0) { "{0:P1}" -f (($Filtered | Where-Object { $_.StaleCategory -eq "Never logged in" }).Count / $total) } else { "0%" }
        }
        [PSCustomObject]@{
            Category = "1 year since last login"
            Count    = ($Filtered | Where-Object { $_.StaleCategory -eq "1 year since last login" }).Count
            Percent  = if ($total -gt 0) { "{0:P1}" -f (($Filtered | Where-Object { $_.StaleCategory -eq "1 year since last login" }).Count / $total) } else { "0%" }
        }
        [PSCustomObject]@{
            Category = "1.5 to 2 years since last login"
            Count    = ($Filtered | Where-Object { $_.StaleCategory -eq "1.5 to 2 years since last login" }).Count
            Percent  = if ($total -gt 0) { "{0:P1}" -f (($Filtered | Where-Object { $_.StaleCategory -eq "1.5 to 2 years since last login" }).Count / $total) } else { "0%" }
        }
        [PSCustomObject]@{
            Category = "More than 2 years since last login"
            Count    = ($Filtered | Where-Object { $_.StaleCategory -eq "More than 2 years since last login" }).Count
            Percent  = if ($total -gt 0) { "{0:P1}" -f (($Filtered | Where-Object { $_.StaleCategory -eq "More than 2 years since last login" }).Count / $total) } else { "0%" }
        }
        [PSCustomObject]@{
            Category = "Total"
            Count    = $total
            Percent  = "100%"
        }
    )

    # ---------------------------------------------------------
    # Output
    # ---------------------------------------------------------
    Write-Host "`nSummary Report" -ForegroundColor Cyan
    $summary | Format-Table -AutoSize

    #Write-Host "`nStale Users" -ForegroundColor Cyan
    #$Filtered | Format-Table Username, FullName, Email, LastLogin, DaysSinceLastLogin, StaleCategory -AutoSize

    # ---------------------------------------------------------
    # Optional exports
    # ---------------------------------------------------------
    if ($ExportPath) {
        if (-not (Test-Path $ExportPath)) {
            New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
        }

        $summary | Export-Csv -NoTypeInformation -Path (Join-Path $ExportPath "$Source_summary.csv")
        $Filtered | Export-Csv -NoTypeInformation -Path (Join-Path $ExportPath "$Source_classified.csv")

        Write-Host "`nExported summary + classified CSVs to $ExportPath" -ForegroundColor Green
    }

    if ($ExportCsv) {
        $date = (Get-Date).ToString("yyyyMMdd")
        $file = "stale_${Source}_users_${date}.csv"
        $Filtered | Export-Csv -NoTypeInformation -Path $file
        Write-Host "Exported stale user CSV → $file"
    }

    return $Filtered
}

Export-ModuleMember -Function Get-StaleArcGISUsers
