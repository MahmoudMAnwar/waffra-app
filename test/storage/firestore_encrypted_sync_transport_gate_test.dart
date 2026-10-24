import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_firestore_encrypted_sync_transport.dart';

void main() {
  test('cloud upload is denied until consent and independent key/source evidence', () {
    const none = WaffraCloudSyncAuthorization();
    expect(none.canUpload, isFalse);
    const onlyConsent = WaffraCloudSyncAuthorization(userConsented: true);
    expect(onlyConsent.canUpload, isFalse);
    const noRecovery = WaffraCloudSyncAuthorization(
      userConsented: true, encryptedSourceVerified: true,
      allWritersRouted: true,
    );
    expect(noRecovery.canUpload, isFalse);
    const noSource = WaffraCloudSyncAuthorization(
      userConsented: true, recoveryKeyVerified: true,
      allWritersRouted: true,
    );
    expect(noSource.canUpload, isFalse);
    const noWidget = WaffraCloudSyncAuthorization(
      userConsented: true, recoveryKeyVerified: true,
      encryptedSourceVerified: true,
    );
    expect(noWidget.canUpload, isFalse);
    const verified = WaffraCloudSyncAuthorization(
      userConsented: true, recoveryKeyVerified: true,
      encryptedSourceVerified: true, allWritersRouted: true,
    );
    expect(verified.canUpload, isTrue);
  });

  test('only server-confirmed commits count as successful publication', () {
    expect(const WaffraCloudPublishResult(
      status: WaffraCloudPublishStatus.created,
    ).confirmed, isTrue);
    expect(const WaffraCloudPublishResult(
      status: WaffraCloudPublishStatus.compareAndSwapped,
    ).confirmed, isTrue);
    expect(const WaffraCloudPublishResult(
      status: WaffraCloudPublishStatus.alreadyApplied,
    ).confirmed, isTrue);
    expect(const WaffraCloudPublishResult(
      status: WaffraCloudPublishStatus.manualConflict,
    ).confirmed, isFalse);
    expect(const WaffraCloudPublishResult(
      status: WaffraCloudPublishStatus.blocked,
    ).confirmed, isFalse);
  });
}
