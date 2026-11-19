import 'package:flutter/material.dart';
import 'theme_controller.dart';

class AgroTheme {
  // ==========================================
  // CONSTANTES BASE (Compatibilidad retroactiva)
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

  static const Color lightBackground = Color(0xFFF3F6F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFECF2EE);
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFE3ECE6);
  static const Color lightSurfaceContainerHighest = Color(0xFFD6E4DB);

  static const Color lightPrimary = Color(0xFF059669);
  static const Color lightPrimaryContainer = Color(0xFF10B981);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnPrimaryContainer = Color(0xFF02371E);

  static const Color lightSecondary = Color(0xFF047857);
  static const Color lightSecondaryContainer = Color(0xFFD1FAE5);
  static const Color lightOnSecondaryContainer = Color(0xFF065F46);

  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);
  static const Color lightOutline = Color(0xFF94A3B8);
  static const Color lightOutlineVariant = Color(0xFFCBD5E1);
  static const Color lightError = Color(0xFFDC2626);

  // Sombras ambientales
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
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

  // ==========================================
  // HELPERS DINÁMICOS DE CONTEXTO (Usar siempre)
  // ==========================================
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color getBg(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color getCard(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color getPrimary(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color getSecondary(BuildContext context) => Theme.of(context).colorScheme.secondary;
  static Color getError(BuildContext context) => Theme.of(context).colorScheme.error;
  static Color getText(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color getSubtext(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
  static Color getBorder(BuildContext context) => Theme.of(context).colorScheme.outlineVariant;
  static Color getSurfaceContainer(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color getSurfaceContainerHigh(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;
  static Color getSurfaceContainerHighest(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  static List<BoxShadow> getShadow(BuildContext context) =>
      isDark(context) ? cardShadow : lightCardShadow;

  // ==========================================
  // GENERADOR GLOBAL DE PALETAS
  // ==========================================
  static ThemeData construirTema({
    required PaletaApp paleta,
    Color customPrimary = const Color(0xFF10B981),
    Color customSecondary = const Color(0xFF38BDF8),
    bool customDark = true,
  }) {
    switch (paleta) {
      case PaletaApp.verdeAgricola:
        return _buildThemeData(
          brightness: Brightness.dark,
          bg: background,
          surface: surfaceContainer,
          surfaceLow: surfaceContainerLow,
          surfaceHigh: surfaceContainerHigh,
          surfaceHighest: surfaceContainerHighest,
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: primaryContainer,
          onPrimaryContainer: onPrimaryContainer,
          secondary: secondary,
          secondaryContainer: secondaryContainer,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          outlineVariant: outlineVariant,
          error: error,
        );

      case PaletaApp.oscuroProfesional:
        return _buildThemeData(
          brightness: Brightness.dark,
          bg: const Color(0xFF111315),
          surface: const Color(0xFF1A1D21),
          surfaceLow: const Color(0xFF15181B),
          surfaceHigh: const Color(0xFF23272C),
          surfaceHighest: const Color(0xFF2C3138),
          primary: const Color(0xFF22C55E),
          onPrimary: const Color(0xFF052E16),
          primaryContainer: const Color(0xFF16A34A),
          onPrimaryContainer: const Color(0xFFECFDF5),
          secondary: const Color(0xFF4ADE80),
          secondaryContainer: const Color(0xFF14532D),
          onSurface: const Color(0xFFF1F5F9),
          onSurfaceVariant: const Color(0xFF94A3B8),
          outline: const Color(0xFF64748B),
          outlineVariant: const Color(0xFF334155),
          error: const Color(0xFFF87171),
        );

      case PaletaApp.modoClaro:
        return _buildThemeData(
          brightness: Brightness.light,
          bg: lightBackground,
          surface: lightSurfaceContainer,
          surfaceLow: lightSurfaceContainerLow,
          surfaceHigh: lightSurfaceContainerHigh,
          surfaceHighest: lightSurfaceContainerHighest,
          primary: lightPrimary,
          onPrimary: lightOnPrimary,
          primaryContainer: lightPrimaryContainer,
          onPrimaryContainer: lightOnPrimaryContainer,
          secondary: lightSecondary,
          secondaryContainer: lightSecondaryContainer,
          onSurface: lightOnSurface,
          onSurfaceVariant: lightOnSurfaceVariant,
          outline: lightOutline,
          outlineVariant: lightOutlineVariant,
          error: lightError,
        );

      case PaletaApp.azulTecnologico:
        return _buildThemeData(
          brightness: Brightness.dark,
          bg: const Color(0xFF081220),
          surface: const Color(0xFF101E33),
          surfaceLow: const Color(0xFF0C1728),
          surfaceHigh: const Color(0xFF172A45),
          surfaceHighest: const Color(0xFF1F385A),
          primary: const Color(0xFF38BDF8),
          onPrimary: const Color(0xFF04263B),
          primaryContainer: const Color(0xFF0284C7),
          onPrimaryContainer: const Color(0xFFE0F2FE),
          secondary: const Color(0xFF60A5FA),
          secondaryContainer: const Color(0xFF1E3A5F),
          onSurface: const Color(0xFFE2E8F0),
          onSurfaceVariant: const Color(0xFF94A3B8),
          outline: const Color(0xFF64748B),
          outlineVariant: const Color(0xFF284266),
          error: const Color(0xFFFCA5A5),
        );

      case PaletaApp.personalizado:
        final primLum = customPrimary.computeLuminance();
        final onPrim = primLum > 0.45 ? const Color(0xFF0F172A) : Colors.white;
        if (customDark) {
          final bgTint = Color.alphaBlend(
            customPrimary.withValues(alpha: 0.06),
            const Color(0xFF0F1216),
          );
          final surfTint = Color.alphaBlend(
            customPrimary.withValues(alpha: 0.08),
            const Color(0xFF171C22),
          );
          final surfHighTint = Color.alphaBlend(
            customPrimary.withValues(alpha: 0.11),
            const Color(0xFF202730),
          );
          return _buildThemeData(
            brightness: Brightness.dark,
            bg: bgTint,
            surface: surfTint,
            surfaceLow: bgTint,
            surfaceHigh: surfHighTint,
            surfaceHighest: Color.alphaBlend(customPrimary.withValues(alpha: 0.15), const Color(0xFF28313D)),
            primary: customPrimary,
            onPrimary: onPrim,
            primaryContainer: customPrimary,
            onPrimaryContainer: onPrim,
            secondary: customSecondary,
            secondaryContainer: customSecondary.withValues(alpha: 0.22),
            onSurface: const Color(0xFFF1F5F9),
            onSurfaceVariant: const Color(0xFFA0AEC0),
            outline: const Color(0xFF64748B),
            outlineVariant: const Color(0xFF334155),
            error: const Color(0xFFF87171),
          );
        } else {
          final bgTint = Color.alphaBlend(
            customPrimary.withValues(alpha: 0.04),
            const Color(0xFFF6F8FA),
          );
          return _buildThemeData(
            brightness: Brightness.light,
            bg: bgTint,
            surface: Colors.white,
            surfaceLow: Color.alphaBlend(customPrimary.withValues(alpha: 0.06), const Color(0xFFF1F5F9)),
            surfaceHigh: Color.alphaBlend(customPrimary.withValues(alpha: 0.10), const Color(0xFFE2E8F0)),
            surfaceHighest: Color.alphaBlend(customPrimary.withValues(alpha: 0.14), const Color(0xFFD8E1EC)),
            primary: customPrimary,
            onPrimary: onPrim,
            primaryContainer: customPrimary,
            onPrimaryContainer: onPrim,
            secondary: customSecondary,
            secondaryContainer: customSecondary.withValues(alpha: 0.18),
            onSurface: const Color(0xFF0F172A),
            onSurfaceVariant: const Color(0xFF475569),
            outline: const Color(0xFF94A3B8),
            outlineVariant: const Color(0xFFCBD5E1),
            error: const Color(0xFFDC2626),
          );
        }
    }
  }

  static ThemeData _buildThemeData({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceLow,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color secondaryContainer,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color error,
  }) {
    final isDarkMode = brightness == Brightness.dark;
    final colorScheme = isDarkMode
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: onPrimary,
            primaryContainer: primaryContainer,
            onPrimaryContainer: onPrimaryContainer,
            secondary: secondary,
            onSecondary: onPrimary,
            secondaryContainer: secondaryContainer,
            surface: surface,
            surfaceContainerLow: surfaceLow,
            surfaceContainerHigh: surfaceHigh,
            surfaceContainerHighest: surfaceHighest,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            outline: outline,
            outlineVariant: outlineVariant,
            error: error,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: onPrimary,
            primaryContainer: primaryContainer,
            onPrimaryContainer: onPrimaryContainer,
            secondary: secondary,
            onSecondary: onPrimary,
            secondaryContainer: secondaryContainer,
            surface: surface,
            surfaceContainerLow: surfaceLow,
            surfaceContainerHigh: surfaceHigh,
            surfaceContainerHighest: surfaceHighest,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            outline: outline,
            outlineVariant: outlineVariant,
            error: error,
          );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineVariant, width: isDarkMode ? 0.8 : 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode ? surfaceHigh : surfaceLow,
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: outline),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? primaryContainer : primary,
          foregroundColor: isDarkMode ? onPrimaryContainer : onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant, width: 0.8),
        ),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDarkMode ? surfaceHigh : surfaceLow,
        selectedColor: primary.withValues(alpha: 0.2),
        side: BorderSide(color: outlineVariant.withValues(alpha: 0.6)),
        labelStyle: TextStyle(color: onSurface, fontSize: 12),
      ),
      useMaterial3: true,
    );
  }

  // Getters heredados por compatibilidad
  static ThemeData get darkTheme => construirTema(paleta: PaletaApp.verdeAgricola);
  static ThemeData get lightTheme => construirTema(paleta: PaletaApp.modoClaro);
}
