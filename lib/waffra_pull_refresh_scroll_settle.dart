import 'package:flutter/material.dart';

/// Finishes a user-initiated pull refresh at the top of its original list.
///
/// The authoritative financial read is always awaited before touching scroll
/// state. Never reset a detached list, a tab the user has since left, or the
/// financial recovery screen. This helper never reads or writes finance data.
Future<void> waffraRefreshAndRestoreScroll({
 required Future<void> Function() refresh,
 required ScrollController controller,
 required bool Function() isStillVisible,
}) async {
 await refresh();
 if(!isStillVisible()||!controller.hasClients)return;

 // Rebuild from the verified finance read before asking for the new extents.
 await WidgetsBinding.instance.endOfFrame;
 if(!isStillVisible()||!controller.hasClients)return;
 final position=controller.position;
 if(!position.hasContentDimensions)return;
 final top=position.minScrollExtent;
 if((position.pixels-top).abs()>0.5)controller.jumpTo(top);
}
