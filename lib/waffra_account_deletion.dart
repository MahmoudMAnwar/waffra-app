import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'waffra_google_auth.dart';

import 'waffra_haptic_feedback.dart';
/// It is NOT enough to enable this flag in a build. The callable must first
/// be deployed with verified backend deletion, recursive Firestore cleanup,
/// Firebase Auth recent-login and a public account-deletion procedure.
const bool waffraAccountDeletionReleased = bool.fromEnvironment(
  'WAFFRA_ACCOUNT_DELETE_READY', defaultValue: false,
);

class WaffraAccountDeletionService {
  const WaffraAccountDeletionService();

  Future<void> deleteVerifiedCloudAccount() async {
    if (!waffraAccountDeletionReleased || Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      throw StateError('Account deletion service is not ready.');
    }
    await WaffraGoogleAuth.reauthenticateCurrentGoogleUser();
    final result = await FirebaseFunctions.instanceFor(region: 'me-central2')
        .httpsCallable('deleteWaffraAccount')
        .call(<String, String>{
      'confirm': 'DELETE_WAFFRA_ACCOUNT',
    });
    if (result.data is! Map || (result.data as Map)['deleted'] != true) {
      throw StateError('Cloud account deletion was not confirmed.');
    }
    await WaffraGoogleAuth.signOut();
  }
}

/// Two-step confirmation. Local finance is NOT silently wiped on a cloud
/// deletion, because SQLCipher and legacy receipt restore safety is still
/// being verified. User may explicitly remove local financial data using
/// the separate existing biometric-confirmed profile action.
class WaffraAccountDeletionPage extends StatefulWidget {
  const WaffraAccountDeletionPage({
    super.key, required this.english, required this.onAccountDeleted,
  });

  final bool english;
  final Future<void> Function() onAccountDeleted;

  @override
  State<WaffraAccountDeletionPage> createState() =>
      _WaffraAccountDeletionPageState();
}

class _WaffraAccountDeletionPageState
    extends State<WaffraAccountDeletionPage> {
  final TextEditingController _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _perform() async {
    if (_busy || !waffraAccountDeletionReleased ||
        _confirmation.text.trim() != 'DELETE') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(widget.english ? 'Confirm account deletion' :
            'تأكيد حذف الحساب'),
        content: Text(widget.english
            ? 'Delete your Google/Firebase Waffra account and cloud data? '
              'This cannot be undone. Local financial data is not automatically deleted.'
            : 'هل تريد حذف حساب وفرة وبيانات السحابة نهائيًا؟ '
              'لا يمكن التراجع. البيانات المالية المحلية لن تُحذف تلقائيًا.'),
        actions: [
          TextButton(onPressed: WaffraHaptics.tap(() => Navigator.pop(dialog, false)),
              child: Text(widget.english ? 'Cancel' : 'إلغاء')),
          FilledButton(onPressed: WaffraHaptics.tap(() => Navigator.pop(dialog, true)),
              child: Text(widget.english ? 'Delete account' : 'حذف الحساب')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await const WaffraAccountDeletionService().deleteVerifiedCloudAccount();
      if (!mounted) return;
      await widget.onAccountDeleted();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.english
          ? 'Deletion was not verified. No success was reported. '
            'Please retry or contact support.'
          : 'لم يتم تأكيد حذف الحساب. لم نعتبر العملية ناجحة. '
            'حاول مرة أخرى أو تواصل مع الدعم.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.english;
    return Scaffold(
      appBar: AppBar(title: Text(english ? 'Delete account' : 'حذف الحساب')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.privacy_tip_outlined, size: 44),
        const SizedBox(height: 18),
        Text(english ? 'Account and cloud data deletion'
            : 'حذف الحساب وبيانات السحابة',
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(english
          ? 'You will need to verify the same Google account again. '
            'Cloud account data will be deleted only if the server confirms success. '
            'Local transactions, photos and backups must be removed separately '
            'through the protected financial-data action.'
          : 'ستحتاج إلى تأكيد نفس حساب Google مرة أخرى. '
            'لن نعلن نجاح حذف بيانات السحابة إلا بعد تأكيد الخادم. '
            'المعاملات والصور والنسخ المحلية تحتاج للحذف بشكل منفصل '
            'من خيار حذف البيانات المالية المحمي.'),
        const SizedBox(height: 16),
        if (!waffraAccountDeletionReleased)
          Text(english
            ? 'Account deletion is not available until the secure deletion '
              'service and public request page pass release checks.'
            : 'حذف الحساب غير مفعّل حتى تنجح اختبارات خدمة الحذف الآمنة '
              'وصفحة طلب الحذف العامة.',
            style: const TextStyle(color: Colors.deepOrange)),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmation,
          enabled: !_busy && waffraAccountDeletionReleased,
          decoration: InputDecoration(
            labelText: english ? 'Type DELETE to confirm' :
              'اكتب DELETE للتأكيد',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        FilledButton.icon(
          onPressed: WaffraHaptics.tap(!_busy && waffraAccountDeletionReleased &&
              _confirmation.text.trim() == 'DELETE' ? _perform : null),
          icon: const Icon(Icons.delete_forever),
          label: Text(english ? 'Permanently delete cloud account' :
              'حذف الحساب السحابي نهائيًا'),
        ),
      ]),
    );
  }
}
