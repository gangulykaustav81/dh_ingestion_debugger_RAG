# RCA Runbook

## Missing or Low Dashboard Count

Start from the UI widget and trace backward through the semantic view, extract aggregate table, exposition fact table, and `Datahub` source table.

Primary checks:

- Confirm dashboard filters for date, facility, modality, and body part.
- Compare the analytics view count with the extract aggregate table.
- Compare extract aggregates with `analytics_exposition.fact_study`.
- Compare exposition facts with `Datahub.dicom_study`, `Datahub.dicom_series`, and `Datahub.dicom_instance`.
- Check ingestion failures in `Datahub.dicom_file` and `Datahub.ingestion_event`.

Useful tables and views:

- `analytics.vw_study_volume_by_modality`
- `analytics.vw_daily_study_trend`
- `analytics_exposition_extract.dashboard_daily_study_volume`
- `analytics_exposition.fact_study`
- `Datahub.dicom_study`
- `Datahub.dicom_series`
- `Datahub.dicom_file`

## Stale Dashboard

A stale dashboard usually means the analytics view is reading old extract data or an ETL stage did not complete.

Primary checks:

- Check `last_refreshed_at` on the relevant analytics view.
- Check `analytics_exposition_extract` aggregate table refresh timestamps.
- Check `analytics_exposition.fact_pipeline_status` for failed or delayed hourly and daily ETL batches.
- Compare the latest source study date in `Datahub` with the latest study date in extract tables.

## Failed Ingestion

Failed ingestion can explain lower study counts, missing modalities, missing sites, and gaps in trend charts.

Primary checks:

- Review `Datahub.dicom_file.ingest_status`.
- Inspect `Datahub.ingestion_event` for parse failures and DB write failures.
- Check whether failed files belong to the affected facility, date range, or modality.
- Confirm whether failed files were retried, skipped, or reprocessed.

## Modality or Body Part Mismatch

Modality and body part issues usually originate from DICOM tag parsing or ETL normalization.

Primary checks:

- Review `Datahub.dicom_series.modality`.
- Review `Datahub.dicom_series.body_part_examined`.
- Review raw tags in `Datahub.dicom_tag_value`.
- Compare source fields with `analytics_exposition.fact_study`.
- Check `analytics.vw_body_part_distribution`.

## Facility or Site Mismatch

Facility issues can occur when site mapping is derived from file path, source system, or DICOM tags.

Primary checks:

- Review source file paths in `Datahub.dicom_file`.
- Review facility mappings in `analytics_exposition.dim_facility`.
- Compare facility-level counts in `analytics.vw_studies_by_facility`.
- Check for unmapped or unknown facility IDs in downstream tables.

## Duplicate or Reprocessed Studies

Duplicate or reprocessed studies can inflate counts or create inconsistent dashboard totals.

Primary checks:

- Check duplicate Study Instance UID values.
- Check duplicate Series Instance UID values.
- Check duplicate SOP Instance UID values.
- Review first and last ingestion timestamps.
- Use `analytics.vw_duplicate_or_reprocessed_studies`.

