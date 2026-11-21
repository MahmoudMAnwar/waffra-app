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
    "m1053_actual_android_sms_skip_evidence_and_unique_legacy_undo": ("safety", (
        "test/m1053_sms_recovery_reason_and_legacy_provenance_test.dart",
        "test/m1052_legacy_excluded_sms_recovery_test.dart",
        "test/m1051_excluded_sms_restore_regression_test.dart")),
    "m1052_legacy_excluded_bank_sms_original_recovery_and_authorization_otp": ("safety", (
        "test/m1052_legacy_excluded_sms_recovery_test.dart",
        "test/m1051_excluded_sms_restore_regression_test.dart",
        "test/m1016_sms_background_financial_intake_test.dart")),
    "m1051_owner_excluded_sms_restore_requeue_and_unblock_rescan": ("safety", (
        "test/m1051_excluded_sms_restore_regression_test.dart",
        "test/m1050_recent_sms_rescan_recovery_test.dart",
        "test/m1037_excluded_sms_readback_and_learning_test.dart")),
    "m1050_explicit_recent_sms_missed_provider_recovery": ("safety", (
        "test/m1050_recent_sms_rescan_recovery_test.dart",
        "test/m638_sms_inbox_delete_sync_test.dart",
        "test/m509_all_sender_sms_rescan_dedup_test.dart")),
    "m1038_source_evidenced_sms_multipart_reassembly": ("safety", (
        "test/m1038_sms_multipart_reassembly_test.dart",
        "test/m1029_android_sms_multipart_grouping_test.dart",
        "test/m1016_sms_background_financial_intake_test.dart",
        "test/m638_sms_inbox_delete_sync_test.dart")),
    "m1037_owner_visible_excluded_sms_and_learning_diagnostics": ("safety", (
        "test/m1037_excluded_sms_readback_and_learning_test.dart",
        "test/m982_background_sms_exclusion_bridge_test.dart",
        "test/m615_m618_sms_review_retention_perf_contract_test.dart")),
    "m1032_owner_sms_rules_backup_v3_roundtrip": ("safety", (
        "test/storage/m440_accounts_portable_v3_test.dart",
        "test/m1032_outgoing_sms_owner_review_gate_test.dart")),
    "m1032_money_transfer_reversal_and_local_rule_notification": ("money", (
        "test/storage/m440_accounts_repository_test.dart",
        "test/storage/m183_encrypted_transaction_recycle_test.dart",
        "test/m1032_outgoing_sms_owner_review_gate_test.dart")),
    "m1032_outgoing_sms_confirmed_owner_gate": ("money", (
        "test/m1032_outgoing_sms_owner_review_gate_test.dart",
        "test/m1031_sms_unified_review_contract_test.dart",
        "test/m462_smart_sms_rule_review_test.dart")),
    "m1031_sms_unified_review_predictions_and_owner_confirmation": ("money", (
        "test/m1031_sms_unified_review_contract_test.dart",
        "test/m1009_sama_notification_swipe_regression_test.dart",
        "test/m462_smart_sms_rule_review_test.dart")),
    "m1030_android_sms_receiver_background_io_and_finish": ("safety", (
        "test/m1030_android_sms_receiver_latency_test.dart",
        "test/m1029_android_sms_multipart_grouping_test.dart",
        "test/m1018_sms_workmanager_wakeup_race_test.dart")),
    "m1029_sms_sender_and_timestamp_multipart_guard": ("safety", (
        "test/m1029_android_sms_multipart_grouping_test.dart",
        "test/m1018_sms_workmanager_wakeup_race_test.dart")),
    "m1028_sms_background_worker_exponential_recovery": ("safety", (
        "test/m1028_sms_worker_retry_recovery_test.dart",
        "test/m1020_sms_background_checkpoint_continuation_test.dart")),
    "m1027_mixed_sms_otp_secret_redaction": ("safety", (
        "test/m1027_sms_mixed_otp_redaction_test.dart",
        "test/m1016_sms_background_financial_intake_test.dart")),
    "m1026_sms_history_explicit_all_inbox_opt_in": ("experience", (
        "test/m1026_sms_history_range_test.dart",
        "test/m1019_sms_intake_capacity_recovery_test.dart")),
    "m1025_sms_finance_native_identity_migration": ("money", (
        "test/m1025_sms_transaction_identity_test.dart",
        "test/m1024_sms_autopost_date_guard_test.dart")),
    "m1024_sms_autopost_explicit_transaction_date_guard": ("money", (
        "test/m1024_sms_autopost_date_guard_test.dart",
        "test/m1020_sms_background_checkpoint_continuation_test.dart")),
    "m1023_sms_review_notification_delivery_and_retry": ("safety", (
        "test/m1023_sms_review_notification_ack_test.dart",
        "test/m1022_sms_rule_checkpoint_revision_test.dart")),
    "m1022_sms_background_rule_checkpoint_invalidation": ("safety", (
        "test/m1022_sms_rule_checkpoint_revision_test.dart",
        "test/m1020_sms_background_checkpoint_continuation_test.dart")),
    "m1021_goal_card_inline_actions_same_as_due_no_tap_sheet": ("experience", (
        "test/m1021_goal_card_inline_actions_test.dart",
        "test/m665_goal_due_display_and_linked_edit_test.dart",
        "test/m388_m390_approved_goal_recurring_receipt_test.dart")),
    "m1020_sms_background_35_second_checkpointed_continuation": ("safety", (
        "test/m1020_sms_background_checkpoint_continuation_test.dart",
        "test/m1017_sms_background_batch_drain_test.dart",
        "test/m1019_sms_intake_capacity_recovery_test.dart")),
    "m1019_android_sms_capacity_replay": ("safety", (
        "test/m1019_sms_intake_capacity_recovery_test.dart",
        "test/m1018_sms_workmanager_wakeup_race_test.dart",
        "test/m1017_sms_background_batch_drain_test.dart")),
    "m1018_android_sms_workmanager_late_wakeup_no_keep_race": ("safety", (
        "test/m1018_sms_workmanager_wakeup_race_test.dart",
        "test/m1016_sms_background_financial_intake_test.dart",
        "test/m1017_sms_background_batch_drain_test.dart")),
    "m1017_all_actionable_sms_background_batches": ("safety", (
        "test/m1017_sms_background_batch_drain_test.dart",
        "test/m462_smart_sms_rule_review_test.dart",
        "test/m1016_sms_background_financial_intake_test.dart")),
    "m1016_nonfinancial_sms_native_intake_financial_evidence_only": ("safety", (
        "test/m1016_sms_background_financial_intake_test.dart",
        "test/m549_sms_review_owner_scoped_test.dart",
        "test/m979_native_otp_prequeue_exclusion_test.dart",
        "test/m981_historical_otp_atomic_intake_test.dart",
        "test/m954_all_sms_rule_routes_regression_test.dart")),
    "m1015_verified_standalone_expense_due_payment_approval": ("money", (
        "test/m1015_standalone_due_confirmed_payment_test.dart",
        "test/m1012_due_reminder_verified_confirmation_test.dart",
        "test/m631_verified_finance_prewarm_test.dart",
        "test/storage/m470_verified_recurring_payment_capture_test.dart",
        "test/m86_recurring_schedule_boundary_test.dart")),
    "m1012_verified_linked_goal_due_confirmation_and_321_reminders": ("money", (
        "test/m1012_due_reminder_verified_confirmation_test.dart",
        "test/m1013_goal_due_month_identity_postponement_test.dart",
        "test/m444_notification_forecast_budget_test.dart",
        "test/m86_recurring_schedule_boundary_test.dart",
        "test/m978_recurring_reminder_goal_index_test.dart",
        "test/m631_verified_finance_prewarm_test.dart",
        "test/storage/m470_verified_recurring_payment_capture_test.dart",
        "test/storage/m266_home_bound_source_regression_test.dart",
        "test/m762_home_finance_persistence_due_extraction_test.dart")),
    "m1011_sms_original_provenance_review_ack_and_verified_transfer": ("money", (
        "test/m1011_reviewed_sms_provenance_ack_transfer_regression_test.dart",
        "test/m983_sms_direct_kind_prefill_refresh_test.dart",
        "test/m985_sms_prefill_identity_status_conflict_duplicate_test.dart",
        "test/m580_sms_security_navigation_performance_test.dart")),
    "m1010_goals_dues_inline_account_validation_and_green_hero": ("experience", (
        "test/m1010_goal_due_required_account_hero_test.dart",
        "test/m693_three_approved_pages_layout_matrix_test.dart")),
    "m1009_sama_direction_sms_review_and_live_notifications_swipe": ("money", (
        "test/m1009_sama_notification_swipe_regression_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m984_sms_calendar_dots_sender_swipe_test.dart")),
    "m1008_two_account_sms_balance_and_history_parity": ("money", (
        "test/storage/m1008_two_accounts_sms_reconciliation_test.dart",
        "test/m1008_sms_account_projection_refresh_regression_test.dart",
        "test/storage/m955_home_verified_summary_parity_test.dart")),
    "m1007_global_and_specific_sender_rules_safe_exclusion": ("safety", (
        "test/m1007_sms_rule_scope_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart")),
    "m1006_visible_finance_retry_no_black_frame": ("experience", (
        "test/m1006_visible_recovery_loading_gate_test.dart",
        "test/m623_verified_home_handoff_no_black_frame_test.dart")),
    "m998_last_four_sender_bank_facts_and_otp_single_pass": ("safety", (
        "test/m998_sms_shared_facts_parity_test.dart",
        "test/m995_sms_single_currency_scan_test.dart")),
    "m998_17_saudi_provider_versioned_offline_templates": ("experience", (
        "test/m998_saudi_sms_all_provider_templates_test.dart",
        "test/m992_saudi_sms_template_registry_test.dart")),
    "m998_reviewed_merchant_alias_correction_and_otp_guards": ("safety", (
        "test/m998_merchant_corrections_and_alias_safety_test.dart",
        "test/m988_sms_merchant_alias_test.dart")),
    "m998_2000_sender_rules_and_currency_stress_corpus": ("experience", (
        "test/m998_sms_2000_corpus_benchmark_test.dart",
        "test/m994_full_sms_rule_impact_test.dart")),
    "m997_sms_14_roadmap_four_kind_owner_sender_index": ("safety", (
        "test/m986_sms_rule_sender_index_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart")),
    "m997_sms_saudi_structured_principal_and_composite": ("safety", (
        "test/m987_sms_structured_bank_context_test.dart",
        "test/m989_sms_reference_currency_regression_test.dart")),
    "m997_sms_rule_undo_merchant_alias_and_simulation": ("safety", (
        "test/m988_sms_rule_simulation_history_test.dart",
        "test/m988_sms_merchant_alias_test.dart")),
    "m997_sms_lifecycle_strict_duplicate_and_review_guard": ("safety", (
        "test/m989_sms_lifecycle_related_events_test.dart",
        "test/m989_sms_review_lifecycle_guard_test.dart")),
    "m997_sms_sar_principal_vat_fee_and_2000_parity": ("money", (
        "test/m990_sms_single_pass_structured_facts_test.dart",
        "test/m989_sms_reference_currency_regression_test.dart")),
    "m997_sms_incremental_rule_rescan_live_sender_calendar": ("experience", (
        "test/m991_sms_incremental_rule_review_test.dart",
        "test/m991_sms_live_counts_source_test.dart",
        "test/m547_sms_incremental_jank_regression_test.dart")),
    "m997_sms_offline_versioned_saudi_bank_templates": ("experience", (
        "test/m992_saudi_sms_template_registry_test.dart",
        "test/m987_sms_structured_bank_context_test.dart")),
    "m997_sms_encrypted_owner_cross_restart_relation_history": ("safety", (
        "test/m993_sms_lifecycle_history_test.dart",
        "test/m989_sms_lifecycle_related_events_test.dart")),
    "m997_sms_full_2000_rule_impact_and_safe_exclusion": ("safety", (
        "test/m994_full_sms_rule_impact_test.dart",
        "test/m990_sms_rule_impact_safe_exclusion_test.dart")),
    "m997_sms_one_pass_currency_legacy_parity": ("safety", (
        "test/m995_sms_single_currency_scan_test.dart",
        "test/m300_jod_cliq_bank_sms_test.dart")),
    "m997_sms_related_duplicate_settlement_refund_advisory_ui": ("experience", (
        "test/m996_sms_related_advisory_ui_test.dart",
        "test/m989_sms_review_lifecycle_guard_test.dart")),
    "m985_sms_identity_prefill_rule_conflict_and_status_guard": ("safety", (
        "test/m985_sms_prefill_identity_status_conflict_duplicate_test.dart",
        "test/m983_sms_direct_kind_prefill_refresh_test.dart",
        "test/m470_sms_sender_and_rule_accuracy_test.dart",
        "test/m304_cross_source_duplicate_review_test.dart")),
    "m982_rebased_owner_background_sms_exclusion_bridge": ("safety", (
        "test/m982_background_sms_exclusion_bridge_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m954_all_sms_rule_routes_regression_test.dart")),
    "m984_sms_received_calendar_dots_and_rtl_sender_swipe": ("experience", (
        "test/m984_sms_calendar_dots_sender_swipe_test.dart",
        "test/m983_sms_direct_kind_prefill_refresh_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m549_approved_home_notifications_test.dart")),
    "m983_sms_direct_kind_editor_prefill_live_review_refresh": ("experience", (
        "test/m983_sms_direct_kind_prefill_refresh_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m669_sms_review_category_search_test.dart",
        "test/m580_sms_security_navigation_performance_test.dart")),
    "m981_history_live_otp_atomic_parity": ("safety", (
        "test/m981_historical_otp_atomic_intake_test.dart",
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m979_native_otp_prequeue_exclusion_test.dart",
        "test/m954_all_sms_rule_routes_regression_test.dart")),
    "m980_four_sms_rule_kinds_every_route": ("safety", (
        "test/m980_four_sms_rule_kinds_every_route_test.dart",
        "test/m954_all_sms_rule_routes_regression_test.dart")),
    "m979_native_new_app_otp_intake_and_mixed_finance": ("safety", (
        "test/m979_native_otp_prequeue_exclusion_test.dart",
        "test/m954_all_sms_rule_routes_regression_test.dart")),
    "m978_reminder_linked_goal_index_parity": ("experience", (
        "test/m978_recurring_reminder_goal_index_test.dart",
        "test/m86_recurring_schedule_boundary_test.dart")),
    "m977_large_argon2id_backup_envelope_integrity": ("safety", (
        "test/m977_large_v2_encrypted_backup_envelope_test.dart",
        "test/waffra_secure_backup_test.dart")),
    "m976_lazy_goal_due_card_viewport_build": ("experience", (
        "test/m976_lazy_goal_due_cards_viewport_test.dart",
        "test/m665_goal_due_display_and_linked_edit_test.dart")),
    "m975_recurring_due_paid_id_snapshot_parity": ("experience", (
        "test/m975_recurring_paid_id_read_cache_test.dart",
        "test/m302_recurring_first_due_regression_test.dart")),
    "m974_goal_due_card_source_index_and_settlement_parity": ("experience", (
        "test/m974_goal_due_card_lookup_index_test.dart",
        "test/m665_goal_due_display_and_linked_edit_test.dart")),
    "m973_single_sms_review_indexed_sender_cleanup": ("experience", (
        "test/m973_sms_review_group_owner_index_test.dart",
        "test/m548_review_grouping_and_signup_perf_test.dart")),
    "m967_verified_preload_and_sms_isolate_session_gate": ("experience", (
        "test/m631_verified_finance_prewarm_test.dart",
        "test/m632_sms_account_splash_isolate_contract_test.dart")),
    "m966_sms_session_guard_after_home_extraction": ("experience", (
        "test/m624_deferred_sms_after_verified_home_test.dart",
        "test/m548_review_grouping_and_signup_perf_test.dart")),
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
