import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class RewardedXpCard extends ConsumerStatefulWidget {
  const RewardedXpCard({super.key});

  @override
  ConsumerState<RewardedXpCard> createState() => _RewardedXpCardState();
}

class _RewardedXpCardState extends ConsumerState<RewardedXpCard> {
  bool _loading = false;

  Future<void> _watchAd() async {
    setState(() => _loading = true);
    final earned = await AdService.showRewarded();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!earned) return;
    await ref
        .read(appControllerProvider.notifier)
        .addBonusXp(AdService.rewardedXpAmount);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '+${AdService.rewardedXpAmount} XP · ${context.strings('xpEarned')}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.enabled) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _loading ? null : _watchAd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings('earnBonusXp'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '+${AdService.rewardedXpAmount} XP',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.play_circle_fill_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
