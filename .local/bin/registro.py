#!/usr/bin/env python3
"""Da nomi file SDS a righe TSV da incollare in REGISTRO SDS.xlsx (foglio "sds Epy").

    registro.py CC053--FOAM-501__SDS_IT_REV5.docx ...

Convenzione nome file: CODICE--NOME-DEL-PRODOTTO__SDS_LINGUA_REV#
Colonne emesse: A CODICE | B (vuoto) | C DATA emissione | D COMMITTENTE |
                E CLIENTE | F DESCRIZIONE | G LINGUA | H NOTE | I revisione
Il prezzo (colonna J) non viene compilato.

La data esce come numero seriale Excel, non come "gg/mm/aaaa": incollato come
testo il foglio lo leggeva all'americana (03/09/2026 -> 9 marzo). La colonna C
è già formattata data, quindi il seriale si vede subito come data corretta.
"""
import os, re, sys, html, zipfile, shutil, argparse, subprocess, datetime

REGISTRO = os.environ.get("SDS_REGISTRO",
    os.path.expanduser("~/.borsini-drive/SDS-DRIVE/REGISTRO SDS.xlsx"))
SHEET = "xl/worksheets/sheet1.xml"          # "sds Epy"
LINGUE = ["IT", "FR", "EN", "DE", "ES", "PT"]
NOME = re.compile(r"^([A-Z0-9]+)--(.+?)__SDS_([A-Z]{2})_REV(\d+)", re.I)
REV_CODA = re.compile(r"\s*[_ ]?REV\.?\s*\d+\s*$", re.I)
EPOCA = datetime.date(1899, 12, 30)         # giorno 0 del calendario Excel


def seriale(d):
    return str((d - EPOCA).days)


def righe_xlsx(path, sheet):
    """Righe del foglio come dict {colonna: valore}, senza dipendenze esterne."""
    z = zipfile.ZipFile(path)
    ss = []
    if "xl/sharedStrings.xml" in z.namelist():
        s = z.read("xl/sharedStrings.xml").decode("utf-8")
        ss = [html.unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S)))
              for si in re.findall(r"<si>(.*?)</si>", s, re.S)]
    xml = z.read(sheet).decode("utf-8")
    for row in re.findall(r"<row[^>]*>(.*?)</row>", xml, re.S):
        out = {}
        for c in re.finditer(r'<c r="([A-Z]+)\d+"([^>]*)>(.*?)</c>', row, re.S):
            ref, attr, body = c.groups()
            t = re.search(r'\bt="([^"]+)"', attr)
            if t and t.group(1) == "inlineStr":
                val = html.unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", body, re.S)))
            else:
                v = re.search(r"<v>(.*?)</v>", body, re.S)
                val = html.unescape(v.group(1)) if v else ""
                if t and t.group(1) == "s" and val:
                    val = ss[int(val)]
            if val:
                out[ref] = val
        if out:
            yield out


def anagrafica(path):
    """codice -> (committente, cliente, descrizione) dall'ultima riga utile."""
    a = {}
    for r in righe_xlsx(path, SHEET):
        cod = r.get("A", "").strip().upper()
        if not cod or cod == "CODICE":
            continue
        vecchio = a.get(cod, ("", "", ""))
        a[cod] = (r.get("D") or vecchio[0], r.get("E") or vecchio[1],
                  r.get("F") or vecchio[2])
    return a


def descrizione(prodotto, rev, precedente):
    """Descrizione già usata per quel codice, con la revisione aggiornata.

    Se il codice è nuovo si ricava dal nome file: i trattini tornano spazi e un
    codice formula finale (X065) torna fra parentesi, come nel registro.
    """
    if precedente:
        base = REV_CODA.sub("", precedente).strip()
    else:
        base = prodotto.replace("-", " ").upper().strip()
        base = re.sub(r"\s(X\d+)$", r" (\1)", base)
    return f"{base} REV{rev}"


def righe(files, data, nota, anag):
    viste, out = set(), []
    for f in files:
        m = NOME.match(os.path.basename(f))
        if not m:
            print(f"! nome non conforme, saltato: {os.path.basename(f)}", file=sys.stderr)
            continue
        cod, prodotto, lingua, rev = m.group(1).upper(), m.group(2), m.group(3).upper(), m.group(4)
        if (cod, lingua, rev) in viste:      # .docx e .pdf della stessa scheda
            continue
        viste.add((cod, lingua, rev))
        committente, cliente, prec = anag.get(cod, ("", "--", ""))
        out.append((cod, "", data, committente, cliente or "--",
                    descrizione(prodotto, rev, prec), lingua, nota, rev))
    ordine = {l: i for i, l in enumerate(LINGUE)}
    out.sort(key=lambda r: (r[0], ordine.get(r[6], 99)))
    return out


def self_check():
    assert NOME.match("CC053--FOAM-501__SDS_IT_REV5.docx").groups() == \
        ("CC053", "FOAM-501", "IT", "5")
    assert NOME.match("SH032--PROFUMATORE-AMBIENTE-MANDARINO-E-TONKA__SDS_IT_REV2.docx"
                      ).group(2) == "PROFUMATORE-AMBIENTE-MANDARINO-E-TONKA"
    assert NOME.match("nota della spesa.pdf") is None
    # revisione sostituita, non accodata
    assert descrizione("X", "4", "RICARICA PER VANIGLIA REV3") == "RICARICA PER VANIGLIA REV4"
    assert descrizione("X", "3", "DETERGENTE BUCATO MUSCHIO BIANCO (X002) REV.2") == \
        "DETERGENTE BUCATO MUSCHIO BIANCO (X002) REV3"
    assert descrizione("X", "1", "ACIDO-CITRICO-LIQUIDO_REV1") == "ACIDO-CITRICO-LIQUIDO REV1"
    # codice nuovo: dal nome file
    assert descrizione("DETERGENTE-BUCATO-ALGA-X085", "2", "") == \
        "DETERGENTE BUCATO ALGA (X085) REV2"
    assert descrizione("FOAM-501", "5", "") == "FOAM 501 REV5"
    # .docx e .pdf della stessa scheda danno una riga sola
    r = righe(["CC053--FOAM-501__SDS_IT_REV5.docx", "CC053--FOAM-501__SDS_IT_REV5.pdf",
               "CC053--FOAM-501__SDS_DE_REV5.docx", "CC053--FOAM-501__SDS_FR_REV5.docx"],
              seriale(datetime.date(2026, 9, 3)), "AGGIORNAMENTO", {})
    assert [x[6] for x in r] == ["IT", "FR", "DE"], r
    assert r[0] == ("CC053", "", "46268", "", "--", "FOAM 501 REV5", "IT",
                    "AGGIORNAMENTO", "5"), r[0]
    # 1-set-26 nel registro è il seriale 46266: la data non deve slittare
    assert seriale(datetime.date(2026, 9, 1)) == "46266"
    print("self-check ok")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("files", nargs="*")
    p.add_argument("-n", "--nota", default="AGGIORNAMENTO",
                   help="colonna NOTE (default: AGGIORNAMENTO; es. NUOVA, 'CAMBIO NOME')")
    p.add_argument("-d", "--data", help="data emissione gg/mm/aaaa (default: oggi)",
                   type=lambda s: seriale(datetime.datetime.strptime(s, "%d/%m/%Y").date()))
    p.add_argument("--registro", default=REGISTRO)
    p.add_argument("--no-copy", action="store_true", help="non copiare negli appunti")
    p.add_argument("--self-check", action="store_true")
    a = p.parse_args()

    if a.self_check:
        return self_check()
    if not a.files:
        p.error("nessun file")

    try:
        anag = anagrafica(a.registro)
    except OSError as e:
        print(f"! registro non leggibile ({e}), committente e cliente restano vuoti",
              file=sys.stderr)
        anag = {}

    data = a.data or seriale(datetime.date.today())
    tsv = "\n".join("\t".join(r) for r in righe(a.files, data, a.nota.upper(), anag))
    if not tsv:
        sys.exit(1)
    print(tsv)
    if not a.no_copy and shutil.which("wl-copy"):
        subprocess.run(["wl-copy"], input=tsv.encode(), check=False)
        print(f"→ {tsv.count(chr(10)) + 1} righe negli appunti", file=sys.stderr)


if __name__ == "__main__":
    main()
