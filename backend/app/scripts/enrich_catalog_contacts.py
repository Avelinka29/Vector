"""Fill missing contacts from preserved source records without claiming verification.

Default is a dry run. --apply writes only empty fields and records field provenance.
Existing curated values and verification flags are never overwritten.
"""
import argparse
import asyncio
import json
import re
from datetime import UTC, datetime
from urllib.parse import urlsplit

from sqlalchemy import select

from app.core.database import SessionFactory
from app.models.catalog import EducationCatalogMetadata, EducationInstitution, EducationSourceRecord


EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE = re.compile(r"(?:\+375|8)\s*\(?\d{2,5}\)?[\d ()-]{4,21}\d")


def extract(fields: dict) -> dict[str, str]:
    result = {}
    address = str(fields.get("Адрес") or "").strip()
    if address and len(address) <= 500:
        result["address"] = address
    text = str(fields.get("Контакная информация") or fields.get("Контактная информация") or "")
    site = re.search(r"(?:web[ -]?сайт|сайт)\s*:\s*(\S+)", text, re.I)
    if site:
        value = site.group(1).strip(' ,;')
        if not value.startswith(('http://', 'https://')):
            value = 'https://' + value
        parsed = urlsplit(value)
        if parsed.scheme in {'http', 'https'} and parsed.hostname and '.' in parsed.hostname and not parsed.username:
            result['website_url'] = value[:1000]
    # Do not mistake a director's office or fax for the admissions committee.
    phones = []
    for segment in re.split(r'[,;\n]', text):
        if re.search(r'при[её]мн\w*\s+комисс', segment, re.I):
            phones.extend(match.group().strip() for match in PHONE.finditer(segment))
    if phones:
        value = ', '.join(dict.fromkeys(phones))
        if len(value) <= 100:
            result['admissions_phone'] = value
    # Generic institutional mailboxes remain in source records, not admissions_email.
    for value in EMAIL.findall(text):
        if re.match(r'(?:abitur|priem|admission|pk(?:[._-]|@))', value, re.I):
            result['admissions_email'] = value
            break
    return result


async def enrich(apply: bool):
    async with SessionFactory() as session:
        institutions = {x.id: x for x in (await session.scalars(select(EducationInstitution))).all()}
        sources = (await session.scalars(select(EducationSourceRecord).order_by(EducationSourceRecord.id))).all()
        changes = []
        for source in sources:
            record = institutions.get(source.institution_id)
            if record is None:
                continue
            for field, value in extract(source.fields or {}).items():
                if getattr(record, field):
                    continue
                setattr(record, field, value)
                changes.append({'institution_id': record.id, 'field': field, 'value': value,
                                'source_url': source.source_url, 'source_record_id': source.id,
                                'source_updated_at': source.source_updated_at,
                                'status': 'extracted_not_verified'})
        counts = {field: sum(x['field'] == field for x in changes) for field in sorted({x['field'] for x in changes})}
        if apply and changes:
            key = 'contact_enrichment_history'
            metadata = await session.get(EducationCatalogMetadata, key)
            history = list(metadata.value) if metadata else []
            history.append({'at': datetime.now(UTC).isoformat(), 'changes': changes})
            if metadata:
                metadata.value = history
            else:
                session.add(EducationCatalogMetadata(key=key, value=history))
            await session.commit()
        else:
            await session.rollback()
        print(json.dumps({'applied': apply, 'institutions': len({x['institution_id'] for x in changes}), 'fields': counts}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    asyncio.run(enrich(parser.parse_args().apply))
