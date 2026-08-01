import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class AdaptiveAdSlot extends StatefulWidget {
  const AdaptiveAdSlot({super.key});

  @override
  State<AdaptiveAdSlot> createState() => _AdaptiveAdSlotState();
}

class _AdaptiveAdSlotState extends State<AdaptiveAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdService.enabled) return;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _ad != null) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: _ad!.size.height.toDouble(),
          width: _ad!.size.width.toDouble(),
          child: AdWidget(ad: _ad!),
        ),
      );
    }
    if (AdService.enabled) return const SizedBox.shrink();
    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.strings('adDevelopment'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
