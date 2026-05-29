@{
    RootModule        = 'Users.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b1c1f0c3-2c7a-4f0a-9e7a-1f4b9d9c1a11'
    Author            = 'Andy'
    Description       = 'User management tools for ArcGIS Online and ArcGIS Enterprise Portal.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-ArcGISUser',
        'Find-ArcGISUser',
        'Get-StaleArcGISUsers'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
