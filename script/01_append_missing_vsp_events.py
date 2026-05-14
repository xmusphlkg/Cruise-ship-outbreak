#!/usr/bin/env python3
"""
01_append_missing_vsp_events.py
================================
将 CDC VSP 网站上有但数据集中遗漏的暴发事件补充到 outbreak_events.csv。

基于 00_run_full_pipeline.py 的抓取结果，识别遗漏事件并以标准格式追加。
"""

from __future__ import annotations

import csv
import re
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
DATASET_PATH = DATA_DIR / "outbreak_events.csv"
SCRAPED_PATH = DATA_DIR / "intermediate" / "cdc_vsp_scraped.csv"

# CDC VSP archive URLs by period
SOURCE_URLS = {
    "archive_2019_2022": "https://archive.cdc.gov/www_cdc_gov/vessel-sanitation/cruise-ship-outbreaks/earlier-outbreaks-2019-2022.html",
    "archive_1993_2018": "https://archive.cdc.gov/www_cdc_gov/nceh/vsp/surv/outbreak/archived-outbreaks-1993-2018.html",
    "earlier_2023_2025": "https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/earlier-outbreaks.html",
    "current_2026": "https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/index.html",
}

CSV_FIELDS = [
    "event_id", "ship_name", "ship_type", "voyage_route", "outbreak_year",
    "outbreak_duration_days", "pathogen_identified", "pathogen_category",
    "secondary_pathogens", "clinical_syndrome", "cases_passengers", "cases_crew",
    "total_crew_onboard", "attack_rate_percent", "hospitalisations", "deaths",
    "transmission_route", "data_source_category", "data_source_reference",
    "source_url", "public_health_response", "notes",
]


def extract_year(dates_str: str) -> str:
    m = re.search(r'(19|20)\d{2}', dates_str)
    return m.group(0) if m else ""


def compute_duration(dates_str: str) -> str:
    """尝试从航行日期计算持续天数"""
    # Format: "M/D/YYYY-M/D/YYYY" or "M/D/YYYY – M/D/YYYY"
    parts = re.split(r'[-–]', dates_str.replace(" ", ""))
    if len(parts) >= 2:
        try:
            # Try parsing start and end dates
            start_str = parts[0].strip()
            end_str = parts[-1].strip()
            for fmt in ("%m/%d/%Y", "%m/%d/%y"):
                try:
                    start = datetime.strptime(start_str, fmt)
                    end = datetime.strptime(end_str, fmt)
                    days = (end - start).days
                    if 0 < days < 365:
                        return str(days)
                except ValueError:
                    continue
        except Exception:
            pass
    return "NR"


def classify_pathogen(agent_str: str) -> tuple[str, str, str]:
    """
    从 CDC VSP 的 causative agent 字段推断:
    (pathogen_identified, pathogen_category, transmission_route)
    """
    agent = agent_str.strip().lower()

    if not agent or agent in ("unknown", "specimens not obtained", ""):
        return "NR", "unknown", "fecal-oral/person-to-person"

    if "norovirus" in agent:
        return "Norovirus", "gastrointestinal_viral", "fecal-oral/person-to-person"
    if "rotavirus" in agent:
        return "Rotavirus", "gastrointestinal_viral", "fecal-oral/person-to-person"
    if "sapovirus" in agent:
        return "Sapovirus", "gastrointestinal_viral", "fecal-oral/person-to-person"

    if "e. coli" in agent or "etec" in agent:
        pathogen = "Escherichia coli (ETEC)"
        category = "foodborne_waterborne_bacterial"
        route = "foodborne"
        # Check for secondary pathogens
        if "shigella" in agent:
            return pathogen, category, route  # secondary handled separately
        return pathogen, category, route

    if "vibrio" in agent:
        return "Vibrio spp.", "foodborne_waterborne_bacterial", "foodborne"
    if "salmonella" in agent:
        return "Salmonella spp.", "foodborne_waterborne_bacterial", "foodborne"
    if "shigella" in agent:
        return "Shigella spp.", "foodborne_waterborne_bacterial", "foodborne"
    if "campylobacter" in agent:
        return "Campylobacter spp.", "foodborne_waterborne_bacterial", "foodborne"
    if "ciguatera" in agent:
        return "Ciguatera toxin", "foodborne_waterborne_bacterial", "foodborne"

    # Default for GI illness
    return "NR", "unknown", "fecal-oral/person-to-person"


def get_secondary_pathogens(agent_str: str) -> str:
    """提取二次病原体"""
    agent = agent_str.strip().lower()
    if "e. coli" in agent and "shigella" in agent:
        return "Shigella"
    if "vibrio" in agent and "e. coli" in agent:
        return "Escherichia coli (ETEC)"
    return "NR"


def build_event_row(event: dict, event_id: str) -> dict:
    """将抓取的事件转换为数据集格式"""
    agent_raw = event.get("causative_agent", "").strip()
    pathogen, category, route = classify_pathogen(agent_raw)
    secondary = get_secondary_pathogens(agent_raw)
    year = extract_year(event.get("sailing_dates", ""))
    duration = compute_duration(event.get("sailing_dates", ""))
    source_page = event.get("source_page", "")
    source_url = SOURCE_URLS.get(source_page, 
                                  "https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/index.html")

    # Handle special pathogen strings
    if "vibrio" in agent_raw.lower() and "e. coli" in agent_raw.lower():
        pathogen = "Vibrio spp."
        category = "foodborne_waterborne_bacterial"
        route = "foodborne"
        secondary = "Escherichia coli (ETEC)"

    # Parse case counts if available
    cases_pax = event.get("cases_passengers", "").strip()
    cases_crew = event.get("cases_crew", "").strip()

    # Build notes
    notes_parts = []
    if event.get("cruise_line", "").strip():
        notes_parts.append(event["cruise_line"].strip())
    notes_parts.append(f"sailing {event.get('sailing_dates', 'NR')}")
    if agent_raw.lower() in ("specimens not obtained", "unknown"):
        notes_parts.append("specimens not obtained")
    notes = "; ".join(notes_parts)

    return {
        "event_id": event_id,
        "ship_name": event.get("ship_name", "").strip(),
        "ship_type": "ocean_cruise",
        "voyage_route": "NR",
        "outbreak_year": year,
        "outbreak_duration_days": duration,
        "pathogen_identified": pathogen,
        "pathogen_category": category,
        "secondary_pathogens": secondary,
        "clinical_syndrome": "acute_gastroenteritis",
        "cases_passengers": cases_pax if cases_pax else "NR",
        "cases_crew": cases_crew if cases_crew else "NR",
        "total_crew_onboard": "NR",
        "attack_rate_percent": "NR",
        "hospitalisations": "NR",
        "deaths": "NR",
        "transmission_route": route,
        "data_source_category": "official_public_health",
        "data_source_reference": "CDC VSP Outbreak Investigations",
        "source_url": source_url,
        "public_health_response": "enhanced_sanitation; port_health_notification",
        "notes": notes,
    }


def main():
    print("=" * 70)
    print("  补充遗漏的 CDC VSP 暴发事件到 outbreak_events.csv")
    print("=" * 70)

    # Load existing dataset
    with DATASET_PATH.open(newline="", encoding="utf-8") as f:
        existing = list(csv.DictReader(f))

    # Load scraped data
    with SCRAPED_PATH.open(newline="", encoding="utf-8") as f:
        scraped = list(csv.DictReader(f))

    # Build existing index
    vsp_existing = [r for r in existing if r["data_source_category"] == "official_public_health"]
    existing_index = set()
    for r in vsp_existing:
        existing_index.add((r["ship_name"].lower().strip(), r["outbreak_year"]))

    # Find missing events
    missing = []
    for e in scraped:
        ship = e.get("ship_name", "").lower().strip()
        year = extract_year(e.get("sailing_dates", ""))
        if ship and year and (ship, year) not in existing_index:
            missing.append(e)

    if not missing:
        print("\n  ✓ 没有遗漏事件，数据集已完整")
        return

    print(f"\n  发现 {len(missing)} 个遗漏事件")

    # Find next event_id
    max_evt = 0
    for r in existing:
        m = re.match(r'EVT-(\d+)', r["event_id"])
        if m:
            max_evt = max(max_evt, int(m.group(1)))

    # Build new rows
    new_rows = []
    next_id = max_evt + 1
    for e in missing:
        event_id = f"EVT-{next_id:03d}"
        row = build_event_row(e, event_id)
        new_rows.append(row)
        next_id += 1

    # Show what we're adding
    print(f"\n  新增事件 (EVT-{max_evt+1:03d} ~ EVT-{next_id-1:03d}):")
    from collections import Counter
    by_year = Counter(r["outbreak_year"] for r in new_rows)
    for y in sorted(by_year.keys()):
        year_events = [r for r in new_rows if r["outbreak_year"] == y]
        print(f"\n    {y} ({by_year[y]} 个事件):")
        for r in year_events:
            print(f"      {r['event_id']}: {r['ship_name']} - {r['pathogen_identified']} ({r['pathogen_category']})")

    # Append to dataset
    all_rows = existing + new_rows

    # Sort by year, then source, then event_id
    def sort_key(r):
        try:
            year = int(r["outbreak_year"])
        except (ValueError, TypeError):
            year = 9999
        source_rank = {"official_public_health": 0, "academic": 1, "grey_literature": 2}.get(
            r.get("data_source_category", ""), 9)
        return (year, source_rank, r["event_id"])

    all_rows.sort(key=sort_key)

    # Write back
    with DATASET_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in all_rows:
            writer.writerow({field: row.get(field, "NR") for field in CSV_FIELDS})

    print(f"\n  ✓ 已写入 {DATASET_PATH}")
    print(f"    原有: {len(existing)} 事件")
    print(f"    新增: {len(new_rows)} 事件")
    print(f"    总计: {len(all_rows)} 事件")


if __name__ == "__main__":
    main()
