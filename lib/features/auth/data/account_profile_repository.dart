import '../domain/account_profile.dart';

abstract interface class AccountProfileRepository {
  Future<AccountProfile> currentProfile();
  Future<AccountProfile> updateDisplayName(String displayName);
  Future<void> requestEmailChange(String email);
  Future<void> resendEmailConfirmation(String email);
}

class UnavailableAccountProfileRepository implements AccountProfileRepository {
  const UnavailableAccountProfileRepository();

  Never _unavailable() =>
      throw StateError('Connect ComboReel to manage your profile.');

  @override
  Future<AccountProfile> currentProfile() async => _unavailable();

  @override
  Future<void> requestEmailChange(String email) async => _unavailable();

  @override
  Future<void> resendEmailConfirmation(String email) async => _unavailable();

  @override
  Future<AccountProfile> updateDisplayName(String displayName) async =>
      _unavailable();
}
