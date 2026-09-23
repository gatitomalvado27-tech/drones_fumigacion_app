import 'package:flutter/material.dart';

class AgroTheme {
  // ==========================================
  // PALETA MODO OSCURO (Cockpit Stitch Nocturno)
  // ==========================================
  static const Color background = Color(0xFF041710);
  static const Color surface = Color(0xFF041710);
  static const Color surfaceDim = Color(0xFF041710);
  static const Color surfaceBright = Color(0xFF293D35);
  static const Color surfaceContainerLowest = Color(0xFF01110B);
  static const Color surfaceContainerLow = Color(0xFF0B1F18);
  static const Color surfaceContainer = Color(0xFF10231C);
  static const Color surfaceContainerHigh = Color(0xFF1A2E26);
  static const Color surfaceContainerHighest = Color(0xFF253931);

  static const Color primary = Color(0xFF8FE2B8);
  static const Color primaryContainer = Color(0xFF74C69D);
  static const Color onPrimary = Color(0xFF003824);
  static const Color onPrimaryContainer = Color(0xFF005236);

  static const Color secondary = Color(0xFF95D4B3);
  static const Color secondaryContainer = Color(0xFF12533A);
  static const Color onSecondaryContainer = Color(0xFF87C6A5);

  static const Color tertiary = Color(0xFFB0DBC3);
  static const Color tertiaryContainer = Color(0xFF95BFA8);

  static const Color onSurface = Color(0xFFD1E8DC);
  static const Color onSurfaceVariant = Color(0xFFBEC9C0);
  static const Color outline = Color(0xFF88938B);
  static const Color outlineVariant = Color(0xFF3F4943);

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  // ==========================================
  // PALETA MODO CLARO (Blanco Suave y Verde Agrícola Vivo)
  // ==========================================
  // Fondo suave que reduce el deslumbramiento bajo la luz solar del campo
  static const Color lightBackground = Color(0xFFF1F5F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFE9F1EC);
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFDFECE3);
  static const Color lightSurfaceContainerHighest = Color(0xFFD4E5DA);

  // Verde agrícola vivo de alta visibilidad
  static const Color lightPrimary = Color(0xFF059669);
  static const Color lightPrimaryContainer = Color(0xFF10B981);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnPrimaryContainer = Color(0xFF02371E);

  static const Color lightSecondary = Color(0xFF047857);
  static const Color lightSecondaryContainer = Color(0xFFD1FAE5);
  static const Color lightOnSecondaryContainer = Color(0xFF065F46);

  // Textos de alto contraste en modo claro (Grafito profundo)
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF334155);
  static const Color lightOutline = Color(0xFF94A3B8);
  static const Color lightOutlineVariant = Color(0xFFCBD5E1);

  static const Color lightError = Color(0xFFDC2626);

  // Sombras ambientales
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  // Helpers de contexto
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color getBg(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color getCard(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color getPrimary(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color getText(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color getSubtext(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
  static Color getBorder(BuildContext context) => Theme.of(context).colorScheme.outlineVariant;
  static Color getSurfaceContainer(BuildContext context) => isDark(context) ? surfaceContainer : lightSurface;
  static Color getSurfaceContainerHigh(BuildContext context) => isDark(context) ? surfaceContainerHigh : lightSurfaceContainerHigh;
  static Color getSurfaceContainerHighest(BuildContext context) => isDark(context) ? surfaceContainerHighest : lightSurfaceContainerHighest;
  static List<BoxShadow> getShadow(BuildContext context) => isDark(context) ? cardShadow : lightCardShadow;

  // ==========================================
  // TEMA OSCURO
  // ==========================================
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onPrimary,
        secondaryContainer: secondaryContainer,
        surface: surfaceContainer,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        error: error,
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant, width: 0.8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceContainer,
        elevation: 0,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        labelStyle: const TextStyle(color: onSurfaceVariant),
        hintStyle: const TextStyle(color: outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      useMaterial3: true,
    );
  }

  // ==========================================
  // TEMA CLARO (Blanco y Verde Vivo)
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: lightOnPrimaryContainer,
        secondary: lightSecondary,
        onSecondary: lightOnPrimary,
        secondaryContainer: lightSecondaryContainer,
        surface: lightSurfaceContainer,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        error: lightError,
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        foregroundColor: lightOnSurface,
        titleTextStyle: TextStyle(
          color: lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceContainerLow,
        labelStyle: const TextStyle(color: lightOnSurfaceVariant),
        hintStyle: const TextStyle(color: lightOutline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightOutlineVariant, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: lightOnSurfaceVariant,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      useMaterial3: true,
    );
  }
}
