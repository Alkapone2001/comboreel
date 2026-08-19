import 'package:flutter/material.dart';

class AppArtwork extends StatelessWidget {
  const AppArtwork({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.child,
  });

  final String? source;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final value = source?.trim();
    final Widget? image = value == null || value.isEmpty
        ? null
        : value.startsWith('assets/')
        ? Image.asset(
            value,
            fit: fit,
            alignment: alignment,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : Image.network(
            value,
            fit: fit,
            alignment: alignment,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
          );
    return Stack(fit: StackFit.expand, children: [fallback, ?image, ?child]);
  }
}
