"""Shared helpers for restoring the cruise-ship outbreak analysis scripts."""

from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any, Iterable, Mapping

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
OUTPUT_DIR = REPO_ROOT / "output"

# Legacy exclusion list removed — these six records with incorrect DOIs
# (EVT-028, EVT-029, EVT-030, EVT-040, EVT-043, EVT-044) were deleted
# from the source CSV as their data could not be verified from primary sources.
EXCLUDED_EVENT_IDS: set[str] = set()

CSV_FIELD_ORDER = [
    "event_id",
    "ship_name",
    "ship_type",
    "voyage_route",
    "outbreak_year",
    "outbreak_duration_days",
    "pathogen_identified",
    "pathogen_category",
    "secondary_pathogens",
    "clinical_syndrome",
    "cases_passengers",
    "cases_crew",
    "total_crew_onboard",
    "attack_rate_percent",
    "hospitalisations",
    "deaths",
    "transmission_route",
    "data_source_category",
    "data_source_reference",
    "source_url",
    "public_health_response",
    "notes",
]

SCREENING_EXCLUSION_EVENT_IDS = {
    "EVT-EXC-001",
}

INCLUDED_EVENT_COLUMNS = [
    "event_id",
    "ship_name",
    "ship_type",
    "outbreak_year",
    "pathogen_identified",
    "pathogen_category",
    "clinical_syndrome",
    "cases_passengers",
    "cases_crew",
    "deaths",
    "data_source_category",
    "data_source_reference",
    "source_url",
    "inclusion_basis",
]

SEARCH_RECORD_COLUMNS = [
    "record_id",
    "source_database",
    "source_category",
    "title",
    "year",
    "ship_name",
    "pathogen",
    "source_url",
    "source_reference",
    "retrieval_date",
    "language",
    "screening_outcome",
]

SCREENING_DECISION_COLUMNS = [
    "record_id",
    "title",
    "source_database",
    "source_category",
    "year",
    "screening_stage",
    "screener_1",
    "screener_2",
    "decision",
    "exclusion_reason_code",
    "exclusion_reason_detail",
    "sensitivity_tag",
    "disagreement",
    "third_reviewer",
    "notes",
]

EXCLUDED_SCREENING_RECORD = {
    "record_id": "EVT-EXC-001",
    "source_database": "Grey literature (other)",
    "source_category": "grey_literature",
    "title": "SMV Freewinds - Measles (2019)",
    "year": "2019",
    "ship_name": "SMV Freewinds",
    "pathogen": "Measles virus",
    "source_url": "",
    "source_reference": "News reports of single measles case on SMV Freewinds, Curacao, 2019",
    "retrieval_date": "2026-05-13",
    "language": "en",
    "screening_outcome": "excluded",
}

EXCLUDED_SCREENING_DECISION = {
    "record_id": "EVT-EXC-001",
    "title": "SMV Freewinds - Measles (2019)",
    "source_database": "Grey literature (other)",
    "source_category": "grey_literature",
    "year": "2019",
    "screening_stage": "full_text",
    "screener_1": "LKG",
    "screener_2": "LKG",
    "decision": "exclude",
    "exclusion_reason_code": "not_outbreak",
    "exclusion_reason_detail": "Single confirmed case without official outbreak designation",
    "sensitivity_tag": "no",
    "disagreement": "no",
    "third_reviewer": "",
    "notes": "",
}

def load_json_records(path: Path) -> dict[str, dict[str, Any]]:
    """Load an event dictionary keyed by event_id from a JSON file."""

    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise ValueError(f"Expected a mapping in {path}, found {type(payload).__name__}")
    records: dict[str, dict[str, Any]] = {}
    for key, value in payload.items():
        if not isinstance(value, dict):
            raise ValueError(f"Expected dict records in {path} for {key}")
        records[str(key)] = value
    return records


def load_outbreak_csv_rows(path: Path | None = None, include_excluded: bool = False) -> list[dict[str, str]]:
    """Read the curated outbreak-events CSV and optionally remove legacy rows."""

    csv_path = path or (DATA_DIR / "outbreak_events.csv")
    with csv_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if include_excluded:
        return rows
    return [row for row in rows if row.get("event_id") not in EXCLUDED_EVENT_IDS]


def merged_raw_records(include_excluded: bool = False) -> list[tuple[str, dict[str, Any]]]:
    """Merge the raw JSON event dictionaries into a single ordered record list."""

    combined: dict[str, dict[str, Any]] = {}
    for json_name in ("extraction_data.json", "covid_and_other_events.json", "additional_events.json"):
        combined.update(load_json_records(DATA_DIR / json_name))

    rows: list[tuple[str, dict[str, Any]]] = []
    for event_id, record in combined.items():
        if not include_excluded and event_id in EXCLUDED_EVENT_IDS:
            continue
        rows.append((event_id, record))

    def sort_key(item: tuple[str, dict[str, Any]]) -> tuple[int, int, str]:
        event_id, record = item
        year = record.get("outbreak_year")
        try:
            year_value = int(year)
        except (TypeError, ValueError):
            year_value = 9999
        source_rank = {
            "official_public_health": 0,
            "academic": 1,
            "grey_literature": 2,
        }.get(str(record.get("data_source_category", "")), 9)
        return (year_value, source_rank, event_id)

    rows.sort(key=sort_key)
    return rows


def clean_value(value: Any) -> str:
    """Convert raw values to the CSV format used in the manuscript outputs."""

    if value is None:
        return "NR"
    if isinstance(value, str):
        stripped = value.strip()
        return stripped if stripped else "NR"
    if isinstance(value, (list, tuple, set)):
        items = [clean_value(item) for item in value]
        items = [item for item in items if item != "NR"]
        return "; ".join(items) if items else "NR"
    if isinstance(value, bool):
        return "yes" if value else "no"
    return str(value)


def record_to_csv_row(event_id: str, record: Mapping[str, Any]) -> dict[str, str]:
    """Map a raw record to the final outbreak-events CSV schema."""

    row: dict[str, str] = {"event_id": event_id}
    for field in CSV_FIELD_ORDER[1:]:
        row[field] = clean_value(record.get(field))
    return row


def write_csv(path: Path, fieldnames: Iterable[str], rows: Iterable[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames))
        writer.writeheader()
        for row in rows:
            writer.writerow({field: clean_value(row.get(field)) for field in fieldnames})
