"""Repeatable import of verified passing scores from a reviewed JSON file.

Run inside the API container:
    python -m app.scripts.import_passing_scores /data/passing_scores.json
"""

import argparse
import asyncio
import json
from datetime import date
from pathlib import Path

from sqlalchemy.dialects.postgresql import insert

from app.core.database import session_factory
from app.models.catalog import EducationPassingScore


def validated_rows(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError("Корень JSON должен быть массивом")
    rows = []
    for index, item in enumerate(payload, start=1):
        required = {"institution_id", "specialty_id", "admission_year", "score", "source_url", "verified_at"}
        missing = required - item.keys()
        if missing:
            raise ValueError(f"Строка {index}: отсутствуют {', '.join(sorted(missing))}")
        if not str(item["source_url"]).startswith("https://"):
            raise ValueError(f"Строка {index}: источник должен использовать HTTPS")
        score = int(item["score"])
        if score < 0 or score > 400:
            raise ValueError(f"Строка {index}: балл должен быть от 0 до 400")
        verified_at = date.fromisoformat(str(item["verified_at"]))
        study_form = str(item.get("study_form", ""))
        funding_type = str(item.get("funding_type", "budget"))
        identity = "|".join([
            str(item["institution_id"]), str(item["specialty_id"]),
            str(item["admission_year"]), study_form, funding_type,
        ])
        rows.append({
            "id": identity[:240],
            "institution_id": str(item["institution_id"]),
            "specialty_id": str(item["specialty_id"]),
            "admission_year": int(item["admission_year"]),
            "study_form": study_form,
            "funding_type": funding_type,
            "score": score,
            "source_url": str(item["source_url"]),
            "verified_at": verified_at,
        })
    return rows


async def import_rows(rows: list[dict]) -> None:
    async with session_factory() as session:
        statement = insert(EducationPassingScore).values(rows)
        statement = statement.on_conflict_do_update(
            constraint="education_passing_scores_identity_key",
            set_={
                "score": statement.excluded.score,
                "source_url": statement.excluded.source_url,
                "verified_at": statement.excluded.verified_at,
            },
        )
        await session.execute(statement)
        await session.commit()


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    arguments = parser.parse_args()
    rows = validated_rows(arguments.path)
    if rows:
        await import_rows(rows)
    print(f"Импортировано или обновлено: {len(rows)}")


if __name__ == "__main__":
    asyncio.run(main())
