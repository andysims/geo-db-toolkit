param(
    [switch]$SearchGroup,
    [switch]$CreateGroup,

    [string]$Source = "portal",
    [string]$Name,
    [string]$ID,
    [string]$Description,
    [string]$Thumbnail,

    [switch]$ExportCsv,
    [string]$ExportPath = $null
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
    $Username = $envData["portal_username"]
    $Password = $envData["portal_password"]
}
elseif ($Source -eq "agol") {
    $BaseUrl  = $envData["agol_url"]
    $Username = $envData["agol_username"]
    $Password = $envData["agol_password"]
}
else {
    Write-Host "Source must be 'portal' or 'agol'."
    exit
}

# -----------------
# TOKEN GENERATION
# -----------------
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$BaseUrl/sharing/rest/generateToken" -Body @{
    username = $Username
    password = $Password
    client   = "referer"
    referer  = $BaseUrl
    f        = "json"
}

if (-not $tokenResponse.token) {
    Write-Host "Token generation failed."
    exit
}

$Token = $tokenResponse.token

# ------------
# PORTAL SELF
# ------------
$portalSelf = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self" -Body @{
    f="json"
    token=$Token
}
$OrgId = $portalSelf.id


# -----
# FUNCS
# -----

function Get-GroupById($gid) {
    Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/groups/$gid" -Body @{
        f="json"; token=$Token
    }
}

function Search-GroupsByName($groupName) {
    Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/community/groups" -Body @{
        f="json"
        token=$Token
        q="title:$groupName orgid:$OrgId"
    }
}

# Portal 11.3 returns ONLY usernames (owner/admins/users)
function Get-GroupUsers($gid) {
    $uri = "$BaseUrl/sharing/rest/community/groups/$gid/users"
    $body = @{
        f                = "json"
        token            = $Token
        showUserProfiles = "true"
        includeProfiles  = "true"
        includeInactive  = "true"
    }
    return Invoke-RestMethod -Uri $uri -Method Post -Body $body
}

# Profile fetch
function Get-UserProfile($username) {

    $uri = "$BaseUrl/sharing/rest/community/users/$username"
    $body = @{
        f = "json"
        token = $Token
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ErrorAction Stop

        # fallback to blank profile
        if ($response -is [string] -and $response -match "<html") {
            return @{
                username = $username
                fullName = $username
                created = $null
                lastLogin = $null
                email = ""
                idpUsername = ""
                userLicenseType = ""
            }
        }

        return $response
    }
    catch {
        return @{
            username = $username
            fullName = $username
            created = $null
            lastLogin = $null
            email = ""
            idpUsername = ""
            userLicenseType = ""
        }
    }
}

function Format-Epoch($ms) {
    if ($ms -and $ms -gt 0) {
        return ([datetime]'1970-01-01').AddMilliseconds($ms).ToString("MM/dd/yyyy hh:mm:ss tt")
    }
    return ""
}

function Clean-FileName([string]$text) {
    return ($text -replace '[^\w\- ]','').Trim()
}


# ------------------
# SEARCH GROUP MODE
# ------------------
if ($SearchGroup) {

    if (-not $Name -and -not $ID) {
        Write-Host "Must specify -Name or -ID when using -SearchGroup."
        exit
    }

    $group = $null

    if ($ID) {
        $group = Get-GroupById $ID
        if ($group.error) {
            Write-Host "Group not found."
            exit
        }
    }

    if ($Name) {

        $results = Search-GroupsByName $Name
        $matches = $results.results

        if ($matches.Count -eq 0) {
            Write-Host "No groups found matching '$Name'."
            exit
        }
        elseif ($matches.Count -eq 1) {
            $group = Get-GroupById $matches[0].id
        }
        else {
            Write-Host "Multiple groups found:"
            for ($i=0; $i -lt $matches.Count; $i++) {
                Write-Host "$i) $($matches[$i].title) | ID: $($matches[$i].id)"
            }
            $choice = Read-Host "Choose a group by number"
            $group = Get-GroupById $matches[$choice].id
        }
    }

    # ---------------------
    # Fetch usernames only 
    # ---------------------
    $usersObj = Get-GroupUsers $group.id
    # Write-Host "==== RAW USERSOBJ RESPONSE ====" -ForegroundColor Yellow
    # $usersObj | ConvertTo-Json -Depth 10 | Write-Host
    # Write-Host "================================" -ForegroundColor Yellow

    $ownerUsername = $usersObj.owner
    $adminUsernames = $usersObj.admins
    $memberUsernames = $usersObj.users

    $totalMembers = 1 + $adminUsernames.Count + $memberUsernames.Count

    # Get owner full profile
    $ownerProfile = Get-UserProfile $ownerUsername


    # -------------------
    # GROUP CONTENT COUNT
    # -------------------
    $contentCount = 0
    try {
        $contentResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/content/groups/$($group.id)" -Body @{
            f = "json"
            token = $Token
        }
        $contentCount = ($contentResp.items | Measure-Object).Count
    }
    catch {
        Write-Warning "Could not retrieve group content count."
    }

    # --------------
    # PRINT SUMMARY
    # --------------
    $createdString = Format-Epoch $group.created

    Write-Host ""
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host " Group Information" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Name              : $($group.title)"
    Write-Host "ID                : $($group.id)"
    Write-Host "Created           : $createdString"
    Write-Host "Group Members     : $totalMembers" -ForegroundColor Green
    Write-Host "Group Content     : $contentCount items" -ForegroundColor Green
    Write-Host ""
    Write-Host "Owner    : $ownerUsername"
    Write-Host "Members  : $($memberUsernames.Count)"
    Write-Host ""


    # ----------------------------------------------------
    # USER PROFILE FETCH (required because Portal returns only usernames)
    # ----------------------------------------------------
    $userProfiles = @()

    # Owner
    $userProfiles += [PSCustomObject]@{
        Username   = $ownerProfile.username
        FullName   = $ownerProfile.fullName
        MemberType = "owner"
        Joined     = ""
        Created    = Format-Epoch $ownerProfile.created
        LastLogin  = Format-Epoch $ownerProfile.lastLogin
        Email      = $ownerProfile.email
        IdpUsername = $ownerProfile.idpUsername
        UserLicenseType = $ownerProfile.userLicenseType
    }

    # Admins
    foreach ($u in $adminUsernames) {
        if ($u -eq $ownerUsername) { continue } # skip owner duplicate

        $p = Get-UserProfile $u

        $userProfiles += [PSCustomObject]@{
            Username   = $p.username
            FullName   = $p.fullName
            MemberType = "admin"
            Joined     = ""
            Created    = Format-Epoch $p.created
            LastLogin  = Format-Epoch $p.lastLogin
            Email      = $p.email
            IdpUsername = $p.idpUsername
            UserLicenseType = $p.userLicenseType
        }
    }

    # Members
    foreach ($u in $memberUsernames) {
        $p = Get-UserProfile $u

        $userProfiles += [PSCustomObject]@{
            Username   = $p.username
            FullName   = $p.fullName
            MemberType = "member"
            Joined     = Format-Epoch $p.created
            Created    = Format-Epoch $p.created
            LastLogin  = Format-Epoch $p.lastLogin
            Email      = $p.email
            IdpUsername = $p.idpUsername
            UserLicenseType = $p.userLicenseType
        }
    }


    # ------------------------
    # EXPORT CSV FILES (both)
    # ------------------------
    if ($ExportCsv) {

        $safeTitle = Clean-FileName $group.title
        $dateTag   = (Get-Date).ToString("yyyyMMdd")

        $minimalPath = "${safeTitle}_${dateTag}_minimal.csv"
        $fullPath    = "${safeTitle}_${dateTag}_full.csv"

        # MINIMAL CSV
        $userProfiles |
            Select-Object Username, FullName, MemberType, Joined |
            Export-Csv -Path $minimalPath -NoTypeInformation

        # FULL CSV
        $userProfiles |
            Export-Csv -Path $fullPath -NoTypeInformation

        Write-Host "Exported Minimal CSV : $minimalPath" -ForegroundColor Green
        Write-Host "Exported Full CSV    : $fullPath" -ForegroundColor Green
    }

    exit
}


# -------------------
# CREATE GROUP MODE 
# -------------------

if ($CreateGroup) {

    if (-not $Name) {
        Write-Host "Must specify -Name when using -CreateGroup."
        exit
    }

    $existing = Search-GroupsByName $Name

    if ($existing.results.Count -gt 0) {
        Write-Host "A group with this name already exists:"
        foreach ($g in $existing.results) {
            Write-Host " - $($g.title) | ID: $($g.id)"
        }
        exit
    }

    $body = @{
        title             = $Name
        description       = $Description
        access            = "org"
        isInvitationOnly  = "true"
        leavingDisallowed = "true"
        membershipAccess  = "org"
        f                 = "json"
        token             = $Token
    }

    if ($Thumbnail) {
        $body.Add("thumbnail", (Get-Content $Thumbnail -Encoding Byte))
    }

    $uri = "$BaseUrl/sharing/rest/community/createGroup"
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "multipart/form-data"

    if ($resp.success -eq $true) {
        Write-Host "Group created successfully:"
        Write-Host "Name: $Name"
        Write-Host "ID:   $($resp.group.id)"
    }
    else {
        Write-Host "Failed to create group."
    }

    exit
}

Write-Host "Specify either -SearchGroup or -CreateGroup."