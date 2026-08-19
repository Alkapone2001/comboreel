import 'package:flutter/material.dart';

class DramaSeries {
  const DramaSeries({
    required this.id,
    required this.title,
    required this.genre,
    required this.episodeLabel,
    required this.colors,
    this.progress,
    this.badge,
    this.episodeId,
    this.positionSeconds = 0,
    this.synopsis = '',
    this.releaseYear,
    this.ageRating,
    this.originalLanguage = 'en',
    this.episodeCount = 0,
    this.posterUrl,
    this.heroUrl,
  });

  final String id;
  final String title;
  final String genre;
  final String episodeLabel;
  final List<Color> colors;
  final double? progress;
  final String? badge;
  final String? episodeId;
  final int positionSeconds;
  final String synopsis;
  final int? releaseYear;
  final String? ageRating;
  final String originalLanguage;
  final int episodeCount;
  final String? posterUrl;
  final String? heroUrl;
}
