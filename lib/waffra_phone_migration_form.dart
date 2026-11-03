import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'waffra_phone_secure_auth.dart';

/// M425: In-place migration for an already authenticated legacy account.
///
/// A Google/Apple account MUST be signed in under its original Firebase UID
/// before this page is accessible. Linking a PhoneAuthCredential does not
/// create or remap ledger owners. Never deletes any old profile or backup.
class WaffraPhoneMigrationForm extends StatefulWidget {
  const WaffraPhoneMigrationForm({
    super.key,
    required this.english,
    required this.initialPhone,
    required this.onMigrated,
  });
  final bool english;
  final String initialPhone;
  final Future<void> Function(String phone, String originalUid) onMigrated;
  @override
  State<WaffraPhoneMigrationForm> createState() =>
      _WaffraPhoneMigrationFormState();
}

class _WaffraPhoneMigrationFormState
    extends State<WaffraPhoneMigrationForm> {
  late final TextEditingController phone;
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<String?> _requestCode() async {
    final input = TextEditingController();
    try {
      return await showDialog<String>(context: context, builder: (ctx) =>
        AlertDialog(
          title: Text(widget.english ?
            'Verify the number you own' : 'تأكيد ملكية رقم الجوال'),
          content: TextField(controller: input,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: widget.english ? 'SMS code' : 'رمز التحقق',
              hintText: '000000',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(widget.english ? 'Cancel' : 'إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx,input.text.trim()),
              child: Text(widget.english ? 'Verify' : 'تأكيد')),
          ],
        ));
    } finally {
      // TextField is disposed after dialog completes its transition.
      WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    }
  }

  Future<void> migrate() async {
    if (busy) return;
    setState(() => message = null);
    if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone.text.trim()) ||
        password.text.length < 8 || password.text.length > 128 ||
        password.text != confirmation.text) {
      setState(() => message = widget.english
        ? 'Enter a Saudi 05 mobile and matching password of 8+ characters.'
        : 'أدخل رقم جوال سعودي يبدأ بـ05 وكلمة مرور ٨ خانات متطابقة.');
      return;
    }
    final originalUid = WaffraPhoneSecureAuth.currentUid;
    if (originalUid == null) {
      setState(() => message = widget.english
        ? 'Sign in with your original account first.'
        : 'سجّل الدخول بحسابك القديم أولًا.');
      return;
    }
    setState(() => busy = true);
    try {
      final linkedUid = await WaffraPhoneSecureAuth.enrollWithOtp(
        phone: phone.text.trim(),
        password: password.text,
        requestCode: _requestCode,
      );
      if (linkedUid != originalUid) {
        throw StateError('uid_changed_during_migration');
      }
      await widget.onMigrated(phone.text.trim(),linkedUid);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => message = widget.english
        ? 'We could not confirm migration. Your old finance data was not deleted.'
        : 'تعذر تأكيد نقل الحساب. بياناتك المالية القديمة لم تُحذف.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.english ?
      'Keep your account and move to phone' : 'نقل الحساب القديم إلى الجوال')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(22),children:[
      Text(widget.english
        ? 'Confirm your existing account, then link a Saudi phone with OTP. '
          'Your original Firebase account identity and saved finance stay unchanged.'
        : 'هنربط رقم جوال سعودي بحسابك القديم بعد رمز التحقق. '
          'هوية الحساب وبياناتك المالية المحفوظة تفضل كما هي.'),
      const SizedBox(height: 18),
      TextField(controller: phone,
        keyboardType: TextInputType.phone,textDirection: TextDirection.ltr,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(
          labelText: widget.english ? 'Saudi mobile' : 'رقم الجوال السعودي',
          hintText: '05XXXXXXXX',border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: password,obscureText:true,
        decoration: InputDecoration(
          labelText: widget.english ? 'New password' : 'كلمة المرور الجديدة',
          border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: confirmation,obscureText:true,
        decoration: InputDecoration(
          labelText: widget.english ? 'Confirm password' : 'تأكيد كلمة المرور',
          border: const OutlineInputBorder())),
      if(message != null) Padding(padding: const EdgeInsets.only(top:12),
        child: Text(message!,style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: busy ? null : migrate,
        icon:const Icon(Icons.verified_user),
        label: Text(busy
            ? (widget.english ? 'Verifying…' : 'جارٍ التحقق…')
            : (widget.english ? 'Verify and migrate' : 'التحقق ونقل الحساب'))),
    ])),
  );
}
