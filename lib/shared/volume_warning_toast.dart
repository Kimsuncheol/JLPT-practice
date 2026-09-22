import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
