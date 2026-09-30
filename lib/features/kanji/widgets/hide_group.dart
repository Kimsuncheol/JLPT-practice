import 'package:flutter/material.dart';

/// The row of hide/show toggles at the foot of a card face.
class HideGroup extends StatelessWidget {
  const HideGroup({required this.side, required this.toggles, super.key});

  final String side;
  final List<HideToggle> toggles;

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
      ],
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
    borderRadius: BorderRadius.circular(20),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
          const SizedBox(height: 4),
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
