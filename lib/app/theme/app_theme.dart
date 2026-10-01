import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class AppTheme {
  AppTheme._();

  static const _ink = AppPalette.ink;
  static const _sage = AppPalette.sage;
  static const _mint = AppPalette.mint;
  static const _cream = AppPalette.cream;
  static const _coral = AppPalette.coral;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: Brightness.light,
      primary: _sage,
      secondary: _coral,
      surface: AppPalette.surfaceLight,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: _cream,
      cardColor: AppPalette.surfaceLight,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _mint,
      brightness: Brightness.dark,
      primary: AppPalette.mintStrong,
      secondary: AppPalette.coralLight,
      surface: AppPalette.surfaceDark,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppPalette.backgroundDark,
      cardColor: AppPalette.surfaceDark,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'SF Pro Display',
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.close_rounded),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: AppSizes.font22,
          fontWeight: AppFontWeights.bold700,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: AppSizes.font36,
          height: AppSizes.lineHeight1_08,
          fontWeight: AppFontWeights.extraBold,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: AppSizes.font26,
          height: AppSizes.lineHeight1_15,
          fontWeight: AppFontWeights.bold700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontWeight: AppFontWeights.bold700),
        titleMedium: TextStyle(fontWeight: AppFontWeights.semiBold),
        bodyLarge: TextStyle(
          fontSize: AppSizes.font16,
          height: AppSizes.lineHeight1_5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.size64, AppSizes.size54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius18),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.font16,
            fontWeight: AppFontWeights.bold700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.size18,
          vertical: AppSizes.size16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.size72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurface,
            fontSize: AppSizes.font11,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        side: BorderSide.none,
      ),
      extensions: const [
        AppColors(success: AppPalette.success, warning: AppPalette.warning),
      ],
    );
  }

  static const mint = _mint;
  static const ink = _ink;
}

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.success, required this.warning});

  final Color success;
  final Color warning;

  @override
  AppColors copyWith({Color? success, Color? warning}) => AppColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
