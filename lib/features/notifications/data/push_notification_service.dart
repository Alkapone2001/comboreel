abstract interface class PushNotificationService {
  bool get available;
  Stream<Uri> get deepLinks;
  Future<bool> enabled();
  Future<void> setEnabled(bool enabled);
}

class UnavailablePushNotificationService implements PushNotificationService {
  const UnavailablePushNotificationService();
  @override
  bool get available => false;
  @override
  Stream<Uri> get deepLinks => const Stream.empty();
  @override
  Future<bool> enabled() async => false;
  @override
  Future<void> setEnabled(bool enabled) =>
      throw StateError('Push notifications are not configured.');
}
