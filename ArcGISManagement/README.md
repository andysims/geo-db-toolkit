# ArcGISManagement

A collection of PowerShell tools and modules for automating and managing Esri ArcGIS Online (AGOL) and ArcGIS Enterprise Portal environments. 

These tools are designed to assist with admin workflows.

## Directory Structure

This repository is organized into domain-specific folders:

* **`Groups/`** - Scripts for auditing, creating, and managing ArcGIS groups and memberships.
* **`Users/`** - Tools for user lifecycle management, profile audits, and identifying inactive/stale accounts.
* **`Content/`** - Tools for item auditing, sharing settings, and data management.

## Configuration

Most tools utilize a shared or directory-specific `.env` file to securely handle Portal and AGOL connection parameters (`url`, `username`, `password`) across automated environments. Refer to the README within each subfolder for specific configuration requirements.
