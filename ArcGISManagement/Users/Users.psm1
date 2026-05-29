# Users.psm1
# A lightweight wrapper module - .ps1 scripts as cmdlets

function Resolve-UserScriptPath {
    param([string]$ScriptName)
    return Join-Path $PSScriptRoot $ScriptName
}

# ---------------------------------------------------------
# Get-ArcGISUser
# ---------------------------------------------------------
function Get-ArcGISUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Username
    )

    & (Resolve-UserScriptPath "Get-ArcGISUser.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Find-ArcGISUser
# ---------------------------------------------------------
function Find-ArcGISUser {
    [CmdletBinding(DefaultParameterSetName="Email")]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [Parameter(ParameterSetName="Email", Mandatory=$true)]
        [string]$Email,

        [Parameter(ParameterSetName="Username", Mandatory=$true)]
        [string]$Username
    )

    & (Resolve-UserScriptPath "Find-ArcGISUser.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Get-StaleArcGISUsers
# ---------------------------------------------------------
function Get-StaleArcGISUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [string]$ExportPath,

        [switch]$ExportCsv
    )

    & (Resolve-UserScriptPath "Get-StaleUsers.ps1") @PSBoundParameters
}

Export-ModuleMember -Function Get-ArcGISUser, Find-ArcGISUser, Get-StaleArcGISUsers
