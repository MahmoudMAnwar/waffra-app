import 'package:flutter/material.dart';

import 'waffra_country_suggestion.dart';
import 'waffra_display_currency.dart';
import 'waffra_reminders.dart';

/// Explicit first-run currency suggestion. No finance mutation or GPS storage.
class WaffraCountryFirstRunPage extends StatefulWidget {
  const WaffraCountryFirstRunPage({
    super.key, required this.english, required this.onComplete,
    this.detectCountry, this.askNotificationPermission,
  });
  final bool english;
  final Future<String?> Function()? detectCountry;
  final Future<bool> Function()? askNotificationPermission;
  final Future<void> Function(String currencyCode, bool remindersGranted)
      onComplete;
  @override State<WaffraCountryFirstRunPage> createState() =>
      _WaffraCountryFirstRunPageState();
}

class _WaffraCountryFirstRunPageState extends State<WaffraCountryFirstRunPage> {
  static const emerald = Color(0xFF087A54);
  late String currencyCode;
  bool detecting = false, submitting = false, enableReminders = false;
  String? detectedIso, message;
  bool isError = false;
  String t(String ar, String en) => widget.english ? en : ar;

  @override void initState() {
    super.initState();
    currencyCode = WaffraDisplayCurrency.country.code;
  }

  Future<void> detect() async {
    if (detecting || submitting) return;
    setState(() { detecting = true; message = null; isError = false; });
    String? iso;
    try {
      iso = await (widget.detectCountry?.call() ??
          WaffraCountrySuggestion.detectCountry());
    } catch (_) { iso = null; }
    if (!mounted) return;
    final suggested = WaffraCountrySuggestion.currencyForIsoCountry(iso);
    setState(() {
      detecting = false;
      detectedIso = iso;
      if (suggested != null) {
        currencyCode = suggested;
        message = t(
          'تم اقتراح ${waffraCountry(suggested).label(false)} حسب بلدك. راجع الاختيار قبل المتابعة.',
          'Suggested ${waffraCountry(suggested).label(true)} from your country. Review before continuing.');
      } else {
        isError = true;
        message = t(
          'تعذر تحديد البلد أو تم رفض إذن الموقع. اختر العملة يدويًا؛ وفرة يعمل عادي.',
          'Country detection unavailable or denied. Choose currency manually; Waffra still works.');
      }
    });
  }

  Future<void> complete({bool skip = false}) async {
    if (detecting || submitting) return;
    setState(() { submitting = true; message = null; isError = false; });
    try {
      var granted = false;
      if (!skip && enableReminders) {
        try {
          granted = await (widget.askNotificationPermission?.call() ??
              WaffraReminders.requestPermission());
        } catch (_) { granted = false; }
        if (!mounted) return;
        if (!granted) {
          setState(() {
            submitting = false;
            enableReminders = false;
            isError = true;
            message = t(
              'لم يتم منح إذن الإشعارات. تابع بدون تذكيرات، أو فعّلها من صفحة المتكررة لاحقًا.',
              'Notifications not permitted. Continue without reminders; you can enable them from Recurring later.');
          });
          return;
        }
      }
      await widget.onComplete(currencyCode, granted);
    } catch (_) {
      if (mounted) setState(() {
        isError = true;
        message = t('تعذر حفظ الإعدادات. حاول مجددًا.',
          'Could not save settings. Please retry.');
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('إعداد وفرة', 'Set up Waffra'))),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(
        key: const Key('m290-country-first-run'),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          const Icon(Icons.public, size: 52, color: emerald),
          const SizedBox(height: 12),
          Text(t('خلّي وفرة يناسب بلدك', 'Make Waffra fit your country'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(t(
            'لو وافقت، هنستخدم موقع تقريبي مرة واحدة فقط لاقتراح عملة بلدك. مش بنحفظ الإحداثيات أو بنتتبع مكانك.',
            'If you agree, we use your approximate location once to suggest a currency. Coordinates are not saved or tracked.'),
            textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('m290-detect-country'),
            onPressed: detecting || submitting ? null : detect,
            icon: detecting
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.location_on_outlined),
            label: Text(detecting
              ? t('جارٍ تحديد البلد...', 'Detecting country...')
              : t('تحديد البلد بالموقع', 'Detect country using location')),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            key: const Key('m290-currency-select'),
            value: currencyCode, isExpanded: true,
            decoration: InputDecoration(
              labelText: t('عملة عرض التطبيق', 'App display currency'),
              prefixIcon: const Icon(Icons.currency_exchange),
              border: const OutlineInputBorder()),
            items: waffraCountryCurrencies.map((option) =>
              DropdownMenuItem<String>(
                value: option.code,
                child: Text(option.label(widget.english),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              )).toList(),
            onChanged: submitting ? null : (value) {
              if (value != null) setState(() {
                currencyCode = value; message = null; isError = false;
              });
            },
          ),
          const SizedBox(height: 9),
          Text(t(
            'عملة العرض لا تحوّل أرصدة المعاملات القديمة، والرسائل بعملات أخرى تحتاج مراجعة سعر الصرف.',
            'Display currency does not convert historical transactions. Foreign-currency SMS needs exchange-rate review.'),
            style: Theme.of(context).textTheme.bodySmall),
          if (message != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message!,
              key: const Key('m290-country-feedback'),
              style: TextStyle(color: isError
                ? Theme.of(context).colorScheme.error : emerald))),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            key: const Key('m290-recurring-notification-toggle'),
            contentPadding: EdgeInsets.zero,
            value: enableReminders,
            onChanged: submitting ? null :
                (enabled) => setState(() => enableReminders = enabled),
            secondary: const Icon(Icons.notifications_active_outlined,
              color: emerald),
            title: Text(t('إشعارات العمليات المتكررة',
              'Recurring payment reminders')),
            subtitle: Text(t(
              'اختياري: هنطلب إذن الإشعارات عند المتابعة. التذكيرات لا تنفذ أي مدفوعات.',
              'Optional permission request when you continue. Reminders never make payments.')),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('m290-setup-confirm'),
            onPressed: detecting || submitting ? null : complete,
            icon: const Icon(Icons.check),
            label: Text(t('حفظ الإعدادات والمتابعة', 'Save and continue'))),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('m290-setup-skip'),
            onPressed: detecting || submitting ? null :
              () => complete(skip: true),
            child: Text(t('تخطي الآن', 'Skip for now'))),
          const SizedBox(height: 8),
          Text(t('يمكنك تغيير العملة والإشعارات من الإعدادات لاحقًا.',
            'You can change currency and notifications later.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ))),
  );
}
