import 'package:flutter/material.dart';
import 'package:shimmer_ai/shimmer_ai.dart';

/// A shimmering rectangular placeholder, sized to match the real
/// content (text line, card, image, ...) it stands in for while loading.
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({this.width, this.height = 14, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return const SizedBox.shrink().withShimmerAi(
      loading: true,
      width: width,
      height: height,
      borderRadius: radius,
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
    );
  }
}

/// A shimmering circular placeholder, for avatars and icon badges.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.shrink().withShimmerAi(
      loading: true,
      width: size,
      height: size,
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}
