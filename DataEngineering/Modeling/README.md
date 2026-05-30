# Modeling

Utilities related to data structure inference, table modeling, and definition generation.  
This directory contains small, focused tools that help analyze datasets and produce database-ready models.  
Additional tools will be added over time as the toolkit grows.

---

## Tools

### **Convert-CsvToDdl.ps1**

PowerShell script that reads a CSV file, infers a reasonable table structure, and generates a `CREATE TABLE` statement for PostgreSQL or SQL Server.

#### What it does

- Reads a CSV file (or a sample of rows)
- Cleans and standardizes column names  
  (spaces → underscores, lowercase for PostgreSQL)
- Infers basic data types (int, float, datetime, string)
- Estimates maximum text lengths and pads conservatively
- Outputs:
  - an inferred schema table
  - a SQL `CREATE TABLE` statement
- Optional: exports the inferred schema to a CSV file

This tool is meant to speed up initial table creation when exploring new datasets.  
Always review the generated DDL before running it in a database.

#### What it is *not*

This is not a full ETL pipeline or a general-purpose CSV loader.  
For more advanced workflows, consider tools like:

- `csvsql` (csvkit)
- `ogr2ogr`
- `Invoke-Sqlcmd` scripts
- SQL Server import utilities (`sqlcmd`, SSMS wizards, dbatools)

The script intentionally keeps its logic simple and predictable.

#### Usage examples

```powershell
.\Convert-CsvToDdl.ps1 -CsvPath .\customers.csv -TableName customers -Dialect postgresql
.\Convert-CsvToDdl.ps1 -CsvPath .\customers.csv -TableName customers -Dialect postgresql -ExportCsv
.\Convert-CsvToDdl.ps1 -CsvPath .\customers.csv -Delimiter '|' -TableName customers -Dialect postgresql
