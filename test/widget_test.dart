import 'package:comboreel/app/comboreel_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen presents the ComboReel catalogue', (tester) async {
    await tester.pumpWidget(const ComboReelApp());

    expect(find.text('ComboReel'), findsOneWidget);
    expect(find.text('Bound by a Secret'), findsOneWidget);
    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('Watch free'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Trending Now'), findsOneWidget);
  });
}
