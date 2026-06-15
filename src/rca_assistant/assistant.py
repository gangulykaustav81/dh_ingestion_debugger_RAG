from dataclasses import dataclass
from pathlib import Path

from .classifier import IssueClassification, classify_issue
from .knowledge_base import KnowledgeBase, SearchResult


DEFAULT_KNOWLEDGE_PATHS = [
    Path("AI_RCA_AGENT_PROPOSAL.md"),
    Path("SCHEMA_OVERVIEW.md"),
    Path("knowledge/rca_runbook.md"),
    Path("knowledge/widget_catalog.md"),
    Path("sql/create_schemas.sql"),
]


@dataclass(frozen=True)
class RCAResponse:
    question: str
    classification: IssueClassification
    answer: str
    sources: list[SearchResult]


class RCAAssistant:
    def __init__(self, knowledge_base: KnowledgeBase):
        self.knowledge_base = knowledge_base

    @classmethod
    def from_default_paths(cls, repo_root: Path) -> "RCAAssistant":
        paths = [repo_root / path for path in DEFAULT_KNOWLEDGE_PATHS]
        return cls(KnowledgeBase.from_paths(paths))

    def answer(self, question: str) -> RCAResponse:
        classification = classify_issue(question)
        search_query = f"{question} {classification.issue_type}"
        sources = self.knowledge_base.search(search_query, limit=5)
        answer = self._compose_answer(question, classification, sources)

        return RCAResponse(
            question=question,
            classification=classification,
            answer=answer,
            sources=sources,
        )

    def _compose_answer(
        self,
        question: str,
        classification: IssueClassification,
        sources: list[SearchResult],
    ) -> str:
        investigation_path = self._investigation_path(classification.issue_type)
        checks = self._checks(classification.issue_type)
        sql = self._sql_hints(classification.issue_type)

        source_lines = []
        for index, result in enumerate(sources, start=1):
            source_lines.append(
                f"[{index}] {Path(result.chunk.source).name} - {result.chunk.title}"
            )

        citations = "\n".join(source_lines) if source_lines else "No matching source chunks found."

        return f"""RCA classification: {classification.issue_type} ({classification.confidence} confidence)

Likely pipeline path:
{investigation_path}

Recommended investigation:
{checks}

Starter SQL checks:
{sql}

Sources used:
{citations}
"""

    @staticmethod
    def _investigation_path(issue_type: str) -> str:
        if issue_type == "missing_or_low_count":
            return "analytics.vw_study_volume_by_modality / vw_daily_study_trend -> analytics_exposition_extract.dashboard_daily_study_volume -> analytics_exposition.fact_study -> Datahub.dicom_study / dicom_series / dicom_file"
        if issue_type == "failed_ingestion":
            return "Datahub.dicom_file -> Datahub.ingestion_event -> analytics_exposition.fact_ingestion_file -> analytics.vw_ingestion_health"
        if issue_type == "stale_dashboard":
            return "analytics views -> analytics_exposition_extract dashboard tables -> analytics_exposition.fact_pipeline_status"
        if issue_type == "duplicate_or_reprocessed":
            return "analytics.vw_duplicate_or_reprocessed_studies -> analytics_exposition.fact_study -> Datahub.dicom_study"
        if issue_type == "modality_or_body_part_mismatch":
            return "analytics.vw_study_volume_by_modality / vw_body_part_distribution -> analytics_exposition.fact_study -> Datahub.dicom_series"
        if issue_type == "facility_or_site_mismatch":
            return "analytics.vw_studies_by_facility -> analytics_exposition.dim_facility / fact_study -> Datahub source path or tags"
        if issue_type == "demographic_mismatch":
            return "analytics.vw_patient_age_group_distribution -> analytics_exposition.fact_study -> Datahub.dicom_study"
        if issue_type == "etl_or_pipeline_delay":
            return "analytics.vw_pipeline_status_breakdown -> analytics_exposition.fact_pipeline_status -> upstream ETL batch logs"
        return "analytics view -> analytics_exposition_extract aggregate -> analytics_exposition fact/dimension -> Datahub source tables"

    @staticmethod
    def _checks(issue_type: str) -> str:
        common_checks = [
            "1. Confirm the affected dashboard widget, date range, facility/site, and modality filters.",
            "2. Check the corresponding analytics view and its `last_refreshed_at` value.",
            "3. Compare extract aggregate counts with exposition fact counts for the same filters.",
            "4. Trace mismatched records back to `Datahub` using source IDs or DICOM UIDs.",
        ]

        issue_specific = {
            "missing_or_low_count": [
                "5. Compare widget count with `analytics.vw_study_volume_by_modality` for the same date, facility, and modality.",
                "6. Compare extract counts with `analytics_exposition.fact_study` and then with `Datahub` study/series records.",
                "7. Check ingestion failures or skipped files for the affected date range.",
            ],
            "failed_ingestion": [
                "5. Review `Datahub.dicom_file.ingest_status` for `FAILED` or `SKIPPED` files.",
                "6. Inspect `Datahub.ingestion_event` for parse or DB write failures.",
            ],
            "stale_dashboard": [
                "5. Check `analytics_exposition_extract` aggregate table refresh timestamps.",
                "6. Review `analytics_exposition.fact_pipeline_status` for failed or delayed daily extract batches.",
            ],
            "duplicate_or_reprocessed": [
                "5. Check duplicate Study Instance UID, Series Instance UID, and SOP Instance UID patterns.",
                "6. Compare first and last ingestion timestamps to identify reprocessing.",
            ],
            "modality_or_body_part_mismatch": [
                "5. Validate modality and body part fields in `Datahub.dicom_series`.",
                "6. Check whether ETL mapping normalized modality/body part values correctly in `fact_study`.",
            ],
            "facility_or_site_mismatch": [
                "5. Validate facility mapping in `dim_facility`.",
                "6. Check whether source file path, tags, or ETL rules mapped the study to the wrong site.",
            ],
            "demographic_mismatch": [
                "5. Validate patient birth date, sex, and age group derivation.",
                "6. Check whether PHI-safe hashes and demographics were transformed consistently.",
            ],
            "etl_or_pipeline_delay": [
                "5. Check latest hourly and daily ETL batch IDs.",
                "6. Compare `records_in`, `records_out`, and `records_failed` by pipeline stage.",
            ],
        }

        lines = common_checks + issue_specific.get(issue_type, [])
        return "\n".join(lines)

    @staticmethod
    def _sql_hints(issue_type: str) -> str:
        hints = {
            "missing_or_low_count": """SELECT snapshot_date, facility_id, modality_code, study_count FROM analytics.vw_study_volume_by_modality ORDER BY snapshot_date DESC;
SELECT study_date, COUNT(*) AS fact_study_count FROM analytics_exposition.fact_study GROUP BY study_date ORDER BY study_date DESC;
SELECT study_date, COUNT(*) AS datahub_study_count FROM Datahub.dicom_study GROUP BY study_date ORDER BY study_date DESC;""",
            "failed_ingestion": """SELECT ingest_status, COUNT(*) FROM Datahub.dicom_file GROUP BY ingest_status;
SELECT event_type, COUNT(*) FROM Datahub.ingestion_event GROUP BY event_type;""",
            "stale_dashboard": """SELECT * FROM analytics.vw_pipeline_status_breakdown ORDER BY latest_completed_at DESC;
SELECT MAX(last_refreshed_at) FROM analytics_exposition_extract.dashboard_daily_study_volume;""",
            "duplicate_or_reprocessed": """SELECT * FROM analytics.vw_duplicate_or_reprocessed_studies;
SELECT study_instance_uid, COUNT(*) FROM Datahub.dicom_study GROUP BY study_instance_uid HAVING COUNT(*) > 1;""",
            "modality_or_body_part_mismatch": """SELECT modality, body_part_examined, COUNT(*) FROM Datahub.dicom_series GROUP BY modality, body_part_examined;
SELECT modality_code, body_part_examined, SUM(study_count) FROM analytics.vw_body_part_distribution GROUP BY modality_code, body_part_examined;""",
            "facility_or_site_mismatch": """SELECT facility_id, facility_name, study_count FROM analytics.vw_studies_by_facility;
SELECT facility_id, facility_name FROM analytics_exposition.dim_facility;""",
            "demographic_mismatch": """SELECT modality_code, patient_age_group, patient_sex, SUM(study_count) FROM analytics.vw_patient_age_group_distribution GROUP BY modality_code, patient_age_group, patient_sex;""",
            "etl_or_pipeline_delay": """SELECT pipeline_stage, run_status, latest_batch_id, records_in, records_out, records_failed FROM analytics.vw_pipeline_status_breakdown;""",
        }

        return hints.get(
            issue_type,
            """SELECT * FROM analytics.vw_rca_lineage_study LIMIT 20;
SELECT * FROM analytics.vw_pipeline_status_breakdown ORDER BY latest_completed_at DESC;""",
        )
