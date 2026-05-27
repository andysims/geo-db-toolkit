# CSV → Database Table Helper (PowerShell)

## csv-to-ddl.ps1
PowerShell script to help automate one of the tasks I end up doing a lot:  
looking at a CSV file and generating a reasonable database table definition from it.

Reads a CSV, infers basic data types, estimates field lengths, and outputs a `CREATE TABLE` statement for either PostgreSQL or SQL Server. Nothing fancy, but saves time when working with new datasets or preparing tables before loading data.

Although I originally built this for personal use, others might find it helpful, so feel free to use it or adapt it to your own workflow.

## What this tool does

- Reads a CSV file (or a sample of rows)
- Cleans and standardizes column names  
  (spaces → underscores, lowercasing for PostgreSQL)
- Tries to guess the field type (int, float, datetime, string)
- For text fields, checks the longest value and pads the size
- Prints:
  - an inferred schema
  - a SQL `CREATE TABLE` statement
- Can optionally export the inferred schema to a CSV for review

This is mainly meant to help with initial table creation before importing data. You should always look over the output before running it — the script intentionally keeps the logic conservative and predictable.

## What this tool is *not*

This isn’t a full ETL tool or a general‑purpose CSV‑to‑database loader.  
For more advanced or production‑grade workflows, you may want to look into:

- `csvsql` from the `csvkit` suite
- `ogr2ogr` for spatial or large-scale data transformations
- A basic PowerShell script that creates a table directly using `Invoke-Sqlcmd`
- For SQL Server:
  - “Import Flat File Wizard” in SSMS
  - `sqlcmd`
  - `dbatools`
  - `OPENROWSET` for ad‑hoc imports


This script is intentionally simple — just enough logic to guess reasonable column definitions based on the content you provide.

## How to use it

### Basic example

```powershell
.\csv-to-ddl.ps1 -CsvPath .\customers.csv -TableName customers -Dialect postgresql
.\csv-to-ddl.ps1 -CsvPath .\customers.csv -TableName customers -Dialect postgresql -ExportCsv
.\csv-to-ddl.ps1 -CsvPath .\customers.csv -Delimiter '|' -TableName customers -Dialect postgresql