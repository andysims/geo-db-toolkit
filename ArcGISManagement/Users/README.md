# **ArcGIS Users (PowerShell)**

This folder contains PowerShell scripts for managing, auditing, and analyzing ArcGIS Online (AGOL) and ArcGIS Enterprise Portal user accounts within the `ArcGISManagement` module.

## **Available Tools**

- **Get-StaleUsers.ps1** — Identifies and exports inactive user accounts.  
- **Find-ArcGISUser.ps1** — Searches for users by email or username and returns profile details.  
- **Get-ArcGISUser.ps1** — Retrieves full details for a specific user, including license type, credits, and counts.

---

# **Get-StaleUsers.ps1**

Identifies stale or inactive ArcGIS users (≥ 1 year since last login or never logged in).  
Exports summary and detailed CSVs if requested.

## Installation

Place the module files in a folder named `StaleUsers`:

```
Users/
  Get-StaleArcGISUsers.psm1
  .env
```

## Importing the Module

```powershell
Import-Module ./Users/Get-StaleArcGISUsers.psm1 -Force
```

## Command Overview

### **Get-StaleArcGISUsers**

Fetches all users, filters stale accounts, classifies them, and optionally exports results.

#### Parameters

- **-Source** (Required)  
  Environment to query. Values: `portal`, `agol`

- **-ExportPath** (Optional)  
  Directory to export summary and classified CSV files.

- **-ExportCsv** (Optional, Switch)  
  Exports a raw CSV of stale users to the current directory.

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

---

# **Find-ArcGISUser.ps1**

Searches for a user by **email** or **username** within AGOL or Portal.  
Returns lightweight profile information and license type (AGOL only).

## Parameters

- **-Source** (Required)  
  `portal` or `agol`

- **-Email** (Optional, mutually exclusive with -Username)  
  Exact email address to search for

- **-Username** (Optional, mutually exclusive with -Email)  
  Exact username to search for

## Behavior

- If **no users** match → prints a warning  
- If **one user** matches → prints formatted details  
- If **multiple users** match → prints a table  
- Fetches AGOL license type via `/userLicenseType` endpoint  
- Portal users return `N/A` for license type

## Example

```powershell
Find-ArcGISUser -Source agol -Email "someone@example.com"
```

---

# **Get-ArcGISUser.ps1**

Retrieves **full details** for a specific user, including:

- First/Last name  
- Email  
- idpUsername  
- Created / Last Login (AM/PM formatting)  
- Role  
- License Type ID + Name (AGOL only)  
- Group count  
- Owned content count  
- Org ID  
- Disabled / Access / Provider  
- Available & Assigned Credits (AGOL only)

## Parameters

- **-Source** (Required)  
  `portal` or `agol`

- **-Username** (Required)  
  Exact username to retrieve

## Example

```powershell
Get-ArcGISUser -Source agol -Username "username"
```

---

# **Environment File (.env)**

All scripts rely on a `.env` file in the same directory:

```
portal_url=
portal_username=
portal_password=

agol_url=
agol_username=
agol_password=
```

---
