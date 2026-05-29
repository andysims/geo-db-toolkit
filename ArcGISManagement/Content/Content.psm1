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


Export-ModuleMember -Function Get-ArcGISContentSummary
