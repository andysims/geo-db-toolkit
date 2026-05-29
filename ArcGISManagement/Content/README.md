# **ArcGIS Content (PowerShell)**

This folder contains PowerShell scripts and an optional PowerShell module for managing, auditing, and analyzing ArcGIS Online (AGOL) and ArcGIS Enterprise Portal **content items** within the `ArcGISManagement` toolkit.

## **Available Tools**

- **Get-ContentSummary.ps1** — Generates an organizational content summary, including totals, sharing breakdowns, top creators, and content type distribution.  
- **Get-NewArcGISItems.ps1** — Lists newly created content within the last *N* days (default: 7).  
- **Find-ArcGISContent.ps1** — Searches for content by owner, title, item ID, or type, with partial matching support.  
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
  Get-NewArcGISItems.ps1
  Find-ArcGISContent.ps1
  .env
```

## Importing the Module

```powershell
Import-Module ./Content/Content.psm1 -Force
```

## Available Cmdlets

After importing, the following commands become available:

- **Get-ArcGISContentSummary**  
- **Get-NewArcGISItems**  
- **Find-ArcGISContent**

## Examples

### Get a content summary

```powershell
Get-ArcGISContentSummary -Source portal
```

### Find content by partial title

```powershell
Find-ArcGISContent -Source agol -Title "map"
```

### List new items created in the last 14 days

```powershell
Get-NewArcGISItems -Source portal -Days 14
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

## Example

```powershell
Get-ArcGISContentSummary -Source agol -ExportTxt
```

---

# **Get-NewArcGISItems.ps1**

Returns all content created within the last *N* days (default: 7).  
Results are sorted newest → oldest and include:

- Title  
- Item ID  
- Created (AM/PM)  
- Type  
- Access  

## Example

```powershell
Get-NewArcGISItems -Source portal -Days 10
```

---

# **Find-ArcGISContent.ps1**

Searches for content using any combination of:

- **-Owner** (exact username)  
- **-Title** (partial match)  
- **-Id** (exact item ID)  
- **-Type** (partial match)  

Behavior:

- One match → **Format‑List**  
- Multiple matches → **Format‑Table -AutoSize**  
- Zero matches → “No content found…”  

Includes:

- Title  
- Item ID  
- Created (AM/PM)  
- Modified (AM/PM)  
- Type  
- Access  
- Owner  

## Example

```powershell
Find-ArcGISContent -Source agol -Type "dashboard"
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

The `-Source` parameter automatically selects the correct prefix (`portal_` or `agol_`).

---