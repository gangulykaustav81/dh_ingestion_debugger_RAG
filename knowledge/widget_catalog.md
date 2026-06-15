# Widget Catalog

## Study Volume by Modality

Business question:

- How many studies were performed by modality for the selected date and facility?

Primary analytics view:

- `analytics.vw_study_volume_by_modality`

Upstream lineage:

- `analytics_exposition_extract.dashboard_daily_study_volume`
- `analytics_exposition.dim_modality`
- `analytics_exposition.dim_facility`
- `analytics_exposition.fact_study`
- `Datahub.dicom_series`
- `Datahub.dicom_study`

## Daily Study Trend

Business question:

- Are study volumes stable over time, or is there a sudden drop/spike?

Primary analytics view:

- `analytics.vw_daily_study_trend`

Upstream lineage:

- `analytics_exposition_extract.dashboard_daily_study_volume`
- `analytics_exposition.fact_study`
- `Datahub.dicom_study`

## Studies by Facility

Business question:

- Which facilities are contributing study volume, and is one site missing data?

Primary analytics view:

- `analytics.vw_studies_by_facility`

Upstream lineage:

- `analytics_exposition_extract.dashboard_facility_volume`
- `analytics_exposition.dim_facility`
- `analytics_exposition.fact_study`
- `Datahub.dicom_file`

## Ingestion Health

Business question:

- Are DICOM files being received, parsed, and written successfully?

Primary analytics view:

- `analytics.vw_ingestion_health`

Upstream lineage:

- `analytics_exposition_extract.dashboard_ingestion_health`
- `analytics_exposition.fact_ingestion_file`
- `Datahub.dicom_file`
- `Datahub.ingestion_event`

## Body Part Distribution

Business question:

- What body parts are represented by modality and date?

Primary analytics view:

- `analytics.vw_body_part_distribution`

Upstream lineage:

- `analytics_exposition_extract.dashboard_modality_body_part`
- `analytics_exposition.fact_study`
- `Datahub.dicom_series`
- `Datahub.dicom_tag_value`

## Patient Age Group Distribution

Business question:

- What patient demographic groups are represented in the study population?

Primary analytics view:

- `analytics.vw_patient_age_group_distribution`

Upstream lineage:

- `analytics_exposition_extract.dashboard_patient_demographics`
- `analytics_exposition.fact_study`
- `Datahub.dicom_study`

## Pipeline Status Breakdown

Business question:

- Which pipeline stage is delayed, failed, or producing fewer records than expected?

Primary analytics view:

- `analytics.vw_pipeline_status_breakdown`

Upstream lineage:

- `analytics_exposition_extract.dashboard_pipeline_status`
- `analytics_exposition.fact_pipeline_status`

## Top Referring Physicians

Business question:

- Which referring physicians are associated with the highest study volume?

Primary analytics view:

- `analytics.vw_top_referring_physicians`

Upstream lineage:

- `analytics_exposition.fact_study`
- `analytics_exposition.dim_referring_physician`
- `Datahub.dicom_study`

## Duplicate or Reprocessed Studies

Business question:

- Are duplicate or reprocessed studies inflating dashboard totals?

Primary analytics view:

- `analytics.vw_duplicate_or_reprocessed_studies`

Upstream lineage:

- `analytics_exposition.fact_study`
- `Datahub.dicom_study`
- `Datahub.dicom_series`
- `Datahub.dicom_instance`

## RCA Lineage Study

Business question:

- How can a downstream analytic study record be traced back to source identifiers?

Primary analytics view:

- `analytics.vw_rca_lineage_study`

Upstream lineage:

- `analytics_exposition.fact_study`
- `analytics_exposition.dim_facility`
- `analytics_exposition.dim_modality`
- `Datahub.dicom_study`

