import 'package:comboreel/app/comboreel_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary discovery controls expose meaningful semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(ComboReelApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Search')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Notifications')), findsOneWidget);
    expect(find.bySemanticsLabel('ComboReel home'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Watch free')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('keyboard traversal reaches and activates search', (
    tester,
  ) async {
    await tester.pumpWidget(ComboReelApp());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.byTooltip('Search'))).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Find your next obsession.'), findsOneWidget);
  });

  testWidgets('critical viewer journey supports 200 percent text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ComboReelApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final detailScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(detailScroll, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.textContaining('Season 1'), findsOneWidget);

    await tester.tap(find.textContaining('Season 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Episode 15:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
