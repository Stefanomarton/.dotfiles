---
name: sds-rebrand
description: Rinomina schede di sicurezza (.docx) esportate da EpyX secondo lo schema CODICE--PRODOTTO__SDS_LINGUA_REVn, sostituisce l'anagrafica del fornitore in sezione 1.3, inserisce il codice UFI in sezione 1.1 e applica le correzioni standard di testo. Usare quando l'utente chiede di rinominare/ribrandizzare SDS, cambiare l'anagrafica dentro le schede, o sistemare gli export EpyX.
---

# SDS rebrand (export EpyX)

Tre operazioni, un solo script: `rebrand.py` (stessa cartella di questo file).

## 1. Ispeziona

```bash
python3 SKILL_DIR/rebrand.py inspect "CLP_CMP002_SDS_R.1_IT (it).docx"
```

Stampa nome prodotto (sez. 1.1), nome file di destinazione e tutte le coppie
etichetta/valore della sezione 1.3 così come sono nel file. **Le etichette del
profilo si copiano da qui**, non si indovinano: cambiano con la lingua della scheda.

## 2. Profilo fornitore

Un JSON in `profiles/`. `profiles/chemplane-italia.json` è l'esempio da copiare.

```json
{
  "header_from": "<ragione sociale attuale, come appare nell'header>",
  "header_to":   "<ragione sociale nuova per l'header>",
  "fields": {
    "Ragione Sociale": "...",
    "fax": null,
    "e-mail": "..."
  }
}
```

- Le chiavi di `fields` sono **prefissi** dell'etichetta (`"e-mail"` intercetta
  `"e-mail della persona competente, responsabile della scheda dati di sicurezza"`).
- Valore `null` = **elimina l'intera riga** dalla tabella (non lasciarla vuota).
- Se un'etichetta del profilo non esiste nel file, lo script si ferma con errore:
  è voluto, significa profilo e file non combaciano.

## 3. Applica

```bash
python3 SKILL_DIR/rebrand.py apply --profile profiles/chemplane-italia.json --dry-run *.docx
python3 SKILL_DIR/rebrand.py apply --profile profiles/chemplane-italia.json \
  --ufi "…/elenco-ufi.xlsx" *.docx
```

Fa, in un colpo solo: anagrafica 1.3 → header (tutti gli `headerN.xml`) → UFI in
1.1 → correzioni standard → rinomina. `--no-rename` per modificare senza
rinominare. L'originale viene rimosso solo se il file rinominato è stato scritto.

**Tutto è idempotente**: rilanciare su file già sistemati non duplica nulla
(la riga UFI viene aggiornata, non riaggiunta; una riga già eliminata non è un
errore). Dopo una ristampa da EpyX si rilancia lo stesso comando.

## 4. UFI (opzionale, `--ufi`)

Aggiunge — o aggiorna — una riga `UFI` subito sotto `Denominazione` in sezione 1.1.

L'`.xlsx` viene letto direttamente (zipfile stdlib, niente openpyxl né
LibreOffice). Servono due colonne intestate **`Codice prodotto`** e **`UFI`**
nella prima sheet; il codice prodotto viene ricavato dal nome del file
(`CMP002--…` o `CLP_CMP002_…`). Se manca l'UFI per un codice lo script si ferma.

## Schema di rinomina

`CLP_<CODICE>_SDS_R.<n>_<LINGUA> (…).docx` → `<CODICE>--<PRODOTTO>__SDS_<LINGUA>_REV<n>.docx`

Il prodotto viene dalla sezione 1.1, maiuscolo, non alfanumerici → `-`
(`GREEN MARKER GAP (ND)` → `GREEN-MARKER-GAP-ND`). Se il nome di partenza non
segue lo schema EpyX, la rinomina viene saltata: rinominare a mano.

## Correzioni standard

Sono nella lista `FIXES` in cima a `rebrand.py`, una riga per correzione, IT+EN.
Si applicano solo se la frase esiste. Attualmente:

- 15.2 — `...per la miscela / per le sostanze indicate in sezione 3.` → `...per la miscela.`

Per aggiungerne una: appendere la coppia `(vecchio, nuovo)` a `FIXES`. Il testo
deve corrispondere a un intero run `<w:t>`: verificare prima con
`unzip -p FILE word/document.xml | grep -o '<w:t[^>]*>[^<]*frammento[^<]*</w:t>'`.

## Verifica

```bash
python3 SKILL_DIR/rebrand.py --self-check      # logica di tabella/slug/fix
pandoc -t plain --wrap=none FILE.docx | sed -n '/1.3 /,/1.4 /p'   # risultato reale
```
