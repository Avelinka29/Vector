import argparse
import asyncio
import hashlib
import json
from datetime import date
from pathlib import Path
from typing import Any

from sqlalchemy import select

from app.core.database import SessionFactory
from app.models.catalog import (
    EducationCatalogMetadata,
    EducationImportIssue,
    EducationInstitution,
    EducationInstitutionSpecialty,
    EducationSourceRecord,
    EducationSpecialty,
)


def parsed_date(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def stable_id(prefix: str, value: dict[str, Any]) -> str:
    canonical = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return f"{prefix}_{hashlib.sha256(canonical.encode()).hexdigest()[:48]}"


async def import_catalog(catalog_path: Path) -> None:
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    institutions = payload.get("institutions", [])
    specialties = payload.get("specialties", [])
    links = payload.get("institution_specialties", [])
    source_records = payload.get("source_records", [])
    issues = payload.get("issues", [])

    async with SessionFactory() as session:
        existing_institutions = {
            record.id: record
            for record in (await session.scalars(select(EducationInstitution))).all()
        }
        for item in institutions:
            record = existing_institutions.get(item["id"])
            if record is None:
                record = EducationInstitution(id=item["id"], name=item["name"])
                session.add(record)
                existing_institutions[record.id] = record
            record.name = item["name"]
            record.type = item.get("institution_type") or ""
            record.locality = item.get("region") or ""
            record.region_id = item.get("region") or ""
            record.address = item.get("address") or ""
            record.source_url = item.get("source_url") or ""
            record.source_updated_at = item.get("source_updated_at") or ""
            record.retrieved_at = parsed_date(item.get("retrieved_at"))
            record.identity_status = item.get("identity_status") or ""
            record.last_verified_at = None
            record.needs_verification = True
            record.is_active = True
        existing_specialties = {
            record.id: record
            for record in (await session.scalars(select(EducationSpecialty))).all()
        }
        for item in specialties:
            record = existing_specialties.get(item["id"])
            if record is None:
                record = EducationSpecialty(id=item["id"], name=item["name"])
                session.add(record)
                existing_specialties[record.id] = record
            record.name = item["name"]
            record.code = str(item.get("code") or "")
            record.education_level = item.get("education_level") or ""
            record.needs_verification = True
            record.is_active = True
        # The export contains repeated pairs. Upsert by the pair so reruns and
        # repetitions update one relation instead of creating duplicates.
        existing_links = {
            (record.institution_id, record.specialty_id): record
            for record in (
                await session.scalars(select(EducationInstitutionSpecialty))
            ).all()
        }
        for item in links:
            key = (item["institution_id"], item["specialty_id"])
            if key[0] not in existing_institutions:
                print(f"Skipped link: unknown institution {key[0]}")
                continue
            if key[1] not in existing_specialties:
                print(f"Skipped link: unknown specialty {key[1]}")
                continue
            record = existing_links.get(key)
            if record is None:
                record = EducationInstitutionSpecialty(
                    institution_id=key[0], specialty_id=key[1]
                )
                session.add(record)
                existing_links[key] = record
            record.qualification = item.get("qualification") or ""
            record.source_label = item.get("source_label") or ""
            record.source_url = item.get("source_url") or ""
            record.extraction_status = item.get("extraction_status") or ""
            record.source_details = item.get("source_details") or ""
            record.needs_verification = True
            record.is_active = True

        existing_source_records = {
            record.id: record
            for record in (await session.scalars(select(EducationSourceRecord))).all()
        }
        for item in source_records:
            record_id = stable_id("source", item)
            record = existing_source_records.get(record_id)
            if record is None:
                record = EducationSourceRecord(id=record_id, institution_id=item["institution_id"])
                session.add(record)
                existing_source_records[record_id] = record
            record.institution_id = item["institution_id"]
            record.source_url = item.get("source_url") or ""
            record.source_updated_at = item.get("source_updated_at") or ""
            record.fields = item.get("fields") or {}
            record.extracted_rows = item.get("extracted_rows") or []

        existing_issues = {
            record.id: record
            for record in (await session.scalars(select(EducationImportIssue))).all()
        }
        for item in issues:
            record_id = stable_id("issue", item)
            record = existing_issues.get(record_id)
            if record is None:
                record = EducationImportIssue(id=record_id, institution_id=item["institution_id"])
                session.add(record)
                existing_issues[record_id] = record
            record.institution_id = item["institution_id"]
            record.error = item.get("error") or ""
            record.source_url = item.get("source_url") or ""

        existing_metadata = {
            record.key: record
            for record in (await session.scalars(select(EducationCatalogMetadata))).all()
        }
        for key, value in (payload.get("metadata") or {}).items():
            record = existing_metadata.get(key)
            if record is None:
                record = EducationCatalogMetadata(key=key, value=value)
                session.add(record)
                existing_metadata[key] = record
            else:
                record.value = value

        await session.commit()

    print(
        "Imported "
        f"{len(institutions)} institutions, {len(specialties)} specialties, "
        f"{len(links)} source links, {len(source_records)} source records, "
        f"and {len(issues)} issues"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import belarus_education.json idempotently")
    parser.add_argument("catalog", type=Path)
    args = parser.parse_args()
    asyncio.run(import_catalog(args.catalog))
