
# StaleUsers PowerShell Module

A minimal README for using the **StaleUsers** PowerShell module.

---

## Installation

Place the module files in a folder named `StaleUsers`:

```
StaleUsers/
  StaleUsers.psm1
  .env
```

---

## Importing the Module

```powershell
Import-Module ./StaleUsers/StaleUsers.psm1 -Force
```

---

## Command Overview

### `Get-StaleArcGISUsers`
Fetches all users, filters stale accounts (≥ 1 year inactive), classifies them, and optionally exports results.

#### Parameters

- **-Source** (Required)  
  Environment to query. Values: `portal`, `agol`

- **-ExportPath** (Optional)  
  Directory to export summary and classified CSV files.

- **-ExportCsv** (Optional, Switch)  
  Exports a raw CSV of stale users to the current directory.

---

## Examples

### Get stale users from Portal
```powershell
Get-StaleArcGISUsers -Source portal
```

### Get stale users from AGOL and export summary + classified CSVs
```powershell
Get-StaleArcGISUsers -Source agol -ExportPath ./out
```

### Export only the raw stale user list
```powershell
Get-StaleArcGISUsers -Source portal -ExportCsv
```
