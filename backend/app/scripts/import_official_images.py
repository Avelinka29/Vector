"""Download institution card images advertised by official institution websites."""
import argparse
import asyncio
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urljoin, urlsplit

import httpx
from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionFactory
from app.models.catalog import EducationInstitution

IMAGE_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
MAX_IMAGE_BYTES = 8 * 1024 * 1024


class ImageMetadataParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.candidates = []

    def handle_starttag(self, tag, attrs):
        values = {key.lower(): value for key, value in attrs if key and value}
        if tag.lower() == "meta":
            key = (values.get("property") or values.get("name") or "").lower()
            if key in {"og:image", "og:image:url", "twitter:image", "twitter:image:src"}:
                self.candidates.append(values.get("content", ""))
        elif tag.lower() == "link" and values.get("rel", "").lower() == "image_src":
            self.candidates.append(values.get("href", ""))
        elif tag.lower() == "img":
            source = values.get("src") or values.get("data-src") or values.get("data-lazy-src") or ""
            description = " ".join((values.get("alt", ""), values.get("class", ""), source)).lower()
            try:
                width = int(re.sub(r"\D", "", values.get("width", "")) or 0)
            except ValueError:
                width = 0
            positive = any(word in description for word in (
                "building", "campus", "универс", "колледж", "училищ", "здание", "slide", "hero"
            ))
            negative = any(word in description for word in ("logo", "icon", "герб", "avatar", "counter"))
            if source and not negative and (width >= 400 or positive):
                self.candidates.append(source)


def safe_name(identifier: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]", "_", identifier)[:180]


async def download_one(client, semaphore, record, directory):
    if not record.website_url or record.image_url:
        return {"id": record.id, "status": "skipped"}
    async with semaphore:
        try:
            page = await client.get(record.website_url)
            page.raise_for_status()
            if "text/html" not in page.headers.get("content-type", ""):
                return {"id": record.id, "status": "no_html"}
            parser = ImageMetadataParser()
            parser.feed(page.text[:2_000_000])
            official_host = urlsplit(str(page.url)).hostname
            for candidate in parser.candidates[:8]:
                image_source = urljoin(str(page.url), candidate.strip())
                if urlsplit(image_source).scheme not in {"http", "https"}:
                    continue
                image = await client.get(image_source)
                if image.status_code != 200:
                    continue
                content_type = image.headers.get("content-type", "").split(";", 1)[0].lower()
                if (content_type not in IMAGE_TYPES or len(image.content) < 20_000
                        or len(image.content) > MAX_IMAGE_BYTES):
                    continue
                filename = safe_name(record.id) + IMAGE_TYPES[content_type]
                (directory / filename).write_bytes(image.content)
                return {"id": record.id, "status": "downloaded", "image_url": f"/catalog-images/{filename}",
                        "image_source_url": image_source, "page_url": str(page.url),
                        "official_host": official_host, "bytes": len(image.content)}
            return {"id": record.id, "status": "no_image_metadata"}
        except (httpx.HTTPError, UnicodeError, ValueError) as error:
            return {"id": record.id, "status": "error", "error": type(error).__name__}


async def run(*, commit: bool, limit: int | None):
    directory = Path(settings.catalog_image_directory)
    directory.mkdir(parents=True, exist_ok=True)
    async with SessionFactory() as session:
        query = select(EducationInstitution).where(EducationInstitution.is_active.is_(True)).order_by(EducationInstitution.id)
        records = list((await session.scalars(query)).all())
        if limit:
            records = records[:limit]
        timeout = httpx.Timeout(15, connect=8)
        headers = {"User-Agent": "VECTOR education catalog image importer/1.0"}
        async with httpx.AsyncClient(timeout=timeout, headers=headers, follow_redirects=True,
                                     verify=False, max_redirects=5) as client:
            semaphore = asyncio.Semaphore(20)
            results = await asyncio.gather(*(download_one(client, semaphore, record, directory)
                                             for record in records))
        by_id = {record.id: record for record in records}
        for result in results:
            if result["status"] == "downloaded":
                record = by_id[result["id"]]
                record.image_url = result["image_url"]
                record.image_source_url = result["image_source_url"]
        if commit:
            await session.commit()
        else:
            await session.rollback()
            for result in results:
                if result["status"] == "downloaded":
                    (directory / Path(result["image_url"]).name).unlink(missing_ok=True)
    summary = {}
    for result in results:
        summary[result["status"]] = summary.get(result["status"], 0) + 1
    print(json.dumps({"applied": commit, "summary": summary, "results": results}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--limit", type=int)
    arguments = parser.parse_args()
    asyncio.run(run(commit=arguments.apply, limit=arguments.limit))
