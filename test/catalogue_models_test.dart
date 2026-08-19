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
      'age_rating': '16+',
      'series_genres': [
        {
          'genres': {'name': 'Romance'},
        },
        {
          'genres': {'name': 'Mystery'},
        },
      ],
      'episodes': [
        {'count': 42},
      ],
    });

    expect(series.title, 'Bound by a Secret');
    expect(series.synopsis, '');
    expect(series.originalLanguage, 'en');
    expect(series.isFeatured, isTrue);
    expect(series.ageRating, '16+');
    expect(series.genres, ['Romance', 'Mystery']);
    expect(series.episodeCount, 42);
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
      'season_id': 'season-1',
      'seasons': {'season_number': 1},
      'series': {'title': 'Bound by a Secret'},
      'synopsis': 'A warning changes the plan.',
    });

    expect(episode.episodeNumber, 6);
    expect(episode.isFree, isFalse);
    expect(episode.coinPrice, 5);
    expect(episode.seasonNumber, 1);
    expect(episode.seriesTitle, 'Bound by a Secret');
    expect(episode.synopsis, 'A warning changes the plan.');
  });
}
