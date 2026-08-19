abstract interface class ViewerPreferencesRepository {
  Future<String> preferredSubtitleLanguage();
  Future<void> setPreferredSubtitleLanguage(String languageCode);
}

class OfflineViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  OfflineViewerPreferencesRepository({String initialLanguage = 'en'})
    : _language = initialLanguage;

  String _language;

  @override
  Future<String> preferredSubtitleLanguage() async => _language;

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {
    _language = languageCode;
  }
}

class UnavailableViewerPreferencesRepository
    implements ViewerPreferencesRepository {
  const UnavailableViewerPreferencesRepository();

  @override
  Future<String> preferredSubtitleLanguage() async => 'en';

  @override
  Future<void> setPreferredSubtitleLanguage(String languageCode) async {}
}
