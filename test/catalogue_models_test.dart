import 'package:comboreel/features/catalogue/domain/catalogue_episode.dart';
import 'package:comboreel/features/catalogue/domain/catalogue_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue series maps nullable backend fields safely', () {
    final series = CatalogueSeries.fromJson({
      'id': 'series-1',
      'slug': 'bound-by-a-secret',
      'title': 'Bound by a Secret',
      'is_featured': true,
    });

    expect(series.title, 'Bound by a Secret');
    expect(series.synopsis, '');
    expect(series.originalLanguage, 'en');
    expect(series.isFeatured, isTrue);
  });

  test('catalogue episode preserves access and pricing metadata', () {
    final episode = CatalogueEpisode.fromJson({
      'id': 'episode-6',
      'series_id': 'series-1',
      'episode_number': 6,
      'title': 'The Warning',
      'duration_seconds': 98,
      'is_free': false,
      'coin_price': 5,
    });

    expect(episode.episodeNumber, 6);
    expect(episode.isFree, isFalse);
    expect(episode.coinPrice, 5);
  });
}
