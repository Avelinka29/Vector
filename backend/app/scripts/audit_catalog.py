"""Export remaining catalog gaps without modifying or certifying any record."""
import argparse
import asyncio
import csv
import json
import re
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

from sqlalchemy import select

from app.core.database import SessionFactory
from app.models.catalog import EducationImportIssue, EducationInstitution, EducationSpecialty


async def audit(output: Path):
    fields = ('address', 'admissions_phone', 'admissions_email', 'admissions_url', 'website_url', 'image_url')
    missing = Counter()
    duplicates = defaultdict(list)
    rows = []
    async with SessionFactory() as session:
        institutions = list((await session.scalars(select(EducationInstitution)
            .where(EducationInstitution.is_active.is_(True)).order_by(EducationInstitution.id))).all())
        specialties = list((await session.scalars(select(EducationSpecialty)
            .where(EducationSpecialty.is_active.is_(True)).order_by(EducationSpecialty.id))).all())
        issues = list((await session.scalars(select(EducationImportIssue))).all())
        for item in institutions:
            gaps = [field for field in fields if not (getattr(item, field) or '').strip()]
            missing.update(gaps)
            if gaps:
                rows.append([item.id, item.name, ';'.join(gaps), item.source_url])
            normalized = re.sub(r'[^\w]+', ' ', item.name.casefold().replace('ё', 'е')).strip()
            duplicates[normalized].append(item.id)
        report = {
            'checked_at': date.today().isoformat(),
            'active_institutions': len(institutions), 'active_specialties': len(specialties),
            'missing_contacts': dict(missing),
            'institutions_requiring_verification': sum(item.needs_verification for item in institutions),
            'institutions_with_verified_source_date': sum(item.last_verified_at is not None for item in institutions),
            'institutions_without_deduplicated_identity': sum(
                item.identity_status == 'source_entry_not_deduplicated' for item in institutions
            ),
            'specialties_without_code': [{'id': item.id, 'name': item.name, 'source_url': item.source_url}
                                         for item in specialties if not item.code.strip()],
            'possible_duplicate_institutions': {name: ids for name, ids in duplicates.items() if len(ids) > 1},
            'import_issues': [{'institution_id': item.institution_id, 'error': item.error,
                              'source_url': item.source_url} for item in issues],
        }
    output.mkdir(parents=True, exist_ok=True)
    (output / 'catalog-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    with (output / 'missing-contacts.csv').open('w', newline='') as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(['id', 'name', 'missing_fields', 'source_url'])
        writer.writerows(rows)
    print(json.dumps({key: report[key] for key in ['checked_at', 'active_institutions',
                     'active_specialties', 'missing_contacts']}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    asyncio.run(audit(parser.parse_args().output))
