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
}
