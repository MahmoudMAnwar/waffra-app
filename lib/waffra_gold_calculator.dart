import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'waffra_amount_formatter.dart';
import 'waffra_gold_market_data.dart';
import 'waffra_i18n.dart';
import 'waffra_search.dart';

/// Spot quotes are USD per troy ounce (31.1034768g), NOT retail shop prices.
class WaffraGoldMath {
  static const troyOunceGrams = 31.1034768;
  static const supportedKarats = <int>[24, 22, 21, 18];

  static double perGram(double spotUsd, int karat, double usdFx) {
    if (!supportedKarats.contains(karat) || !spotUsd.isFinite ||
        !usdFx.isFinite || spotUsd <= 0 || usdFx <= 0) {
      throw const FormatException('Invalid spot, purity or FX rate');
    }
    return spotUsd * (karat / 24) * usdFx / troyOunceGrams;
  }

  static double total(double gramPrice, double grams) {
    final result = gramPrice * grams;
    if (!gramPrice.isFinite || gramPrice <= 0 || !grams.isFinite ||
        grams <= 0 || grams > 1000000 || !result.isFinite) {
      throw const FormatException('Invalid grams or amount');
    }
    return result;
  }
}

class WaffraGoldQuote {
  final double spotUsd;
  final double sarFx;
  final double currencyFx;
  final DateTime spotAt;
  final DateTime? fxAt;
  const WaffraGoldQuote(this.spotUsd, this.sarFx, this.currencyFx, this.spotAt, this.fxAt);
  double gram(int karat, {bool sar = false}) =>
      WaffraGoldMath.perGram(spotUsd, karat, sar ? sarFx : currencyFx);
}

/// Both FX legs derive from one USD-base quote. No static/invented rates.
class WaffraGoldPriceService {
  const WaffraGoldPriceService();

  Future<WaffraGoldQuote> load(String currency, {http.Client? client}) async {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Invalid currency');
    }
    final owns = client == null;
    final api = client ?? http.Client();
    try {
      // The market panel and calculator share a verified spot source.
      final gold = await const WaffraGoldSpotService().fetch(client: api);
      final price = gold.usdPerTroyOunce;
      final timestamp = gold.updatedAtUtc;
      Map rates;
      DateTime? fxAt;
      try {
        final fx = await api.get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
            .timeout(const Duration(seconds: 12));
        if (fx.statusCode != 200) throw const FormatException('Primary FX unavailable');
        final data = jsonDecode(fx.body);
        if (data is! Map || data['result'] != 'success' || data['rates'] is! Map) {
          throw const FormatException('Invalid primary FX response');
        }
        rates = data['rates'] as Map;
        if (data['time_last_update_unix'] is num) {
          fxAt = DateTime.fromMillisecondsSinceEpoch(
            (data['time_last_update_unix'] as num).toInt() * 1000, isUtc: true);
        }
      } catch (_) {
        final fx = await api.get(Uri.parse(
          'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
        )).timeout(const Duration(seconds: 12));
        if (fx.statusCode != 200) throw const FormatException('Backup FX unavailable');
        final data = jsonDecode(fx.body);
        if (data is! Map || data['usd'] is! Map) {
          throw const FormatException('Invalid backup FX response');
        }
        rates = {for (final e in (data['usd'] as Map).entries)
          e.key.toString().toUpperCase(): e.value};
        fxAt = DateTime.tryParse((data['date'] ?? '').toString());
      }

      double rate(String code) {
        if (code == 'USD') return 1;
        final value = rates[code];
        if (value is! num || !value.toDouble().isFinite || value.toDouble() <= 0) {
          throw FormatException('FX unavailable for ' + code);
        }
        return value.toDouble();
      }
      if (fxAt != null &&
          (fxAt.isAfter(DateTime.now().add(const Duration(days: 1))) ||
           DateTime.now().difference(fxAt.toUtc()) > const Duration(days: 7))) {
        throw const FormatException('Stale FX quote');
      }
      return WaffraGoldQuote(price, rate('SAR'), rate(currency), timestamp, fxAt);
    } finally {
      if (owns) api.close();
    }
  }
}

class WaffraGoldCalculatorPage extends StatefulWidget {
  final Map<String, String> arabicCurrencies;
  final Map<String, String> englishCurrencies;
  const WaffraGoldCalculatorPage({
    super.key, required this.arabicCurrencies, required this.englishCurrencies,
  });
  @override
  State<WaffraGoldCalculatorPage> createState() => _WaffraGoldCalculatorPageState();
}

class _WaffraGoldCalculatorPageState extends State<WaffraGoldCalculatorPage> {
  final TextEditingController weight = TextEditingController(text: '1');
  final service = const WaffraGoldPriceService();
  String currency = 'SAR', error = '';
  int karat = 21, revision = 0;
  bool busy = false;
  WaffraGoldQuote? quote;

  String t(String en, String ar) => waffraIsEnglish ? en : ar;
  String money(double value, String code) => value.toStringAsFixed(2) + ' ' + code;
  String stamp(DateTime d) {
    final local = d.toLocal();
    return local.day.toString() + '/' + local.month.toString() + '/' +
        local.year.toString() + ' ' + local.hour.toString().padLeft(2, '0') +
        ':' + local.minute.toString().padLeft(2, '0');
  }

  @override
  void dispose() {
    ++revision;
    weight.dispose();
    super.dispose();
  }

  Future<void> selectCurrency() async {
    final filter = TextEditingController();
    String query = '';
    try {
      final selected = await showDialog<String>(
        context: context,
        builder: (dialog) => StatefulBuilder(builder: (dialog, refresh) {
          final keys = widget.arabicCurrencies.keys.where((code) =>
              (code + ' ' + (widget.arabicCurrencies[code] ?? '') + ' ' +
               (widget.englishCurrencies[code] ?? ''))
                  .contains(waffraSearchKey(query))).toList();
          return AlertDialog(
            title: Text(t('Gold quotation currency', 'عملة تسعير الذهب')),
            content: SizedBox(width: 400, height: 400, child: Column(children: [
              TextField(controller: filter, autofocus: true,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                  hintText: t('Search currencies', 'ابحث عن العملة')),
                onChanged: (value) => refresh(() => query = value)),
              Expanded(child: ListView.builder(itemCount: keys.length,
                itemBuilder: (_, index) {
                  final code = keys[index];
                  final label = waffraIsEnglish
                      ? widget.englishCurrencies[code] : widget.arabicCurrencies[code];
                  return ListTile(title: Text((label ?? code) + ' (' + code + ')'),
                    onTap: () => Navigator.pop(dialog, code));
                })),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(dialog),
              child: Text(t('Cancel', 'إلغاء')))],
          );
        }),
      );
      if (selected != null && mounted && selected != currency) {
        ++revision;
        setState(() { currency = selected; quote = null; busy = false; error = ''; });
        unawaited(fetchQuote());
      }
    } finally { filter.dispose(); }
  }

  Future<void> fetchQuote() async {
    final grams = double.tryParse(weight.text.trim().replaceAll(',', ''));
    if (grams == null || !grams.isFinite || grams <= 0 || grams > 1000000) {
      setState(() { quote = null;
        error = t('Enter a valid positive weight in grams.',
                  'اكتب وزنًا صحيحًا بالجرام أكبر من صفر.'); });
      return;
    }
    final current = ++revision;
    final target = currency;
    setState(() { busy = true; quote = null; error = ''; });
    try {
      final value = await service.load(target);
      if (mounted && current == revision && currency == target) {
        setState(() => quote = value);
      }
    } catch (_) {
      if (mounted && current == revision) {
        setState(() => error = t('Gold/FX rates are unavailable or outdated. Retry later.',
          'أسعار الذهب أو الصرف غير متاحة أو قديمة. حاول لاحقًا.'));
      }
    } finally {
      if (mounted && current == revision) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(weight.text.trim().replaceAll(',', ''));
    final valid = quote != null && grams != null &&
        grams.isFinite && grams > 0 && grams <= 1000000;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFB2D5C2) : const Color(0xFF075C40);
    final currencyName = (waffraIsEnglish
        ? widget.englishCurrencies[currency] : widget.arabicCurrencies[currency]) ?? currency;
    return Scaffold(
      appBar: AppBar(title: Text(t('Gold price calculator', 'حاسبة أسعار الذهب'))),
      body: ListView(padding: const EdgeInsets.all(17), children: [
        Text(t('Estimate the value of gold in SAR, EGP, or any supported currency.',
               'احسب قيمة الذهب بالريال السعودي أو الجنيه المصري أو أي عملة مدعومة.')),
        const SizedBox(height: 15),
        Card(child: Padding(padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('Purity', 'عيار الذهب'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final value in WaffraGoldMath.supportedKarats)
                ChoiceChip(label: Text(t(value.toString() + 'K', 'عيار ' + value.toString())),
                  selected: value == karat,
                  onSelected: (_) => setState(() => karat = value)),
            ]),
            const SizedBox(height: 15),
            TextField(controller: weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [const WaffraAmountFormatter()],
              decoration: InputDecoration(labelText: t('Weight in grams', 'الوزن بالجرام'),
                prefixIcon: const Icon(Icons.scale_outlined),
                border: const OutlineInputBorder()),
              onChanged: (_) => setState(() => error = '')),
            const SizedBox(height: 12),
            OutlinedButton.icon(key: const Key('waffra-gold-currency-picker'),
              onPressed: busy ? null : selectCurrency,
              icon: const Icon(Icons.currency_exchange),
              label: Text(t('Show in ', 'اعرض السعر بـ ') + currencyName + ' (' + currency + ')')),
            const SizedBox(height: 10),
            FilledButton.icon(key: const Key('waffra-gold-quote-button'),
              onPressed: busy ? null : fetchQuote, icon: const Icon(Icons.refresh),
              label: Text(busy ? t('Fetching...', 'جاري جلب السعر...')
                : t('Get latest available quote', 'عرض أحدث سعر متاح'))),
          ]))),
        if (busy) const Padding(padding: EdgeInsets.all(12),
          child: LinearProgressIndicator()),
        if (error.isNotEmpty) Padding(padding: const EdgeInsets.all(10),
          child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (valid) ...[
          const SizedBox(height: 10),
          Card(color: dark ? const Color(0xFF174C3C) : const Color(0xFFE4F4EB),
            child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Estimated total', 'الإجمالي التقريبي'),
                  style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(money(WaffraGoldMath.total(quote!.gram(karat), grams), currency),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 9),
                Text(t('Saudi riyal equivalent: ', 'ما يعادله بالريال: ') +
                  money(WaffraGoldMath.total(quote!.gram(karat, sar: true), grams), 'SAR')),
                if (currency != 'SAR') Text(t('Indicative FX: 1 SAR ≈ ', 'سعر الصرف: 1 ريال ≈ ') +
                  money(quote!.currencyFx / quote!.sarFx, currency)),
              ]))),
          const SizedBox(height: 12),
          Text(t('Spot price per gram', 'سعر الجرام العالمي'),
            style: Theme.of(context).textTheme.titleMedium),
          for (final value in WaffraGoldMath.supportedKarats)
            Card(child: ListTile(
              title: Text(t(value.toString() + 'K', 'عيار ' + value.toString())),
              subtitle: Text(money(quote!.gram(value, sar: true), 'SAR')),
              trailing: Text(money(quote!.gram(value), currency),
                textDirection: TextDirection.ltr,
                style: TextStyle(fontWeight: FontWeight.bold, color: ink)))),
          const SizedBox(height: 10),
          Text(t('Gold updated: ', 'آخر تحديث للذهب: ') + stamp(quote!.spotAt)),
          if (quote!.fxAt != null)
            Text(t('FX updated: ', 'آخر تحديث للصرف: ') + stamp(quote!.fxAt!)),
        ],
        const SizedBox(height: 20),
        Text(t(
          'Sources: Gold-API USD/troy ounce; ExchangeRate-API or backup FX. '
          'Indicative spot only: no retail premiums, making charges, VAT or local taxes.',
          'المصادر: Gold-API للأونصة التروي بالدولار ومزود أسعار صرف مع احتياطي. '
          'السعر استرشادي عالمي ولا يشمل المصنعية أو هامش المحلات أو الضرائب.',
        ), style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
