"""Converts Legally-Talk-Law-Book.xlsx into assets/data/law_book.json for the
Partner App's Law Book (Law points → Old → New sections).

Run from the partner folder after editing the Excel file:
    python tool/law_book_to_json.py
Needs: pip install openpyxl
"""
import json
import pathlib
import openpyxl

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'Legally-Talk-Law-Book.xlsx'
TARGET = ROOT / 'assets' / 'data' / 'law_book.json'

# Sheet → (code id, old act, new act)
TABLES = {
    'IPC to BNS': ('IPC', 'IPC 1860', 'BNS 2023'),
    'CrPC to BNSS': ('CrPC', 'CrPC 1973', 'BNSS 2023'),
    'Evidence to BSA': ('IEA', 'Evidence Act 1872', 'BSA 2023'),
}
IMPORTANT_CODES = {'IPC': 'IPC', 'CrP': 'CrPC', 'Evi': 'IEA'}


def text(v):
    return '' if v is None else str(v).strip()


def main():
    wb = openpyxl.load_workbook(SOURCE, read_only=True, data_only=True)

    important = set()
    for row in wb['Important Sections'].iter_rows(values_only=True):
        code = IMPORTANT_CODES.get(text(row[0] if row else '')[:3])
        if code and row[1]:
            important.add((code, text(row[1])))

    rows = []
    for sheet, (code, _, _) in TABLES.items():
        for r in list(wb[sheet].iter_rows(values_only=True))[3:]:
            if not r or r[0] is None or not text(r[0]).isdigit():
                continue
            old, old_title, new, new_text, status, chapter = (text(c) for c in r[1:7])
            if not (old or new):
                continue
            status = status if status in ('Changed', 'New', 'Deleted') else 'Same'
            rows.append({
                'c': code, 'o': old, 'ot': old_title, 'n': new, 'nt': new_text, 's': status, 'ch': chapter,
                **({'i': 1} if (code, old) in important else {}),
            })

    data = {
        'codes': [{'id': c, 'from': f, 'to': t} for c, f, t in TABLES.values()],
        'source': 'National Crime Records Bureau (NCRB) Sankalan – Corresponding Section Tables',
        'note': 'One old section can map to several new sub-sections. Offences committed before 1 July 2024 are still tried under the old codes. Reference aid only — check the official gazette text before advising a client.',
        'rows': rows,
    }
    TARGET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'{len(rows)} rows ({sum(1 for r in rows if r.get("i"))} important) -> {TARGET}')


if __name__ == '__main__':
    main()
