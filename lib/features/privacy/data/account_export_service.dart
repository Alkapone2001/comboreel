import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

class AccountExportFile {
  AccountExportFile.fromJson(String json)
    : bytes = Uint8List.fromList(utf8.encode(json));

  static const fileName = 'comboreel-account-export.json';
  static const mimeType = 'application/json';

  final Uint8List bytes;
}

abstract interface class AccountExportService {
  const AccountExportService();

  Future<void> export(AccountExportFile file, {Rect? origin});
}

class SystemAccountExportService implements AccountExportService {
  const SystemAccountExportService();

  @override
  Future<void> export(AccountExportFile file, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'ComboReel account export',
        subject: 'ComboReel account export',
        files: [
          XFile.fromData(file.bytes, mimeType: AccountExportFile.mimeType),
        ],
        fileNameOverrides: const [AccountExportFile.fileName],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: true,
      ),
    );
  }
}
