import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/catalogue_series.dart';
import '../../home/domain/series.dart';
import '../data/viewer_library_repository.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({
    super.key,
    required this.catalogueRepository,
    required this.viewerLibraryRepository,
    required this.viewerId,
    required this.onOpenSeries,
  });

  final CatalogueRepository catalogueRepository;
  final ViewerLibraryRepository viewerLibraryRepository;
  final String? viewerId;
  final ValueChanged<DramaSeries> onOpenSeries;

  Future<List<CatalogueSeries>> _load() async {
    final id = viewerId;
    if (id == null) return [];
    final ids = await viewerLibraryRepository.favouriteSeriesIds(id);
    final catalogue = await catalogueRepository.latestSeries(limit: 100);
    return catalogue.where((item) => ids.contains(item.id)).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My List')),
    body: FutureBuilder<List<CatalogueSeries>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'My List could not load.',
              style: TextStyle(color: AppColors.coral),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final series = snapshot.data!;
        if (series.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bookmark_border_rounded,
                    size: 58,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    viewerId == null
                        ? 'Sign in to build your list'
                        : 'Your list is ready for stories',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the bookmark on a series to keep it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: series.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = series[index];
            final presentation = _presentation(item, index);
            return Card(
              color: AppColors.surface,
              child: ListTile(
                onTap: () => onOpenSeries(presentation),
                contentPadding: const EdgeInsets.all(10),
                leading: Container(
                  width: 58,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: presentation.colors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.releaseYear?.toString() ?? 'New series'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            );
          },
        );
      },
    ),
  );
}

DramaSeries _presentation(CatalogueSeries series, int index) {
  const palettes = [
    [Color(0xFF6B233F), Color(0xFF19101C)],
    [Color(0xFF0F4C5C), Color(0xFF081B20)],
  ];
  return DramaSeries(
    id: series.id,
    title: series.title,
    genre: series.originalLanguage.toUpperCase(),
    episodeLabel: series.releaseYear?.toString() ?? 'New series',
    colors: palettes[index % palettes.length],
  );
}
