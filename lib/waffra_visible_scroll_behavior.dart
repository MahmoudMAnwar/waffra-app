import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shows an unobtrusive, non-interactive scroll position marker on Android
/// and iOS for *every vertical Scrollable*, including nested dialog lists,
/// category pickers, long transaction forms, goals and analytics. The marker
/// is never displayed when all content fits. It does not claim the drag gesture;
/// the underlying list keeps full touch, keyboard and accessibility semantics.
///
/// Scrollbar(thumbVisibility:true) requires a uniquely attached controller,
/// which is not provided by many legacy Waffra lists. A notification-driven
/// position cue avoids attaching a second controller (or sharing a controller
/// between nested scroll views) and does not change finance/list persistence.
class WaffraVisibleScrollBehavior extends MaterialScrollBehavior {
  const WaffraVisibleScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context, Widget child, ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) {
      return super.buildScrollbar(context, child, details);
    }
    // Preserve Flutter's native draggable desktop scrollbars.
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return WaffraOverflowScrollCue(child: child);
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return super.buildScrollbar(context, child, details);
    }
  }
}

class WaffraOverflowScrollCue extends StatefulWidget {
  const WaffraOverflowScrollCue({super.key, required this.child});
  final Widget child;

  @override
  State<WaffraOverflowScrollCue> createState() =>
      _WaffraOverflowScrollCueState();
}

class _WaffraOverflowScrollCueState extends State<WaffraOverflowScrollCue> {
  double _visibleFraction = 1;
  double _progress = 0;
  double _nextVisible = 1;
  double _nextProgress = 0;
  bool _updateQueued = false;

  void _observe(ScrollMetrics m) {
    // Finite scroll metrics only: infinite/lazy unbounded content must not
    // produce NaNs, negative offsets or out-of-bounds overlay placement.
    final view = m.viewportDimension;
    final before = m.extentBefore;
    final after = m.extentAfter;
    if (!view.isFinite || !before.isFinite || !after.isFinite ||
        view <= 0 || before < 0 || after < 0) {
      _nextVisible = 1;
      _nextProgress = 0;
    } else {
      final content = view + before + after;
      if (content <= view + 6) {
        _nextVisible = 1;
        _nextProgress = 0;
      } else {
        _nextVisible = (view / content).clamp(.09, 1.0).toDouble();
        final range = before + after;
        _nextProgress = range > 0
            ? (before / range).clamp(0.0, 1.0).toDouble()
            : 0;
      }
    }
    if (_updateQueued) return;
    _updateQueued = true;
    // ScrollMetricsNotification is sent during layout, when calling setState
    // immediately would trigger a "marked dirty during build" exception.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueued = false;
      if (!mounted) return;
      if ((_visibleFraction - _nextVisible).abs() > .002 ||
          (_progress - _nextProgress).abs() > .002) {
        setState(() {
          _visibleFraction = _nextVisible;
          _progress = _nextProgress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical) {
          _observe(notification.metrics);
        }
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            _observe(notification.metrics);
          }
          return false;
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            widget.child,
            if (_visibleFraction < .999)
              PositionedDirectional(
                end: 2, top: 0, bottom: 0,
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = constraints.maxHeight;
                      if (!height.isFinite || height <= 0) {
                        return const SizedBox.shrink();
                      }
                      final thumb = math.min(
                        height, math.max(18.0, height * _visibleFraction));
                      final offset = (height - thumb) * _progress;
                      final dark =
                          Theme.of(context).brightness == Brightness.dark;
                      final color = dark
                          ? const Color(0xFF62CEA0)
                          : const Color(0xFF087A54);
                      return SizedBox(
                        width: 4,
                        height: height,
                        child: Stack(children: <Widget>[
                          Positioned(
                            top: offset, left: 0, right: 0,
                            child: Semantics(
                              label: 'Scroll position indicator',
                              child: Container(
                                key: const Key('waffra-overflow-scroll-thumb'),
                                width: 4, height: thumb,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .70),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
