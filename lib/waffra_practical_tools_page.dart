import 'package:flutter/material.dart';
import 'waffra_centered_dropdown.dart';
import 'package:flutter/services.dart';

import 'diagnostics/waffra_private_release_diagnostics.dart';
import 'waffra_practical_ledger_engine.dart';
import 'waffra_amount_formatter.dart';
import 'waffra_i18n.dart';

/// Four read-only tools opened from an already verified Home snapshot.
/// Neither bank SMS nor receipts are uploaded or written to any ledger here.
class WaffraPracticalToolsPage extends StatefulWidget {
  const WaffraPracticalToolsPage({
    super.key, required this.entries, required this.english,
    this.onNotice,
    this.goalOverallocated = false,
  });
  final List<WaffraPracticalEntry> entries;
  final bool english;
  /// True only from a verified Home finance snapshot; never repaired here.
  final bool goalOverallocated;
  final ValueChanged<String>? onNotice;
  @override State<WaffraPracticalToolsPage> createState() =>
      _WaffraPracticalToolsPageState();
}

class _WaffraPracticalToolsPageState extends State<WaffraPracticalToolsPage> {
  static const green = Color(0xFF087A54);
  final query = TextEditingController();
  final opening = TextEditingController(text: '0');
  final actual = TextEditingController();
  WaffraSafeDiagnosticCode? userSelectedIssue;
  bool? incomeFilter;
  DateTimeRange? range;
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  int? openSection;
  final ScrollController sectionScroll = ScrollController();
  final sectionKeys = List.generate(4, (_) => GlobalKey());

  String t(String ar, String en) => widget.english ? en : ar;
  String cash(int minor) => (minor / 100).toStringAsFixed(2) +
      (widget.english ? ' SAR' : ' ريال');

  @override void dispose() {
    query.dispose(); opening.dispose(); actual.dispose();
    sectionScroll.dispose(); super.dispose();
  }

  void openTool(int index) {
    setState(() => openSection = openSection == index ? null : index);
    if (openSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = sectionKeys[index].currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut, alignment: 0.02);
        }
      });
    }
  }

  Widget section(int index, String ar, String en, IconData icon,
      Widget child, Key key) => Container(
        key: sectionKeys[index],
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ListTile(
              key: key,
              leading: Icon(icon, color: green),
              title: Text(t(ar, en),
                style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: Icon(openSection == index
                ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onTap: () => openTool(index),
            ),
            if (openSection == index)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                child: child),
          ]),
        ),
      );

  String diagnosticLabel(WaffraSafeDiagnosticCode code) => switch (code) {
    WaffraSafeDiagnosticCode.appStartupBlocked =>
      t('تعذر تشغيل التطبيق', 'App startup blocked'),
    WaffraSafeDiagnosticCode.financeWitnessMismatch =>
      t('عدم تطابق البيانات المالية', 'Financial data mismatch'),
    WaffraSafeDiagnosticCode.encryptedVaultCannotOpen =>
      t('تعذر فتح الخزنة المشفرة', 'Encrypted vault cannot open'),
    WaffraSafeDiagnosticCode.widgetJournalRecoveryNeeded =>
      t('مشكلة استعادة بيانات الويدجت', 'Widget data recovery needed'),
    WaffraSafeDiagnosticCode.cloudRevisionConflict =>
      t('تعارض المزامنة السحابية', 'Cloud sync conflict'),
    WaffraSafeDiagnosticCode.receiptIntegrityFailure =>
      t('مشكلة في سلامة المرفقات', 'Receipt integrity issue'),
    WaffraSafeDiagnosticCode.reportRenderFailed =>
      t('تعذر عرض التقرير', 'Report rendering failed'),
  };

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
      WaffraHealthIssueKind.unassignedNamedBudget =>
        t('مصروف غير مربوط بميزانية', 'Expense without named budget'),
      WaffraHealthIssueKind.orphanBudgetLink =>
        t('رابط ميزانية غير موجودة', 'Missing or deleted budget link'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('نتائج للمراجعة فقط، ولن نحذف أو نغير أي معاملة.',
        'Review-only findings; no transaction will be changed or deleted.'),
      if (widget.goalOverallocated)
        notice('المدخر في الأهداف أكبر من الرصيد المالي المسجل. راجع العمليات ومحفظة الأهداف.',
          'Goal savings exceed recorded net cash. Review your ledger and goals wallet.'),
      Text(t('ملاحظات: ', 'Findings: ') +
        (found.length + (widget.goalOverallocated ? 1 : 0)).toString(),
        key: const Key('m281-health-count'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      if (found.isEmpty && !widget.goalOverallocated)
        Text(t('لا توجد ملاحظات واضحة.', 'No obvious issues found.')),
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

  int? exactMinor(String source) {
    final value=waffraStrictNumericInput(source,
      decimalPlaces:2,allowZero:true,allowNegative:true,maxValue:1e12);
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
        WaffraText(t('الدخل: ', 'Income: ') + cash(summary.incomeMinor),currencyEnglish:widget.english),
        WaffraText(t('المصروفات: ', 'Expenses: ') + cash(summary.expenseMinor),currencyEnglish:widget.english),
        Text(t('عدد المعاملات: ', 'Transactions: ') +
          summary.transactionCount.toString()),
        WaffraText(t('المتوقع: ', 'Expected closing: ') +
          cash(summary.expectedCloseMinor),currencyEnglish:widget.english,
          key: const Key('m281-close-expected')),
        const SizedBox(height: 8),
        TextField(controller: actual, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: t('الرصيد الفعلي', 'Actual balance'),
            border: const OutlineInputBorder())),
        if (actualMinor != null)
          WaffraText(t('فرق المطابقة: ', 'Reconciliation difference: ') +
            cash(summary.differenceMinor(actualMinor)),currencyEnglish:widget.english),
      ],
    ]);
  }

  Widget diagnostics() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('اختر نوع المشكلة التي واجهتها. لا نجمع بيانات شخصية أو رسائل بنكية أو ملفات.',
        'Select the issue you experienced. No personal details, bank SMS or files are collected.'),
      WaffraCenteredDropdownFormField<WaffraSafeDiagnosticCode>(
        key: const Key('m281-diagnostic-select'),
        isExpanded: true,
        decoration:InputDecoration(labelText:t('نوع المشكلة', 'Problem category'),
          border:const OutlineInputBorder()),
        initialValue: userSelectedIssue,
        items: WaffraSafeDiagnosticCode.values.map((code) =>
          DropdownMenuItem<WaffraSafeDiagnosticCode>(
            value: code, child: Text(diagnosticLabel(code)))).toList(),
        onChanged: (code) => setState(() => userSelectedIssue = code),
      ),
      Align(alignment:AlignmentDirectional.centerStart,child:OutlinedButton.icon(
        key: const Key('m281-copy-safe-diagnostics'),
        onPressed: userSelectedIssue == null ? null :
          () => Clipboard.setData(ClipboardData(
            text: 'Waffra issue category: ' +
              WaffraSafeDiagnosticEvent(userSelectedIssue!).safeTag)),
        icon: const Icon(Icons.copy),
        label: Text(t('نسخ رمز المشكلة المختارة فقط', 'Copy selected safe issue code')),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('أدوات وفرة الإضافية', 'Practical finance tools'))),
    body: SafeArea(child: ListView(
      controller: sectionScroll,
      key: const Key('m281-practical-tools-screen'),
      padding: const EdgeInsets.all(14), children: [
        section(0, 'مركز صحة البيانات', 'Data health center',
          Icons.health_and_safety_outlined, health(),
          const Key('m281-health-tile')),
        section(1, 'البحث الذكي الشامل', 'Advanced financial search',
          Icons.manage_search, advancedSearch(), const Key('m281-search-tile')),
        section(2, 'الإقفال الشهري', 'Monthly close preview',
          Icons.calendar_month_outlined, monthlyClose(),
          const Key('m281-month-tile')),
        section(3, 'تشخيص الأعطال الآمن', 'Safe support diagnostics',
          Icons.support_agent_outlined, diagnostics(),
          const Key('m281-diagnostics-tile')),
      ],
    )),
  );
}
