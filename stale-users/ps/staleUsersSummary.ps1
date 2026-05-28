param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,

    [string]$ExportPath  # optional output directory
)

# Validating CSV
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

# Determine script directory (for default export path)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$users = Import-Csv $CsvPath

# Parsing LastLogin and compute days since last login
foreach ($u in $users) {

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

$now = Get-Date

# Classifying users based on last login
foreach ($u in $users) {

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
        # Not stale
        $u | Add-Member -NotePropertyName StaleCategory -NotePropertyValue "Less than 1 year"
    }
}

# Category Buckets
$never       = $users | Where-Object { $_.StaleCategory -eq "Never logged in" }
$oneYear     = $users | Where-Object { $_.StaleCategory -eq "1 year since last login" }
$oneHalfToTwo = $users | Where-Object { $_.StaleCategory -eq "1.5 to 2 years since last login" }
$moreThanTwo  = $users | Where-Object { $_.StaleCategory -eq "More than 2 years since last login" }

$total = $users.Count

$summary = @(
    [PSCustomObject]@{
        Category = "Never logged in"
        Count    = $never.Count
        Percent  = if ($total -gt 0) { "{0:P1}" -f ($never.Count / $total) } else { "0%" }
    }
    [PSCustomObject]@{
        Category = "1 year since last login"
        Count    = $oneYear.Count
        Percent  = if ($total -gt 0) { "{0:P1}" -f ($oneYear.Count / $total) } else { "0%" }
    }
    [PSCustomObject]@{
        Category = "1.5 to 2 years since last login"
        Count    = $oneHalfToTwo.Count
        Percent  = if ($total -gt 0) { "{0:P1}" -f ($oneHalfToTwo.Count / $total) } else { "0%" }
    }
    [PSCustomObject]@{
        Category = "More than 2 years since last login"
        Count    = $moreThanTwo.Count
        Percent  = if ($total -gt 0) { "{0:P1}" -f ($moreThanTwo.Count / $total) } else { "0%" }
    }

    [PSCustomObject]@{
        Category = "Total"
        Count    = $total
        Percent  = "100%"
    }
)

# Display summary
Write-Host ""
Write-Host "Summary Report" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

Write-Host ""
Write-Host "Detailed Groups" -ForegroundColor Cyan

Write-Host "`nNever logged in:" -ForegroundColor Yellow
$never | Select-Object Username, FullName, Email, DaysSinceLastLogin | Format-Table -AutoSize

Write-Host "`n1 year since last login:" -ForegroundColor Yellow
$oneYear | Select-Object Username, FullName, Email, LastLogin, DaysSinceLastLogin | Format-Table -AutoSize

Write-Host "`n1.5 to 2 years since last login:" -ForegroundColor Yellow
$oneHalfToTwo | Select-Object Username, FullName, Email, LastLogin, DaysSinceLastLogin | Format-Table -AutoSize

Write-Host "`nMore than 2 years since last login:" -ForegroundColor Yellow
$moreThanTwo | Select-Object Username, FullName, Email, LastLogin, DaysSinceLastLogin | Format-Table -AutoSize


# Optional Exports: Two files
if ($ExportPath) {

    if (-not (Test-Path $ExportPath)) {
        Write-Host "Export directory does not exist. Creating: $ExportPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }

    $inputName = [IO.Path]::GetFileNameWithoutExtension($CsvPath)

    # 1. Summary file
    $summaryFile = Join-Path $ExportPath ("{0}_summary.csv" -f $inputName)
    $summary | Export-Csv -NoTypeInformation -Path $summaryFile

    # 2. Classified full CSV file
    $classifiedFile = Join-Path $ExportPath ("{0}_classified.csv" -f $inputName)
    $users | Export-Csv -NoTypeInformation -Path $classifiedFile

    Write-Host "`nSummary exported to:     $summaryFile" -ForegroundColor Green
    Write-Host "Classified CSV exported to: $classifiedFile" -ForegroundColor Green
}