"""Apply individually reviewed contact fields; do not certify the whole catalog row."""
import argparse
import asyncio
from datetime import date
import json
from pathlib import Path
from urllib.parse import urlsplit

from email_validator import validate_email

from app.core.database import SessionFactory
from app.models.catalog import EducationCatalogMetadata, EducationInstitution

FIELDS = {'address': 500, 'admissions_phone': 100, 'admissions_email': 320,
          'website_url': 1000, 'admissions_url': 1000,
          'image_url': 1000, 'image_source_url': 1000}


def validate_rows(rows):
    if not isinstance(rows, list):
        raise ValueError('Expected a list of reviewed contact groups')
    seen = set()
    for row in rows:
        checked_at = date.fromisoformat(row['checked_at'])
        if checked_at > date.today():
            raise ValueError('Verification date cannot be in the future')
        source = urlsplit(row['source_url'])
        if source.scheme != 'https' or not source.hostname:
            raise ValueError('HTTPS source required')
        if not row['institution_ids'] or not row['fields']:
            raise ValueError('Institution IDs and fields are required')
        for field, value in row['fields'].items():
            if field not in FIELDS or not isinstance(value, str) or not value.strip() or len(value) > FIELDS[field]:
                raise ValueError('Invalid contact field')
            if field == 'admissions_email':
                validate_email(value, check_deliverability=False)
            if field.endswith('_url'):
                parsed = urlsplit(value)
                if parsed.scheme not in ('http', 'https') or not parsed.hostname:
                    raise ValueError('Invalid contact URL')
            for identifier in row['institution_ids']:
                key = (identifier, field)
                if key in seen:
                    raise ValueError('Duplicate institution field in reviewed data')
                seen.add(key)


async def apply(path: Path, *, commit: bool = False):
    rows = json.loads(path.read_text())
    validate_rows(rows)
    changes = []
    async with SessionFactory() as session:
        for row in rows:
            for identifier in row['institution_ids']:
                institution = await session.get(EducationInstitution, identifier)
                if institution is None:
                    raise ValueError('Unknown institution: ' + identifier)
                key = 'verified_contacts:' + identifier
                metadata = await session.get(EducationCatalogMetadata, key)
                evidence = dict(metadata.value) if metadata else {}
                for field, value in row['fields'].items():
                    prior = evidence.get(field, {})
                    if (getattr(institution, field) == value and prior.get('value') == value
                            and prior.get('source_url') == row['source_url']
                            and prior.get('checked_at') == row['checked_at']):
                        continue
                    changes.append({'institution_id': identifier, 'field': field,
                                    'previous_value': getattr(institution, field), 'value': value})
                    evidence[field] = {'value': value, 'previous_value': getattr(institution, field),
                                       'source_url': row['source_url'], 'checked_at': row['checked_at']}
                    setattr(institution, field, value)
                if metadata:
                    metadata.value = evidence
                else:
                    session.add(EducationCatalogMetadata(key=key, value=evidence))
        if commit:
            await session.commit()
        else:
            await session.rollback()
    print(json.dumps({'applied': commit, 'field_changes': len(changes), 'changes': changes}, ensure_ascii=False))
    return changes


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--apply', action='store_true', help='Commit the reviewed changes; default is dry-run')
    args = parser.parse_args()
    asyncio.run(apply(args.path, commit=args.apply))
