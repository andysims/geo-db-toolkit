# Content.psm1

function Resolve-ContentScriptPath {
    param([string]$ScriptName)
    return Join-Path $PSScriptRoot $ScriptName
}

# ---------------------------------------------------------
# Get-ArcGISContentSummary
# ---------------------------------------------------------
function Get-ArcGISContentSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [switch]$ExportTxt
    )

    & (Resolve-ContentScriptPath "Get-ContentSummary.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Get-NewArcGISItems
# ---------------------------------------------------------
function Get-NewArcGISItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [int]$Days = 7
    )

    & (Resolve-ContentScriptPath "Get-NewArcGISItems.ps1") @PSBoundParameters
}

# ---------------------------------------------------------
# Find-ArcGISContent
# ---------------------------------------------------------
function Find-ArcGISContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("portal", "agol")]
        [string]$Source,

        [string]$Owner,
        [string]$Title,
        [string]$Id,
        [string]$Type
    )

    & (Resolve-ContentScriptPath "Find-ArcGISContent.ps1") @PSBoundParameters
}

Export-ModuleMember -Function `
    Get-ArcGISContentSummary, `
    Get-NewArcGISItems, `
    Find-ArcGISContent
