import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// The row of hide/show toggles at the foot of a card face, optionally ending
/// with a [trailing] action such as start over.
class HideGroup extends StatelessWidget {
  const HideGroup({
    required this.side,
    required this.toggles,
    this.trailing,
    super.key,
  });

  final String side;
  final List<HideToggle> toggles;
  final HideGroupAction? trailing;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('hide-group-$side'),
    child: Row(
      children: [
        for (final toggle in toggles)
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('hide-$side-${toggle.id}'),
              child: toggle,
            ),
          ),
        if (trailing != null)
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('hide-$side-action'),
              child: trailing!,
            ),
          ),
      ],
    ),
  );
}

/// An action that sits in the hide group's row, laid out like a [HideToggle].
/// Its label wraps onto as many lines as it needs.
class HideGroupAction extends StatelessWidget {
  const HideGroupAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppSizes.radius20),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.size10,
        horizontal: AppSizes.size8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: AppSizes.space4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}

class HideToggle extends StatelessWidget {
  const HideToggle({
    required this.id,
    required this.hidden,
    required this.hideLabel,
    required this.showLabel,
    required this.onTap,
    super.key,
  });

  final String id;
  final bool hidden;
  final String hideLabel;
  final String showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppSizes.radius20),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.size10,
        horizontal: AppSizes.size8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
          const SizedBox(height: AppSizes.space4),
          Text(
            hidden ? showLabel : hideLabel,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}
