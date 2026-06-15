# Mock DICOM Analytics Schemas

This project uses four MariaDB schemas to model a simplified DICOM ingestion and analytics pipeline. The goal is to give the RCA agent realistic database structures for lineage, dashboard debugging, and root cause analysis.

## Pipeline Flow

```text
Datahub
-> analytics_exposition
-> analytics_exposition_extract
-> analytics
-> Analytics UI widgets
```

## Datahub

`Datahub` represents the ingestion service storage layer. It stores DICOM files after they are discovered, parsed, and written to MariaDB.

Main responsibility:

- Track source DICOM files and ingestion status.
- Store parsed DICOM study, series, and instance metadata.
- Preserve raw DICOM tag values for traceability.
- Capture ingestion events and failures.

Tables:

- `dicom_file`: source file path, file metadata, ingestion status, parse status, and failure message.
- `dicom_study`: study-level DICOM metadata such as Study Instance UID, patient fields, study date, accession number, and referring physician.
- `dicom_series`: series-level metadata such as Series Instance UID, modality, body part, protocol, and manufacturer.
- `dicom_instance`: instance-level metadata such as SOP Instance UID, acquisition date/time, image dimensions, and transfer syntax.
- `dicom_tag_value`: flexible raw DICOM tag storage for fields not promoted into structured columns.
- `ingestion_event`: event history for file discovery, parsing, DB writes, and failures.

Example RCA use:

If a dashboard count is low, support can check whether files were received, parsed, failed, skipped, or missing in `Datahub`.

## analytics_exposition

`analytics_exposition` represents the hourly ETL output. It converts raw ingestion data into analytics-ready dimensions and facts.

Main responsibility:

- Normalize source data into facts and dimensions.
- Provide stable business fields for downstream analytics.
- Preserve references back to source `Datahub` identifiers.
- Track ETL batch IDs and analytics availability timestamps.
- Store data quality and pipeline status facts.

Tables:

- `dim_facility`: facility/site reference data.
- `dim_modality`: modality reference data such as CT, MR, XR, and US.
- `dim_referring_physician`: referring physician reference data.
- `fact_study`: study-level analytic fact with source study ID, modality, facility, demographics, counts, and ETL batch metadata.
- `fact_ingestion_file`: analytics-ready view of ingestion file status.
- `fact_pipeline_status`: ETL batch/run status by pipeline stage.
- `fact_data_quality_issue`: detected quality issues such as missing modality, invalid dates, or unmapped facility.

Example RCA use:

If `Datahub` has the correct records but the dashboard is wrong, this schema helps determine whether the hourly ETL missed records, mapped fields incorrectly, or created data quality exceptions.

## analytics_exposition_extract

`analytics_exposition_extract` represents the daily extract schema. It contains dashboard-ready aggregate tables, potentially in a separate database from `Datahub`.

Main responsibility:

- Store pre-aggregated metrics for UI performance.
- Support dashboard widgets without repeatedly scanning fact tables.
- Capture the latest refreshed state of daily analytic measures.

Tables:

- `dashboard_daily_study_volume`: study, series, and instance counts by date, facility, and modality.
- `dashboard_facility_volume`: study and failed file counts by facility.
- `dashboard_ingestion_health`: received, parsed, failed, and skipped file counts by facility.
- `dashboard_modality_body_part`: study counts by modality and body part.
- `dashboard_patient_demographics`: study counts by modality, age group, and sex.
- `dashboard_pipeline_status`: summarized pipeline status and latest batch metadata.

Example RCA use:

If the hourly analytics facts are correct but the UI is stale or incorrect, this schema helps verify whether the daily extract ran and whether aggregate tables were refreshed.

## analytics

`analytics` represents the UI-facing semantic layer. It contains views used by dashboard widgets.

Main responsibility:

- Provide stable query surfaces for the analytics UI.
- Hide joins and aggregate table details from the frontend.
- Expose lineage-friendly views for RCA.

Views:

- `vw_study_volume_by_modality`: supports the study volume by modality widget.
- `vw_daily_study_trend`: supports daily study trend charts.
- `vw_studies_by_facility`: supports facility/site volume dashboards.
- `vw_ingestion_health`: supports ingestion health and failure widgets.
- `vw_body_part_distribution`: supports clinical body part distribution analysis.
- `vw_patient_age_group_distribution`: supports patient demographic widgets.
- `vw_pipeline_status_breakdown`: supports ETL and pipeline status monitoring.
- `vw_top_referring_physicians`: supports referring physician volume analysis.
- `vw_duplicate_or_reprocessed_studies`: supports duplicate or reprocessed study investigation.
- `vw_rca_lineage_study`: supports RCA tracing from analytics records back to source study identifiers.

Example RCA use:

If extract tables are correct but the UI still shows incorrect values, support can inspect these views to identify view-level filter, join, grouping, or semantic mapping issues.

## Dashboard Use Cases

The schemas are designed to support these initial widgets:

1. Study volume by modality.
2. Daily study trend.
3. Studies by facility or site.
4. Turnaround or ingestion delay analysis.
5. Failed ingestion count.
6. Body part distribution.
7. Study or pipeline status breakdown.
8. Top referring physicians.
9. Patient age group distribution.
10. Duplicate or reprocessed studies.

## RCA Questions This Model Supports

The model is intended to help answer questions like:

- Did the source DICOM file arrive?
- Did parsing fail for the file?
- Was the study written to `Datahub`?
- Did the hourly ETL transform the study into `analytics_exposition`?
- Was the study mapped to the correct facility, modality, and body part?
- Did the daily extract refresh the aggregate dashboard tables?
- Is the analytics view filtering or grouping the data incorrectly?
- Is the dashboard stale because `last_refreshed_at` is old?

## Recreating the Schemas

Run the schema script with the MariaDB client:

```powershell
& 'C:\Program Files\MariaDB 12.3\bin\mariadb.exe' --skip-ssl -h localhost -P 3306 -u root -ppassword < .\sql\create_schemas.sql
```

For production-like environments, use a dedicated non-root user and avoid placing passwords directly in shell history.
