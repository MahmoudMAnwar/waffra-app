import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'diagnostics/waffra_private_release_diagnostics.dart';
import 'waffra_practical_ledger_engine.dart';

/// Five read-only tools opened from an already verified Home snapshot.
/// Neither bank SMS nor receipts are uploaded or written to any ledger here.
class WaffraPracticalToolsPage extends StatefulWidget {
  const WaffraPracticalToolsPage({
    super.key, required this.entries, required this.english,
  });
  final List<WaffraPracticalEntry> entries;
  final bool english;
  @override State<WaffraPracticalToolsPage> createState() =>
      _WaffraPracticalToolsPageState();
}

class _WaffraPracticalToolsPageState extends State<WaffraPracticalToolsPage> {
  static const green = Color(0xFF087A54);
  final query = TextEditingController();
  final opening = TextEditingController(text: '0');
  final actual = TextEditingController();
  final merchant = TextEditingController();
  final amount = TextEditingController();
  bool? incomeFilter;
  DateTimeRange? range;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime receiptDate = DateTime.now();
  XFile? pickedReceipt;
  bool receiptReviewed = false;
  WaffraSafeDiagnosticCode? userSelectedIssue;

  String t(String ar, String en) => widget.english ? en : ar;
  String cash(int minor) => (minor / 100).toStringAsFixed(2) +
      (widget.english ? ' SAR' : ' ريال');

  @override void dispose() {
    query.dispose(); opening.dispose(); actual.dispose();
    merchant.dispose(); amount.dispose(); super.dispose();
  }

  Widget section(String ar, String en, IconData icon, Widget child, Key key) =>
      Card(
        key: key, margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon, color: green),
          title: Text(t(ar, en), style: const TextStyle(fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [child],
        ),
      );

  Widget notice(String ar, String en) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(alignment: AlignmentDirectional.centerStart,
      child: Text(t(ar, en),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
  );

  Widget health() {
    final found = WaffraDataHealth.inspect(widget.entries);
    String issue(WaffraHealthIssueKind kind) => switch (kind) {
      WaffraHealthIssueKind.duplicateId => t('معرف مكرر', 'Duplicate record ID'),
      WaffraHealthIssueKind.possibleDuplicate =>
        t('عملية قد تكون مكررة', 'Potential duplicate transaction'),
      WaffraHealthIssueKind.invalidAmount => t('مبلغ غير صالح', 'Invalid amount'),
      WaffraHealthIssueKind.missingCategory =>
        t('تصنيف يحتاج مراجعة', 'Category needs review'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('نتائج للمراجعة فقط، ولن نحذف أو نغير أي معاملة.',
        'Review-only findings; no transaction will be changed or deleted.'),
      Text(t('ملاحظات: ', 'Findings: ') + found.length.toString(),
        key: const Key('m281-health-count'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      if (found.isEmpty) Text(t('لا توجد ملاحظات واضحة.', 'No obvious issues found.')),
      ...found.take(25).map((i) => ListTile(
        dense: true, title: Text(issue(i.kind)),
        subtitle: Text(t('رقم العملية: ', 'Record ID: ') + i.entryId),
      )),
      if (found.length > 25) notice('تظهر أول 25 ملاحظة فقط.',
        'First 25 findings shown.'),
    ]);
  }

  Widget advancedSearch() {
    final result = WaffraLedgerSearch.find(widget.entries,
      query: query.text, income: incomeFilter,
      start: range?.start, end: range?.end);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('البحث محلي في المعاملات المحمّلة فقط.',
        'Search loaded transactions locally only.'),
      TextField(
        key: const Key('m281-search-query'), controller: query,
        maxLength: 200, onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.search),
          hintText: t('التاجر، التصنيف أو المبلغ', 'Merchant, category or amount'),
        ),
      ),
      Wrap(spacing: 7, runSpacing: 5, children: [
        ChoiceChip(label: Text(t('الكل', 'All')), selected: incomeFilter == null,
          onSelected: (_) => setState(() => incomeFilter = null)),
        ChoiceChip(label: Text(t('دخل', 'Income')), selected: incomeFilter == true,
          onSelected: (_) => setState(() => incomeFilter = true)),
        ChoiceChip(label: Text(t('مصروف', 'Expense')), selected: incomeFilter == false,
          onSelected: (_) => setState(() => incomeFilter = false)),
        OutlinedButton.icon(icon: const Icon(Icons.date_range),
          label: Text(t('فترة زمنية', 'Date range')),
          onPressed: () async {
            final now = DateTime.now();
            final next = await showDateRangePicker(
              context: context, firstDate: DateTime(2010),
              lastDate: DateTime(now.year + 1, 12, 31),
              initialDateRange: range);
            if (next != null && mounted) setState(() => range = next);
          }),
        if (range != null) IconButton(
          tooltip: t('إزالة التاريخ', 'Remove date filter'),
          onPressed: () => setState(() => range = null),
          icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 8),
      Text(t('النتائج: ', 'Results: ') + result.length.toString(),
        key: const Key('m281-search-count')),
      ...result.take(60).map((entry) => ListTile(
        dense: true,
        title: Text(entry.title), subtitle: Text(entry.category),
        trailing: Text((entry.income ? '+' : '-') +
          entry.amount.toStringAsFixed(2),
          textDirection: TextDirection.ltr),
      )),
      if (result.length > 60) notice('أول 60 نتيجة فقط.', 'First 60 results.'),
    ]);
  }

  Future<void> pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source, imageQuality: 85, maxWidth: 2048);
      if (file == null || !mounted) return;
      setState(() { pickedReceipt = file; receiptReviewed = false; });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        t('تعذر اختيار صورة. راجع أذونات الجهاز.',
          'Cannot select image. Check device permissions.'))));
    }
  }

  Widget receiptAssistant() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('اختر صورة وراجع البيانات يدويًا. التعرف التلقائي OCR لم يُفعّل بعد.',
        'Choose a photo and review fields manually. Automatic OCR is not enabled.'),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: () => pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(t('التقاط فاتورة', 'Take receipt photo'))),
        OutlinedButton.icon(onPressed: () => pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(t('اختيار صورة', 'Choose image'))),
      ]),
      if (pickedReceipt != null) Text(t(
        'الصورة للمراجعة فقط، ولن تُضاف لمعاملة أو تُرفع للسحابة. قد يحتفظ النظام بنسخة مؤقتة.',
        'Review-only image. Not attached to a transaction or uploaded; the OS may keep a temporary copy.')),
      const SizedBox(height: 12),
      TextField(
        key: const Key('m281-receipt-merchant'), controller: merchant,
        maxLength: 250, onChanged: (_) => setState(() => receiptReviewed = false),
        decoration: InputDecoration(labelText: t('اسم المتجر', 'Merchant'),
          border: const OutlineInputBorder())),
      TextField(
        key: const Key('m281-receipt-amount'), controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => receiptReviewed = false),
        decoration: InputDecoration(labelText: t('المبلغ', 'Amount'),
          border: const OutlineInputBorder())),
      TextButton.icon(icon: const Icon(Icons.event),
        label: Text(t('تاريخ الفاتورة', 'Receipt date')),
        onPressed: () async {
          final day = await showDatePicker(context: context,
            initialDate: receiptDate, firstDate: DateTime(2010),
            lastDate: DateTime(DateTime.now().year + 1));
          if (day != null && mounted) setState(() {
            receiptDate = day; receiptReviewed = false;
          });
        }),
      FilledButton(
        onPressed: () {
          final raw = double.tryParse(amount.text.replaceAll(',', '.'));
          final draft = WaffraReceiptReviewDraft(
            amount: raw ?? double.nan,
            merchant: merchant.text, date: receiptDate);
          setState(() => receiptReviewed = draft.isValid);
        },
        child: Text(t('التحقق من بيانات الفاتورة', 'Validate receipt draft'))),
      if (receiptReviewed) Text(
        t('البيانات صالحة. لم نضف أي معاملة؛ أكدها من شاشة إضافة معاملة.',
          'Fields validated; no transaction saved. Confirm in Add Transaction.'),
        key: const Key('m281-receipt-reviewed')),
    ],
  );

  int? exactMinor(String source) {
    final value = double.tryParse(source.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value.abs() > 1e12) return null;
    final halalas = value * 100;
    if ((halalas - halalas.round()).abs() > 0.000001) return null;
    return halalas.round();
  }

  Widget monthlyClose() {
    final openingMinor = exactMinor(opening.text);
    final actualMinor = exactMinor(actual.text);
    final summary = openingMinor != null ? WaffraMonthlyClose.preview(widget.entries,
      year: month.year, month: month.month,
      openingMinor: openingMinor) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('معاينة فقط؛ لا حفظ للإقفال إلا بعد اعتماد التخزين المشفر.',
        'Preview only; month-close history requires verified encrypted storage.'),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left),
          tooltip: t('الشهر السابق', 'Previous month'),
          onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
        Text('${month.month}/${month.year}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right),
          tooltip: t('الشهر التالي', 'Next month'),
          onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
      ]),
      TextField(key: const Key('m281-opening-balance'), controller: opening,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: t('رصيد أول الشهر', 'Opening balance'),
          border: const OutlineInputBorder())),
      const SizedBox(height: 8),
      if (summary == null) Text(t('أدخل رصيدًا صحيحًا.', 'Enter a valid balance.'))
      else ...[
        Text(t('الدخل: ', 'Income: ') + cash(summary.incomeMinor)),
        Text(t('المصروفات: ', 'Expenses: ') + cash(summary.expenseMinor)),
        Text(t('عدد المعاملات: ', 'Transactions: ') +
          summary.transactionCount.toString()),
        Text(t('المتوقع: ', 'Expected closing: ') +
          cash(summary.expectedCloseMinor),
          key: const Key('m281-close-expected')),
        const SizedBox(height: 8),
        TextField(controller: actual, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: t('الرصيد الفعلي', 'Actual balance'),
            border: const OutlineInputBorder())),
        if (actualMinor != null)
          Text(t('فرق المطابقة: ', 'Reconciliation difference: ') +
            cash(summary.differenceMinor(actualMinor))),
      ],
    ]);
  }

  Widget diagnostics() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('اختر نوع المشكلة التي واجهتها. لا نجمع بيانات شخصية أو رسائل بنكية أو ملفات.',
        'Select the issue you experienced. No personal details, bank SMS or files are collected.'),
      DropdownButton<WaffraSafeDiagnosticCode>(
        key: const Key('m281-diagnostic-select'),
        isExpanded: true,
        hint: Text(t('نوع المشكلة', 'Problem category')),
        value: userSelectedIssue,
        items: WaffraSafeDiagnosticCode.values.map((code) =>
          DropdownMenuItem<WaffraSafeDiagnosticCode>(
            value: code, child: Text(code.name))).toList(),
        onChanged: (code) => setState(() => userSelectedIssue = code),
      ),
      OutlinedButton.icon(
        key: const Key('m281-copy-safe-diagnostics'),
        onPressed: userSelectedIssue == null ? null :
          () => Clipboard.setData(ClipboardData(
            text: 'Waffra issue category: ' +
              WaffraSafeDiagnosticEvent(userSelectedIssue!).safeTag)),
        icon: const Icon(Icons.copy),
        label: Text(t('نسخ رمز المشكلة المختارة فقط', 'Copy selected safe issue code')),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('أدوات وفرة الإضافية', 'Practical finance tools'))),
    body: SafeArea(child: ListView(
      key: const Key('m281-practical-tools-screen'),
      padding: const EdgeInsets.all(14), children: [
        section('مركز صحة البيانات', 'Data health center',
          Icons.health_and_safety_outlined, health(),
          const Key('m281-health-tile')),
        section('البحث الذكي الشامل', 'Advanced financial search',
          Icons.manage_search, advancedSearch(), const Key('m281-search-tile')),
        section('مساعد الفواتير', 'Receipt review assistant',
          Icons.receipt_long_outlined, receiptAssistant(),
          const Key('m281-receipt-tile')),
        section('الإقفال الشهري', 'Monthly close preview',
          Icons.calendar_month_outlined, monthlyClose(),
          const Key('m281-month-tile')),
        section('تشخيص الأعطال الآمن', 'Safe support diagnostics',
          Icons.support_agent_outlined, diagnostics(),
          const Key('m281-diagnostics-tile')),
      ],
    )),
  );
}
