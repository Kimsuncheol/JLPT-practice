import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

const volumeWarningToastDuration = Duration(seconds: 3);

/// Shows volume feedback as a short-lived toast instead of a snackbar.
void showVolumeWarningToast(BuildContext context, String message) {
  final toast = FToast().init(context);
  // A repeated tap should refresh the warning, rather than queue several of
  // the same warning for the user to wait through.
  toast.removeQueuedCustomToasts();
  toast.showToast(
    toastDuration: volumeWarningToastDuration,
    fadeDuration: const Duration(milliseconds: 150),
    gravity: ToastGravity.BOTTOM,
    ignorePointer: true,
    child: Material(
      key: const ValueKey('volume-warning-toast'),
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppSizes.radius24),
          boxShadow: const [
            BoxShadow(
              color: AppPalette.shadow20,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.size18,
            vertical: AppSizes.size12,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ),
      ),
    ),
  );
}
