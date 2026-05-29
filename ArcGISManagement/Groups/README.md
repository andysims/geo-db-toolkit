
# ArcGIS Groups (PowerShell)

This tool audits ArcGIS Online (AGOL) and ArcGIS Enterprise Portal groups using the ArcGIS REST API.  
It retrieves group membership, user profiles, and detailed group statistics (no Esri modules req.).  
All connection settings are loaded from a `.env` file, making the tool portable and easy to automate.

The script can be used interactively, as part of administrative workflows, or scheduled for regular audits.

## Features

### Get-ArcGISGroup.ps1

- Connects to either **Portal** or **AGOL** using `.env` configuration
- Supports:
  - `-Source portal`
  - `-Source agol`
- Retrieves full group metadata:
  - Title, ID, created timestamp
  - Item count
  - Member totals (admin + member + owner)
- Fetches group membership directly from REST API, including:
  - Owner
  - Admins
  - Members
- Fetches **full user profiles** for each member:
  - fullName
  - email
  - idpUsername
  - created date
  - joined date
  - lastLogin
  - userLicenseType
- Supports **two CSV exports**:
  - **Minimal CSV**  
    Username, FullName, MemberType, Joined  
  - **Full Profile CSV**  
    Includes all profile attributes returned by the API
- Includes robust fallbacks for Portal environments that return usernames only
- Prints a clean summary of group information

## .env File Example

```
-------------------------------------------------------
ArcGIS Portal
-------------------------------------------------------
portal_url=https://myportal.domain.com/portal
portal_username=my_portal_user
portal_password=my_portal_password

-------------------------------------------------------
ArcGIS Online
-------------------------------------------------------
agol_url=https://www.arcgis.com
agol_username=my_agol_user
agol_password=my_agol_password
```

The `.env` file must be placed in the same directory as `Get-ArcGISGroup.ps1`.

## Parameters

### **Get-ArcGISGroup.ps1**

**-SearchGroup**  
Searches for a group and prints group details, members, and optionally exports CSV files.  
Requires either `-Name` or `-ID`.

**-CreateGroup**  
Creates a new Portal/AGOL group using REST API.

**-Name**  
Group name to search or create.

**-ID**  
Group ID to fetch directly.

**-Source**  
Either `portal` or `agol`.  
Determines which credentials and URL to load from `.env`.

**-ExportCsv**  
Enables export of:
- `[title]_[yyyyMMdd]_minimal.csv`
- `[title]_[yyyyMMdd]_full.csv`

**-ExportPath (optional)**  
Directory to write CSV files to.  
If omitted, files write to the working directory.

**-Description (for CreateGroup)**  
Optional text used when creating a group.

**-Thumbnail (for CreateGroup)**  
Optional path to a thumbnail image to upload with the group.

## Output Details

### **Console Summary Example**

```
=============================
 Group Information
=============================
Name              : Fire Department
ID                : 12345678998765432112345678998765
Created           : 01/01/2026 02:22:23 PM
Group Members     : 12
Group Content     : 6 items

Owner    : FireDeptChief
Members  : 11

Exported Minimal CSV : Fire Department_20260528_minimal.csv
Exported Full CSV    : Fire Department_20260528_full.csv
```

### **Minimal CSV Columns**

```
Username
FullName
MemberType
Joined
```

### **Full CSV Columns**

```
Username
FullName
Email
IdpUsername
MemberType
Created
Joined
LastLogin
UserLicenseType
```

## Usage Examples

### Search for a Portal group by name
```
.\Get-ArcGISGroup.ps1 -SearchGroup -Source portal -Name "Public Works Services"
```

### Search by group ID in AGOL and export CSVs
```
.\Get-ArcGISGroup.ps1 -SearchGroup -Source agol -ID abcd1234efgh5678 -ExportCsv
```

### Export to a specific directory
```
.\Get-ArcGISGroup.ps1 -SearchGroup -Name "Fire" -ExportCsv -ExportPath "C:\Reports"
```

### Create a new Portal group
```
.\Get-ArcGISGroup.ps1 -CreateGroup -Source portal -Name "GIS Admin Tools" -Description "Admin automation group"
```

## Notes

- No Esri modules required.
- User profiles are fetched individually.
- CSV exports are created automatically.
