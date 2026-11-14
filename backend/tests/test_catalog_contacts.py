from app.scripts.enrich_catalog_contacts import extract


def test_contact_extraction_does_not_promote_director_or_fax():
    fields = {'Адрес': 'Минск, ул. Тестовая, 1', 'Контакная информация':
              'Тел.: 8(017) 378 60 10 (приемная директора), 8(017) 378 60 56 (приемная комиссия)\n'
              'Факс: 8(017) 378 60 11\nWeb-сайт: https://example.by/ E-mail: abitur@example.by'}
    result = extract(fields)
    assert result['admissions_phone'] == '8(017) 378 60 56'
    assert result['admissions_email'] == 'abitur@example.by'
    assert result['website_url'] == 'https://example.by/'
    assert result['address'] == fields['Адрес']
    assert 'admissions_email' not in extract({'Контакная информация': 'E-mail: director@example.by'})
    assert 'admissions_phone' not in extract({'Контакная информация': 'Факс: 8(017) 378 60 11'})
    assert extract({}) == {}
