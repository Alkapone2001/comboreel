import 'package:app_links/app_links.dart';

abstract interface class DeepLinkService {
  Stream<Uri> get links;
}

class NoopDeepLinkService implements DeepLinkService {
  const NoopDeepLinkService();
  @override
  Stream<Uri> get links => const Stream.empty();
}

class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService() : _appLinks = AppLinks();
  final AppLinks _appLinks;
  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}
