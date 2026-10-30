import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'diagnostics/waffra_private_release_diagnostics.dart';
import 'waffra_practical_ledger_engine.dart';
import 'waffra_receipt_ocr.dart';
import 'waffra_receipt_ocr_parser.dart';
import 'waffra_amount_formatter.dart';

/// Five read-only tools opened from an already verified Home snapshot.
/// Neither bank SMS nor receipts are uploaded or written to any ledger here.
class WaffraPracticalToolsPage extends StatefulWidget {
  const WaffraPracticalToolsPage({
    super.key, required this.entries, required this.english,
    this.onNotice, this.pickImage, this.scanReceipt,
  });
  final List<WaffraPracticalEntry> entries;
  final bool english;
  final ValueChanged<String>? onNotice;
  /// Optional seams for pure widget tests; production uses native OCR.
  final Future<XFile?> Function(ImageSource)? pickImage;
  final Future<WaffraReceiptOcrFields> Function(String)? scanReceipt;
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
  String? receiptPickerError;
  String? receiptValidationError;
  String? recognizedReceiptText;
  bool receiptOcrBusy = false;
  bool receiptOcrFinished = false;
  bool receiptOcrHasSuggestions = false;
  bool receiptDateRecognized = false;
  int ocrGeneration = 0;
  WaffraSafeDiagnosticCode? userSelectedIssue;
  int? openSection;
  final ScrollController sectionScroll = ScrollController();
  final sectionKeys = List.generate(5, (_) => GlobalKey());

  String t(String ar, String en) => widget.english ? en : ar;
  String cash(int minor) => (minor / 100).toStringAsFixed(2) +
      (widget.english ? ' SAR' : ' ريال');

  @override void dispose() {
    ocrGeneration++;
    query.dispose(); opening.dispose(); actual.dispose();
    merchant.dispose(); amount.dispose(); sectionScroll.dispose(); super.dispose();
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

  String ocrErrorMessage(Object error) {
    final code = error is WaffraReceiptOcrException ? error.code : '';
    return switch (code) {
      'model_download_failed' => t(
        'تعذر تنزيل ملفات اللغة. تأكد من الإنترنت ثم حاول مجددًا.',
        'Could not download OCR language files. Check internet and retry.'),
      'model_integrity_failed' => t(
        'تعذر التحقق من سلامة ملفات اللغة. أعد المحاولة.',
        'Language model verification failed. Please retry.'),
      'image_missing' => t(
        'ملف الصورة غير متاح. التقط صورة جديدة أو اخترها مرة أخرى.',
        'Image file unavailable. Choose another image.'),
      'unsupported_platform' => t(
        'قراءة الفواتير متاحة حاليًا على Android وiOS فقط.',
        'Receipt OCR currently requires Android or iOS.'),
      _ => t('تعذرت قراءة الصورة. جرّب صورة واضحة ومضاءة جيدًا.',
        'Could not read the image. Try a clear, well-lit picture.'),
    };
  }

  Future<void> pick(ImageSource source) async {
    XFile? file;
    try {
      file = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await ImagePicker().pickImage(
              source: source, imageQuality: 85, maxWidth: 2048);
    } catch (_) {
      if (!mounted) return;
      setState(() => receiptPickerError = t(
        'تعذر فتح الكاميرا أو اختيار الصورة. راجع أذونات الجهاز.',
        'Could not use camera or gallery. Check device permissions.'));
      return;
    }
    if (file == null || !mounted) return;
    final currentGeneration = ++ocrGeneration;
    setState(() {
      pickedReceipt = file;
      receiptReviewed = false;
      receiptPickerError = null;
      receiptValidationError = null;
      receiptOcrBusy = true;
      receiptOcrFinished = false;
      receiptOcrHasSuggestions = false;
      receiptDateRecognized = false;
      recognizedReceiptText = null;
      merchant.clear();
      amount.clear();
      receiptDate = DateTime.now();
    });

    try {
      // The recognized text stays in memory and is NEVER auto-saved as a
      // transaction, receipt attachment, or original bank SMS.
      final result = widget.scanReceipt != null
          ? await widget.scanReceipt!(file.path)
          : await WaffraReceiptOcr.scan(file.path);
      if (!mounted || currentGeneration != ocrGeneration) return;
      setState(() {
        receiptOcrBusy = false;
        receiptOcrFinished = true;
        receiptOcrHasSuggestions = result.hasSuggestions;
        recognizedReceiptText = result.rawText;
        if (result.merchant != null) merchant.text = result.merchant!;
        if (result.amount != null) {
          amount.text = result.amount!.toStringAsFixed(2);
        }
        if (result.date != null) {
          receiptDate = result.date!;
          receiptDateRecognized = true;
        }
      });
    } catch (error) {
      if (!mounted || currentGeneration != ocrGeneration) return;
      setState(() {
        receiptOcrBusy = false;
        receiptOcrFinished = true;
        receiptPickerError = ocrErrorMessage(error);
      });
    }
  }

  Widget receiptAssistant() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      notice('اختر فاتورة أو صوّرها. تُنزّل نماذج القراءة مرة واحدة، دون رفع الصورة. راجع قبل الحفظ.',
        'Scan a receipt. Reading models download once; your image stays on-device. Review before saving.'),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: () => pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(t('التقاط فاتورة', 'Take receipt photo'))),
        OutlinedButton.icon(onPressed: () => pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(t('اختيار صورة', 'Choose image'))),
      ]),
      if (pickedReceipt != null) notice(
        'هذه معاينة فقط: لن تُحفظ الفاتورة أو تُنشأ معاملة تلقائيًا.',
        'Preview only: no receipt or transaction is automatically saved.'),
      if (receiptOcrBusy) Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(t(
            'جاري قراءة الفاتورة واستخراج البيانات...',
            'Reading receipt and extracting details...'),
            key: const Key('m287-ocr-loading'))),
        ]),
      ),
      if (receiptPickerError != null) Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(receiptPickerError!,
          key: const Key('m281-receipt-picker-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      if (receiptOcrFinished && receiptPickerError == null)
        Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            receiptOcrHasSuggestions
              ? t('تم استخراج بيانات مبدئية. تأكد من صحتها قبل المتابعة.',
                  'Receipt details extracted. Please review their accuracy.')
              : t('لم نتمكن من تحديد الحقول تلقائيًا. راجع النص إن وُجد، أو أدخل البيانات يدويًا.',
                  'Could not identify receipt fields. Review available text or enter details manually.'),
            key: const Key('m287-ocr-result'),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          )),
      if (recognizedReceiptText != null &&
          recognizedReceiptText!.trim().isNotEmpty)
        ExpansionTile(
          key: const Key('m287-ocr-raw-text'),
          title: Text(t('النص المقروء من الفاتورة', 'Recognized receipt text')),
          children: [
            Padding(padding: const EdgeInsets.all(10),
              child: SelectableText(recognizedReceiptText!)),
          ],
        ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('m281-receipt-merchant'), controller: merchant,
        maxLength: 250, onChanged: (_) => setState(() {
          receiptReviewed = false; receiptValidationError = null;
        }),
        decoration: InputDecoration(labelText: t('اسم المتجر', 'Merchant'),
          border: const OutlineInputBorder())),
      TextField(
        key: const Key('m281-receipt-amount'), controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {
          receiptReviewed = false; receiptValidationError = null;
        }),
        decoration: InputDecoration(labelText: t('المبلغ', 'Amount'),
          border: const OutlineInputBorder())),
      Align(alignment:AlignmentDirectional.centerStart,child:TextButton.icon(icon: const Icon(Icons.event),
        label: Text(t('تاريخ الفاتورة', 'Receipt date')),
        onPressed: () async {
          final day = await showDatePicker(context: context,
            initialDate: receiptDate, firstDate: DateTime(2010),
            lastDate: DateTime(DateTime.now().year + 1));
          if (day != null && mounted) setState(() {
            receiptDate = day; receiptReviewed = false;
            receiptDateRecognized = true;
            receiptValidationError = null;
          });
        })),
      if (receiptOcrFinished && !receiptDateRecognized)
        notice('تاريخ الفاتورة لم يُحدد؛ التاريخ المعروض هو اليوم. يُرجى مراجعته.',
          'Receipt date not recognized; today is shown. Please verify it.'),
      Align(alignment:AlignmentDirectional.centerStart,child:FilledButton(
        onPressed: receiptOcrBusy ? null : () {
          final parsedAmount = WaffraReceiptOcrParser.amountFromText(
            amount.text.trim());
          final draft = WaffraReceiptReviewDraft(
            amount: parsedAmount ?? double.nan,
            merchant: merchant.text, date: receiptDate);
          setState(() {
            receiptReviewed = draft.isValid;
            receiptValidationError = draft.isValid ? null :
              t('تأكد من اسم المتجر ومبلغ موجب بدقة هللتين فقط.',
                'Enter a merchant and a positive amount with up to two decimals.');
          });
        },
        child: Text(t('التحقق من بيانات الفاتورة', 'Validate receipt draft')))),
      if (receiptValidationError != null)
        Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(receiptValidationError!,
            key: const Key('m287-receipt-validation-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (receiptReviewed) Text(
        t('البيانات صالحة. لم نضف أي معاملة؛ أكدها من شاشة إضافة معاملة.',
          'Fields validated; no transaction saved. Confirm in Add Transaction.'),
        key: const Key('m281-receipt-reviewed')),
    ],
  );

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
        section(2, 'قارئ الفواتير OCR', 'Receipt OCR scanner',
          Icons.receipt_long_outlined, receiptAssistant(),
          const Key('m281-receipt-tile')),
        section(3, 'الإقفال الشهري', 'Monthly close preview',
          Icons.calendar_month_outlined, monthlyClose(),
          const Key('m281-month-tile')),
        section(4, 'تشخيص الأعطال الآمن', 'Safe support diagnostics',
          Icons.support_agent_outlined, diagnostics(),
          const Key('m281-diagnostics-tile')),
      ],
    )),
  );
}
