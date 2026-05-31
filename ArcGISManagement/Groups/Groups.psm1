# Groups.psm1
# A lightweight wrapper module - .ps1 scripts as cmdlets

function Resolve-GroupScriptPath {
    param([string]$ScriptName)
    return Join-Path $PSScriptRoot $ScriptName
}

# ---------------------------------------------------------
# Get-ArcGISGroup
# ---------------------------------------------------------
function Get-ArcGISGroup {
    [CmdletBinding()]
    param(
        [switch]$SearchGroup,

        [ValidateSet("portal", "agol")]
        [string]$Source = "portal",

        [string]$Name,
        [string]$ID,

        [switch]$ExportCsv,
        [string]$ExportPath
    )

    & (Resolve-GroupScriptPath "Get-ArcGISGroup.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Add-ArcGISGroupUsers
# ---------------------------------------------------------
function Add-ArcGISGroupUsers {
    [CmdletBinding()]
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

    & (Resolve-GroupScriptPath "Add-ArcGISGroupUsers.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Get-ArcGISUserGroups
# ---------------------------------------------------------
function Get-ArcGISUserGroups {
    [CmdletBinding()]
    param(
        [ValidateSet("portal", "agol")]
        [string]$Source = "portal",

        [string]$Username,
        [string]$Email,
        [string]$LastName,

        [switch]$ExportCsv
    )

    & (Resolve-GroupScriptPath "Get-ArcGISUserGroups.ps1") @PSBoundParameters
}

Export-ModuleMember -Function Get-ArcGISGroup, Add-ArcGISGroupUsers, Get-ArcGISUserGroups
