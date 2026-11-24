from app.scripts.prepare_bsuir_scores import INSTITUTION, convert


def test_unique_bsuir_specialty_scores_keep_form_and_funding():
    html = """<h1>Проходные баллы 2026 года</h1><table>
    <tr><td>Faculty</td><td>6-05-0611-03</td><td>AI</td>
    <td>390</td><td>345</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
    </table>"""
    catalog = [{"id": "ai", "institution_id": INSTITUTION, "code": "6-05-0611-03"}]

    rows, skipped = convert(html, catalog)

    assert skipped == []
    assert [(row["study_form"], row["funding_type"], row["score"]) for row in rows] == [
        ("дневная", "budget", 390),
        ("дневная", "paid", 345),
    ]
    assert all(row["institution_id"] == INSTITUTION for row in rows)
    assert all(row["specialty_id"] == "ai" for row in rows)
    assert all(row["admission_year"] == 2026 for row in rows)


def test_ambiguous_faculty_and_half_passing_score_are_not_imported():
    html = """<h1>Проходные баллы 2026 года</h1><table>
    <tr><td>Faculty A</td><td>6-05-0611-04</td><td>Track A</td>
    <td>300</td><td>п/п 250</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
    <tr><td>Faculty B</td><td>6-05-0611-04</td><td>Track B</td>
    <td>310</td><td>260</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
    <tr><td>Faculty C</td><td>6-05-0612-02</td><td>Track C</td>
    <td>-</td><td>п/п 220</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
    </table>"""
    catalog = [
        {"id": "economics", "institution_id": INSTITUTION, "code": "6-05-0611-04"},
        {"id": "informatics", "institution_id": INSTITUTION, "code": "6-05-0612-02"},
    ]

    rows, skipped = convert(html, catalog)

    assert rows == []
    assert [item["reason"] for item in skipped] == [
        "ambiguous_faculty_or_catalog_code",
        "ambiguous_faculty_or_catalog_code",
        "half_passing_or_non_numeric_result",
    ]
