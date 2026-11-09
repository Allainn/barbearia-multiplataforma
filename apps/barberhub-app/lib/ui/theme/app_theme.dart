import 'package:flutter/material.dart';

/// Espaçamentos do app. Telas usam estes nomes, nunca números soltos.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Raios de borda.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

/// Cores da marca. Na tela, use os papéis do `colorScheme` (primary, tertiary...),
/// que já trazem a versão certa para o tema claro e o escuro.
abstract final class AppColors {
  /// Azul-marinho de barbearia clássica: vira o `primary`.
  static const navy = Color(0xFF1F3A5F);

  /// Latão das cadeiras e navalhas antigas: vira o `tertiary` (destaques, favorito, preço).
  static const brass = Color(0xFFB8893A);
}

/// Famílias de fonte embarcadas em `assets/fonts/`.
abstract final class AppFonts {
  /// Títulos grandes (display e headline): serifada, dá o tom "barbearia clássica".
  static const display = 'DM Serif Display';

  /// Todo o resto.
  static const body = 'Manrope';
}

/// Tema claro e escuro do BarberHub (Material 3), gerados das cores da marca.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme scheme(Brightness brightness) {
    // O latão gera um esquema próprio, e os papéis "primary" dele viram o "tertiary"
    // do app: assim o container e o texto sobre ele continuam com contraste certo.
    final brass = ColorScheme.fromSeed(
      seedColor: AppColors.brass,
      brightness: brightness,
    );
    return ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
    ).copyWith(
      tertiary: brass.primary,
      onTertiary: brass.onPrimary,
      tertiaryContainer: brass.primaryContainer,
      onTertiaryContainer: brass.onPrimaryContainer,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(platform: TargetPlatform.android)
        .englishLike
        .apply(
          fontFamily: AppFonts.body,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    TextStyle? serif(TextStyle? style) =>
        style?.copyWith(fontFamily: AppFonts.display, letterSpacing: 0);
    return base.copyWith(
      displayLarge: serif(base.displayLarge),
      displayMedium: serif(base.displayMedium),
      displaySmall: serif(base.displaySmall),
      headlineLarge: serif(base.headlineLarge),
      headlineMedium: serif(base.headlineMedium),
      headlineSmall: serif(base.headlineSmall),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = AppTheme.scheme(brightness);
    final text = _textTheme(scheme);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
