import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class ContentShareService {
  Uri publicLink(Uri deepLink);
  Future<void> share({
    required String title,
    required Uri deepLink,
    Rect? origin,
  });
}

class SystemContentShareService implements ContentShareService {
  const SystemContentShareService(this.publicAppUrl);
  final String publicAppUrl;

  @override
  Uri publicLink(Uri deepLink) {
    final base = Uri.tryParse(publicAppUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      return deepLink;
    }
    return base.replace(
      path: '/',
      queryParameters: {'deep_link': deepLink.toString()},
    );
  }

  @override
  Future<void> share({
    required String title,
    required Uri deepLink,
    Rect? origin,
  }) => SharePlus.instance.share(
    ShareParams(
      title: title,
      subject: title,
      text: '$title\n${publicLink(deepLink)}',
      sharePositionOrigin: origin,
    ),
  );
}

class NoopContentShareService implements ContentShareService {
  const NoopContentShareService();
  @override
  Uri publicLink(Uri deepLink) => deepLink;
  @override
  Future<void> share({
    required String title,
    required Uri deepLink,
    Rect? origin,
  }) async {}
}
