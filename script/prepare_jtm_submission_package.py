#!/usr/bin/env python3

from __future__ import annotations

import html
import re
import shutil
import zipfile
from datetime import date
from pathlib import Path
from xml.sax.saxutils import escape


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = REPO_ROOT / "manuscript" / "journal_of_travel_medicine_research_letter"
OUT_DIR = SRC_DIR / "submission_package_2026-06-17"


def xml_text(text: str) -> str:
    return escape(text, {'"': "&quot;"})


def render_runs(text: str) -> str:
    """Render a small subset of Markdown inline markup to OOXML runs."""
    text = text.replace("  ", " ")
    parts: list[tuple[str, bool, bool]] = []
    pos = 0
    pattern = re.compile(r"(\*\*[^*]+\*\*|\*[^*]+\*)")
    for match in pattern.finditer(text):
        if match.start() > pos:
            parts.append((text[pos : match.start()], False, False))
        token = match.group(0)
        if token.startswith("**"):
            parts.append((token[2:-2], True, False))
        else:
            parts.append((token[1:-1], False, True))
        pos = match.end()
    if pos < len(text):
        parts.append((text[pos:], False, False))

    runs = []
    for chunk, bold, italic in parts:
        if chunk == "":
            continue
        props = []
        if bold:
            props.append("<w:b/>")
        if italic:
            props.append("<w:i/>")
        rpr = f"<w:rPr>{''.join(props)}</w:rPr>" if props else ""
        preserve = ' xml:space="preserve"' if chunk[:1].isspace() or chunk[-1:].isspace() else ""
        runs.append(f"<w:r>{rpr}<w:t{preserve}>{xml_text(chunk)}</w:t></w:r>")
    return "".join(runs) or "<w:r><w:t/></w:r>"


def para(text: str = "", style: str | None = None, align: str | None = None) -> str:
    props = []
    if style:
        props.append(f'<w:pStyle w:val="{style}"/>')
    if align:
        props.append(f'<w:jc w:val="{align}"/>')
    ppr = f"<w:pPr>{''.join(props)}</w:pPr>" if props else ""
    return f"<w:p>{ppr}{render_runs(text)}</w:p>"


def markdown_to_paragraphs(markdown: str, cover_letter: bool = False) -> str:
    paragraphs = []
    for raw in markdown.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("# "):
            paragraphs.append(para(line[2:].strip(), "Title"))
        elif line.startswith("## "):
            paragraphs.append(para(line[3:].strip(), "Heading1"))
        elif cover_letter and re.match(r"^\d{1,2} [A-Z][a-z]+ 20\d{2}$", line):
            paragraphs.append(para(line, align="right"))
        else:
            paragraphs.append(para(line))
    return "\n".join(paragraphs)


def styles_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr><w:spacing w:line="480" w:lineRule="auto" w:after="160"/></w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:pPr><w:spacing w:line="480" w:lineRule="auto" w:after="160"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:line="480" w:lineRule="auto" w:after="240"/><w:jc w:val="center"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:line="480" w:lineRule="auto" w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
  </w:style>
</w:styles>
"""


def document_xml(body: str) -> str:
    sect_pr = """
    <w:sectPr>
      <w:headerReference w:type="default" r:id="rIdHeader1"/>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
    """
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    {body}
    {sect_pr}
  </w:body>
</w:document>
"""


def header_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr><w:jc w:val="right"/></w:pPr>
    <w:r><w:fldChar w:fldCharType="begin"/></w:r>
    <w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>
    <w:r><w:fldChar w:fldCharType="separate"/></w:r>
    <w:r><w:t>1</w:t></w:r>
    <w:r><w:fldChar w:fldCharType="end"/></w:r>
  </w:p>
</w:hdr>
"""


def content_types_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
</Types>
"""


def root_rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"""


def document_rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
  <Relationship Id="rIdHeader1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
</Relationships>
"""


def settings_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:updateFields w:val="true"/>
</w:settings>
"""


def write_docx(markdown_path: Path, docx_path: Path, cover_letter: bool = False) -> None:
    body = markdown_to_paragraphs(markdown_path.read_text(encoding="utf-8"), cover_letter=cover_letter)
    with zipfile.ZipFile(docx_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types_xml())
        zf.writestr("_rels/.rels", root_rels_xml())
        zf.writestr("word/document.xml", document_xml(body))
        zf.writestr("word/_rels/document.xml.rels", document_rels_xml())
        zf.writestr("word/styles.xml", styles_xml())
        zf.writestr("word/settings.xml", settings_xml())
        zf.writestr("word/header1.xml", header_xml())


def copy_file(src: Path, dst_dir: Path, dst_name: str | None = None) -> Path:
    dst = dst_dir / (dst_name or src.name)
    shutil.copy2(src, dst)
    return dst


def package_manifest(files: list[Path]) -> str:
    lines = [
        "# JTM Research Letter Submission Package",
        "",
        f"Prepared: {date.today().isoformat()}",
        "",
        "This package follows the Journal of Travel Medicine Research Letter format checked on 2026-06-17:",
        "- no abstract;",
        "- 50-word maximum highlight included at the start of the manuscript;",
        "- one separate Figure 1 file supplied;",
        "- figure legend and alt text included in the manuscript file;",
        "- manuscript and cover letter supplied as Word-compatible DOCX files.",
        "",
        "## Files",
    ]
    for path in sorted(files, key=lambda p: p.name):
        lines.append(f"- `{path.name}`")
    lines.extend(
        [
            "",
            "## Final Manual Items",
            "- Complete author names, degrees, affiliations, ORCIDs, and corresponding author details.",
            "- Complete the CRediT author contribution statement.",
            "- Open the DOCX files in Word/LibreOffice once to confirm pagination and field updates.",
            "- Upload the TIFF as the preferred separate figure file; keep PDF as an editable backup if the portal permits.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)

    files: list[Path] = []
    manuscript_docx = OUT_DIR / "manuscript_jtm_research_letter.docx"
    cover_docx = OUT_DIR / "cover_letter_jtm_research_letter.docx"
    write_docx(SRC_DIR / "manuscript_jtm_research_letter.md", manuscript_docx)
    write_docx(SRC_DIR / "cover_letter_jtm_research_letter.md", cover_docx, cover_letter=True)
    files.extend([manuscript_docx, cover_docx])

    for suffix in ("tif", "pdf", "png"):
        files.append(copy_file(REPO_ROOT / "output" / f"Figure_1_public_visibility.{suffix}", OUT_DIR))

    for src in [
        SRC_DIR / "manuscript_jtm_research_letter.md",
        SRC_DIR / "cover_letter_jtm_research_letter.md",
        SRC_DIR / "jtm_submission_checklist.md",
        REPO_ROOT / "output" / "table_s_full_dataset.csv",
    ]:
        files.append(copy_file(src, OUT_DIR))

    supp_dir = OUT_DIR / "supplementary_tables"
    supp_dir.mkdir()
    for src in sorted((REPO_ROOT / "output" / "supplementary_tables").glob("*.csv")):
        files.append(copy_file(src, supp_dir))

    manifest = OUT_DIR / "SUBMISSION_PACKAGE_README.md"
    manifest.write_text(package_manifest(files), encoding="utf-8")
    files.append(manifest)

    zip_path = OUT_DIR.with_suffix(".zip")
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(files, key=lambda p: str(p.relative_to(OUT_DIR))):
            zf.write(path, path.relative_to(OUT_DIR))

    print(f"Prepared {OUT_DIR}")
    print(f"Prepared {zip_path}")


if __name__ == "__main__":
    main()
