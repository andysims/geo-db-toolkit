param(
    [string]$CsvPath,
    [string]$TableName = "mytable",
    [string]$Dialect = "postgresql",   # or sqlserver
    [int]$SampleSize = 100,
    [string]$Delimiter = ",",
    [switch]$ExportCsv,                # -ExportCsv
    [string]$ExportPath                # optional output location
)

# Defaults export target to script dir
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Type mapping for DDL generation
$typeMap = @{
    "postgresql" = @{
        "int"      = "bigint"
        "float"    = "numeric"
        "datetime" = "timestamp"
        "string"   = "text"
    }
    "sqlserver" = @{
        "int"      = "BIGINT"
        "float"    = "FLOAT"
        "datetime" = "DATETIME2"
        "string"   = "NVARCHAR"
    }
}

# Loads initial sample
$rows = Import-Csv -Path $CsvPath -Delimiter $Delimiter | Select-Object -First $SampleSize
if (-not $rows) {
    Write-Host "CSV is empty or unreadable."
    exit
}

# Loads first row
$firstRow = Import-Csv -Path $CsvPath -Delimiter $Delimiter | Select-Object -First 1

# Infer schema for each column
$schema = foreach ($col in $rows[0].PSObject.Properties.Name) {

    # Column name cleanup, for example: underscores + lowercase for Postgres
    $cleanName = $col -replace "\s+", "_"
    if ($Dialect -eq "postgresql") {
        $cleanName = $cleanName.ToLower()
    }

    # Values for analysis
    $values = $rows | ForEach-Object { $_.$col } | Where-Object { $_ -ne "" -and $_ -ne $null }

    $isNumeric = $values -and (
        ($values | Where-Object { $_ -match '^-?\d+(\.\d+)?$' }).Count / $values.Count -gt 0.95
    )

    $isDate = $values -and (
        ($values | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}' }).Count / $values.Count -gt 0.90
    )

    $maxLen = ($values | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxLen) { $maxLen = 0 }

    if ($isNumeric) {
        $dtype = ($values[0] -match '\.') ? "float" : "int"
    }
    elseif ($isDate) {
        $dtype = "datetime"
    }
    else {
        $dtype = "string"
    }

    # Sample value from first row
    $sampleValue = $firstRow.$col

    [PSCustomObject]@{
        ColumnName   = $cleanName
        InferredType = $dtype
        MaxLength    = $maxLen
        SampleValue  = $sampleValue
    }
}


Write-Host "`nInferred Schema:"
$schema | Format-Table ColumnName, InferredType, MaxLength, SampleValue

# Generates DDL
$map = $typeMap[$Dialect]
$columnsSql = @()

foreach ($col in $schema) {

    $sqlType = $map[$($col.InferredType)]

    # Resize NVARCHAR for SQL Server
    if ($Dialect -eq "sqlserver" -and $col.InferredType -eq "string") {
        $newSize = [math]::Ceiling($col.MaxLength * 1.5)
        if ($newSize -lt 50) { $newSize = 50 }
        $sqlType = "NVARCHAR($newSize)"
    }

    $columnsSql += "    $($col.ColumnName) $sqlType"
}

# ID adjusts, based on SQLSVR or PG
$idCol = if ($Dialect -eq "postgresql") {
    "    id serial primary key"
} else {
    "    id INT IDENTITY(1,1) PRIMARY KEY"
}

$ddl = "CREATE TABLE $TableName (`n$idCol,`n" + ($columnsSql -join ",`n") + "`n);"

Write-Host "`nGenerated DDL:`n"
Write-Host $ddl

# Optional export
if ($ExportCsv) {

    if (-not $ExportPath) {
        $ExportPath = Join-Path $ScriptDir "$TableName`_schema_export.csv"
    }

    $schema | Export-Csv -NoTypeInformation -Path $ExportPath

    Write-Host "`nSchema exported to: $ExportPath"
}