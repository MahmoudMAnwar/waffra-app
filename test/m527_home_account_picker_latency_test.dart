import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = readWaffraMainSourceForContracts();
  final start = source.indexOf('Future<void> _m467PickHomeAccount()async{');
  final end = source.indexOf('Future<void> openVerifiedAccounts()async{', start);
  final method = start < 0 || end < start ? '' : source.substring(start, end);

  test('M527 opens picker before waiting for a cold verified read', () {
    expect(start, greaterThanOrEqualTo(0));
    final modal = method.indexOf('showModalBottomSheet<String>(');
    expect(modal, greaterThan(0));
    final beforeModal = method.substring(0, modal);
    expect(beforeModal, contains('pendingAccounts=_m468VerifiedAccountsLoaded'));
    expect(beforeModal, contains(':_m467RefreshHomeAccounts();'));
    expect(beforeModal, isNot(contains('await _m467RefreshHomeAccounts()')));
    expect(method, contains("key:const Key('m527-account-picker-loading')"));
  });

  test('M527 never exposes unverified money accounts from cold cache', () {
    expect(method, contains('future:pendingAccounts'));
    expect(method, contains('if(state.connectionState!=ConnectionState.done)'));
    expect(method, contains('if(!_m468VerifiedAccountsLoaded)'));
    expect(method, contains(
        "key:const Key('m527-account-picker-verification-failed')"));
    expect(method, contains('return verifiedChoices();'));
    final failed = method.indexOf('if(!_m468VerifiedAccountsLoaded){');
    final ready = method.indexOf('return verifiedChoices();', failed);
    expect(failed, greaterThan(0));
    expect(ready, greaterThan(failed));
    expect(method.substring(failed, ready), contains('Navigator.pop(sheet)'));
  });

  test('M527 hot cache, selection and persistence remain unchanged', () {
    expect(method, contains('if(pendingAccounts==null)return verifiedChoices();'));
    expect(method, contains('WaffraHomeAccountsSheet('));
    expect(method, contains('if(next==null||!mounted)return;'));
    expect(method, contains("if(next=='manage')"));
    expect(method, contains("_m467Accounts.any((a)=>a.id==next&&!a.archived)"));
    expect(method, contains('setState(()=>_m467SelectedAccount=next)'));
    expect(method, contains('await p.setString(_m467ChoiceKey,next)'));
    expect(method, contains('if(mounted)await _m467RefreshHomeAccounts();'));
    expect(method, isNot(contains('saveCaptured(')));
    expect(method, isNot(contains('persist(')));
  });
}
