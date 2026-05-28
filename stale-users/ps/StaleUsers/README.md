StaleUsers PowerShell Module

A minimal README for using the StaleUsers PowerShell module.

Installation

Place the module files in a folder named StaleUsers:

StaleUsers\
    StaleUsers.psm1
    .env

Importing the Module

Import-Module ./StaleUsers/StaleUsers.psm1 -Force

Command Overview

Get-StaleArcGISUsers

Fetches all users, filters stale accounts (≥1 year inactive), classifies them, and optionally exports results.

Parameters

-Source (Required)Environment to query. Values: portal, agol

-ExportPath (Optional)Directory to export summary and classified CSV files.

-ExportCsv (Optional, Switch)Exports a raw CSV of stale users to the current directory.

Examples

1. Get stale users from Portal

Get-StaleArcGISUsers -Source portal

2. Get stale users from AGOL and export summary + classified CSVs

Get-StaleArcGISUsers -Source agol -ExportPath ./out

3. Export only the raw stale user list

Get-StaleArcGISUsers -Source portal -ExportCsv