param(
    [switch]$SearchGroup,
    [switch]$CreateGroup,

    [string]$Source = "portal",  # portal or agol
    [string]$Name,
    [string]$ID,
    [string]$Description,
    [string]$Thumbnail,

    [switch]$ExportCsv,
    [string]$ExportPath = "./group_members_export.csv"
)

# ----------------------------------------------------
# LOAD .ENV
# ----------------------------------------------------
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

# ----------------------------------------------------
# TOKEN GENERATION
# ----------------------------------------------------
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

# ----------------------------------------------------
# PORTAL SELF (GET ORG ID)
# ----------------------------------------------------
$portalSelf = Invoke-RestMethod -Method Get -Uri "$BaseUrl/sharing/rest/portals/self" -Body @{
    f="json"
    token=$Token
}
$OrgId = $portalSelf.id


# ----------------------------------------------------
# HELPERS
# ----------------------------------------------------
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

function Get-GroupUsers($gid) {
    # MUST use real "&", not "&amp;"
    $uri = "$BaseUrl/sharing/rest/community/groups/$gid/users?f=json&token=$Token&showUserProfiles=true"
    return Invoke-RestMethod -Uri $uri -Method Get
}

function Get-UserProfile($username) {
    $uri = "$BaseUrl/sharing/rest/community/users/$username?f=json&token=$Token"
    return Invoke-RestMethod -Uri $uri -Method Get
}

function Format-Epoch($ms) {
    if ($ms -and $ms -gt 0) {
        return ([datetime]'1970-01-01').AddMilliseconds($ms).ToString("MM/dd/yyyy hh:mm:ss tt")
    }
    return "Never"
}


# ----------------------------------------------------
# SEARCH GROUP MODE
# ----------------------------------------------------
if ($SearchGroup) {

    if (-not $Name -and -not $ID) {
        Write-Host "Must specify -Name or -ID when using -SearchGroup."
        exit
    }

    $group = $null

    # -------------------------------------------
    # BY ID
    # -------------------------------------------
    if ($ID) {
        $full = Get-GroupById $ID
        if ($full.error) {
            Write-Host "Group not found."
            exit
        }
        $group = $full
    }

    # -------------------------------------------
    # BY NAME (partial)
    # -------------------------------------------
    if ($Name) {
        $results = Search-GroupsByName $Name
        $matches = $results.results

        if ($matches.Count -eq 0) {
            Write-Host "No groups found matching '$Name'."
            exit
        }
        elseif ($matches.Count -eq 1) {
            $group = $matches[0]
        }
        else {
            Write-Host "Multiple groups found:"
            for ($i=0; $i -lt $matches.Count; $i++) {
                Write-Host "$i) $($matches[$i].title) | ID: $($matches[$i].id)"
            }

            if ($ExportCsv) {
                Write-Host ""
                Write-Host "CSV export deferred — select ONE group first."
            }

            $choice = Read-Host "Choose a group by number"
            $group = $matches[$choice]
        }
    }

    # ------------------------------------------------
    # FETCH GROUP DETAILS + USERS
    # ------------------------------------------------
    $fullGroup = Get-GroupById $group.id
    $usersObj  = Get-GroupUsers $group.id

    $owner  = $fullGroup.owner
    $admins = $usersObj.admins
    $users  = $usersObj.users

    # ------------------------------------------------
    # PRINT OUTPUT
    # ------------------------------------------------
    $createdDate = ([datetime]'1970-01-01').AddMilliseconds($fullGroup.created)
    $createdStr  = $createdDate.ToString("MM/dd/yyyy hh:mm:ss tt")

    Write-Host ""
    Write-Host "============================="
    Write-Host " Group Information"
    Write-Host "============================="
    Write-Host "Name:        $($fullGroup.title)"
    Write-Host "ID:          $($fullGroup.id)"
    Write-Host "Created:     $createdStr"
    Write-Host ""

    Write-Host "Owner:"
    Write-Host " - $owner"
    Write-Host ""

    Write-Host "Managers:"
    if ($admins.Count -gt 0) {
        foreach ($a in $admins) { Write-Host " - $a" }
    } else {
        Write-Host " - None"
    }
    Write-Host ""

    Write-Host "Members:"
    if ($users.Count -gt 0) {
        foreach ($u in $users) { Write-Host " - $u" }
    } else {
        Write-Host " - None"
    }
    Write-Host ""


    # ------------------------------------------------
    # EXPORT TO CSV
    # ------------------------------------------------
    if ($ExportCsv) {

        if (-not $group.id) {
            Write-Host "ERROR: No single group selected. CSV export aborted."
            exit
        }

        $export = @()

        function Add-UserRow($username, $role) {
            try {
                $profile = Get-UserProfile $username
            }
            catch {
                # If profile is not accessible, fallback
                $profile = @{
                    fullName = ""
                    email = ""
                    created = $null
                    lastLogin = $null
                    userLicenseType = ""
                    idpUsername = ""
                }
            }

            $created   = Format-Epoch $profile.created
            $lastLogin = Format-Epoch $profile.lastLogin

            $export += [PSCustomObject]@{
                Username        = $username
                FullName        = $profile.fullName
                Email           = $profile.email
                Role            = $role
                Created         = $created
                LastLogin       = $lastLogin
                UserLicenseType = $profile.userLicenseType
                IdpUsername     = $profile.idpUsername
            }
        }

        # Add owner
        Add-UserRow $owner "Owner"

        # Add managers
        foreach ($m in $admins) {
            Add-UserRow $m "Manager"
        }

        # Add members
        foreach ($u in $users) {
            Add-UserRow $u "Member"
        }

        $export | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host ""
        Write-Host "Exported to: $ExportPath"
    }

    exit
}

# ----------------------------------------------------
# CREATE GROUP MODE
# ----------------------------------------------------
if ($CreateGroup) {

    if (-not $Name) {
        Write-Host "Must specify -Name when using -CreateGroup."
        exit
    }

    # Avoid duplicates
    $existing = Search-GroupsByName $Name

    if ($existing.results.Count -gt 0) {
        Write-Host "A group with this name already exists:"
        foreach ($g in $existing.results) {
            Write-Host " - $($g.title) | ID: $($g.id)"
        }
        Write-Host "Group not created."
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