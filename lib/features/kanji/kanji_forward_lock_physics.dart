import 'package:flutter/widgets.dart';

/// Lets a [PageView] scroll back freely but stops it moving forward past
/// [lockedPage], the page the learner is on until they flip its card.
class KanjiForwardLockPhysics extends ScrollPhysics {
  const KanjiForwardLockPhysics({required this.lockedPage, super.parent});

  /// Read on every scroll movement: a [Scrollable] keeps the physics it was
  /// created with, so the lock cannot be swapped by rebuilding with new physics.
  final ValueGetter<int?> lockedPage;

  @override
  KanjiForwardLockPhysics applyTo(ScrollPhysics? ancestor) =>
      KanjiForwardLockPhysics(
        lockedPage: lockedPage,
        parent: buildParent(ancestor),
      );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final locked = lockedPage();
    if (locked != null && value > position.pixels) {
      final limit = locked * position.viewportDimension;
      if (value > limit) {
        // Refuse the part of this movement that lies beyond the limit.
        return position.pixels >= limit - 0.001
            ? value - position.pixels
            : value - limit;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
