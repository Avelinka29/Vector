"""Convert reviewed official GRSU HTML tables and a catalog mapping to import JSON.

No fuzzy matching: ambiguous codes and nonnumeric results are reported, never guessed.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date
from decimal import Decimal, InvalidOperation
from html.parser import HTMLParser
import json
from pathlib import Path
import re

SOURCES = {
    'day': 'https://abit.grsu.by/view/272-kategorii-ru/vysshee/itogi-priema-proshlykh-let/2025/1794-prokhodnoj-ball-po-spetsialnostyam-2026.html',
    'parttime': 'https://abit.grsu.by/view/272-kategorii-ru/vysshee/itogi-priema-proshlykh-let/2025/1795-2026-prokhodnye-bally-zaochnaya.html',
}


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self.row, self.cell = [], [], None

    def handle_starttag(self, tag, attrs):
        if tag == 'tr': self.row = []
        if tag in {'td', 'th'}: self.cell = ''

    def handle_data(self, data):
        if self.cell is not None: self.cell += data

    def handle_endtag(self, tag):
        if tag in {'td', 'th'} and self.cell is not None:
            self.row.append(' '.join(self.cell.split()))
            self.cell = None
        if tag == 'tr' and self.row: self.rows.append(self.row)


def convert(html: str, catalog: list[dict], kind: str):
    parser = TableParser()
    parser.feed(html)
    rows = [r for r in parser.rows if len(r) >= 4 and re.fullmatch(r'\d-\d{2}-\d{4}-\d{2}', r[1])]
    codes = Counter(r[1] for r in rows)
    by_code = defaultdict(list)
    for item in catalog: by_code[item['code']].append(item)
    output, skipped = [], []
    columns = [('дневная', 'budget'), ('дневная', 'paid')] if kind == 'day' else [
        ('заочная', 'budget'), ('заочная', 'paid'),
        ('заочная сокращённая', 'budget'), ('заочная сокращённая', 'paid')]
    for row in rows:
        code = row[1]
        if codes[code] != 1 or len(by_code[code]) != 1:
            skipped.append({'code': code, 'reason': 'ambiguous_or_missing_catalog_code'})
            continue
        if len(row) != 2 + len(columns):
            raise ValueError('Unexpected table columns')
        for value, (form, funding) in zip(row[2:], columns):
            if not value or value in {'—', '–', '-'}: continue
            try:
                score = Decimal(value.replace(',', '.'))
            except InvalidOperation:
                skipped.append({'code': code, 'reason': 'nonnumeric_result', 'value': value})
                continue
            if not score.is_finite() or not 0 <= score <= 400:
                raise ValueError('Invalid score')
            output.append(dict(institution_id='abiturient_e9f0edc100ad7c',
                               specialty_id=by_code[code][0]['id'], admission_year=2026,
                               study_form=form, funding_type=funding, score=float(score),
                               source_url=SOURCES[kind], verified_at=date.today().isoformat()))
    return output, skipped


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('day_html', type=Path)
    parser.add_argument('parttime_html', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text())
    result, report = [], {}
    for kind, path in [('day', args.day_html), ('parttime', args.parttime_html)]:
        rows, skipped = convert(path.read_text(), catalog, kind)
        result.extend(rows)
        report[kind] = {'importable': len(rows), 'skipped': skipped, 'source_url': SOURCES[kind]}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    args.output.with_suffix('.report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: {'importable': v['importable'], 'skipped': len(v['skipped'])} for k,v in report.items()}))
