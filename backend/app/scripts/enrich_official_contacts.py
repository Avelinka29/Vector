"""Fill missing admissions links and dedicated admissions emails from official websites."""
import argparse
import asyncio
from html.parser import HTMLParser
import json
from urllib.parse import unquote, urljoin, urlsplit

import httpx
from sqlalchemy import select

from app.core.database import SessionFactory
from app.models.catalog import EducationInstitution

ADMISSIONS_WORDS = ("абитури", "прием", "приём", "postup", "abitur", "admission", "entrants")


class OfficialContactsParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.current_href = ""
        self.current_text = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self.current_href = dict(attrs).get("href", "") or ""
            self.current_text = []

    def handle_data(self, data):
        if self.current_href:
            self.current_text.append(data)

    def handle_endtag(self, tag):
        if tag.lower() == "a" and self.current_href:
            self.links.append((self.current_href.strip(), " ".join(self.current_text).strip()))
            self.current_href = ""
            self.current_text = []


def extract_contacts(html: str, page_url: str) -> dict[str, str]:
    parser = OfficialContactsParser()
    parser.feed(html[:2_000_000])
    result = {}
    for href, text in parser.links:
        decoded = unquote(href).lower()
        context = (decoded + " " + text.lower())
        if href.lower().startswith("mailto:"):
            email = unquote(href[7:].split("?", 1)[0]).strip()
            local = email.split("@", 1)[0].lower()
            if "@" in email and any(word in local for word in ("abitur", "priem", "admission")):
                result.setdefault("admissions_email", email)
        elif any(word in context for word in ADMISSIONS_WORDS):
            candidate = urljoin(page_url, href)
            if urlsplit(candidate).scheme in {"http", "https"}:
                result.setdefault("admissions_url", candidate)
    return result


async def fetch_one(client, semaphore, record):
    if not record.website_url or (record.admissions_url and record.admissions_email):
        return record.id, {}, "skipped"
    async with semaphore:
        try:
            response = await client.get(record.website_url)
            response.raise_for_status()
            if "text/html" not in response.headers.get("content-type", ""):
                return record.id, {}, "no_html"
            fields = extract_contacts(response.text, str(response.url))
            if record.admissions_url:
                fields.pop("admissions_url", None)
            if record.admissions_email:
                fields.pop("admissions_email", None)
            return record.id, fields, "found" if fields else "not_found"
        except (httpx.HTTPError, UnicodeError, ValueError) as error:
            return record.id, {}, "error:" + type(error).__name__


async def run(*, commit: bool):
    async with SessionFactory() as session:
        records = list((await session.scalars(select(EducationInstitution).where(
            EducationInstitution.is_active.is_(True)).order_by(EducationInstitution.id))).all())
        timeout = httpx.Timeout(15, connect=8)
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True, verify=False,
                                     headers={"User-Agent": "VECTOR education catalog importer/1.0"}) as client:
            semaphore = asyncio.Semaphore(20)
            results = await asyncio.gather(*(fetch_one(client, semaphore, record) for record in records))
        records_by_id = {record.id: record for record in records}
        changes = []
        summary = {}
        for identifier, fields, status in results:
            summary[status] = summary.get(status, 0) + 1
            record = records_by_id[identifier]
            for field, value in fields.items():
                setattr(record, field, value)
                changes.append({"institution_id": identifier, "field": field, "value": value,
                                "source_url": record.website_url})
        if commit:
            await session.commit()
        else:
            await session.rollback()
    print(json.dumps({"applied": commit, "summary": summary, "changes": changes}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    arguments = parser.parse_args()
    asyncio.run(run(commit=arguments.apply))
