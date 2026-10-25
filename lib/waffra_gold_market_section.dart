import 'dart:async';
import 'package:flutter/material.dart';
import 'waffra_gold_market_data.dart';

/// Read-only global spot price utility under currency conversion.
/// Never touches the user's financial records or SQLCipher source.
class WaffraGoldMarketSection extends StatefulWidget {
  const WaffraGoldMarketSection({super.key, this.loadSpot, required this.english});

  final Future<WaffraGoldSpotQuote> Function()? loadSpot;
  final bool english;

  @override State<WaffraGoldMarketSection> createState() =>
      _WaffraGoldMarketSectionState();
}

class _WaffraGoldMarketSectionState extends State<WaffraGoldMarketSection> {
  static const _forest = Color(0xFF073F31);
  static const _gold = Color(0xFFD4AF37);
  static const _goldDark = Color(0xFF9E751B);
  static const _cream = Color(0xFFFFF7E3);
  static const _weights = <double>[1, 5, 10, 20, 50, 100, waffraTroyOunceGrams];

  final _weight = TextEditingController();
  WaffraGoldSpotQuote? _quote;
  String? _error;
  bool _loading = false;
  bool _allBars = false;
  int _karat = 21;
  DateTime? _lastSuccessfulRequest;

  String t(String en, String ar) => widget.english ? en : ar;
  String usd(double amount) => '\$\u00a0${amount.toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fetch());
    });
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted || _loading) return;
    // Provider changes quote every ~30s: no repeated rapid polling.
    if (_quote != null && _lastSuccessfulRequest != null &&
        DateTime.now().difference(_lastSuccessfulRequest!) <
            const Duration(seconds: 30)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.loadSpot ?? const WaffraGoldSpotService().fetch)();
      if (!mounted) return;
      if (_quote != null &&
          result.updatedAtUtc.isBefore(_quote!.updatedAtUtc)) {
        setState(() {
          _error = t('Source returned an older quote; last verified price retained.',
              'المصدر أعاد سعرًا أقدم؛ نعرض آخر سعر موثّق.');
        });
      } else {
        setState(() {
          _quote = result;
          _lastSuccessfulRequest = DateTime.now();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = t(
              'Gold prices are unavailable right now. Retry to fetch a verified quote.',
              'تعذر جلب سعر ذهب موثّق حاليًا. حاول التحديث مرة أخرى.');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _stamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year} '
        '${pad(local.hour)}:${pad(local.minute)}';
  }

  double? get _grams {
    final raw = _weight.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1000000) {
      return null;
    }
    return parsed;
  }

  Widget _barIcon({double width = 42, double height = 30}) =>
      CustomPaint(size: Size(width, height), painter: const _GoldBarPainter());

  Widget _title(String title, IconData symbol, {Widget? action}) =>
      Row(children: [
        Icon(symbol, size: 21, color: _goldDark),
        const SizedBox(width: 7),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface : _forest)),
        ),
        if (action != null) action,
      ]);

  Widget _priceCard(BuildContext context, int karat, double width) {
    final fine = waffraGoldFineness[karat]!;
    final price = _quote == null ? '—' : usd(_quote!.gramUsd(karat));
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: .28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Semantics(
              label: t('Gold purity $karat karat', 'ذهب عيار $karat'),
              child: SizedBox(
                width: 44, height: 32,
                child: Stack(alignment: Alignment.center, children: [
                  _barIcon(width: 44, height: 32),
                  Positioned(
                    bottom: 7,
                    child: Text('$karat',
                      style: const TextStyle(color: _forest,
                        fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t('Karat $karat', 'عيار $karat'),
                  maxLines: 1,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
          FittedBox(
            alignment: AlignmentDirectional.centerStart,
            fit: BoxFit.scaleDown,
            child: Text(price,
                key: Key('waffra-gold-karat-$karat-price'),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
          ),
          Text(t('USD / gram', 'دولار لكل جرام'),
              style: TextStyle(
                  fontSize: 10.5, color: Theme.of(context).hintColor)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: _cream, borderRadius: BorderRadius.circular(10)),
            child: Text(
                t('Purity ', 'نقاء ') +
                    '${(fine * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10.5, color: _goldDark)),
          ),
        ]),
      ),
    );
  }

  Widget _bullionCard(BuildContext context, double grams, double width) {
    final ounce = grams == waffraTroyOunceGrams;
    final label = ounce
        ? t('1 troy oz', 'أونصة تروي')
        : t('${grams.toInt()} g bar', 'سبيكة ${grams.toInt()} جرام');
    final price =
        _quote == null ? '—' : usd(_quote!.estimateUsd(karat: 24, grams: grams));
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: .26)),
        ),
        child: Column(children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 10),
          _barIcon(width: 48, height: 34),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(price,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          Text(t('USD · 24K spot estimate', 'دولار · تقدير خام عيار 24'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9.5, color: Theme.of(context).hintColor)),
        ]),
      ),
    );
  }

  Widget _marketSummary(BuildContext context) {
    final quote = _quote;
    final onDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        onDark ? Theme.of(context).colorScheme.onSurface : _forest;
    final updated = quote?.updatedAtUtc;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: .35)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Troy-ounce spot', 'سعر الأونصة العالمي'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(quote == null ? '—' : usd(quote.usdPerTroyOunce),
                    key: const Key('waffra-world-gold-ounce'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
              ),
            ]),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 46, color: _gold.withValues(alpha: .3)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Pure gold / gram', 'الجرام الخالص عالميًا'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(quote == null ? '—' : usd(quote.pureGramUsd),
                    key: const Key('waffra-world-gold-pure-gram'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          Icon(Icons.schedule_rounded, size: 16, color: _goldDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              updated == null
                  ? t('No verified quote yet', 'لا يوجد سعر موثّق بعد')
                  : t('Source time: ', 'آخر تحديث من المصدر: ') +
                      _stamp(updated) +
                      (quote!.isOlderThan(const Duration(hours: 72),
                              DateTime.now())
                          ? t(' · old quote', ' · سعر قديم')
                          : ''),
              style: TextStyle(
                  fontSize: 11.5, color: Theme.of(context).hintColor),
            ),
          ),
          IconButton(
            tooltip: t('Refresh gold spot quote', 'تحديث سعر الذهب'),
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh_rounded, color: _goldDark),
          ),
        ]),
      ]),
    );
  }

  Widget _calculator(BuildContext context) {
    final grams = _grams;
    final double? total =
        _quote == null || grams == null ? null :
        _quote!.estimateUsd(karat: _karat, grams: grams);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark ? Theme.of(context).cardColor : const Color(0xFFE8F4EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: .34)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(t('Estimate your gold', 'احسب قيمة ذهبك'),
            Icons.calculate_outlined),
        const SizedBox(height: 7),
        Text(
            t('Raw gold value by purity and weight at the latest source quote.',
                'قدّر قيمة الذهب الخام بالعيار والوزن حسب آخر سعر موثّق.'),
            style:
                TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('waffra-gold-calc-karat'),
              initialValue: _karat,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('Karat', 'العيار'), isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: waffraGoldFineness.keys.map((k) => DropdownMenuItem(
                value: k, child: Text(t('K$k', 'عيار $k')),
              )).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _karat = value);
              },
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              key: const Key('waffra-gold-calc-weight'),
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: t('Weight (g)', 'الوزن (جرام)'),
                  hintText: t('Enter weight', 'أدخل الوزن'), isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF4A412D) : _cream,
            border: Border.all(color: _gold.withValues(alpha: .4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.price_check_rounded, color: _goldDark),
            const SizedBox(width: 9),
            Expanded(child: Text(t('Estimated spot value', 'القيمة التقديرية'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
            Text(total == null ? '—' : usd(total),
                key: const Key('waffra-gold-calculated-value'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      key: const Key('waffra-global-gold-market-section'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: light
            ? const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFFFFF1CB), Color(0xFFF7FAF4)])
            : null,
        color: light ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52, height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _forest, borderRadius: BorderRadius.circular(15)),
            child: _barIcon(width: 39, height: 30),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Global gold prices', 'أسعار الذهب العالمية'),
                style: TextStyle(
                  color: light ? _forest : Theme.of(context).colorScheme.onSurface,
                  fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(t('Indicative spot prices by karat and gold bar',
                'تابع السعر الاسترشادي حسب العيار والسبيكة'),
                style: TextStyle(
                    fontSize: 11.5, color: Theme.of(context).hintColor)),
          ])),
        ]),
        const SizedBox(height: 16),
        _marketSummary(context),
        if (_loading) const Padding(
          padding: EdgeInsets.only(top: 10),
          child: LinearProgressIndicator(color: _goldDark)),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!,
              key: const Key('waffra-gold-quote-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
        ),
        const SizedBox(height: 18),
        _title(t('Gold karats', 'أسعار الذهب حسب العيار'),
            Icons.workspace_premium_outlined),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, size) {
          final width = (size.maxWidth - 9) / 2;
          return Wrap(spacing: 9, runSpacing: 9, children: [
            for (final karat in waffraGoldFineness.keys)
              _priceCard(context, karat, width),
          ]);
        }),
        const SizedBox(height: 20),
        _title(t('Gold bars', 'أسعار السبائك الذهبية'),
            Icons.inventory_2_outlined,
            action: TextButton(
              onPressed: () => setState(() => _allBars = !_allBars),
              child: Text(_allBars ? t('Show less', 'عرض أقل') :
                  t('See all', 'عرض الكل'),
                  style: const TextStyle(color: _goldDark)),
            )),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, size) {
          final width = (size.maxWidth - 9) / 2;
          return Wrap(spacing: 9, runSpacing: 9, children: [
            for (final weight in _allBars ? _weights : _weights.take(4))
              _bullionCard(context, weight, width),
          ]);
        }),
        const SizedBox(height: 16),
        _calculator(context),
        const SizedBox(height: 13),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 17, color: _goldDark),
          const SizedBox(width: 6),
          Expanded(child: Text(
            t(
              'Source: Gold-API · USD spot per troy ounce. Values are indicative raw gold content; retail premiums, workmanship, bid/ask spread and taxes are excluded.',
              'المصدر: Gold-API · سعر الأونصة التروي بالدولار. الأرقام قيمة الذهب الخام استرشاديًا فقط، ولا تشمل المصنعية أو فرق البيع والشراء أو الضرائب.',
            ),
            style: TextStyle(fontSize: 10.5,
                color: Theme.of(context).hintColor),
          )),
        ]),
      ]),
    );
  }
}

/// Small metallic gold bullion illustration, entirely local and lightweight.
class _GoldBarPainter extends CustomPainter {
  const _GoldBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF8C5E0A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final body = Path()
      ..moveTo(size.width * .10, size.height * .46)
      ..lineTo(size.width * .28, size.height * .16)
      ..lineTo(size.width * .82, size.height * .16)
      ..lineTo(size.width * .97, size.height * .46)
      ..lineTo(size.width * .90, size.height * .87)
      ..lineTo(size.width * .14, size.height * .87)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(colors: [
        Color(0xFFB8790A), Color(0xFFFFE59A),
        Color(0xFFFFC447), Color(0xFFB8790A),
      ]).createShader(Offset.zero & size);
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);
    final top = Path()
      ..moveTo(size.width * .28, size.height * .16)
      ..lineTo(size.width * .82, size.height * .16)
      ..lineTo(size.width * .89, size.height * .45)
      ..lineTo(size.width * .21, size.height * .45)
      ..close();
    canvas.drawPath(top, Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE69C), Color(0xFFD9A01E)],
      ).createShader(Offset.zero & size));
    canvas.drawPath(top, outline);
    final shine = Paint()
      ..color = const Color(0xFFFFF4C7).withValues(alpha: .9)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * .33, size.height * .23),
      Offset(size.width * .72, size.height * .23), shine);
  }

  @override
  bool shouldRepaint(covariant _GoldBarPainter oldDelegate) => false;
}
