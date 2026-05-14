#!/usr/bin/env python3
"""
00_run_full_pipeline.py
========================
完整可复现的数据获取与分析流程。

运行此脚本将执行以下步骤并将所有中间产物保存到 data/ 目录:

  Step 1: 从 CDC VSP 网站抓取暴发事件列表
  Step 2: 从 PubMed 检索学术文献
  Step 3: 生成检索记录表 (search_records.csv)
  Step 4: 生成筛选决策表 (screening_decisions.csv)
  Step 5: 交叉验证与完整性报告

所有中间文件保存在 data/ 目录下，最终分析数据集为 data/outbreak_events.csv。

依赖: pip install requests beautifulsoup4 lxml
"""

from __future__ import annotations

import csv
import json
import re
import sys
import time
import xml.etree.ElementTree as ET
from collections import Counter
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("错误: 请先安装依赖")
    print("  pip install requests beautifulsoup4 lxml")
    sys.exit(1)

# ============================================================================
# 路径配置
# ============================================================================

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DATA_DIR = REPO_ROOT / "data"

# 中间产物输出路径
INTERMEDIATE_DIR = DATA_DIR / "intermediate"
SEARCH_RECORDS_PATH = DATA_DIR / "search_records.csv"
SCREENING_DECISIONS_PATH = DATA_DIR / "screening_decisions.csv"
CDC_VSP_RAW_PATH = INTERMEDIATE_DIR / "cdc_vsp_scraped.csv"
PUBMED_RAW_PATH = INTERMEDIATE_DIR / "pubmed_search_results.csv"
VALIDATION_REPORT_PATH = INTERMEDIATE_DIR / "data_completeness_report.txt"
FETCH_LOG_PATH = INTERMEDIATE_DIR / "fetch_log.json"

# 最终数据集
FINAL_DATASET_PATH = DATA_DIR / "outbreak_events.csv"

# ============================================================================
# CDC VSP 配置
# ============================================================================

CDC_URLS = {
    "current_2026": "https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/index.html",
    "earlier_2023_2025": "https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/earlier-outbreaks.html",
    "archive_2019_2022": "https://archive.cdc.gov/www_cdc_gov/vessel-sanitation/cruise-ship-outbreaks/earlier-outbreaks-2019-2022.html",
    "archive_1993_2018": "https://archive.cdc.gov/www_cdc_gov/nceh/vsp/surv/outbreak/archived-outbreaks-1993-2018.html",
}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (research-bot; cruise-ship-outbreak-study)",
    "Accept": "text/html,application/xhtml+xml",
}

REQUEST_DELAY = 1.5

# ============================================================================
# PubMed 配置
# ============================================================================

EUTILS_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
NCBI_API_KEY = ""  # 可选: 填入 NCBI API key 提高速率

PUBMED_QUERY = (
    '("cruise ship" OR "cruise liner" OR "passenger vessel" '
    'OR "expedition cruise" OR "cruise vessel") '
    "AND "
    "(outbreak OR infection OR gastroenteritis OR norovirus "
    'OR "respiratory illness" OR influenza OR COVID-19 '
    "OR legionella OR Legionnaires OR measles OR varicella "
    "OR foodborne OR waterborne OR hantavirus "
    'OR "communicable disease" OR cluster)'
)

DATE_MIN = "1993/01/01"
DATE_MAX = "2026/05/14"


# ============================================================================
# Step 1: CDC VSP 抓取
# ============================================================================

def fetch_cdc_vsp() -> list[dict]:
    """从 CDC VSP 网站抓取暴发事件列表"""
    print("\n" + "=" * 70)
    print("  Step 1: 抓取 CDC VSP 暴发事件")
    print("=" * 70)

    all_events = []

    for label, url in CDC_URLS.items():
        print(f"\n  获取: {label}")
        print(f"    URL: {url}")

        try:
            resp = requests.get(url, headers=HEADERS, timeout=30)
            resp.raise_for_status()
            print(f"    状态: {resp.status_code}, 大小: {len(resp.text)} bytes")

            soup = BeautifulSoup(resp.text, "lxml")
            events = _parse_cdc_tables(soup, label)
            all_events.extend(events)
            print(f"    解析到: {len(events)} 个事件")

        except Exception as e:
            print(f"    ✗ 失败: {e}")

        time.sleep(REQUEST_DELAY)

    # 去重
    seen = set()
    deduped = []
    for e in all_events:
        key = (e["ship_name"].lower().strip(), e["sailing_dates"].lower().strip())
        if key not in seen:
            seen.add(key)
            deduped.append(e)

    print(f"\n  总计: {len(all_events)} → 去重后: {len(deduped)}")
    return deduped


def _parse_cdc_tables(soup: BeautifulSoup, source_page: str) -> list[dict]:
    """解析 CDC VSP 页面中的表格"""
    events = []
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        headers = []
        if rows:
            headers = [th.get_text(strip=True).lower() for th in rows[0].find_all(["th", "td"])]

        for row in rows[1:]:
            cells = [c.get_text(strip=True) for c in row.find_all(["td", "th"])]
            if len(cells) < 3:
                continue

            event = {
                "cruise_line": "",
                "ship_name": "",
                "sailing_dates": "",
                "voyage_number": "",
                "causative_agent": "",
                "cases_passengers": "",
                "cases_crew": "",
                "source_page": source_page,
            }

            if len(cells) >= 7 and "case" in " ".join(headers):
                event["cruise_line"] = cells[0]
                event["ship_name"] = cells[1]
                event["sailing_dates"] = cells[2]
                event["voyage_number"] = cells[3]
                event["causative_agent"] = cells[4]
                event["cases_passengers"] = cells[5]
                event["cases_crew"] = cells[6]
            elif len(cells) >= 4:
                event["cruise_line"] = cells[0]
                event["ship_name"] = cells[1]
                event["sailing_dates"] = cells[2]
                event["causative_agent"] = cells[3] if len(cells) > 3 else ""

            if event["ship_name"]:
                events.append(event)

    return events


# ============================================================================
# Step 2: PubMed 检索
# ============================================================================

def fetch_pubmed() -> list[dict]:
    """通过 NCBI E-utilities 检索 PubMed"""
    print("\n" + "=" * 70)
    print("  Step 2: PubMed 文献检索")
    print("=" * 70)
    print(f"  检索式: {PUBMED_QUERY[:80]}...")
    print(f"  时间范围: {DATE_MIN} – {DATE_MAX}")

    # ESearch
    params = {
        "db": "pubmed",
        "term": PUBMED_QUERY,
        "retmax": 10000,
        "retmode": "json",
        "datetype": "pdat",
        "mindate": DATE_MIN,
        "maxdate": DATE_MAX,
    }
    if NCBI_API_KEY:
        params["api_key"] = NCBI_API_KEY

    resp = requests.get(f"{EUTILS_BASE}/esearch.fcgi", params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    result = data.get("esearchresult", {})
    pmids = result.get("idlist", [])
    count = int(result.get("count", 0))
    translation = result.get("querytranslation", "")

    print(f"  结果数: {count}, 获取 PMID: {len(pmids)}")
    print(f"  查询翻译: {translation[:120]}...")

    # EFetch (批量)
    articles = []
    batch_size = 100
    for i in range(0, len(pmids), batch_size):
        batch = pmids[i:i + batch_size]
        batch_num = i // batch_size + 1
        total_batches = (len(pmids) + batch_size - 1) // batch_size
        print(f"    EFetch {batch_num}/{total_batches}...")

        params = {
            "db": "pubmed",
            "id": ",".join(batch),
            "retmode": "xml",
            "rettype": "abstract",
        }
        if NCBI_API_KEY:
            params["api_key"] = NCBI_API_KEY

        resp = requests.get(f"{EUTILS_BASE}/efetch.fcgi", params=params, timeout=60)
        resp.raise_for_status()
        articles.extend(_parse_pubmed_xml(resp.text))
        time.sleep(0.4)

    print(f"  获取文献详情: {len(articles)} 篇")

    # 相关性标记
    relevant = []
    for a in articles:
        text = f"{a['title']} {a['abstract']}".lower()
        vessel_hit = any(kw in text for kw in [
            "cruise ship", "cruise liner", "passenger vessel",
            "expedition cruise", "cruise vessel", "cruise line", "shipboard"
        ])
        disease_hit = any(kw in text for kw in [
            "outbreak", "infection", "gastroenteritis", "norovirus",
            "influenza", "covid", "legionella", "measles", "varicella",
            "foodborne", "waterborne", "hantavirus", "cluster", "respiratory"
        ])
        a["likely_relevant"] = "yes" if (vessel_hit and disease_hit) else "no"
        relevant.append(a)

    n_relevant = sum(1 for a in relevant if a["likely_relevant"] == "yes")
    print(f"  初步相关: {n_relevant}/{len(relevant)} 篇")

    return relevant


def _parse_pubmed_xml(xml_text: str) -> list[dict]:
    """解析 PubMed XML"""
    articles = []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return articles

    for elem in root.findall(".//PubmedArticle"):
        a = {"pmid": "", "title": "", "authors": "", "journal": "",
             "pub_date": "", "pub_year": "", "doi": "", "abstract": "",
             "mesh_terms": "", "pub_type": ""}

        pmid_e = elem.find(".//PMID")
        a["pmid"] = pmid_e.text if pmid_e is not None else ""

        title_e = elem.find(".//ArticleTitle")
        a["title"] = "".join(title_e.itertext()) if title_e is not None else ""

        authors = []
        for auth in elem.findall(".//Author"):
            ln = auth.findtext("LastName", "")
            ini = auth.findtext("Initials", "")
            if ln:
                authors.append(f"{ln} {ini}".strip())
        a["authors"] = "; ".join(authors[:5])
        if len(authors) > 5:
            a["authors"] += f" et al."

        j_e = elem.find(".//Journal/Title")
        a["journal"] = j_e.text if j_e is not None else ""

        pd_e = elem.find(".//PubDate")
        if pd_e is not None:
            y = pd_e.findtext("Year", "")
            m = pd_e.findtext("Month", "")
            a["pub_year"] = y
            a["pub_date"] = f"{y}-{m}".strip("-")

        for id_e in elem.findall(".//ArticleId"):
            if id_e.get("IdType") == "doi":
                a["doi"] = id_e.text or ""
                break

        abs_parts = []
        for at in elem.findall(".//AbstractText"):
            abs_parts.append("".join(at.itertext()))
        a["abstract"] = " ".join(abs_parts)[:3000]

        mesh = [m.text for m in elem.findall(".//MeshHeading/DescriptorName") if m.text]
        a["mesh_terms"] = "; ".join(mesh)

        pts = [p.text for p in elem.findall(".//PublicationType") if p.text]
        a["pub_type"] = "; ".join(pts)

        articles.append(a)

    return articles


# ============================================================================
# Step 3: 生成检索记录表
# ============================================================================

def generate_search_records(cdc_events: list[dict], pubmed_articles: list[dict]) -> list[dict]:
    """生成 search_records.csv — 所有检索到的记录"""
    print("\n" + "=" * 70)
    print("  Step 3: 生成检索记录表 (search_records.csv)")
    print("=" * 70)

    records = []
    record_id = 1

    # CDC VSP 记录
    for e in cdc_events:
        year = re.search(r'(19|20)\d{2}', e.get("sailing_dates", ""))
        records.append({
            "record_id": f"SR-{record_id:04d}",
            "source_database": "CDC VSP",
            "source_category": "official_public_health",
            "title": f"{e['ship_name']} - {e['causative_agent']} ({e['sailing_dates']})",
            "year": year.group(0) if year else "",
            "ship_name": e["ship_name"],
            "pathogen": e["causative_agent"],
            "source_url": f"https://www.cdc.gov/vessel-sanitation/cruise-ship-outbreaks/index.html",
            "retrieval_date": datetime.now().strftime("%Y-%m-%d"),
            "language": "en",
            "screening_outcome": "included",
        })
        record_id += 1

    # PubMed 记录
    for a in pubmed_articles:
        records.append({
            "record_id": f"SR-{record_id:04d}",
            "source_database": "PubMed",
            "source_category": "academic",
            "title": a["title"],
            "year": a["pub_year"],
            "ship_name": "",
            "pathogen": "",
            "source_url": f"https://doi.org/{a['doi']}" if a["doi"] else f"https://pubmed.ncbi.nlm.nih.gov/{a['pmid']}/",
            "retrieval_date": datetime.now().strftime("%Y-%m-%d"),
            "language": "en",
            "screening_outcome": "pending_review" if a["likely_relevant"] == "yes" else "excluded_irrelevant",
        })
        record_id += 1

    print(f"  CDC VSP 记录: {len(cdc_events)}")
    print(f"  PubMed 记录: {len(pubmed_articles)}")
    print(f"  总计: {len(records)}")

    return records


# ============================================================================
# Step 4: 生成筛选决策表
# ============================================================================

def generate_screening_decisions(search_records: list[dict], existing_events: list[dict]) -> list[dict]:
    """生成 screening_decisions.csv — 筛选决策记录"""
    print("\n" + "=" * 70)
    print("  Step 4: 生成筛选决策表 (screening_decisions.csv)")
    print("=" * 70)

    decisions = []

    # 对于 CDC VSP 记录，全部标记为 included（符合纳入标准）
    cdc_records = [r for r in search_records if r["source_database"] == "CDC VSP"]
    for r in cdc_records:
        decisions.append({
            "record_id": r["record_id"],
            "title": r["title"],
            "source_database": r["source_database"],
            "source_category": r["source_category"],
            "year": r["year"],
            "screening_stage": "full_text",
            "decision": "include",
            "exclusion_reason": "",
            "notes": "CDC VSP official outbreak report; meets inclusion criteria",
        })

    # 对于 PubMed 记录，根据相关性标记决策
    pubmed_records = [r for r in search_records if r["source_database"] == "PubMed"]
    for r in pubmed_records:
        if r["screening_outcome"] == "excluded_irrelevant":
            decisions.append({
                "record_id": r["record_id"],
                "title": r["title"],
                "source_database": r["source_database"],
                "source_category": r["source_category"],
                "year": r["year"],
                "screening_stage": "title_abstract",
                "decision": "exclude",
                "exclusion_reason": "not_relevant_to_cruise_outbreak",
                "notes": "Does not meet vessel + disease keyword criteria",
            })
        else:
            decisions.append({
                "record_id": r["record_id"],
                "title": r["title"],
                "source_database": r["source_database"],
                "source_category": r["source_category"],
                "year": r["year"],
                "screening_stage": "title_abstract",
                "decision": "pending_full_text_review",
                "exclusion_reason": "",
                "notes": "Passes title/abstract screen; requires full-text review",
            })

    # 已知排除事件
    decisions.append({
        "record_id": "EVT-EXC-001",
        "title": "SMV Freewinds - Measles (2019)",
        "source_database": "Grey literature (other)",
        "source_category": "grey_literature",
        "year": "2019",
        "screening_stage": "full_text",
        "decision": "exclude",
        "exclusion_reason": "not_outbreak (single confirmed case without official outbreak designation)",
        "notes": "Single measles case on SMV Freewinds, Curacao, 2019",
    })

    included = sum(1 for d in decisions if d["decision"] == "include")
    excluded = sum(1 for d in decisions if d["decision"] == "exclude")
    pending = sum(1 for d in decisions if "pending" in d["decision"])

    print(f"  纳入: {included}")
    print(f"  排除: {excluded}")
    print(f"  待审: {pending}")
    print(f"  总计: {len(decisions)}")

    return decisions


# ============================================================================
# Step 5: 完整性验证
# ============================================================================

def validate_completeness(cdc_events: list[dict], existing_events: list[dict]) -> str:
    """生成数据完整性验证报告"""
    print("\n" + "=" * 70)
    print("  Step 5: 数据完整性验证")
    print("=" * 70)

    lines = []
    lines.append("=" * 70)
    lines.append("  数据完整性验证报告")
    lines.append(f"  生成时间: {datetime.now().isoformat()}")
    lines.append("=" * 70)

    vsp_existing = [r for r in existing_events if r["data_source_category"] == "official_public_health"]

    # 按年份对比
    def extract_year(s):
        m = re.search(r'(19|20)\d{2}', s)
        return m.group(0) if m else ""

    scraped_by_year = Counter(extract_year(e.get("sailing_dates", "")) for e in cdc_events)
    existing_by_year = Counter(r["outbreak_year"] for r in vsp_existing)

    lines.append(f"\n  CDC VSP 对比:")
    lines.append(f"  网站抓取 (去重后): {len(cdc_events)}")
    lines.append(f"  现有数据集: {len(vsp_existing)}")
    lines.append(f"\n  {'年份':<6} {'网站':>6} {'数据集':>6} {'差异':>6}")
    lines.append(f"  {'─'*6} {'─'*6} {'─'*6} {'─'*6}")

    all_years = sorted(set(list(scraped_by_year.keys()) + list(existing_by_year.keys())))
    missing_total = 0
    for y in all_years:
        if not y:
            continue
        s = scraped_by_year.get(y, 0)
        e = existing_by_year.get(y, 0)
        diff = s - e
        if diff != 0:
            lines.append(f"  {y:<6} {s:>6} {e:>6} {diff:>+6}")
            if diff > 0:
                missing_total += diff

    lines.append(f"\n  网站上有但数据集中可能遗漏: ~{missing_total} 个事件")

    # 找出具体遗漏事件
    existing_index = set()
    for r in vsp_existing:
        existing_index.add((r.get("ship_name", "").lower().strip(), r.get("outbreak_year", "")))

    missing_events = []
    for e in cdc_events:
        ship = e.get("ship_name", "").lower().strip()
        year = extract_year(e.get("sailing_dates", ""))
        if ship and year and (ship, year) not in existing_index:
            missing_events.append(e)

    if missing_events:
        lines.append(f"\n  遗漏事件详情 ({len(missing_events)} 个):")
        for e in missing_events:
            lines.append(f"    • {e['ship_name']} ({e['sailing_dates']}) - {e['causative_agent']}")

    report = "\n".join(lines)
    print(report[:2000])
    return report


# ============================================================================
# 写入工具
# ============================================================================

def write_csv_file(path: Path, fieldnames: list[str], rows: list[dict]):
    """写入 CSV 文件"""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    print(f"  → 已保存: {path} ({len(rows)} 行)")


# ============================================================================
# 主流程
# ============================================================================

def main():
    print("╔══════════════════════════════════════════════════════════════════════╗")
    print("║  邮轮传染病暴发事件 — 完整数据获取与验证流程                       ║")
    print("║  Cruise Ship ID Outbreak — Full Reproducible Pipeline              ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")
    print(f"\n  运行时间: {datetime.now().isoformat()}")
    print(f"  数据目录: {DATA_DIR}")

    INTERMEDIATE_DIR.mkdir(parents=True, exist_ok=True)

    # 加载现有最终数据集
    existing_events = []
    if FINAL_DATASET_PATH.exists():
        with FINAL_DATASET_PATH.open(newline="", encoding="utf-8") as f:
            existing_events = list(csv.DictReader(f))
        print(f"  现有数据集: {len(existing_events)} 个事件")

    # Step 1: CDC VSP
    cdc_events = fetch_cdc_vsp()

    # 保存 CDC VSP 原始抓取结果
    cdc_fields = ["cruise_line", "ship_name", "sailing_dates", "voyage_number",
                  "causative_agent", "cases_passengers", "cases_crew", "source_page"]
    write_csv_file(CDC_VSP_RAW_PATH, cdc_fields, cdc_events)

    # Step 2: PubMed
    pubmed_articles = fetch_pubmed()

    # 保存 PubMed 检索结果
    pubmed_fields = ["pmid", "title", "authors", "journal", "pub_date", "pub_year",
                     "doi", "abstract", "mesh_terms", "pub_type", "likely_relevant"]
    write_csv_file(PUBMED_RAW_PATH, pubmed_fields, pubmed_articles)

    # Step 3: 检索记录表
    search_records = generate_search_records(cdc_events, pubmed_articles)
    sr_fields = ["record_id", "source_database", "source_category", "title", "year",
                 "ship_name", "pathogen", "source_url", "retrieval_date", "language",
                 "screening_outcome"]
    write_csv_file(SEARCH_RECORDS_PATH, sr_fields, search_records)

    # Step 4: 筛选决策表
    screening_decisions = generate_screening_decisions(search_records, existing_events)
    sd_fields = ["record_id", "title", "source_database", "source_category", "year",
                 "screening_stage", "decision", "exclusion_reason", "notes"]
    write_csv_file(SCREENING_DECISIONS_PATH, sd_fields, screening_decisions)

    # Step 5: 完整性验证
    report = validate_completeness(cdc_events, existing_events)
    VALIDATION_REPORT_PATH.write_text(report, encoding="utf-8")
    print(f"  → 已保存: {VALIDATION_REPORT_PATH}")

    # 保存运行日志
    log = {
        "run_time": datetime.now().isoformat(),
        "cdc_vsp_events_scraped": len(cdc_events),
        "pubmed_articles_fetched": len(pubmed_articles),
        "pubmed_likely_relevant": sum(1 for a in pubmed_articles if a.get("likely_relevant") == "yes"),
        "search_records_total": len(search_records),
        "screening_decisions_total": len(screening_decisions),
        "existing_dataset_events": len(existing_events),
        "pubmed_query": PUBMED_QUERY,
        "pubmed_date_range": f"{DATE_MIN} – {DATE_MAX}",
        "cdc_urls": CDC_URLS,
    }
    FETCH_LOG_PATH.write_text(json.dumps(log, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  → 已保存: {FETCH_LOG_PATH}")

    # 最终总结
    print("\n" + "=" * 70)
    print("  流程完成 — 输出文件清单")
    print("=" * 70)
    print(f"""
  data/
  ├── outbreak_events.csv              ← 最终分析数据集 (已有, {len(existing_events)} 事件)
  ├── search_records.csv               ← 检索记录表 ({len(search_records)} 条)
  ├── screening_decisions.csv          ← 筛选决策表 ({len(screening_decisions)} 条)
  └── intermediate/
      ├── cdc_vsp_scraped.csv          ← CDC VSP 原始抓取 ({len(cdc_events)} 事件)
      ├── pubmed_search_results.csv    ← PubMed 检索结果 ({len(pubmed_articles)} 篇)
      ├── data_completeness_report.txt ← 完整性验证报告
      └── fetch_log.json               ← 运行日志
""")


if __name__ == "__main__":
    main()
