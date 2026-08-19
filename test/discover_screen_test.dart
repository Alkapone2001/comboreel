import 'package:comboreel/features/catalogue/data/offline_catalogue_repository.dart';
import 'package:comboreel/features/discover/presentation/discover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('discover explains when a search has no matches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoverScreen(
            catalogueRepository: const OfflineCatalogueRepository(),
            onOpenSeries: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'nothing matches this');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No stories found'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
  });
}
