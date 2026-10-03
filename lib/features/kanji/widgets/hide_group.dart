import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// The row of hide/show toggles at the foot of a card face.
///
/// [morePages] adds further rows of toggles that the learner swipes to; the
/// group is then as tall as one row.
class HideGroup extends StatefulWidget {
  const HideGroup({
    required this.side,
    required this.toggles,
    this.morePages = const [],
    super.key,
  });

  final String side;
  final List<HideToggle> toggles;
  final List<List<HideToggle>> morePages;

  @override
  State<HideGroup> createState() => _HideGroupState();
}

class _HideGroupState extends State<HideGroup> {
  // Icon, its gap, the toggle's vertical padding and two label lines.
  static const _labelLines = 2;
  static const _labelLineHeight = 1.5;

  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _row(List<Widget> items) => Row(
    children: [
      for (final item in items)
        Expanded(
          child: KeyedSubtree(
            key: item is HideToggle
                ? ValueKey('hide-${widget.side}-${item.id}')
                : ValueKey('hide-${widget.side}-action'),
            child: item,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final first = <Widget>[...widget.toggles];
    if (widget.morePages.isEmpty) {
      return Container(
        key: ValueKey('hide-group-${widget.side}'),
        child: _row(first),
      );
    }
    final labelHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) *
        _labelLineHeight *
        _labelLines;
    final rowHeight = AppSizes.size10 * 2 + 24 + AppSizes.space4 + labelHeight;
    final pages = [first, ...widget.morePages];
    return Container(
      key: ValueKey('hide-group-${widget.side}'),
      child: SizedBox(
        height: rowHeight,
        child: PageView(
          controller: _controller,
          children: [
            for (final page in pages)
              Align(alignment: Alignment.topCenter, child: _row(page)),
          ],
        ),
      ),
    );
  }
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
