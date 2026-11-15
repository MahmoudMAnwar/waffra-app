#!/usr/bin/env python3
"""M946: Fail-closed, all-feature smoke manifest executed at every PR head.

Real Flutter tests, encrypted-database tests and UI tests—not checkboxes.
A feature with no runnable test cannot be marked covered. The matrix is NOT
a substitute for real-device SMS, notifications, biometric or backup UAT.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
from m949_unique_functional_case_audit import audit as audit_m949
from m950_extended_functional_audit import audit as audit_m950
from m951_last_functional_gap_audit import audit as audit_m951

ROOT = Path(__file__).resolve().parents[2]
GROUPS = ("money", "experience", "safety")

# Each user-facing capability has a real runnable suite. Tests can be reused
# across capabilities; the runner de-duplicates within each CI shard.
FEATURES: dict[str, tuple[str, tuple[str, ...]]] = {
    "m965_home_state_invalidation_and_permission_cache": ("experience", (
        "test/m965_home_state_cache_lifecycle_extraction_test.dart",
        "test/m940_m941_home_ledger_pagination_test.dart",
        "test/m528_settings_async_cache_regression_test.dart")),
    "m964_home_state_pure_helper_architecture": ("experience", (
        "test/m964_home_state_pure_helpers_extraction_test.dart",
        "test/m630_home_first_frame_contention_test.dart",
        "test/m528_settings_async_cache_regression_test.dart")),
    "m963_verified_edit_undo_updates_home_account_view": ("experience", (
        "test/m963_verified_edit_undo_account_refresh_test.dart",
        "test/storage/m953_verified_historical_edit_regression_test.dart")),
    "m961_home_account_month_cache_and_witness_invalidation": ("experience", (
        "test/m961_verified_month_scope_cache_test.dart",
        "test/m684_finance_period_index_test.dart")),
    "m960_grouped_sqlcipher_account_balances_source_parity": ("money", (
        "test/storage/m960_grouped_account_balance_parity_test.dart",
        "test/storage/m440_accounts_repository_test.dart")),
    # M952: all new finance/goal/readiness regressions execute on exact PR SHA
    # rather than existing only as locally runnable, unregistered test files.
    "m955_home_verified_month_summary_without_ledger_hydration": ("money", (
        "test/storage/m955_home_verified_summary_parity_test.dart",
        "test/storage/m448_account_context_read_test.dart")),
    "m952_encrypted_account_domain_fail_closed": ("safety", (
        "test/storage/m952_account_linked_schema_readiness_test.dart",
        "test/storage/m440_accounts_portable_v3_test.dart")),
    "m952_historical_unassigned_keyset_and_month": ("money", (
        "test/storage/m944_sqlcipher_keyset_paging_test.dart",
        "test/storage/m952_account_linked_schema_readiness_test.dart")),
    "m952_many_goal_contributions_and_budget_parity": ("money", (
        "test/storage/m952_goal_projection_scale_parity_test.dart",
        "test/storage/m952_budget_single_pass_parity_test.dart")),
    "m952_legacy_multibudget_entry_dedup_and_account_balance": ("money", (
        "test/storage/m952_multibudget_ledger_dedup_test.dart",
        "test/storage/m944_sqlcipher_keyset_paging_test.dart")),
    "m951_preposting_bank_sms_eligibility_thresholds": ("experience", (
        "test/m951_sms_eligibility_and_budget_alert_isolation_test.dart",
        "test/waffra_auto_sms_policy_test.dart")),
    "m951_owner_budget_alert_notifications_and_months": ("money", (
        "test/m951_sms_eligibility_and_budget_alert_isolation_test.dart",
        "test/m444_budget_alert_once_test.dart")),
    "m950_exact_unicode_sms_last_four_bank_provenance": ("experience", (
        "test/m950_account_sms_due_budget_decision_matrix_test.dart",
        "test/storage/m448_account_context_policy_test.dart")),
    "m950_due_override_global_budget_goal_source_conservation": ("money", (
        "test/m950_account_sms_due_budget_decision_matrix_test.dart",
        "test/storage/m448_account_context_policy_test.dart")),
    "m950_verified_monthly_budget_and_historical_account_paging": ("money", (
        "test/storage/m950_verified_monthly_scopes_and_history_test.dart",
        "test/storage/m448_account_context_read_test.dart")),
    "m949_account_rename_transfer_archive_and_partial_legacy_link": ("money", (
        "test/storage/m949_account_lifecycle_cross_feature_test.dart",
        "test/storage/m440_accounts_repository_test.dart")),
    "m949_goal_recurring_category_multi_step_atomicity": ("money", (
        "test/storage/m949_goal_recurring_category_sequences_test.dart",
        "test/storage/m641_goal_account_integrity_test.dart")),
    "m949_combined_date_amount_search_category_account_filters": ("experience", (
        "test/m949_home_filter_combined_user_journeys_test.dart",
        "test/m940_m941_home_ledger_pagination_test.dart")),
    "exact_month_end_date_range_filters": ("money", (
        "test/m948_financial_properties_and_performance_test.dart",
        "test/m940_m941_home_ledger_pagination_test.dart")),
    "ten_thousand_row_read_index_and_render_window": ("safety", (
        "test/m948_financial_properties_and_performance_test.dart",
        "test/m940_m941_home_ledger_pagination_test.dart")),
    "cent_accurate_randomized_finance_arithmetic": ("money", (
        "test/m948_financial_properties_and_performance_test.dart",
        "test/m86_recurring_schedule_boundary_test.dart")),
    "leap_year_long_horizon_scheduling": ("money", (
        "test/m948_financial_properties_and_performance_test.dart",
        "test/m86_recurring_schedule_boundary_test.dart")),
    "concurrent_manual_sms_no_double_booking": ("safety", (
        "test/storage/m946_whole_app_money_journey_smoke_test.dart",
        "test/storage/m141_sqlcipher_multi_step_transaction_rollback_test.dart")),
    "bad_finance_inputs_and_rollback": ("safety", (
        "test/storage/m946_whole_app_money_journey_smoke_test.dart",
        "test/storage/m440_account_linked_entry_writer_test.dart")),
    "narrow_rtl_high_text_scale_metric_layout": ("experience", (
        "test/m948_financial_properties_and_performance_test.dart",
        "test/m674_approved_page_designs_test.dart")),
    "accounts_opening_and_subaccounts": ("money", (
        "test/storage/m440_account_linked_entry_writer_test.dart",
        "test/m470_new_account_dialog_test.dart")),
    "account_selected_history_and_scopes": ("money", (
        "test/m470_account_scope_and_transfer_date_test.dart",
        "test/m470_balance_header_account_picker_test.dart")),
    "manual_income_expense_database_posting": ("money", (
        "test/storage/m946_whole_app_money_journey_smoke_test.dart",
        "test/storage/m457_direct_manual_finance_commit_test.dart")),
    "internal_transfer_and_balance_conservation": ("money", (
        "test/m647_m652_financial_activity_regression_test.dart",
        "test/m670_feedback_transfer_dashboard_test.dart")),
    "goals_wallet_and_bank_funding": ("money", (
        "test/m641_goal_recurring_account_binding_test.dart",
        "test/m371_goal_wallet_and_budgets_regression_test.dart")),
    "goal_due_settlement_exactly_once": ("money", (
        "test/m362_goal_wallet_due_settlement_test.dart",
        "test/m665_goal_due_display_and_linked_edit_test.dart")),
    "recurring_due_schedule_and_accounts": ("money", (
        "test/storage/m447_account_recurring_atomic_test.dart",
        "test/m470_recurring_provider_accounts_test.dart")),
    "budgets_and_bank_expenses": ("money", (
        "test/m515_budget_verified_save_test.dart",
        "test/m296_monthly_budget_and_transactions_test.dart")),
    "category_hierarchy_and_financial_inputs": ("money", (
        "test/m357_budget_hierarchy_and_filter_layout_test.dart",
        "test/m359_budget_directory_and_templates_test.dart")),
    "legacy_archives_and_migrated_goals": ("money", (
        "test/storage/m614_legacy_v24_restore_test.dart",
        "test/storage/m935_phase_two_restore_finance_acceptance_test.dart")),
    "monthly_finance_and_activity_cards": ("money", (
        "test/m945_restored_history_filters_ui_test.dart",
        "test/m674_approved_page_designs_test.dart")),
    "first_run_permissions_and_login": ("experience", (
        "test/m463_auth_first_one_page_test.dart",
        "test/m639_permissions_onboarding_plain_copy_test.dart")),
    "biometrics_logout_and_lock": ("experience", (
        "test/m424_mandatory_biometrics_test.dart",
        "test/m470_logout_and_refresh_test.dart")),
    "home_verified_first_frame": ("experience", (
        "test/m622_immediate_home_without_loader_test.dart",
        "test/m623_verified_home_handoff_no_black_frame_test.dart")),
    "bank_sms_parsing_review_and_original_text": ("experience", (
        "test/bank_sms_test.dart",
        "test/m507_sms_amount_and_continuous_review_test.dart")),
    "sms_rules_learning_and_sender_matching": ("experience", (
        "test/m473_manual_sms_keyword_learning_parity_test.dart",
        "test/m665_sms_review_structural_learning_test.dart")),
    "bulk_sms_rescan_dedupe_and_exclusions": ("experience", (
        "test/m509_all_sender_sms_rescan_dedup_test.dart",
        "test/m461_sms_exclusion_and_history_scan_test.dart")),
    "notifications_and_delete_sync": ("experience", (
        "test/m549_approved_home_notifications_test.dart",
        "test/m638_sms_inbox_delete_sync_test.dart")),
    "search_filter_dropdown_and_page_navigation": ("experience", (
        "test/m669_sms_review_category_search_test.dart",
        "test/m355_global_scroll_cue_search_test.dart")),
    "snackbar_fab_rtl_and_empty_states": ("experience", (
        "test/m644_no_fab_snackbar_width_test.dart",
        "test/m945_restored_history_filters_ui_test.dart")),
    "riyals_arabic_layout_and_amounts": ("experience", (
        "test/m270_native_riyal_widget_contract_test.dart",
        "test/m270_original_riyal_currency_presentation_test.dart")),
    "financial_pdf_and_export": ("experience", (
        "test/m224_pdf_verified_display_currency_test.dart",
        "test/m662_sms_review_activity_pdf_regression_test.dart")),
    "currency_converter_gold_and_oil_tools": ("experience", (
        "test/m281_practical_tools_test.dart",
        "test/m222_gold_calculator_test.dart",
        "test/m259_oil_quotes_test.dart")),
    "encrypted_sqlcipher_cold_reopen": ("safety", (
        "test/storage/m946_whole_app_money_journey_smoke_test.dart",
        "test/storage/m440_accounts_portable_v3_test.dart")),
    "backup_password_restore_durability": ("safety", (
        "test/waffra_secure_backup_test.dart",
        "test/storage/m935_phase_two_restore_finance_acceptance_test.dart")),
    "bank_sms_anti_replay_no_double_charge": ("safety", (
        "test/storage/m440_account_linked_entry_writer_test.dart",
        "test/m508_saudi_default_sms_rules_test.dart")),
    "privacy_security_and_user_session": ("safety", (
        "test/m279_app_wide_security_regression_test.dart",
        "test/m580_sms_security_navigation_performance_test.dart")),
    "receipts_and_encrypted_finance": ("safety", (
        "test/m262_bank_sms_notes_separation_test.dart",
        "test/storage/m457_direct_manual_finance_commit_test.dart")),
    "transaction_delete_cancel_undo_and_receipt_parity": ("safety", (
        "test/storage/m183_encrypted_transaction_recycle_test.dart",
        "test/storage/m183_transaction_home_ui_guard_test.dart",
        "test/m947_deletion_flow_contract_test.dart")),
    "deleted_goals_restore_and_30_day_retention": ("safety", (
        "test/storage/encrypted_goal_recycle_test.dart",
        "test/storage/m938_legacy_goal_recycle_repair_test.dart",
        "test/m938_goals_restore_fab_contract_test.dart")),
    "recurring_and_category_recycle_without_history_loss": ("safety", (
        "test/storage/m185_encrypted_module_recycle_test.dart",
        "test/m907_home_delete_all_extraction_test.dart")),
    "delete_all_and_biometric_full_reset_protection": ("safety", (
        "test/m907_home_delete_all_extraction_test.dart",
        "test/m947_deletion_flow_contract_test.dart")),
    "sms_delete_exclude_synchronization": ("experience", (
        "test/m638_sms_inbox_delete_sync_test.dart",
        "test/m470_sms_excluded_senders_test.dart")),
    "cloud_account_delete_release_guard": ("safety", (
        "test/m107_release_backend_gating_test.dart",
        "test/m279_app_wide_security_regression_test.dart")),
    "deleted_data_and_retired_features": ("safety", (
        "test/m671_tour_retirement_snackbar_tap_test.dart",
        "test/m470_sms_excluded_senders_test.dart")),
    "input_required_fields_and_validation": ("safety", (
        "test/waffra_validators_test.dart",
        "test/m374_transaction_dialog_ux_test.dart")),
    "main_widgets_and_source_consistency": ("safety", (
        "test/m108_home_widget_one_finance_writer_test.dart",
        "test/m470_recurring_provider_accounts_test.dart")),
    "long_history_pagination_no_freeze": ("safety", (
        "test/m468_app_refresh_performance_regression_test.dart",
        "test/m547_sms_incremental_jank_regression_test.dart")),
    "goal_recurring_budget_cross_linkage": ("safety", (
        "test/m343_goal_recurring_named_budgets_test.dart",
        "test/m641_goal_recurring_account_binding_test.dart")),
}

# Must remain listed; CI cannot pretend that unit/widget tests prove these.
DEVICE_ONLY = (
    "Android actual SMS permission, background delivery and bank sender accuracy",
    "OS biometric enrollment and lifecycle; screenshot/recent-app privacy",
    "notification permission, OS posting and cross-page delivery",
    "visual overflow on short, tall and different-font-scale Android screens",
    "signed APK installation/updating the older spouse handset without data loss",
    "password-authorized exact owner backup restore and historical goal parity",
    "external exchange-rate, gold and oil upstream freshness in live conditions",
    "real Android delete-sheet navigation, biometric dialog and post-delete black-frame check",
)

PRODUCTION_GUARDS = (
    "lib/main.dart",
    "lib/waffra_home_goals_recurring_pages.part.dart",
    "lib/waffra_home_dashboard_analytics.part.dart",
    "lib/waffra_home_entry_sheet.part.dart",
    "lib/storage/waffra_unified_finance_writer.dart",
    "lib/storage/waffra_accounts_repository.dart",
    "lib/storage/waffra_legacy_v24_sqlcipher_converter.dart",
    "lib/waffra_home_transaction_ledger_actions.part.dart",
    "lib/waffra_home_delete_all_transactions.part.dart",
    "lib/waffra_home_category_confirmations.part.dart",
    "lib/storage/waffra_encrypted_transaction_recycle.dart",
    "lib/storage/waffra_encrypted_goal_recycle.dart",
    "lib/storage/waffra_encrypted_module_recycle.dart",
)

def group_tests(group: str) -> tuple[str, ...]:
    if group not in GROUPS:
        raise ValueError(f"Unknown mandatory smoke group: {group}")
    return tuple(sorted({p for g, tests in FEATURES.values()
                         if g == group for p in tests}))

def validate(root: Path = ROOT) -> dict[str, object]:
    if len(FEATURES) < 30 or len(GROUPS) != 3:
        raise ValueError("Full application feature inventory was reduced")
    missing = []
    weak = []
    for name, (group, tests) in FEATURES.items():
        if group not in GROUPS or len(tests) < 2:
            weak.append(name)
        for p in tests:
            f = root / p
            if not f.is_file():
                missing.append(p)
            elif p.endswith("_test.dart"):
                source = f.read_text(encoding="utf-8", errors="replace")
                if not ("test(" in source or "testWidgets(" in source):
                    weak.append(name + ":" + p)
    missing.extend(p for p in PRODUCTION_GUARDS if not (root / p).is_file())
    if missing or weak:
        raise ValueError(f"M946 uncovered feature/source: missing={sorted(set(missing))} "
                         f"weak={sorted(set(weak))}")
    new_functional = audit_m949(root)
    extended_functional = audit_m950(root)
    final_functional = audit_m951(root)
    buckets = {g: group_tests(g) for g in GROUPS}
    if any(len(v) < 10 for v in buckets.values()):
        raise ValueError("A critical smoke shard was silently reduced")
    return {
        "gate": "M946 full app actionable smoke; physical device acceptance separate",
        "features_count": len(FEATURES),
        "new_nonduplicate_functional_cases": new_functional["unique_case_count"] + extended_functional["new_functional_case_count"] + final_functional["new_M951_functional_case_count"],
        "new_functional_case_breakdown": {"M949":new_functional["unique_case_count"],
                                          "M950":extended_functional["new_functional_case_count"],
                                          "M951":final_functional["new_M951_functional_case_count"]},
        "test_files_count": len({p for _, t in FEATURES.values() for p in t}),
        "groups": {g: {"files": list(files), "count": len(files)}
                   for g, files in buckets.items()},
        "features": {k: {"group": g, "tests": list(tests)}
                     for k, (g, tests) in FEATURES.items()},
        "device_only_not_passed": list(DEVICE_ONLY),
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", choices=GROUPS)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--output")
    parser.add_argument("--head", help="Mandatory exact Git commit for CI evidence")
    args = parser.parse_args()
    report = validate()
    if args.head:
        actual = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        if actual != args.head:
            raise ValueError(f"Wrong checkout: expected {args.head}, got {actual}")
        report["head"] = actual
    if args.output:
        output = ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False,
                                     indent=2) + "\n", encoding="utf-8")
    if args.group:
        print("\n".join(group_tests(args.group)))
    else:
        print(f"M946: {report['features_count']} features, "
              f"{report['test_files_count']} runnable test files; "
              f"{len(DEVICE_ONLY)} device-only obligations NOT certified")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
