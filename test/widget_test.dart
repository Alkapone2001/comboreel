import 'package:comboreel/app/comboreel_app.dart';
import 'package:comboreel/features/series/presentation/series_detail_screen.dart';
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

  testWidgets('bottom navigation preserves access to primary areas', (
    tester,
  ) async {
    await tester.pumpWidget(const ComboReelApp());

    await tester.tap(find.text('Coins'));
    await tester.pumpAndSettle();

    expect(find.text('Coins & rewards'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Your ComboReel profile'), findsOneWidget);
  });

  testWidgets('featured series opens details and starts playback', (
    tester,
  ) async {
    await tester.pumpWidget(const ComboReelApp());

    await tester.tap(find.text('My List'));
    await tester.pumpAndSettle();

    expect(find.byType(SeriesDetailScreen), findsOneWidget);

    final detailScroll = find.descendant(
      of: find.byType(SeriesDetailScreen),
      matching: find.byType(CustomScrollView),
    );
    await tester.drag(detailScroll, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Episodes'), findsOneWidget);
    expect(find.text('Start watching — Episode 1'), findsOneWidget);

    await tester.tap(find.text('Start watching — Episode 1'));
    await tester.pumpAndSettle();

    expect(find.text('EP 1 / 42'), findsOneWidget);
    expect(find.text('Next episode'), findsOneWidget);
  });
}
