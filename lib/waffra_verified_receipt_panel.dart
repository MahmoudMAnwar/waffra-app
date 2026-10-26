import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'storage/waffra_receipt_screen_contract.dart';

import 'waffra_haptic_feedback.dart';
/// Verified SQLCipher-only receipt preview and 30-day recovery surface.
/// The caller must inject an independently verified finance authority port.
/// This widget does NOT switch finance sources or touch legacy receipt files.
class WaffraVerifiedReceiptPanel extends StatefulWidget {
  const WaffraVerifiedReceiptPanel({
    super.key,
    required this.port,
    required this.entryId,
    this.english = false,
    this.clock,
  });

  final WaffraReceiptScreenPort port;
  final String entryId;
  final bool english;
  final DateTime Function()? clock;

  @override
  State<WaffraVerifiedReceiptPanel> createState() =>
      _WaffraVerifiedReceiptPanelState();
}

class _WaffraVerifiedReceiptPanelState
    extends State<WaffraVerifiedReceiptPanel> {
  WaffraReceiptScreenState? _receipt;
  bool _busy = true;
  String? _error;
  int _page = 0;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();
  String get _loadLabel =>
      widget.english ? 'Refresh receipts' : 'تحديث المرفقات';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant WaffraVerifiedReceiptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId ||
        oldWidget.port != widget.port) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loaded = await widget.port.load(widget.entryId);
      if (!mounted || loaded.entryId != widget.entryId) return;
      setState(() {
        _receipt = loaded;
        _page = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _receipt = null;
        _error = widget.english
            ? 'Could not verify encrypted receipts. Reload to try again.'
            : 'تعذّر التحقق من المرفقات المشفرة. حاول التحديث.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final baseline = _receipt;
    if (_busy || baseline == null || !baseline.hasActiveImages) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.english
            ? 'Move attachments to recycle bin?'
            : 'نقل المرفقات إلى المحذوفة؟'),
        content: Text(widget.english
            ? 'The images can be restored for 30 days. The transaction and its amount remain unchanged.'
            : 'تقدر تسترجع الصور خلال 30 يومًا. المعاملة ومبلغها مش هيتغيروا.'),
        actions: [
          TextButton(
            onPressed: WaffraHaptics.tap(() => Navigator.pop(dialogContext, false)),
            child: Text(widget.english ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            key: const Key('confirm-encrypted-receipt-recycle'),
            onPressed: WaffraHaptics.tap(() => Navigator.pop(dialogContext, true)),
            child: Text(widget.english ? 'Confirm' : 'تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _commit(() => widget.port.moveToRecycle(
      baseline: baseline,
      userConfirmed: true,
      now: _now(),
    ));
  }

  Future<void> _restore() async {
    final baseline = _receipt;
    if (_busy || baseline == null || !baseline.isInRecycleBin) return;
    await _commit(() => widget.port.restore(
      baseline: baseline,
      now: _now(),
    ));
  }

  Future<void> _commit(
    Future<WaffraReceiptScreenState> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verified = await action();
      if (!mounted || verified.entryId != widget.entryId) return;
      setState(() {
        _receipt = verified;
        _page = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.english
          ? 'The financial or image source changed. Reload before retrying.'
          : 'بيانات المعاملة أو الصورة اتغيرت. حدّث الصفحة قبل المحاولة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final active = receipt?.hasActiveImages ?? false;
    final archived = receipt?.isInRecycleBin ?? false;
    final recoverable = archived &&
        _now().millisecondsSinceEpoch < receipt!.recoverUntilMs!;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      key: const Key('verified-encrypted-receipt-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.english ? 'Encrypted attachments' : 'المرفقات المشفرة',
            style: Theme.of(context).textTheme.titleMedium),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!,
                key: const Key('verified-receipt-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (active) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: PageView.builder(
              key: const Key('verified-encrypted-receipt-pages'),
              itemCount: receipt!.images.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (_, index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 1.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      Uint8List.fromList(receipt.images[index]),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image_outlined, color: primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${_page + 1} / ${receipt.images.length}',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('move-encrypted-receipts-to-trash'),
            onPressed: WaffraHaptics.tap(_busy ? null : _remove),
            icon: const Icon(Icons.delete_outline),
            label: Text(widget.english
                ? 'Move attachments to recycle bin'
                : 'نقل المرفقات إلى المحذوفة'),
          ),
        ] else if (archived) ...[
          const SizedBox(height: 12),
          Text(widget.english
              ? 'Attachments are in the encrypted recycle bin.'
              : 'المرفقات محفوظة في سلة المحذوفات المشفرة.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('restore-encrypted-receipts'),
            onPressed: WaffraHaptics.tap(_busy || !recoverable ? null : _restore),
            icon: const Icon(Icons.restore),
            label: Text(widget.english
                ? (recoverable ? 'Restore attachments' : 'Recovery period expired')
                : (recoverable ? 'استرجاع المرفقات' : 'انتهت مهلة الاسترجاع')),
          ),
        ] else if (!_busy && _error == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(widget.english
                ? 'No encrypted attachments for this transaction.'
                : 'ما فيه مرفقات مشفرة للمعاملة دي.'),
          ),
        TextButton.icon(
          key: const Key('refresh-encrypted-receipts'),
          onPressed: WaffraHaptics.tap(_busy ? null : _refresh),
          icon: const Icon(Icons.refresh_outlined),
          label: Text(_loadLabel),
        ),
      ],
    );
  }
}
