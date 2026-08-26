#!/usr/bin/env python3
"""Rinomina + ribranding di SDS esportate da EpyX (.docx).

  rebrand.py inspect FILE...
  rebrand.py apply --profile P.json [--dry-run] [--no-rename] FILE...
  rebrand.py --self-check
"""
import argparse, json, re, sys, zipfile
from html import unescape
from pathlib import Path

T = re.compile(r"<w:t(?: [^>]*)?>(.*?)</w:t>", re.S)   # non deve agganciare <w:tr>

# Correzioni standard: applicate se il run esiste, altrimenti ignorate.
FIXES = [
    ("Non è stata elaborata una valutazione di sicurezza chimica per la miscela / per le sostanze indicate in sezione 3.",
     "Non è stata elaborata una valutazione di sicurezza chimica per la miscela."),
    ("No chemical safety assessment has been processed for the mixture / for the substances mentioned in section 3.",
     "No chemical safety assessment has been processed for the mixture."),
]


def rows(xml, start, end):
    """(inizio, fine, [testi]) di ogni <w:tr> fra l'intestazione `start` e `end`."""
    lo = xml.index(f">{start}", 0) if f">{start}" in xml else 0
    hi = xml.index(f">{end}", lo) if f">{end}" in xml else len(xml)
    out = []
    for m in re.finditer(r"<w:tr>.*?</w:tr>", xml[lo:hi], re.S):
        out.append((lo + m.start(), lo + m.end(), T.findall(m.group())))
    return out


def set_value(row_xml, value):
    """Sostituisce l'ultimo run di testo della riga (= cella valore)."""
    ms = list(T.finditer(row_xml))
    assert ms, "riga senza testo"
    m = ms[-1]
    return row_xml[:m.start(1)] + value + row_xml[m.end(1):]


def edit_1_3(xml, fields):
    """fields: {prefisso_etichetta: nuovo_valore | None (= elimina riga)}."""
    todo = dict(fields)
    for start, end, texts in reversed(rows(xml, "1.3", "1.4")):
        label = texts[0].strip() if texts else ""
        hit = next((k for k in todo if label.lower().startswith(k.lower())), None)
        if hit is None:
            continue
        value = todo.pop(hit)
        xml = xml[:start] + ("" if value is None else set_value(xml[start:end], value)) + xml[end:]
    # una riga da eliminare che non c'è più è un no-op, non un errore (rerun)
    missing = [k for k, v in todo.items() if v is not None]
    assert not missing, f"etichette non trovate in 1.3: {missing}"
    return xml


def clone_row(row_xml, label, value):
    """Copia una riga (2 celle) cambiandone etichetta e valore."""
    ms = list(T.finditer(row_xml))
    assert len(ms) == 2, f"attese 2 celle, trovate {len(ms)}"
    a, b = ms
    return (row_xml[:a.start(1)] + label + row_xml[a.end(1):b.start(1)]
            + value + row_xml[b.end(1):])


def set_ufi(xml, ufi):
    """Riga UFI subito sotto Denominazione in 1.1; aggiorna se già presente."""
    r = rows(xml, "1.1", "1.2")
    assert r, "sezione 1.1 non trovata"
    for start, end, texts in r:
        if texts and texts[0].strip().upper() == "UFI":
            return xml[:start] + set_value(xml[start:end], ufi) + xml[end:]
    start, end, _ = r[0]
    return xml[:end] + clone_row(xml[start:end], "UFI", ufi) + xml[end:]


def read_xlsx(path):
    """Prima sheet come lista di dict {intestazione: valore}. Solo testo."""
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        shared = []
        if "xl/sharedStrings.xml" in names:
            for si in re.findall(r"<si>(.*?)</si>", z.read("xl/sharedStrings.xml").decode(), re.S):
                shared.append("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S)))
        sheet = z.read("xl/worksheets/sheet1.xml").decode()

    def colnum(ref):
        n = 0
        for ch in re.match(r"[A-Z]+", ref).group():
            n = n * 26 + ord(ch) - 64
        return n - 1

    table = []
    for row in re.findall(r"<row[^>]*>(.*?)</row>", sheet, re.S):
        cells = {}
        for m in re.finditer(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', row, re.S):
            attrs, body = m.group(1), m.group(2) or ""
            v = re.search(r"<v>(.*?)</v>", body, re.S)
            txt = v.group(1) if v else ""
            if 't="s"' in attrs and txt:
                txt = shared[int(txt)]
            elif 't="inlineStr"' in attrs:
                txt = "".join(re.findall(r"<t[^>]*>(.*?)</t>", body, re.S))
            cells[colnum(re.search(r'r="([A-Z]+)', attrs).group(1))] = unescape(txt)
        table.append(cells)
    if not table:
        return []
    head = table[0]
    return [{head[k]: v for k, v in r.items() if k in head} for r in table[1:]]


def ufi_map(path):
    """{codice prodotto: UFI} dal file elenco-ufi.xlsx."""
    out = {}
    for r in read_xlsx(path):
        code, ufi = r.get("Codice prodotto", "").strip(), r.get("UFI", "").strip()
        if code and ufi:
            out[code] = ufi
    assert out, f"nessuna coppia codice/UFI in {path}"
    return out


def apply_fixes(xml):
    for old, new in FIXES:
        xml = xml.replace(f">{old}</w:t>", f">{new}</w:t>")
    return xml


def product(xml):
    r = rows(xml, "1.1", "1.2")
    assert r, "sezione 1.1 non trovata"
    return r[0][2][-1].strip()


def slug(name):
    return re.sub(r"-+", "-", re.sub(r"[^A-Z0-9]+", "-", name.upper())).strip("-")


def target_name(src, xml):
    """CLP_<CODE>_SDS_R.<n>_<LANG> (...).docx -> <CODE>--<PROD>__SDS_<LANG>_REV<n>.docx"""
    m = re.match(r"CLP_(\w+)_SDS_R\.(\d+)_([A-Z]{2})", src.name)
    if not m:
        return None
    code, rev, lang = m.groups()
    return f"{code}--{slug(product(xml))}__SDS_{lang}_REV{rev}.docx"


def code_of(path):
    """Codice prodotto dal nome file, sia schema EpyX sia schema finale."""
    m = re.match(r"(?:CLP_)?([A-Z]+\d+)[-_]", path.name)
    assert m, f"codice prodotto non deducibile da {path.name}"
    return m.group(1)


def read(path, part):
    with zipfile.ZipFile(path) as z:
        return z.read(part).decode("utf-8")


def rewrite(src, dst, parts):
    tmp = dst.with_suffix(".tmp")
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = parts.get(item.filename)
            zout.writestr(item, data.encode("utf-8") if data else zin.read(item.filename))
    tmp.replace(dst)


def cmd_inspect(paths):
    for p in paths:
        xml = read(p, "word/document.xml")
        print(f"\n### {p.name}")
        print(f"prodotto: {product(xml)}")
        print(f"nuovo nome: {target_name(p, xml)}")
        for *_, t in rows(xml, "1.1", "1.2"):
            if t and t[0].strip().upper() == "UFI":
                print(f"UFI: {t[-1].strip()}")
        for *_, texts in rows(xml, "1.3", "1.4"):
            if texts:
                print(f"  {texts[0].strip()!r}: {texts[-1].strip()!r}")


def cmd_apply(paths, profile, dry, rename, ufi_file=None):
    prof = json.loads(Path(profile).read_text())
    ufis = ufi_map(ufi_file) if ufi_file else {}
    for p in paths:
        with zipfile.ZipFile(p) as z:
            names = z.namelist()
        doc = apply_fixes(edit_1_3(read(p, "word/document.xml"), prof["fields"]))
        if ufis:
            code = code_of(p)
            assert code in ufis, f"UFI mancante per {code}"
            doc = set_ufi(doc, ufis[code])
        parts = {"word/document.xml": doc}
        old_hdr, new_hdr = prof.get("header_from"), prof.get("header_to")
        if new_hdr:
            for n in names:
                if re.fullmatch(r"word/header\d+\.xml", n):
                    parts[n] = read(p, n).replace(f">{old_hdr}</w:t>", f">{new_hdr}</w:t>")
        dst = p.with_name(target_name(p, doc)) if rename and target_name(p, doc) else p
        assert dst == p or not dst.exists(), f"esiste già: {dst.name}"
        print(f"{p.name}  ->  {dst.name}")
        if not dry:
            rewrite(p, dst, parts)
            if dst != p:
                p.unlink()


def self_check():
    row = "<w:tr><w:tc><w:p><w:r><w:t>fax</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>031</w:t></w:r></w:p></w:tc></w:tr>"
    row2 = row.replace("fax", "Provincia").replace("031", "Como")
    xml = f"<w:t>1.3 Fornitore</w:t><w:tbl>{row2}{row}</w:tbl><w:t>1.4 Emergenza</w:t><w:t>Como</w:t>"
    out = edit_1_3(xml, {"Provincia": "Genova", "fax": None})
    assert ">Genova<" in out and "fax" not in out, out
    assert out.endswith("<w:t>Como</w:t>"), "modificato testo fuori da 1.3"
    assert slug("GREEN MARKER GAP (ND)") == "GREEN-MARKER-GAP-ND"
    assert slug("PLANOIL 200XB") == "PLANOIL-200XB"
    assert apply_fixes(f">{FIXES[0][0]}</w:t>") == f">{FIXES[0][1]}</w:t>"
    r11 = row.replace("fax", "Denominazione").replace("031", "PROD X")
    x11 = f"<w:t>1.1 Identificatore</w:t><w:tbl>{r11}</w:tbl><w:t>1.2 Usi</w:t>"
    once = set_ufi(x11, "AAAA-1111")
    assert once.count("<w:tr>") == 2 and ">UFI<" in once and ">AAAA-1111<" in once
    twice = set_ufi(once, "BBBB-2222")
    assert twice.count("<w:tr>") == 2 and ">BBBB-2222<" in twice, "set_ufi non idempotente"
    print("self-check ok")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", nargs="?", choices=["inspect", "apply"])
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--profile")
    ap.add_argument("--ufi", help="elenco-ufi.xlsx: aggiunge/aggiorna la riga UFI in 1.1")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-rename", action="store_true")
    ap.add_argument("--self-check", action="store_true")
    a = ap.parse_args()
    if a.self_check:
        self_check()
    elif a.cmd == "inspect":
        cmd_inspect(a.files)
    elif a.cmd == "apply":
        cmd_apply(a.files, a.profile, a.dry_run, not a.no_rename, a.ufi)
    else:
        ap.print_help(); sys.exit(1)
