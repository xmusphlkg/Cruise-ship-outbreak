#!/usr/bin/env python3
"""
03_fix_dataset_consistency.py
==============================
修复数据集中的一致性问题：
1. 删除确认的重复事件 EVT-750 (与 EVT-013 重复)
2. 将 EVT-002 (MV Hondius, WHO DON) 重新分类为 grey_literature
3. 将 EVT-027 (Ambition, news/prefecture) 重新分类为 grey_literature
4. 重新生成 supplementary tables
"""

import csv
import sys
from pathlib import Path
from collections import Counter

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
DATASET_PATH = DATA_DIR / "outbreak_events.csv"

sys.path.insert(0, str(REPO_ROOT / "script"))
from analysis_common import CSV_FIELD_ORDER


def main():
    print("=" * 70)
    print("  修复数据集一致性问题")
    print("=" * 70)

    with DATASET_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    print(f"  原始事件数: {len(rows)}")

    # Fix 1: Remove duplicate EVT-750
    before = len(rows)
    rows = [r for r in rows if r["event_id"] != "EVT-750"]
    print(f"  删除 EVT-750 (Horizon 1994 Legionella, 与 EVT-013 重复): {before} → {len(rows)}")

    # Fix 2: Reclassify EVT-002 as grey_literature
    for r in rows:
        if r["event_id"] == "EVT-002":
            r["data_source_category"] = "grey_literature"
            r["data_source_reference"] = "WHO Disease Outbreak News 2026-DON601; ECDC Rapid Risk Assessment 14 May 2026"
            print(f"  EVT-002 (MV Hondius): official_public_health → grey_literature")

    # Fix 3: Reclassify EVT-027 as grey_literature
    for r in rows:
        if r["event_id"] == "EVT-027":
            r["data_source_category"] = "grey_literature"
            print(f"  EVT-027 (Ambition): official_public_health → grey_literature")

    # Verify final counts
    N = len(rows)
    srcs = Counter(r["data_source_category"] for r in rows)
    cats = Counter(r["pathogen_category"] for r in rows)

    print(f"\n  最终事件数: {N}")
    print(f"  数据来源: {dict(srcs)}")
    print(f"  病原体类别: {dict(sorted(cats.items(), key=lambda x: -x[1]))}")

    # Write back
    with DATASET_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELD_ORDER)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "NR") for field in CSV_FIELD_ORDER})

    print(f"\n  ✓ 已保存: {DATASET_PATH}")

    # Print key stats for manuscript update
    print(f"\n{'='*70}")
    print(f"  Manuscript 更新所需的关键数字 (N={N})")
    print(f"{'='*70}")

    def pct(n, total):
        return f"{n/total*100:.1f}"

    print(f"\n  数据来源:")
    for src in ["official_public_health", "academic", "grey_literature"]:
        n = srcs.get(src, 0)
        print(f"    {src}: {n} ({pct(n, N)}%)")

    print(f"\n  病原体类别:")
    order = ["gastrointestinal_viral", "unknown", "foodborne_waterborne_bacterial",
             "respiratory_viral", "legionella", "vaccine_preventable", "zoonotic"]
    for cat in order:
        n = cats.get(cat, 0)
        print(f"    {cat}: {n} ({pct(n, N)}%)")

    # Periods
    def get_period(year):
        y = int(year)
        if y <= 2019:
            return "1993-2019"
        elif y <= 2022:
            return "2020-2022"
        else:
            return "2023-2026"

    periods = Counter(get_period(r["outbreak_year"]) for r in rows)
    print(f"\n  时间段 (3期):")
    for p in ["1993-2019", "2020-2022", "2023-2026"]:
        print(f"    {p}: {periods[p]}")

    # Deaths
    deaths_events = sum(1 for r in rows if r.get("deaths", "NR") not in ("NR", "", "0"))
    total_deaths = 0
    for r in rows:
        d = r.get("deaths", "NR")
        if d not in ("NR", ""):
            try:
                total_deaths += int(float(d))
            except ValueError:
                pass
    print(f"\n  死亡: {deaths_events} 个事件, {total_deaths} 人")

    # Hospitalisations
    hosp = sum(1 for r in rows if r.get("hospitalisations", "NR") not in ("NR", ""))
    print(f"  住院数据可用: {hosp} 个事件")

    # VSP viral gastroenteritis
    vsp = [r for r in rows if r["data_source_category"] == "official_public_health"]
    vsp_gi = sum(1 for r in vsp if r["pathogen_category"] == "gastrointestinal_viral")
    print(f"\n  VSP 中病毒性胃肠炎: {vsp_gi}/{len(vsp)} ({vsp_gi/len(vsp)*100:.1f}%)")

    # Academic respiratory
    acad = [r for r in rows if r["data_source_category"] == "academic"]
    acad_resp = sum(1 for r in acad if r["pathogen_category"] == "respiratory_viral")
    print(f"  Academic 中呼吸道病毒: {acad_resp}/{len(acad)} ({acad_resp/len(acad)*100:.1f}%)")

    # Non-VSP
    non_vsp = [r for r in rows if r["data_source_category"] != "official_public_health"]
    non_vsp_resp = sum(1 for r in non_vsp if r["pathogen_category"] == "respiratory_viral")
    print(f"  Non-VSP 中呼吸道病毒: {non_vsp_resp}/{len(non_vsp)} ({non_vsp_resp/len(non_vsp)*100:.1f}%)")

    # 2020-2022 respiratory
    p2020 = [r for r in rows if 2020 <= int(r["outbreak_year"]) <= 2022]
    p2020_resp = sum(1 for r in p2020 if r["pathogen_category"] == "respiratory_viral")
    print(f"  2020-2022 呼吸道病毒: {p2020_resp}/{len(p2020)} ({p2020_resp/len(p2020)*100:.1f}%)")


if __name__ == "__main__":
    main()
