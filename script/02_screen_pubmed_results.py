#!/usr/bin/env python3
"""
02_screen_pubmed_results.py
============================
对 PubMed 检索结果按照纳入排除标准进行筛选标注，
生成 data/pubmed_screening.csv，包含原始字段 + screening_decision + exclusion_reason。

纳入标准 (来自 supplementary_appendix.md):
- 发生在远洋或探险邮轮上
- 涉及 ≥2 例流行病学关联的传染病病例，或获得官方暴发认定
- 确认、疑似或未知传染病病因
- 发表在同行评审期刊、官方公共卫生报告或权威灰色文献中
- 发生在 1993年1月 至 2026年5月14日之间

排除标准:
- 军舰、货船、渔船、渡轮或内河游轮
- 单例旅行相关感染（无暴发认定）
- 非传染性病因
- 无暴发数据的建模研究
- 无权威来源引用的新闻报道
- 综述/荟萃分析（不报告新暴发事件）
- 方法学/干预研究（不报告新暴发事件）
- 与邮轮暴发无关的文献
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
PUBMED_RAW = DATA_DIR / "intermediate" / "pubmed_search_results.csv"
OUTPUT_PATH = DATA_DIR / "pubmed_screening.csv"
DATASET_PATH = DATA_DIR / "outbreak_events.csv"


# ============================================================================
# 已纳入数据集的 DOI 列表（用于标记 "included" 的文献）
# ============================================================================

def load_existing_dois() -> set[str]:
    """从现有数据集中提取所有 DOI"""
    dois = set()
    with DATASET_PATH.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get("data_source_category") != "academic":
                continue
            url = row.get("source_url", "")
            doi_match = re.search(r'(10\.\d{4,}/[^\s,]+)', url)
            if doi_match:
                dois.add(doi_match.group(1).lower().rstrip("/"))
    return dois


# ============================================================================
# 排除规则（基于标题和摘要的关键词匹配）
# ============================================================================

def classify_article(title: str, abstract: str, pub_type: str, doi: str,
                     existing_dois: set[str]) -> tuple[str, str]:
    """
    对文献进行分类，返回 (decision, reason)。
    
    decision: "include" | "exclude"
    reason: 排除原因（纳入时为空）
    """
    text = f"{title} {abstract}".lower()
    title_lower = title.lower()
    pub_type_lower = pub_type.lower()

    # 1. 已通过 DOI 确认纳入
    if doi:
        doi_clean = doi.lower().rstrip("/")
        if doi_clean in existing_dois:
            return "include", ""

    # 2. 检查是否与邮轮相关
    vessel_keywords = [
        "cruise ship", "cruise liner", "passenger vessel", "expedition cruise",
        "cruise vessel", "cruise line", "shipboard", "cruiseship",
        "cruise passenger", "ocean liner",
    ]
    has_vessel = any(kw in text for kw in vessel_keywords)

    if not has_vessel:
        # 可能是 "passenger ship" 但指渡轮/货船
        if "passenger ship" in text or "ship" in text:
            # 检查是否明确是非邮轮
            non_cruise = ["ferry", "cargo", "naval", "navy", "military",
                         "fishing vessel", "river cruise", "riverboat"]
            if any(nc in text for nc in non_cruise):
                return "exclude", "non_cruise_vessel"
            # 模糊情况，如果没有暴发相关词也排除
            if not any(kw in text for kw in ["outbreak", "cluster", "cases"]):
                return "exclude", "not_relevant_to_cruise_outbreak"
        else:
            return "exclude", "not_relevant_to_cruise_outbreak"

    # 3. 综述/荟萃分析
    review_indicators = [
        "systematic review", "meta-analysis", "scoping review",
        "narrative review", "literature review", "integrative review",
    ]
    if any(ri in text for ri in review_indicators):
        # 但如果综述中报告了具体暴发数据（如 Willebrand 2022），可能纳入
        if "table" in text and ("outbreak" in text) and any(
            kw in text for kw in ["cases", "passengers", "crew", "attack rate"]
        ):
            # 可能是报告暴发数据的综述 → 待人工确认
            pass
        else:
            return "exclude", "review_or_meta_analysis"

    if "review" in pub_type_lower and "systematic" not in text:
        # PubMed pub type = Review
        if not any(kw in text for kw in ["outbreak", "cluster", "cases reported"]):
            return "exclude", "review_or_meta_analysis"

    # 4. 建模/模拟研究（无实际暴发数据）
    model_indicators = [
        "mathematical model", "simulation model", "agent-based model",
        "compartmental model", "stochastic model", "transmission model",
        "seir model", "sir model",
    ]
    if any(mi in text for mi in model_indicators):
        if not any(kw in text for kw in ["outbreak data", "reported cases", "case report"]):
            return "exclude", "modelling_study_no_outbreak_data"

    # 5. 方法学/干预/监测系统研究（不报告新暴发）
    method_indicators = [
        "hand hygiene intervention", "surveillance system design",
        "wastewater surveillance", "environmental monitoring",
        "ventilation", "air quality", "disinfection protocol",
        "vaccination coverage", "vaccine uptake",
    ]
    if any(mi in text for mi in method_indicators):
        if not any(kw in text for kw in ["outbreak", "cluster", "cases"]):
            return "exclude", "methodology_or_intervention_study"

    # 6. 非传染性病因
    non_infectious = [
        "carbon monoxide", "chemical exposure", "food poisoning" ,
        "ciguatera", "scombroid", "paralytic shellfish",
    ]
    # ciguatera 等食物中毒在本研究中被排除（non-infectious foodborne intoxication）
    if any(ni in text for ni in non_infectious):
        if "outbreak" not in text:
            return "exclude", "non_infectious_aetiology"

    # 7. 单例病例报告（无暴发认定）
    single_case_indicators = [
        "single case", "one case", "a case of", "case report",
        "travel-associated case", "imported case",
    ]
    if any(sc in title_lower for sc in single_case_indicators):
        if not any(kw in text for kw in ["outbreak", "cluster", "additional cases"]):
            return "exclude", "single_case_no_outbreak_designation"

    # 8. 社论/评论/新闻（非原始数据）
    editorial_types = ["editorial", "comment", "letter", "news", "correspondence"]
    if any(et in pub_type_lower for et in editorial_types):
        if not any(kw in text for kw in ["cases", "outbreak", "passengers", "crew"]):
            return "exclude", "editorial_or_commentary"

    # 9. 检查是否报告了具体暴发事件（需要有具体病例数据）
    specific_outbreak_indicators = [
        "cases among passengers", "cases among crew",
        "attack rate", "case count", "ill passengers",
        "passengers reported ill", "crew reported ill",
        "confirmed cases", "probable cases",
        r"\d+ cases", r"\d+ passengers",
    ]
    has_specific_outbreak = any(
        re.search(si, text) if "\\" in si else (si in text)
        for si in specific_outbreak_indicators
    )

    # 强暴发指标（标题中明确提到暴发）
    title_outbreak = any(kw in title_lower for kw in [
        "outbreak", "cluster", "epidemic",
        "norovirus on", "influenza on", "covid-19 on",
        "sars-cov-2 on", "legionella on", "hantavirus on",
    ])

    if has_vessel and (has_specific_outbreak or title_outbreak):
        return "include", ""

    # 10. 有邮轮 + 暴发关键词但不够具体 → 可能是一般性讨论
    general_outbreak_words = ["outbreak", "cluster", "infection", "illness"]
    has_general_outbreak = any(kw in text for kw in general_outbreak_words)

    if has_vessel and has_general_outbreak:
        # 进一步区分：是否有具体数据 vs 一般性讨论
        data_indicators = [
            "patients", "specimens", "laboratory confirmed",
            "pcr", "rt-pcr", "stool sample", "nasopharyngeal",
            "isolation", "quarantine", "disembark",
            "voyage", "sailing", "itinerary",
        ]
        has_data = any(di in text for di in data_indicators)

        general_only = [
            "prevention", "preparedness", "policy", "guideline",
            "recommendation", "risk assessment", "travel medicine",
            "health advice", "insurance", "regulation", "legislation",
            "ventilation design", "air filtration", "water treatment",
            "sanitation program", "inspection score",
        ]
        is_general = any(gi in text for gi in general_only) and not has_data

        if is_general:
            return "exclude", "general_discussion_no_outbreak_data"

        # 有暴发词 + 有数据指标 → 可能报告暴发
        if has_data:
            return "include", ""

        # 模糊情况 → 排除（保守策略）
        return "exclude", "no_specific_outbreak_data_reported"

    # 11. 有邮轮关键词但完全没有暴发/疾病相关内容
    if has_vessel:
        return "exclude", "cruise_related_but_no_outbreak_data"

    return "exclude", "not_relevant_to_cruise_outbreak"


# ============================================================================
# 主流程
# ============================================================================

def main():
    print("=" * 70)
    print("  PubMed 检索结果筛选标注")
    print("=" * 70)

    # Load existing DOIs
    existing_dois = load_existing_dois()
    print(f"  现有数据集中的 DOI: {len(existing_dois)}")

    # Load PubMed results
    with PUBMED_RAW.open(newline="", encoding="utf-8") as f:
        articles = list(csv.DictReader(f))
    print(f"  PubMed 检索结果: {len(articles)} 篇")

    # Screen each article
    results = []
    for a in articles:
        title = a.get("title", "")
        abstract = a.get("abstract", "")
        pub_type = a.get("pub_type", "")
        doi = a.get("doi", "")

        decision, reason = classify_article(title, abstract, pub_type, doi, existing_dois)

        row = dict(a)  # copy all original fields
        row["screening_decision"] = decision
        row["exclusion_reason"] = reason
        results.append(row)

    # Stats
    from collections import Counter
    decisions = Counter(r["screening_decision"] for r in results)
    reasons = Counter(r["exclusion_reason"] for r in results if r["exclusion_reason"])

    print(f"\n  筛选结果:")
    print(f"    纳入 (include): {decisions.get('include', 0)}")
    print(f"    排除 (exclude): {decisions.get('exclude', 0)}")

    print(f"\n  排除原因分布:")
    for reason, n in reasons.most_common():
        print(f"    {reason}: {n}")

    # Write output
    fieldnames = list(articles[0].keys()) + ["screening_decision", "exclusion_reason"]

    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            writer.writerow(row)

    print(f"\n  ✓ 已保存: {OUTPUT_PATH} ({len(results)} 行)")

    # Show included articles
    included = [r for r in results if r["screening_decision"] == "include"]
    print(f"\n  纳入的文献 ({len(included)} 篇):")
    for r in sorted(included, key=lambda x: x.get("pub_year", ""), reverse=True)[:30]:
        doi_str = f" | DOI: {r['doi']}" if r['doi'] else ""
        print(f"    [{r.get('pub_year','')}] {r['title'][:75]}...")
        print(f"         PMID: {r['pmid']}{doi_str}")


if __name__ == "__main__":
    main()
