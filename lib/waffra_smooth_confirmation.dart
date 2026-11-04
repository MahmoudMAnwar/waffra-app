import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// UI-only feedback for a verified asynchronous confirmation. It never edits
/// ledger data, retries failed writes, or reports success before the writer.
class WaffraSmoothOperationController extends ChangeNotifier {
  final Map<int, String> _operations = <int, String>{};
  int _nextId = 0;
  bool _isDisposed = false;

  bool get busy => _operations.isNotEmpty;
  int get pendingOperations => _operations.length;
  String get label => _operations.isEmpty ? '' : _operations.values.last;

  /// A visible frame is scheduled BEFORE a potentially expensive async write.
  /// The underlying future stays authoritative; exceptions propagate and the
  /// busy overlay clears even when the writer throws.
  Future<T> track<T>(String description, Future<T> Function() action) async {
    if (_isDisposed) throw StateError('Operation controller is disposed');
    final id = ++_nextId;
    _operations[id] = description;
    notifyListeners();
    try {
      await SchedulerBinding.instance.endOfFrame;
      return await action();
    } finally {
      _operations.remove(id);
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operations.clear();
    super.dispose();
  }
}

/// Repaint-isolated lightweight loading surface; no blur or per-frame Home
/// rebuilding. It blocks repeat input until the awaited confirmation ends.
class WaffraSmoothConfirmationOverlay extends StatelessWidget {
  const WaffraSmoothConfirmationOverlay({
    super.key, required this.controller, required this.english,
  });

  final WaffraSmoothOperationController controller;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final busy = controller.busy;
        return IgnorePointer(
          ignoring: !busy,
          child: AnimatedSwitcher(
            duration: reduced ? Duration.zero :
                const Duration(milliseconds: 170),
            reverseDuration: reduced ? Duration.zero :
                const Duration(milliseconds: 130),
            child: busy ? Stack(
              key: const ValueKey('waffra-saving-in-progress'),
              fit: StackFit.expand,
              children: [
                const ModalBarrier(
                  color: Color(0x66000000),
                  dismissible: false,
                ),
                Center(
                  child: RepaintBoundary(
                    child: Material(
                      key: const Key('waffra-smooth-save-indicator'),
                      elevation: 7,
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 23, vertical: 19),
                        child: Semantics(
                          liveRegion: true,
                          label: english ? 'Saving changes' :
                              'جارٍ حفظ التغييرات',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Text(
                                english ? 'Saving changes…' :
                                    'جارٍ حفظ التغييرات…',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ) : const SizedBox.shrink(
              key: ValueKey('waffra-saving-idle'),
            ),
          ),
        );
      },
    );
  }
}
