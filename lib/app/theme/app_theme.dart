import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _ink = Color(0xFF16241D);
  static const _sage = Color(0xFF567563);
  static const _mint = Color(0xFFDDF3E5);
  static const _cream = Color(0xFFF8F5ED);
  static const _coral = Color(0xFFE9755E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: Brightness.light,
      primary: _sage,
      secondary: _coral,
      surface: const Color(0xFFFFFDF8),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: _cream,
      cardColor: const Color(0xFFFFFDF8),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _mint,
      brightness: Brightness.dark,
      primary: const Color(0xFF9FD6B4),
      secondary: const Color(0xFFFFA18C),
      surface: const Color(0xFF19211D),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF101713),
      cardColor: const Color(0xFF19211D),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'SF Pro Display',
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      extensions: const [
        AppColors(success: Color(0xFF3A7D5A), warning: Color(0xFFD57842)),
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
