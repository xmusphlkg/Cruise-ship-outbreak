#!/usr/bin/env python3
"""Validate the frozen EID event-level dataset for consistency checks."""

from __future__ import annotations

from collections import Counter
from pathlib import Path

from analysis_common import load_outbreak_csv_rows

EXPECTED_ROWS = 479
VALID_PATHOGEN_CATEGORIES = {
    "gastrointestinal_viral",
    "unknown",
    "foodborne_waterborne_bacterial",
    "respiratory_viral",
    "legionella",
    "vaccine_preventable",
    "zoonotic",
}
VALID_SOURCE_CATEGORIES = {"official_public_health", "academic"}


def is_missing(value: str) -> bool:
    return (value or "").strip() in {"", "NR"}


def is_cdc_vsp_record(row: dict[str, str]) -> bool:
    ref = (row.get("data_source_reference") or "").strip()
    return row.get("data_source_category") == "official_public_health" and (
        ref == "NR" or ref.startswith("CDC VSP")
    )


def is_non_vsp_official_record(row: dict[str, str]) -> bool:
    return row.get("data_source_category") == "official_public_health" and not is_cdc_vsp_record(row)


def entry_source_tier(row: dict[str, str]) -> str:
    if is_cdc_vsp_record(row):
        return "CDC VSP entry"
    if is_non_vsp_official_record(row):
        return "Non-VSP official public health report"
    return "Peer-reviewed academic publication"


def add_error(errors: list[str], event_id: str, message: str) -> None:
    errors.append(f"{event_id}: {message}")


def main() -> int:
    rows = load_outbreak_csv_rows()
    errors: list[str] = []
    warnings: list[str] = []

    if len(rows) != EXPECTED_ROWS:
        errors.append(f"Expected {EXPECTED_ROWS} rows, found {len(rows)}")

    event_ids = [row.get("event_id", "") for row in rows]
    for event_id, count in Counter(event_ids).items():
        if is_missing(event_id) or count > 1:
            errors.append(f"Invalid event_id {event_id!r}: count={count}")

    duplicate_keys = Counter(
        (
            row.get("ship_name", ""),
            row.get("voyage_route", ""),
            row.get("outbreak_year", ""),
            row.get("pathogen_identified", ""),
            row.get("pathogen_category", ""),
        )
        for row in rows
    )
    for key, count in duplicate_keys.items():
        if count > 1:
            warnings.append(f"Potential duplicate vessel/route/year/pathogen key {key!r}: count={count}")

    for row in rows:
        event_id = row.get("event_id", "UNKNOWN")
        year = row.get("outbreak_year", "")
        try:
            year_int = int(year)
        except ValueError:
            add_error(errors, event_id, f"invalid outbreak_year {year!r}")
        else:
            if year_int < 1993 or year_int > 2026:
                add_error(errors, event_id, f"outbreak_year out of range: {year_int}")

        if row.get("pathogen_category") not in VALID_PATHOGEN_CATEGORIES:
            add_error(errors, event_id, f"invalid pathogen_category {row.get('pathogen_category')!r}")

        if row.get("data_source_category") not in VALID_SOURCE_CATEGORIES:
            add_error(errors, event_id, f"invalid data_source_category {row.get('data_source_category')!r}")

        if is_missing(row.get("source_url", "")) and is_missing(row.get("data_source_reference", "")):
            add_error(errors, event_id, "missing both source_url and data_source_reference")

        if row.get("data_source_category") == "academic" and is_cdc_vsp_record(row):
            add_error(errors, event_id, "academic row classified as CDC VSP entry")

        if row.get("pathogen_category") == "unknown" and "gastro" not in row.get("clinical_syndrome", "").lower():
            add_error(errors, event_id, "unknown etiology row lacks gastrointestinal syndrome text")

        if entry_source_tier(row) == "Peer-reviewed academic publication" and row.get("data_source_category") != "academic":
            add_error(errors, event_id, "entry-source tier/source category discordance")

    if errors:
        print("Dataset validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    source_counts = Counter(entry_source_tier(row) for row in rows)
    pathogen_counts = Counter(row["pathogen_category"] for row in rows)
    print(f"Dataset validation passed for {len(rows)} event-records.")
    if warnings:
        print(f"Warnings reviewed: {len(warnings)} potential duplicate keys.")
        for warning in warnings[:10]:
            print(f"- {warning}")
        if len(warnings) > 10:
            print(f"- ... {len(warnings) - 10} additional potential duplicate keys not shown")
    print("Entry-source counts:")
    for label, count in sorted(source_counts.items()):
        print(f"- {label}: {count}")
    print("Pathogen-category counts:")
    for label, count in sorted(pathogen_counts.items()):
        print(f"- {label}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
