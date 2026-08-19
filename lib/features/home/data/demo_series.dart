import 'package:flutter/material.dart';

import '../domain/series.dart';

const featuredSeries = DramaSeries(
  id: 'demo-bound-by-a-secret',
  title: 'Bound by a Secret',
  genre: 'Romance  •  Mystery',
  episodeLabel: '42 bite-sized episodes',
  colors: [Color(0xFF6B233F), Color(0xFF19101C), Color(0xFF09090C)],
  badge: 'NEW SERIES',
);

const continueWatching = [
  DramaSeries(
    id: 'demo-last-promise',
    title: 'The Last Promise',
    genre: 'Romance',
    episodeLabel: 'Episode 8',
    colors: [Color(0xFF243B55), Color(0xFF141E30)],
    progress: .62,
  ),
  DramaSeries(
    id: 'demo-hidden-heir',
    title: 'Hidden Heir',
    genre: 'Drama',
    episodeLabel: 'Episode 3',
    colors: [Color(0xFF603813), Color(0xFF1D0F08)],
    progress: .31,
  ),
  DramaSeries(
    id: 'demo-after-midnight',
    title: 'After Midnight',
    genre: 'Thriller',
    episodeLabel: 'Episode 11',
    colors: [Color(0xFF42275A), Color(0xFF15121A)],
    progress: .78,
  ),
];

const trendingSeries = [
  DramaSeries(
    id: 'demo-stolen-vows',
    title: 'Stolen Vows',
    genre: 'Enemies to lovers',
    episodeLabel: '58 episodes',
    colors: [Color(0xFF8E2D56), Color(0xFF241019)],
    badge: '#1',
  ),
  DramaSeries(
    id: 'demo-the-alibi',
    title: 'The Alibi',
    genre: 'Crime thriller',
    episodeLabel: '36 episodes',
    colors: [Color(0xFF0F4C5C), Color(0xFF081B20)],
    badge: '#2',
  ),
  DramaSeries(
    id: 'demo-second-chance-ceo',
    title: 'Second Chance CEO',
    genre: 'Romance',
    episodeLabel: '64 episodes',
    colors: [Color(0xFF7B4B2A), Color(0xFF21140C)],
    badge: '#3',
  ),
];
