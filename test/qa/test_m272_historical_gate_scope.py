from pathlib import Path

def test_historical_sha_pinned_scopes_do_not_block_unrelated_ui_prs():
    m147 = Path(".github/workflows/m147-final-main-review-gate.yml").read_text()
    m268 = Path(".github/workflows/m268-smart-features.yml").read_text()
    assert "if: github.head_ref == 'review/m147-main-merge-readiness-final-gate'" in m147
    assert ("if: github.event_name != 'pull_request' || github.head_ref == "
            "'feature/m268-all-ten-smart-finance-illustrations-today-20261027'") in m268
    # Do not remove the historical safety audits; leave them runnable on
    # their intended branch and preserve the current independent main CI.
    assert "python3 scripts/m147_main_merge_readiness_audit.py" in m147
    assert "python3 scripts/qa/m268_scope_review.py" in m268
    apk = Path(".github/workflows/android.yml").read_text()
    assert "Full mandatory Flutter and Python test suite" in apk
    assert "Gate QA APK on embedded SHA and current branch head" in apk
    assert "if: hashFiles('build/m147-final-review-report.json') != ''" in m147
