import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class MitlistTheme {
  static const double radiusNone = 0;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusFull = 9999;

  static const Cubic easeMicro = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Cubic easePage = Cubic(0.4, 0.0, 0.6, 1.0);
  static const Cubic easeToast = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Cubic easeSettle = Cubic(0.25, 1.0, 0.5, 1.0);

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: MitlistColors.primary500,
      onPrimary: MitlistColors.textOnPrimary,
      primaryContainer: MitlistColors.primary100,
      onPrimaryContainer: MitlistColors.primary950,
      secondary: MitlistColors.neutral700,
      onSecondary: MitlistColors.textOnPrimary,
      secondaryContainer: MitlistColors.surfaceSecondary,
      onSecondaryContainer: MitlistColors.textPrimary,
      tertiary: MitlistColors.neutral500,
      onTertiary: MitlistColors.textOnPrimary,
      tertiaryContainer: MitlistColors.neutral200,
      onTertiaryContainer: MitlistColors.neutral900,
      error: MitlistColors.error500,
      onError: MitlistColors.textOnError,
      errorContainer: MitlistColors.error50,
      onErrorContainer: MitlistColors.error900,
      surface: MitlistColors.surfaceSoft,
      onSurface: MitlistColors.textPrimary,
      surfaceContainerHighest: MitlistColors.surfaceSecondary,
      onSurfaceVariant: MitlistColors.textSecondary,
      outline: MitlistColors.borderPrimary,
      outlineVariant: MitlistColors.borderSecondary,
      shadow: MitlistColors.neutral950,
      scrim: MitlistColors.scrimLight,
      inverseSurface: MitlistColors.neutral950,
      onInverseSurface: MitlistColors.surfaceSoft,
      inversePrimary: MitlistColors.primary100,
      surfaceTint: MitlistColors.primary500,
    );

    final textTheme = MitlistTypography.lightTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: MitlistColors.surfaceSoft,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MitlistColors.surfaceSoft,
        foregroundColor: MitlistColors.textPrimary,
        titleTextStyle: textTheme.headlineSmall,
        shape: const Border(
          bottom: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MitlistColors.surfacePrimary,
        selectedItemColor: MitlistColors.primary700,
        unselectedItemColor: MitlistColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
      cardTheme: CardThemeData(
        color: MitlistColors.surfacePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MitlistColors.primary500,
          foregroundColor: MitlistColors.neutral950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: MitlistColors.borderPrimary, width: 2),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return MitlistColors.primary600;
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MitlistColors.primary700,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: MitlistColors.borderPrimary, width: 2),
          backgroundColor: MitlistColors.surfacePrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MitlistColors.primary700,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MitlistColors.surfacePrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.primary500, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.error500, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.error500, width: 2),
        ),
        labelStyle: textTheme.labelMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: MitlistColors.textTertiary),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: MitlistColors.error600,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MitlistColors.surfacePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: MitlistColors.surfacePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MitlistColors.borderSecondary,
        thickness: 2,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MitlistColors.neutral950,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: MitlistColors.textOnPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MitlistColors.surfacePrimary,
        selectedColor: MitlistColors.neutral950,
        secondarySelectedColor: MitlistColors.neutral950,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        labelStyle: textTheme.labelSmall,
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(color: MitlistColors.textOnPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        side: const BorderSide(color: MitlistColors.borderPrimary, width: 2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MitlistColors.primary500;
          }
          return MitlistColors.surfacePrimary;
        }),
        side: const BorderSide(color: MitlistColors.borderPrimary, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MitlistColors.primary500,
        foregroundColor: MitlistColors.neutral950,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: MitlistColors.primary400,
      onPrimary: MitlistColors.neutral950,
      primaryContainer: MitlistColors.primary900,
      onPrimaryContainer: MitlistColors.primary100,
      secondary: MitlistColors.neutral300,
      onSecondary: MitlistColors.neutral950,
      secondaryContainer: MitlistColors.neutral800,
      onSecondaryContainer: MitlistColors.surfaceSoft,
      tertiary: MitlistColors.neutral500,
      onTertiary: MitlistColors.neutral950,
      tertiaryContainer: MitlistColors.neutral700,
      onTertiaryContainer: MitlistColors.surfaceSoft,
      error: MitlistColors.error400,
      onError: MitlistColors.neutral950,
      errorContainer: MitlistColors.error900,
      onErrorContainer: MitlistColors.error50,
      surface: MitlistColors.neutral950,
      onSurface: MitlistColors.surfaceSoft,
      surfaceContainerHighest: MitlistColors.neutral900,
      onSurfaceVariant: MitlistColors.neutral300,
      outline: MitlistColors.surfaceSoft,
      outlineVariant: MitlistColors.neutral800,
      shadow: MitlistColors.neutral950,
      scrim: MitlistColors.scrimDark,
      inverseSurface: MitlistColors.surfaceSoft,
      onInverseSurface: MitlistColors.neutral950,
      inversePrimary: MitlistColors.primary700,
      surfaceTint: MitlistColors.primary400,
    );

    final textTheme = MitlistTypography.darkTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: MitlistColors.neutral950,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MitlistColors.neutral950,
        foregroundColor: MitlistColors.surfaceSoft,
        titleTextStyle: textTheme.headlineSmall,
        shape: const Border(
          bottom: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MitlistColors.neutral900,
        selectedItemColor: MitlistColors.primary400,
        unselectedItemColor: MitlistColors.neutral400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
      cardTheme: CardThemeData(
        color: MitlistColors.neutral900,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MitlistColors.primary400,
          foregroundColor: MitlistColors.neutral950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: MitlistColors.surfaceSoft, width: 2),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MitlistColors.primary300,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: MitlistColors.surfaceSoft, width: 2),
          backgroundColor: MitlistColors.neutral900,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MitlistColors.primary300,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MitlistColors.neutral900,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.primary400, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.error400, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: MitlistColors.error400, width: 2),
        ),
        labelStyle: textTheme.labelMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: MitlistColors.neutral500),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: MitlistColors.error400,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MitlistColors.neutral900,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: MitlistColors.neutral900,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MitlistColors.neutral800,
        thickness: 2,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MitlistColors.surfaceSoft,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: MitlistColors.neutral950),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MitlistColors.neutral900,
        selectedColor: MitlistColors.surfaceSoft,
        secondarySelectedColor: MitlistColors.surfaceSoft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        labelStyle: textTheme.labelSmall,
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(color: MitlistColors.neutral950),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        side: const BorderSide(color: MitlistColors.surfaceSoft, width: 2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MitlistColors.primary400;
          }
          return MitlistColors.neutral900;
        }),
        side: const BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MitlistColors.primary400,
        foregroundColor: MitlistColors.neutral950,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MitlistColors.surfaceSoft, width: 2),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
