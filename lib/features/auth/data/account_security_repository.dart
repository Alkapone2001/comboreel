abstract interface class AccountSecurityRepository {
  Stream<void> get passwordRecoveryRequests;

  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
}

class UnavailableAccountSecurityRepository
    implements AccountSecurityRepository {
  const UnavailableAccountSecurityRepository();

  @override
  Stream<void> get passwordRecoveryRequests => const Stream.empty();

  @override
  Future<void> requestPasswordReset(String email) => Future.error(
    StateError('Connect ComboReel to enable password recovery.'),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      Future.error(StateError('Connect ComboReel to update your password.'));
}
