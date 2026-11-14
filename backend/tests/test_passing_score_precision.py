import json
from decimal import Decimal
import pytest
from app.scripts.import_passing_scores import validated_rows


def test_fractional_score_is_not_truncated(tmp_path):
    path = tmp_path / 'scores.json'
    row = dict(institution_id='test', specialty_id='test', admission_year=2026,
               score=283.6, source_url='https://example.edu/scores', verified_at='2026-11-09')
    path.write_text(json.dumps([row]))
    assert validated_rows(path)[0]['score'] == Decimal('283.6')
    for invalid in ['NaN', 'Infinity', '-1', '401', '1.234']:
        path.write_text(json.dumps([{**row, 'score': invalid}]))
        with pytest.raises(ValueError):
            validated_rows(path)
