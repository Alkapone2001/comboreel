class AccountDeletionPreview {
  const AccountDeletionPreview({required this.activePlatforms});
  final List<String> activePlatforms;
}

abstract interface class PrivacyRepository {
  Future<String> exportData();
  Future<AccountDeletionPreview> deletionPreview();
  Future<void> deleteAccount({
    required String password,
    required bool acknowledgedSubscriptions,
  });
}

class UnavailablePrivacyRepository implements PrivacyRepository {
  const UnavailablePrivacyRepository();
  @override
  Future<AccountDeletionPreview> deletionPreview() =>
      Future.error(StateError('Connect the backend to manage account data.'));
  @override
  Future<void> deleteAccount({
    required String password,
    required bool acknowledgedSubscriptions,
  }) => Future.error(StateError('Connect the backend to manage account data.'));
  @override
  Future<String> exportData() =>
      Future.error(StateError('Connect the backend to export account data.'));
}
