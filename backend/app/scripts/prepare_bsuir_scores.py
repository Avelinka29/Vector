"""Prepare reviewed 2026 BSUIR scores; never conflate faculties or half-passing scores."""
import argparse
from collections import Counter, defaultdict
from datetime import date
import json
from pathlib import Path
import re

from app.scripts.prepare_grsu_scores import TableParser

SOURCE = 'https://abitur.bsuir.by/prokhodnye-bally-2026-goda'
INSTITUTION = 'abiturient_d0e47fee005fc7'


def convert(html, catalog):
    if '2026' not in html:
        raise ValueError('Expected the reviewed 2026 page')
    parser = TableParser()
    parser.feed(html)
    rows = [(r, re.search(r'\b\d-\d{2}-\d{4}-\d{2}\b', r[1])) for r in parser.rows if len(r) == 11]
    rows = [(r, match.group()) for r, match in rows if match]
    if not rows:
        raise ValueError('No expected 11-column score rows')
    counts = Counter(code for _, code in rows)
    by_code = defaultdict(list)
    for item in catalog:
        if item['institution_id'] == INSTITUTION:
            by_code[item['code']].append(item)
    columns = [('дневная', 'budget'), ('дневная', 'paid'), ('заочная', 'budget'),
               ('заочная', 'paid'), ('заочная сокращённая', 'budget'),
               ('заочная сокращённая', 'paid'), ('дистанционная', 'budget'), ('дистанционная', 'paid')]
    output, skipped = [], []
    for row, code in rows:
        if counts[code] != 1 or len(by_code[code]) != 1:
            skipped.append(dict(code=code, faculty=row[0], reason='ambiguous_faculty_or_catalog_code'))
            continue
        for value, (form, funding) in zip(row[3:], columns):
            if not value or value in {'-', '—'}:
                continue
            if not re.fullmatch(r'\d{1,3}', value):
                skipped.append(dict(code=code, form=form, funding=funding, value=value,
                                    reason='half_passing_or_non_numeric_result'))
                continue
            score = int(value)
            if not 0 <= score <= 400:
                raise ValueError('Score out of range')
            output.append(dict(institution_id=INSTITUTION, specialty_id=by_code[code][0]['id'],
                               admission_year=2026, study_form=form, funding_type=funding,
                               score=score, source_url=SOURCE, verified_at=date.today().isoformat()))
    return output, skipped


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html',type=Path)
    parser.add_argument('catalog',type=Path)
    parser.add_argument('output',type=Path)
    args = parser.parse_args()
    rows, skipped = convert(args.html.read_text(),json.loads(args.catalog.read_text()))
    args.output.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    args.output.with_suffix('.report.json').write_text(json.dumps(dict(source_url=SOURCE,
        imported=len(rows),skipped=skipped,excluded='Targeted competition and half-passing scores are not ordinary passing scores'),ensure_ascii=False,indent=2)+'\n')
    print('Prepared:',len(rows),'Skipped:',len(skipped))
