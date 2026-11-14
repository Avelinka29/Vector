from app.scripts.prepare_grsu_scores import convert


def test_ambiguous_specialty_is_not_assigned_a_guessed_score():
    html = '''<table>
    <tr><td>Architecture</td><td>7-07-0731-01</td><td>283.6</td><td>282.3</td></tr>
    <tr><td>Track A</td><td>6-05-0232-04</td><td>346</td><td>289</td></tr>
    <tr><td>Track B</td><td>6-05-0232-04</td><td>317</td><td>287</td></tr>
    </table>'''
    catalog = [{'id': 'architecture', 'code': '7-07-0731-01'}, {'id': 'philology', 'code': '6-05-0232-04'}]
    rows, skipped = convert(html, catalog, 'day')
    assert [r['score'] for r in rows] == [283.6, 282.3]
    assert all(r['specialty_id'] == 'architecture' for r in rows)
    assert len(skipped) == 2


def test_no_exam_result_does_not_become_zero():
    html = '<table><tr><td>Test</td><td>6-05-0112-01</td><td></td><td></td><td>235</td><td>без вступительных испытаний</td></tr></table>'
    rows, skipped = convert(html, [{'id': 'test', 'code': '6-05-0112-01'}], 'parttime')
    assert len(rows) == 1 and rows[0]['score'] == 235
    assert rows[0]['study_form'] == 'заочная сокращённая'
    assert len(skipped) == 1
