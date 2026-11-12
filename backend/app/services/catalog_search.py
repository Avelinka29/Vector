"""Shared institution lookup for the public catalog and the assistant."""
import re

from sqlalchemy import and_, case, func, or_

from app.models.catalog import EducationInstitution


# Match whole tokens: БГУ must never also match БГУИР.
INSTITUTION_ALIASES = {
    "гргу": ("гродненский", "государственный", "университет", "купалы"),
    "grsu": ("гродненский", "государственный", "университет", "купалы"),
    "бгуир": ("белорусский", "информатики", "радиоэлектроники"),
    "бгу": ("белорусский государственный университет",),
    "бнту": ("белорусский национальный технический",),
    "бгэу": ("белорусский государственный экономический",),
    "бгаа": ("белорусская государственная академия авиации",),
}

STOP_WORDS = set("какие какой какая какие есть покажи пожалуйста мне помоги подобрать подбери "
                 "варианты вариант направления направление специальности специальность учреждения "
                 "учреждение университет университеты обучение учиться поступление поступить "
                 "источники источник записи справочника справочник данные информацию расскажи "
                 "сравни для про это там них еще ещё можно хочу хочу ли и или где что как а в на по".split())


def words(text: str) -> list[str]:
    return re.findall(r"[\w-]+", text.casefold().replace("ё", "е"))


def aliases_in(text: str) -> list[str]:
    return list(dict.fromkeys(word for word in words(text) if word in INSTITUTION_ALIASES))


def search_terms(text: str) -> list[str]:
    return list(dict.fromkeys(word for word in words(text)
                              if len(word) >= 3 and word not in STOP_WORDS
                              and word not in INSTITUTION_ALIASES))[:24]


def contains(column, term: str):
    # contains(autoescape=True) treats user '%' and '_' as literal characters.
    return func.lower(column).contains(term.lower(), autoescape=True)


def alias_filter(aliases: list[str]):
    filters = []
    for alias in aliases:
        if alias == "бгу":
            # The full BГУ name is also a prefix of БГУИР and several other universities.
            name = func.lower(func.trim(EducationInstitution.name, ' «»"'))
            filters.append(name == INSTITUTION_ALIASES[alias][0])
        else:
            filters.append(and_(*(contains(EducationInstitution.name, term)
                                  for term in INSTITUTION_ALIASES[alias]),
                                ~contains(EducationInstitution.name, "филиал"),
                                ~contains(EducationInstitution.name, "колледж")))
    return or_(*filters)


def institution_search(text: str):
    aliases = aliases_in(text)
    if aliases:
        return alias_filter(aliases)
    terms = search_terms(text)
    if not terms:
        # An explicit catalog search consisting of a generic word is still useful.
        terms = words(text)
    return and_(*(or_(contains(EducationInstitution.name, term),
                     contains(EducationInstitution.locality, term),
                     contains(EducationInstitution.region_id, term)) for term in terms))


def relevance(columns, terms: list[str]):
    return sum((case((or_(*(contains(column, term) for column in columns)), 1), else_=0)
                for term in terms), 0)
