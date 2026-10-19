import argparse
import asyncio
import json
from datetime import date
from pathlib import Path

from app.core.database import SessionFactory
from app.models.catalog import EducationInstitution, EducationSpecialty


def parsed_date(value: str | None) -> date | None:
    return date.fromisoformat(value) if value else None


async def import_catalog(institutions_path: Path, specialties_path: Path) -> None:
    institutions = json.loads(institutions_path.read_text(encoding="utf-8"))
    specialties = json.loads(specialties_path.read_text(encoding="utf-8"))
    async with SessionFactory() as session:
        for item in institutions:
            record = await session.get(EducationInstitution, item["id"])
            if record is None:
                record = EducationInstitution(id=item["id"], name=item["name"])
                session.add(record)
            record.name = item["name"]
            record.type = item.get("type", "")
            record.locality = item.get("locality", "")
            record.region_id = item.get("regionID", "")
            record.address = item.get("address", "")
            record.website_url = item.get("websiteURL", "")
            record.admissions_phone = item.get("admissionsPhone", "")
            record.admissions_email = item.get("admissionsEmail", "")
            record.admissions_url = item.get("admissionsURL", "")
            record.source_url = item.get("sourceURL", "")
            record.last_verified_at = parsed_date(item.get("lastVerifiedAt"))
            record.needs_verification = item.get("needsVerification", True)
            record.is_active = item.get("isActive", True)
        await session.flush()

        for item in specialties:
            if await session.get(EducationInstitution, item["institutionID"]) is None:
                print(f"Skipped {item['id']}: unknown institution {item['institutionID']}")
                continue
            record = await session.get(EducationSpecialty, item["id"])
            if record is None:
                record = EducationSpecialty(
                    id=item["id"], institution_id=item["institutionID"], name=item["name"]
                )
                session.add(record)
            record.institution_id = item["institutionID"]
            record.name = item["name"]
            record.code = str(item.get("code") or "")
            record.qualification = item.get("qualification") or ""
            record.study_forms = item.get("studyForms") or []
            record.source_url = item.get("sourceURL", "")
            record.last_verified_at = parsed_date(item.get("lastVerifiedAt"))
            record.needs_verification = item.get("needsVerification", True)
            record.is_active = item.get("isActive", True)
        await session.commit()
    print(f"Imported {len(institutions)} institutions and {len(specialties)} specialties")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("institutions", type=Path)
    parser.add_argument("specialties", type=Path)
    args = parser.parse_args()
    asyncio.run(import_catalog(args.institutions, args.specialties))
