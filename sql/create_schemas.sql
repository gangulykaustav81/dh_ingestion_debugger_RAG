CREATE DATABASE IF NOT EXISTS Datahub
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS analytics_exposition
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS analytics_exposition_extract
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS analytics
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE Datahub;

CREATE TABLE IF NOT EXISTS dicom_file (
  file_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_path VARCHAR(1024) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_size_bytes BIGINT NULL,
  file_hash_sha256 CHAR(64) NULL,
  ingest_status ENUM('RECEIVED','PARSED','FAILED','SKIPPED') NOT NULL DEFAULT 'RECEIVED',
  received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  parsed_at DATETIME NULL,
  error_message TEXT NULL,
  UNIQUE KEY uq_dicom_file_source_path (source_path)
);

CREATE TABLE IF NOT EXISTS dicom_study (
  study_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  file_id BIGINT NULL,
  study_instance_uid VARCHAR(128) NOT NULL,
  patient_id VARCHAR(128) NULL,
  patient_name VARCHAR(255) NULL,
  patient_birth_date DATE NULL,
  patient_sex VARCHAR(16) NULL,
  study_date DATE NULL,
  study_time TIME NULL,
  accession_number VARCHAR(128) NULL,
  study_description VARCHAR(512) NULL,
  referring_physician_name VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_study_instance_uid (study_instance_uid),
  KEY idx_study_patient_id (patient_id),
  KEY idx_study_date (study_date),
  CONSTRAINT fk_study_file FOREIGN KEY (file_id) REFERENCES dicom_file(file_id)
);

CREATE TABLE IF NOT EXISTS dicom_series (
  series_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  study_id BIGINT NOT NULL,
  series_instance_uid VARCHAR(128) NOT NULL,
  modality VARCHAR(32) NULL,
  body_part_examined VARCHAR(128) NULL,
  series_number INT NULL,
  series_description VARCHAR(512) NULL,
  protocol_name VARCHAR(255) NULL,
  station_name VARCHAR(128) NULL,
  manufacturer VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_series_instance_uid (series_instance_uid),
  KEY idx_series_modality (modality),
  KEY idx_series_study_id (study_id),
  CONSTRAINT fk_series_study FOREIGN KEY (study_id) REFERENCES dicom_study(study_id)
);

CREATE TABLE IF NOT EXISTS dicom_instance (
  instance_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  series_id BIGINT NOT NULL,
  file_id BIGINT NOT NULL,
  sop_instance_uid VARCHAR(128) NOT NULL,
  sop_class_uid VARCHAR(128) NULL,
  instance_number INT NULL,
  image_type VARCHAR(512) NULL,
  acquisition_date DATE NULL,
  acquisition_time TIME NULL,
  rows_count INT NULL,
  columns_count INT NULL,
  transfer_syntax_uid VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_sop_instance_uid (sop_instance_uid),
  KEY idx_instance_series_id (series_id),
  KEY idx_instance_file_id (file_id),
  KEY idx_instance_acquisition_date (acquisition_date),
  CONSTRAINT fk_instance_series FOREIGN KEY (series_id) REFERENCES dicom_series(series_id),
  CONSTRAINT fk_instance_file FOREIGN KEY (file_id) REFERENCES dicom_file(file_id)
);

CREATE TABLE IF NOT EXISTS dicom_tag_value (
  tag_value_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  file_id BIGINT NOT NULL,
  entity_type ENUM('FILE','STUDY','SERIES','INSTANCE') NOT NULL,
  entity_id BIGINT NULL,
  tag_group CHAR(4) NOT NULL,
  tag_element CHAR(4) NOT NULL,
  tag_keyword VARCHAR(128) NULL,
  vr VARCHAR(8) NULL,
  tag_value TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tag_file (file_id),
  KEY idx_tag_lookup (tag_group, tag_element),
  KEY idx_tag_keyword (tag_keyword),
  CONSTRAINT fk_tag_file FOREIGN KEY (file_id) REFERENCES dicom_file(file_id)
);

CREATE TABLE IF NOT EXISTS ingestion_event (
  event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  file_id BIGINT NULL,
  event_type ENUM('DISCOVERED','READ_STARTED','PARSE_SUCCEEDED','PARSE_FAILED','DB_WRITE_SUCCEEDED','DB_WRITE_FAILED') NOT NULL,
  event_message TEXT NULL,
  event_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_event_file_id (file_id),
  KEY idx_event_type_at (event_type, event_at),
  CONSTRAINT fk_event_file FOREIGN KEY (file_id) REFERENCES dicom_file(file_id)
);

USE analytics_exposition;

CREATE TABLE IF NOT EXISTS dim_facility (
  facility_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  facility_id VARCHAR(64) NOT NULL,
  facility_name VARCHAR(255) NOT NULL,
  region VARCHAR(128) NULL,
  active_flag BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_facility_id (facility_id)
);

CREATE TABLE IF NOT EXISTS dim_modality (
  modality_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  modality_code VARCHAR(32) NOT NULL,
  modality_name VARCHAR(128) NOT NULL,
  clinical_category VARCHAR(128) NULL,
  active_flag BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_modality_code (modality_code)
);

CREATE TABLE IF NOT EXISTS dim_referring_physician (
  physician_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  physician_name VARCHAR(255) NOT NULL,
  physician_identifier VARCHAR(128) NULL,
  active_flag BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_physician_name_identifier (physician_name, physician_identifier)
);

CREATE TABLE IF NOT EXISTS fact_study (
  study_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_study_id BIGINT NOT NULL,
  source_study_instance_uid VARCHAR(128) NOT NULL,
  facility_key BIGINT NULL,
  modality_key BIGINT NULL,
  physician_key BIGINT NULL,
  patient_id_hash CHAR(64) NULL,
  patient_age_years INT NULL,
  patient_age_group VARCHAR(32) NULL,
  patient_sex VARCHAR(16) NULL,
  study_date DATE NULL,
  accession_number VARCHAR(128) NULL,
  body_part_examined VARCHAR(128) NULL,
  study_description VARCHAR(512) NULL,
  series_count INT NOT NULL DEFAULT 0,
  instance_count INT NOT NULL DEFAULT 0,
  first_ingested_at DATETIME NULL,
  analytics_available_at DATETIME NULL,
  etl_batch_id VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_source_study_id (source_study_id),
  KEY idx_fact_study_date (study_date),
  KEY idx_fact_study_facility (facility_key),
  KEY idx_fact_study_modality (modality_key),
  CONSTRAINT fk_fact_study_facility FOREIGN KEY (facility_key) REFERENCES dim_facility(facility_key),
  CONSTRAINT fk_fact_study_modality FOREIGN KEY (modality_key) REFERENCES dim_modality(modality_key),
  CONSTRAINT fk_fact_study_physician FOREIGN KEY (physician_key) REFERENCES dim_referring_physician(physician_key)
);

CREATE TABLE IF NOT EXISTS fact_ingestion_file (
  ingestion_file_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_file_id BIGINT NOT NULL,
  source_path VARCHAR(1024) NOT NULL,
  facility_key BIGINT NULL,
  ingest_status VARCHAR(32) NOT NULL,
  received_at DATETIME NULL,
  parsed_at DATETIME NULL,
  failure_reason TEXT NULL,
  etl_batch_id VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_source_file_id (source_file_id),
  KEY idx_ingestion_status (ingest_status),
  KEY idx_ingestion_received_at (received_at),
  CONSTRAINT fk_ingestion_file_facility FOREIGN KEY (facility_key) REFERENCES dim_facility(facility_key)
);

CREATE TABLE IF NOT EXISTS fact_pipeline_status (
  pipeline_status_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  pipeline_stage VARCHAR(64) NOT NULL,
  batch_id VARCHAR(128) NULL,
  run_status VARCHAR(32) NOT NULL,
  records_in INT NOT NULL DEFAULT 0,
  records_out INT NOT NULL DEFAULT 0,
  records_failed INT NOT NULL DEFAULT 0,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pipeline_stage_status (pipeline_stage, run_status),
  KEY idx_pipeline_completed_at (completed_at)
);

CREATE TABLE IF NOT EXISTS fact_data_quality_issue (
  dq_issue_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_entity VARCHAR(64) NOT NULL,
  source_entity_id BIGINT NULL,
  issue_type VARCHAR(128) NOT NULL,
  severity VARCHAR(32) NOT NULL,
  issue_message TEXT NOT NULL,
  detected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  KEY idx_dq_issue_type (issue_type),
  KEY idx_dq_detected_at (detected_at)
);

USE analytics_exposition_extract;

CREATE TABLE IF NOT EXISTS dashboard_daily_study_volume (
  snapshot_date DATE NOT NULL,
  facility_id VARCHAR(64) NOT NULL,
  modality_code VARCHAR(32) NOT NULL,
  study_count INT NOT NULL DEFAULT 0,
  series_count INT NOT NULL DEFAULT 0,
  instance_count INT NOT NULL DEFAULT 0,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, facility_id, modality_code)
);

CREATE TABLE IF NOT EXISTS dashboard_facility_volume (
  snapshot_date DATE NOT NULL,
  facility_id VARCHAR(64) NOT NULL,
  facility_name VARCHAR(255) NOT NULL,
  region VARCHAR(128) NULL,
  study_count INT NOT NULL DEFAULT 0,
  failed_file_count INT NOT NULL DEFAULT 0,
  avg_ingestion_delay_minutes DECIMAL(10,2) NULL,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, facility_id)
);

CREATE TABLE IF NOT EXISTS dashboard_ingestion_health (
  snapshot_date DATE NOT NULL,
  facility_id VARCHAR(64) NOT NULL,
  received_file_count INT NOT NULL DEFAULT 0,
  parsed_file_count INT NOT NULL DEFAULT 0,
  failed_file_count INT NOT NULL DEFAULT 0,
  skipped_file_count INT NOT NULL DEFAULT 0,
  parse_success_rate DECIMAL(5,2) NULL,
  last_failure_message TEXT NULL,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, facility_id)
);

CREATE TABLE IF NOT EXISTS dashboard_modality_body_part (
  snapshot_date DATE NOT NULL,
  modality_code VARCHAR(32) NOT NULL,
  body_part_examined VARCHAR(128) NOT NULL,
  study_count INT NOT NULL DEFAULT 0,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, modality_code, body_part_examined)
);

CREATE TABLE IF NOT EXISTS dashboard_patient_demographics (
  snapshot_date DATE NOT NULL,
  modality_code VARCHAR(32) NOT NULL,
  patient_age_group VARCHAR(32) NOT NULL,
  patient_sex VARCHAR(16) NOT NULL,
  study_count INT NOT NULL DEFAULT 0,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, modality_code, patient_age_group, patient_sex)
);

CREATE TABLE IF NOT EXISTS dashboard_pipeline_status (
  snapshot_date DATE NOT NULL,
  pipeline_stage VARCHAR(64) NOT NULL,
  run_status VARCHAR(32) NOT NULL,
  latest_batch_id VARCHAR(128) NULL,
  records_in INT NOT NULL DEFAULT 0,
  records_out INT NOT NULL DEFAULT 0,
  records_failed INT NOT NULL DEFAULT 0,
  latest_completed_at DATETIME NULL,
  last_error_message TEXT NULL,
  last_refreshed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (snapshot_date, pipeline_stage, run_status)
);

USE analytics;

CREATE OR REPLACE VIEW vw_study_volume_by_modality AS
SELECT
  e.snapshot_date,
  e.facility_id,
  COALESCE(f.facility_name, e.facility_id) AS facility_name,
  e.modality_code,
  COALESCE(m.modality_name, e.modality_code) AS modality_name,
  e.study_count,
  e.series_count,
  e.instance_count,
  e.last_refreshed_at
FROM analytics_exposition_extract.dashboard_daily_study_volume e
LEFT JOIN analytics_exposition.dim_facility f ON f.facility_id = e.facility_id
LEFT JOIN analytics_exposition.dim_modality m ON m.modality_code = e.modality_code;

CREATE OR REPLACE VIEW vw_daily_study_trend AS
SELECT
  snapshot_date,
  SUM(study_count) AS study_count,
  SUM(series_count) AS series_count,
  SUM(instance_count) AS instance_count,
  MAX(last_refreshed_at) AS last_refreshed_at
FROM analytics_exposition_extract.dashboard_daily_study_volume
GROUP BY snapshot_date;

CREATE OR REPLACE VIEW vw_studies_by_facility AS
SELECT
  snapshot_date,
  facility_id,
  facility_name,
  region,
  study_count,
  failed_file_count,
  avg_ingestion_delay_minutes,
  last_refreshed_at
FROM analytics_exposition_extract.dashboard_facility_volume;

CREATE OR REPLACE VIEW vw_ingestion_health AS
SELECT
  snapshot_date,
  facility_id,
  received_file_count,
  parsed_file_count,
  failed_file_count,
  skipped_file_count,
  parse_success_rate,
  last_failure_message,
  last_refreshed_at
FROM analytics_exposition_extract.dashboard_ingestion_health;

CREATE OR REPLACE VIEW vw_body_part_distribution AS
SELECT
  snapshot_date,
  modality_code,
  body_part_examined,
  study_count,
  last_refreshed_at
FROM analytics_exposition_extract.dashboard_modality_body_part;

CREATE OR REPLACE VIEW vw_patient_age_group_distribution AS
SELECT
  snapshot_date,
  modality_code,
  patient_age_group,
  patient_sex,
  study_count,
  last_refreshed_at
FROM analytics_exposition_extract.dashboard_patient_demographics;

CREATE OR REPLACE VIEW vw_pipeline_status_breakdown AS
SELECT
  snapshot_date,
  pipeline_stage,
  run_status,
  latest_batch_id,
  records_in,
  records_out,
  records_failed,
  latest_completed_at,
  last_error_message,
  last_refreshed_at
FROM analytics_exposition_extract.dashboard_pipeline_status;

CREATE OR REPLACE VIEW vw_top_referring_physicians AS
SELECT
  s.study_date AS snapshot_date,
  COALESCE(df.facility_id, 'UNKNOWN') AS facility_id,
  COALESCE(dm.modality_code, 'UNKNOWN') AS modality_code,
  COALESCE(dp.physician_name, 'UNKNOWN') AS referring_physician_name,
  COUNT(*) AS study_count,
  MAX(s.created_at) AS last_refreshed_at
FROM analytics_exposition.fact_study s
LEFT JOIN analytics_exposition.dim_facility df ON df.facility_key = s.facility_key
LEFT JOIN analytics_exposition.dim_modality dm ON dm.modality_key = s.modality_key
LEFT JOIN analytics_exposition.dim_referring_physician dp ON dp.physician_key = s.physician_key
GROUP BY
  s.study_date,
  COALESCE(df.facility_id, 'UNKNOWN'),
  COALESCE(dm.modality_code, 'UNKNOWN'),
  COALESCE(dp.physician_name, 'UNKNOWN');

CREATE OR REPLACE VIEW vw_duplicate_or_reprocessed_studies AS
SELECT
  source_study_instance_uid,
  COUNT(*) AS duplicate_count,
  MIN(first_ingested_at) AS first_seen_at,
  MAX(first_ingested_at) AS last_seen_at,
  GROUP_CONCAT(source_study_id ORDER BY source_study_id SEPARATOR ',') AS source_study_ids
FROM analytics_exposition.fact_study
GROUP BY source_study_instance_uid
HAVING COUNT(*) > 1;

CREATE OR REPLACE VIEW vw_rca_lineage_study AS
SELECT
  s.study_key,
  s.source_study_id,
  s.source_study_instance_uid,
  df.facility_id,
  df.facility_name,
  dm.modality_code,
  dm.modality_name,
  s.study_date,
  s.accession_number,
  s.body_part_examined,
  s.series_count,
  s.instance_count,
  s.first_ingested_at,
  s.analytics_available_at,
  s.etl_batch_id
FROM analytics_exposition.fact_study s
LEFT JOIN analytics_exposition.dim_facility df ON df.facility_key = s.facility_key
LEFT JOIN analytics_exposition.dim_modality dm ON dm.modality_key = s.modality_key;
