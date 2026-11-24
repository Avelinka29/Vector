from app.scripts.enrich_official_contacts import extract_contacts


def test_extracts_only_admissions_specific_contacts():
    html = '''
      <a href="mailto:info@example.by">Общий email</a>
      <a href="mailto:abitur@example.by">Приёмная комиссия</a>
      <a href="/abiturient/">Абитуриенту</a>
    '''
    assert extract_contacts(html, "https://example.by/") == {
        "admissions_email": "abitur@example.by",
        "admissions_url": "https://example.by/abiturient/",
    }
