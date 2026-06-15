from dataclasses import dataclass


@dataclass(frozen=True)
class IssueClassification:
    issue_type: str
    confidence: str
    matched_terms: list[str]


ISSUE_PATTERNS = {
    "missing_or_low_count": [
        "missing",
        "low",
        "lower",
        "not showing",
        "not reflecting",
        "count",
        "volume",
        "fewer",
        "dropped",
    ],
    "stale_dashboard": [
        "stale",
        "old",
        "not refreshed",
        "refresh",
        "yesterday",
        "today",
        "last refreshed",
    ],
    "failed_ingestion": [
        "failed",
        "parse",
        "parsing",
        "ingestion",
        "error",
        "skipped",
        "file",
    ],
    "facility_or_site_mismatch": [
        "facility",
        "site",
        "hospital",
        "clinic",
        "location",
        "region",
    ],
    "modality_or_body_part_mismatch": [
        "modality",
        "ct",
        "mr",
        "xr",
        "us",
        "body part",
        "chest",
        "head",
        "abdomen",
    ],
    "demographic_mismatch": [
        "patient",
        "age",
        "sex",
        "gender",
        "demographic",
    ],
    "duplicate_or_reprocessed": [
        "duplicate",
        "duplicated",
        "reprocessed",
        "double",
        "inflated",
        "too high",
        "higher",
    ],
    "etl_or_pipeline_delay": [
        "etl",
        "pipeline",
        "batch",
        "delayed",
        "delay",
        "hourly",
        "daily",
        "extract",
    ],
}

ISSUE_PRIORITY = {
    "missing_or_low_count": 100,
    "duplicate_or_reprocessed": 95,
    "failed_ingestion": 90,
    "stale_dashboard": 85,
    "etl_or_pipeline_delay": 80,
    "modality_or_body_part_mismatch": 50,
    "facility_or_site_mismatch": 40,
    "demographic_mismatch": 35,
}


def classify_issue(question: str) -> IssueClassification:
    normalized = question.lower()
    scores: dict[str, list[str]] = {}

    for issue_type, terms in ISSUE_PATTERNS.items():
        matches = [term for term in terms if term in normalized]
        if matches:
            scores[issue_type] = matches

    if not scores:
        return IssueClassification(
            issue_type="general_pipeline_rca",
            confidence="low",
            matched_terms=[],
        )

    best_type, matched_terms = max(
        scores.items(),
        key=lambda item: (
            len(item[1]),
            ISSUE_PRIORITY.get(item[0], 0),
            sum(len(term) for term in item[1]),
        ),
    )
    confidence = "high" if len(matched_terms) >= 3 else "medium"

    return IssueClassification(
        issue_type=best_type,
        confidence=confidence,
        matched_terms=matched_terms,
    )
