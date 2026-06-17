#!/usr/bin/env python3
"""Generate the supplementary appendix tables and full event-level dataset."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

from analysis_common import CSV_FIELD_ORDER, OUTPUT_DIR, load_outbreak_csv_rows, write_csv

TOTAL_EVENT_COUNT = 479
FULL_DATASET_FILENAME = "table_s_full_dataset.csv"
SUPPLEMENTARY_TABLE_DIRNAME = "supplementary_tables"

SOURCE_LABELS = {
    "cdc_vsp": "CDC VSP entries",
    "additional_official": "Non-VSP official public-health reports",
    "academic": "Events identified from peer-reviewed academic publications",
}

PATHOGEN_LABELS = {
    "gastrointestinal_viral": "Viral gastroenteritis",
    "unknown": "Unknown aetiology",
    "foodborne_waterborne_bacterial": "Bacterial/protozoal gastrointestinal pathogens",
    "respiratory_viral": "Respiratory viral",
    "legionella": "Legionella spp.",
    "vaccine_preventable": "Vaccine-preventable infections",
    "zoonotic": "Zoonotic infection",
}

PATHOGEN_ORDER = [
    "gastrointestinal_viral",
    "unknown",
    "foodborne_waterborne_bacterial",
    "respiratory_viral",
    "legionella",
    "vaccine_preventable",
    "zoonotic",
]

SOURCE_ORDER = ["cdc_vsp", "additional_official", "academic"]

PERIOD_ORDER = ["1993–2009", "2010–2019", "2020–2022", "2023–2026"]

CREW_IN_PORT_EVENT_IDS = {"EVT-200", "EVT-201", "EVT-206", "EVT-209"}


def format_pct(numerator: int, denominator: int) -> str:
    """Format a percentage using the manuscript's middle-dot decimal style."""
    if denominator == 0:
        return "0·0%"
    return f"{(numerator / denominator) * 100:.1f}%".replace(".", "·")


def format_count_pct(numerator: int, denominator: int) -> str:
    """Format a count as `n (p%)`, or `0` when the count is zero."""
    if numerator == 0:
        return "0"
    return f"{numerator} ({format_pct(numerator, denominator)})"


def parse_int(value: str) -> int | None:
    """Parse a manuscript CSV field into an integer when possible."""
    stripped = (value or "").strip()
    if not stripped or stripped == "NR":
        return None
    try:
        return int(float(stripped))
    except ValueError:
        return None


def is_cdc_vsp_record(row: dict[str, str]) -> bool:
    """Return True for CDC VSP entries and other VSP-derived logs."""
    ref = (row.get("data_source_reference") or "").strip()
    return row.get("data_source_category") == "official_public_health" and (
        ref == "NR" or ref.startswith("CDC VSP")
    )


def is_additional_official_record(row: dict[str, str]) -> bool:
    """Return True for non-VSP official public-health reports."""
    return row.get("data_source_category") == "official_public_health" and not is_cdc_vsp_record(row)


def source_group_for_s1(row: dict[str, str]) -> str:
    """Map each row to the mutually exclusive entry-source tiers used in Table S1."""
    if is_cdc_vsp_record(row):
        return "cdc_vsp"
    if is_additional_official_record(row):
        return "additional_official"
    return "academic"


def is_reported(value: str) -> bool:
    return (value or "").strip() not in {"", "NR"}


def output_paths(output_dir: Path) -> tuple[Path, Path]:
    supplementary_dir = output_dir / SUPPLEMENTARY_TABLE_DIRNAME
    full_dataset_path = output_dir / FULL_DATASET_FILENAME
    supplementary_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    return supplementary_dir, full_dataset_path


def build_table_s1(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    source_totals = Counter(source_group_for_s1(row) for row in rows)
    pathogen_counts = Counter((source_group_for_s1(row), row["pathogen_category"]) for row in rows)

    table_rows: list[dict[str, str]] = []
    for pathogen_code in PATHOGEN_ORDER:
        row = {"Pathogen category": PATHOGEN_LABELS[pathogen_code]}
        for source_code in SOURCE_ORDER:
            n = pathogen_counts[(source_code, pathogen_code)]
            row[SOURCE_LABELS[source_code]] = format_count_pct(n, source_totals[source_code])
        table_rows.append(row)
    return table_rows


def build_table_s2(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    table_rows: list[dict[str, str]] = []
    for pathogen_code in PATHOGEN_ORDER:
        subset = [row for row in rows if row["pathogen_category"] == pathogen_code]
        cumulative_cases = 0
        for row in subset:
            passenger = parse_int(row["cases_passengers"])
            crew = parse_int(row["cases_crew"])
            if passenger is not None and crew is not None:
                cumulative_cases += passenger + crew
        deaths = sum(parse_int(row["deaths"]) or 0 for row in subset)
        table_rows.append(
            {
                "Pathogen category": PATHOGEN_LABELS[pathogen_code],
                "Events, n (%)": format_count_pct(len(subset), TOTAL_EVENT_COUNT),
                "Cumulative cases": str(cumulative_cases),
                "Deaths": str(deaths),
            }
        )
    return table_rows


def build_table_s3(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    period_map = {
        "1993–2009": lambda year: year <= 2009,
        "2010–2019": lambda year: 2010 <= year <= 2019,
        "2020–2022": lambda year: 2020 <= year <= 2022,
        "2023–2026": lambda year: year >= 2023,
    }
    period_totals = Counter()
    counts = Counter()
    for row in rows:
        year = int(row["outbreak_year"])
        for period_label, predicate in period_map.items():
            if predicate(year):
                period_totals[period_label] += 1
                counts[(period_label, row["pathogen_category"])] += 1
                break

    table_rows: list[dict[str, str]] = []
    for pathogen_code in PATHOGEN_ORDER:
        row = {"Pathogen category": PATHOGEN_LABELS[pathogen_code]}
        for period in PERIOD_ORDER:
            n = counts[(period, pathogen_code)]
            row[period] = format_count_pct(n, period_totals[period])
        table_rows.append(row)
    return table_rows


def build_table_s4(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    fields = [
        ("Outbreak year", "outbreak_year"),
        ("Transmission route", "transmission_route"),
        ("Public health response", "public_health_response"),
        ("Deaths", "deaths"),
        ("Outbreak duration", "outbreak_duration_days"),
        ("Pathogen identified", "pathogen_identified"),
        ("Cases (passengers)", "cases_passengers"),
        ("Cases (crew)", "cases_crew"),
        ("Overall attack rate", "attack_rate_percent"),
        ("Hospitalisations", "hospitalisations"),
    ]
    table_rows: list[dict[str, str]] = []
    for label, field in fields:
        available = sum(is_reported(row[field]) for row in rows)
        missing = len(rows) - available
        table_rows.append(
            {
                "Data field": label,
                "Events with data available": format_count_pct(available, len(rows)),
                "Events with missing data": format_count_pct(missing, len(rows)),
            }
        )
    return table_rows


def build_table_s5(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    table_rows: list[dict[str, str]] = []
    for pathogen_code in PATHOGEN_ORDER:
        subset = [row for row in rows if row["pathogen_category"] == pathogen_code]
        death_values = [parse_int(row["deaths"]) for row in subset]
        reported_death_values = [value for value in death_values if value is not None]
        events_with_death = sum(value > 0 for value in reported_death_values)
        total_deaths = sum(reported_death_values)
        events_with_zero_deaths = sum(value == 0 for value in reported_death_values)
        events_missing_death_data = len(subset) - len(reported_death_values)
        table_rows.append(
            {
                "Pathogen category": PATHOGEN_LABELS[pathogen_code],
                "Events with >=1 death": str(events_with_death),
                "Total deaths": str(total_deaths),
                "Events with zero deaths": str(events_with_zero_deaths),
                "Events with death data missing": str(events_missing_death_data),
            }
        )
    death_values = [parse_int(row["deaths"]) for row in rows]
    reported_death_values = [value for value in death_values if value is not None]
    total_events_with_death = sum(value > 0 for value in reported_death_values)
    total_deaths = sum(reported_death_values)
    total_events_with_zero_deaths = sum(value == 0 for value in reported_death_values)
    total_events_missing_death_data = len(rows) - len(reported_death_values)
    table_rows.append(
        {
            "Pathogen category": "Total",
            "Events with >=1 death": str(total_events_with_death),
            "Total deaths": str(total_deaths),
            "Events with zero deaths": str(total_events_with_zero_deaths),
            "Events with death data missing": str(total_events_missing_death_data),
        }
    )
    return table_rows


def counts_for_subset(rows: list[dict[str, str]]) -> dict[str, int]:
    return Counter(row["pathogen_category"] for row in rows)


def build_sensitivity_row(label: str, rows: list[dict[str, str]], note: str) -> dict[str, str]:
    counts = counts_for_subset(rows)
    total = len(rows)
    row = {
        "Analysis": label,
        "Events": str(total),
        "Viral gastroenteritis": format_count_pct(counts["gastrointestinal_viral"], total),
        "Unknown aetiology": format_count_pct(counts["unknown"], total),
        "Bacterial/protozoal gastrointestinal pathogens": format_count_pct(counts["foodborne_waterborne_bacterial"], total),
        "Respiratory viral": format_count_pct(counts["respiratory_viral"], total),
        "Legionella spp.": format_count_pct(counts["legionella"], total),
        "Vaccine-preventable infections": format_count_pct(counts["vaccine_preventable"], total),
        "Zoonotic infection": format_count_pct(counts["zoonotic"], total),
        "Note": note,
    }
    return row


def build_table_s6(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    primary = rows
    excluding_crew_in_port = [row for row in rows if row["event_id"] not in CREW_IN_PORT_EVENT_IDS]
    official_public_health = [row for row in rows if row["data_source_category"] == "official_public_health"]
    cdc_vsp_only = [row for row in rows if is_cdc_vsp_record(row)]
    non_vsp = [row for row in rows if not is_cdc_vsp_record(row)]
    academic_only = [row for row in rows if row["data_source_category"] == "academic"]

    return [
        build_sensitivity_row(
            "Primary analysis",
            primary,
            "Viral gastroenteritis remains the dominant category in the full reported-event dataset.",
        ),
        build_sensitivity_row(
            "Excluding 2020-22 crew-in-port events",
            excluding_crew_in_port,
            "These four docked-ship crew-only SARS-CoV-2 events were excluded as a sensitivity check; respiratory viral event-records decreased from 28 to 24 while the source-composition pattern remained the same.",
        ),
        build_sensitivity_row(
            "CDC VSP entries + non-VSP official public-health reports",
            official_public_health,
            "The combined CDC VSP entries + non-VSP official public-health reports set is dominated by viral gastroenteritis and includes 430 CDC VSP entries plus six non-VSP official public-health reports.",
        ),
        build_sensitivity_row(
            "CDC VSP-only",
            cdc_vsp_only,
            "The CDC VSP subset contains no respiratory viral outbreaks.",
        ),
        build_sensitivity_row(
            "Non-VSP sources",
            non_vsp,
            "This subset combines six non-VSP official public-health reports and 43 events identified from peer-reviewed academic publications; respiratory viral events dominate the remaining non-VSP record.",
        ),
        build_sensitivity_row(
            "Events identified from peer-reviewed academic publications only",
            academic_only,
            "The event subset identified from peer-reviewed academic publications is dominated by respiratory viral events, consistent with publication bias toward novel or severe pathogens.",
        ),
    ]


def source_text(row: dict[str, str]) -> str:
    fields = [
        row.get("data_source_category", ""),
        row.get("data_source_reference", ""),
        row.get("source_url", ""),
        row.get("notes", ""),
    ]
    return " ".join(fields).lower()


def yes_no(value: bool) -> str:
    return "yes" if value else "no"


def has_vsp_source(row: dict[str, str]) -> bool:
    text = source_text(row)
    return source_group_for_s1(row) == "cdc_vsp" or "vessel-sanitation" in text or "cdc vsp" in text


def has_non_vsp_official_source(row: dict[str, str]) -> bool:
    text = source_text(row)
    official_markers = [
        "ecdc",
        "who.int",
        "disease outbreak news",
        "mmwr",
        "cdc.gov/mmwr",
        "ukhsa",
        "public health",
        "health authority",
    ]
    return source_group_for_s1(row) == "additional_official" or any(marker in text for marker in official_markers)


def has_academic_source(row: dict[str, str]) -> bool:
    text = source_text(row)
    return row.get("data_source_category") == "academic" or "doi.org" in text or "pubmed" in text


def build_table_s8(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    """Build event-level source contribution indicators from curated source fields.

    These indicators describe source types visible in the curated record and are
    not an exhaustive bibliographic linkage table for every event.
    """
    source_tier_labels = {
        "cdc_vsp": "CDC VSP entry",
        "additional_official": "Non-VSP official public-health report",
        "academic": "Peer-reviewed academic publication",
    }
    table_rows: list[dict[str, str]] = []
    for row in rows:
        entry_source = source_group_for_s1(row)
        table_rows.append(
            {
                "event_id": row["event_id"],
                "ship_name": row["ship_name"],
                "outbreak_year": row["outbreak_year"],
                "pathogen_category": PATHOGEN_LABELS[row["pathogen_category"]],
                "entry_source_tier": source_tier_labels[entry_source],
                "cdc_vsp_source_in_curated_record": yes_no(has_vsp_source(row)),
                "non_vsp_official_source_in_curated_record": yes_no(has_non_vsp_official_source(row)),
                "academic_source_in_curated_record": yes_no(has_academic_source(row)),
                "source_reference": row.get("data_source_reference", "NR"),
                "source_url": row.get("source_url", "NR"),
            }
        )
    return table_rows


def write_table(output_dir: Path, filename: str, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise ValueError(f"Refusing to write empty table: {filename}")
    fieldnames = list(rows[0].keys())
    write_csv(output_dir / filename, fieldnames, rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=OUTPUT_DIR,
        help="Destination directory for generated tables (default: output/)",
    )
    args = parser.parse_args()

    rows = load_outbreak_csv_rows()
    supplementary_dir, full_dataset_path = output_paths(args.output_dir)

    write_csv(full_dataset_path, CSV_FIELD_ORDER, rows)

    write_table(supplementary_dir, "table_s1_source_bias.csv", build_table_s1(rows))
    write_table(supplementary_dir, "table_s2_pathogen_summary.csv", build_table_s2(rows))
    write_table(supplementary_dir, "table_s3_temporal_distribution.csv", build_table_s3(rows))
    write_table(supplementary_dir, "table_s4_field_completeness.csv", build_table_s4(rows))
    write_table(supplementary_dir, "table_s5_deaths_by_pathogen.csv", build_table_s5(rows))
    write_table(supplementary_dir, "table_s6_sensitivity_analyses.csv", build_table_s6(rows))
    write_table(supplementary_dir, "table_s8_source_contribution_indicators.csv", build_table_s8(rows))


if __name__ == "__main__":
    main()
