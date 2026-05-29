# **ArcGIS Users (PowerShell)**

This folder contains PowerShell scripts and an optional PowerShell module for managing, auditing, and analyzing ArcGIS Online (AGOL) and ArcGIS Enterprise Portal user accounts within the `ArcGISManagement` toolkit.

## **Available Tools**

- **Get-StaleUsers.ps1** — Identifies and exports inactive user accounts.  
- **Find-ArcGISUser.ps1** — Searches for users by email or username and returns profile details.  
- **Get-ArcGISUser.ps1** — Retrieves full details for a specific user, including license type, credits, and counts.  
- **Users.psm1** — Optional module that exposes all user tools as importable cmdlets.

---

# **Using the Users Toolkit Module (Users.psm1)**

The `Users.psm1` module provides a clean, unified interface for all user‑related scripts.  
It does **not** modify the underlying `.ps1` files — it simply wraps them as cmdlets.

## Folder Structure

Place the module in the same folder as your scripts:

```
Users/
  Users.psm1
  Get-ArcGISUser.ps1
  Find-ArcGISUser.ps1
  Get-StaleUsers.ps1
  .env
```

## Importing the Module

```powershell
Import-Module ./Users/Users.psm1 -Force
```

## Available Cmdlets

After importing, the following commands become available:

- **Get-ArcGISUser**  
- **Find-ArcGISUser**  
- **Get-StaleArcGISUsers**

## Examples

### Get a specific user

```powershell
Get-ArcGISUser -Source agol -Username "username"
```

### Search for a user by email

```powershell
Find-ArcGISUser -Source portal -Email "someone@example.com"
```

### Get stale users

```powershell
Get-StaleArcGISUsers -Source agol -ExportCsv
```

---

# **Get-StaleUsers.ps1**

Identifies stale or inactive ArcGIS users (≥ 1 year since last login or never logged in).  
Exports summary and detailed CSVs if requested.

## Installation (Standalone)

Place the module files in a folder named `Users`:

```
Users/
  Get-StaleArcGISUsers.psm1
  .env
```

## Importing the Module (Standalone)

```powershell
Import-Module ./Users/Get-StaleArcGISUsers.psm1 -Force
```

## Command Overview

### **Get-StaleArcGISUsers**

Fetches all users, filters stale accounts, classifies them, and optionally exports results.

#### Parameters

- **-Source** (Required)  
  `portal` or `agol`

- **-ExportPath** (Optional)  
  Directory to export summary and classified CSV files.

- **-ExportCsv** (Optional, Switch)  
  Exports a raw CSV of stale users to the current directory.

## Examples

```powershell
Get-StaleArcGISUsers -Source portal
Get-StaleArcGISUsers -Source agol -ExportPath ./out
Get-StaleArcGISUsers -Source portal -ExportCsv
```

---

# **Find-ArcGISUser.ps1**

Searches for a user by **email** or **username** within AGOL or Portal.  
Returns lightweight profile information and license type (AGOL only).

## Parameters

- **-Source** (Required)  
  `portal` or `agol`

- **-Email** (Optional, exclusive with -Username)  
- **-Username** (Optional, exclusive with -Email)

## Behavior

- No matches → warning  
- One match → formatted details  
- Multiple matches → table  
- Fetches AGOL license type via `/userLicenseType`  
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