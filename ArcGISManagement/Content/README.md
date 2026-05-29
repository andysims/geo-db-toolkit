# **ArcGIS Content (PowerShell)**

This folder contains PowerShell scripts and an optional PowerShell module for managing, auditing, and analyzing ArcGIS Online (AGOL) and ArcGIS Enterprise Portal **content items** within the `ArcGISManagement` toolkit.

## **Available Tools**

- **Get-ContentSummary.ps1** — Generates an organizational content summary, including totals, sharing breakdowns, top creators, and content type distribution.  
- **Content.psm1** — Optional module that exposes all content tools as importable cmdlets.

---

# **Using the Content Toolkit Module (Content.psm1)**

The `Content.psm1` module provides a clean, unified interface for all content‑related scripts.  
It does **not** modify the underlying `.ps1` files — it simply wraps them as cmdlets.

## Folder Structure

Place the module in the same folder as your scripts:

```
Content/
  Content.psm1
  Get-ContentSummary.ps1
  .env
```

## Importing the Module

```powershell
Import-Module ./Content/Content.psm1 -Force
```

## Available Cmdlets

After importing, the following commands become available:

- **Get-ArcGISContentSummary**

## Examples

### Get a content summary for Portal

```powershell
Get-ArcGISContentSummary -Source portal
```

### Export a TXT summary for AGOL

```powershell
Get-ArcGISContentSummary -Source agol -ExportTxt
```

---

# **Get-ContentSummary.ps1**

Generates a high‑level organizational content summary, including:

- Total content count  
- Admin user’s content count  
- Oldest + newest content (AM/PM formatting)  
- Sharing breakdown (Public, Org, Shared, Private)  
- Top 10 users by content count  
- Content type distribution  
- Optional TXT export to Downloads  
- Automatic exclusion of Esri system accounts (`esri_*`, `esri-`, `esri.`)

## Installation (Standalone)

Place the script in a folder named `Content`:

```
Content/
  Get-ContentSummary.ps1
  .env
```

## Importing the Module (Standalone)

```powershell
Import-Module ./Content/Content.psm1 -Force
```

## Command Overview

### **Get-ContentSummary**

Fetches all content items in the organization, filters out Esri system accounts, computes summary metrics, and optionally exports a TXT report.

#### Parameters

- **-Source** (Required)  
  `portal` or `agol`

- **-ExportTxt** (Optional, Switch)  
  Exports a TXT summary to the user's Downloads folder.

## Examples

```powershell
Get-ContentSummary -Source portal
Get-ContentSummary -Source agol -ExportTxt
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
