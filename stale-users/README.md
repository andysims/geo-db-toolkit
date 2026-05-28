
# StaleUsers (PowerShell)

Tool provides a way to audit ArcGIS Online (AGOL) or ArcGIS Enterprise Portal users and identify stale enterprise accounts. It uses the ArcGIS REST API directly and loads all connection settings from `.env` file (uses PowerShell parser; no external modules needed).

Tool can be used as a standalone script or adapted into a larger automation workflow.

## Features

### fetchStaleUsers.ps1

- Connects to either Portal or AGOL using values from `.env`
- Supports:
  - `-Source portal`
  - `-Source agol`
- Uses pagination to support large organizations
- Identifies enterprise users (`idpUsername` present)
- Flags users who:
  - never logged in
  - haven’t logged in for ≥ 1 year
- Collects detailed user information:
  - first, last, full name
  - email
  - idpUsername
  - created date
  - last login
  - content count
  - group count
  - role
  - user license type
- Prints results to screen
- Optional CSV export with automatic timestamped filename

### staleUsersSummary.ps1

- Reads the CSV exported from the first script
- Computes days since last login
- Assigns each user to a category:
  - never logged in
  - 1 year since last login
  - 1.5–2 years since last login
  - more than 2 years since last login
- Generates a summary table with counts and percentages
- Adds a “StaleCategory” field to every user
- Exports two CSV files (when export path is provided):
  - `[inputname]_summary.csv`
  - `[inputname]_classified.csv` (full user list with new fields)
- Prints detailed lists for each category

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

The `.env` file must be placed in the same directory as the scripts.

## Parameters

### fetchStaleUsers.ps1

**-Source**  
Either `portal` or `agol`. Determines which prefix to use when reading `.env` entries.

**-ExportCsv**  
Exports stale user details to a CSV file named:

```
stale_[source]_users_[yyyyMMdd].csv
```

**-ExportPath (optional, if added later)**  
If enabled, exports to the provided directory.

### staleUsersSummary.ps1

**-CsvPath**  
Path to the CSV exported from the first script.

**-ExportPath (optional)**  
Directory where summary and classified CSV files will be dumped.

## Usage Examples

### Pull stale users from Portal
```
.\fetchStaleUsers.ps1 -Source portal
```

### Export stale AGOL users to CSV
```
.\fetchStaleUsers.ps1 -Source agol -ExportCsv
```

### Summarize a stale-user CSV
```
.\staleUsersSummary.ps1 -CsvPath .\stale_portal_users_20260527.csv
```

### Export summaries to a directory
```
.\staleUsersSummary.ps1 -CsvPath .\stale_agol_users_20260527.csv -ExportPath .
eports```

## Notes

- No external modules are required — `.env` values are parsed.
- No ArcGIS-specific PowerShell modules are required; everything uses REST API calls.
- The stale-user script supports pagination.
- The summary script expects the CSV format produced by the first script.
- Scripts are intended for internal automation but can easily be adapted or extended.
