import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agro_theme.dart';

enum PaletaApp {
  verdeAgricola,
  oscuroProfesional,
  modoClaro,
  azulTecnologico,
  personalizado,
}

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  static const String _keyPaleta = 'proicaro_paleta_app';
  static const String _keyLegacyTheme = 'proicaro_theme_mode';
  static const String _keyCustomPrimary = 'proicaro_custom_primary';
  static const String _keyCustomSecondary = 'proicaro_custom_secondary';
  static const String _keyCustomDark = 'proicaro_custom_dark';

  PaletaApp _paleta = PaletaApp.verdeAgricola;
  Color _customPrimary = const Color(0xFF10B981);
  Color _customSecondary = const Color(0xFF38BDF8);
  bool _customDark = true;

  PaletaApp get paleta => _paleta;
  Color get customPrimary => _customPrimary;
  Color get customSecondary => _customSecondary;
  bool get customDark => _customDark;

  bool get isDarkMode {
    switch (_paleta) {
      case PaletaApp.modoClaro:
        return false;
      case PaletaApp.personalizado:
        return _customDark;
      case PaletaApp.verdeAgricola:
      case PaletaApp.oscuroProfesional:
      case PaletaApp.azulTecnologico:
        return true;
    }
  }

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeData get themeData {
    return AgroTheme.construirTema(
      paleta: _paleta,
      customPrimary: _customPrimary,
      customSecondary: _customSecondary,
      customDark: _customDark,
    );
  }

  Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final paletaGuardada = prefs.getString(_keyPaleta);

    if (paletaGuardada != null) {
      _paleta = _parsePaleta(paletaGuardada);
    } else {
      // Migración limpia desde la preferencia anterior dark/light
      final legacy = prefs.getString(_keyLegacyTheme) ?? 'dark';
      _paleta = legacy == 'light' ? PaletaApp.modoClaro : PaletaApp.verdeAgricola;
    }

    final primInt = prefs.getInt(_keyCustomPrimary);
    final secInt = prefs.getInt(_keyCustomSecondary);
    final darkBool = prefs.getBool(_keyCustomDark);

    if (primInt != null) _customPrimary = Color(primInt);
    if (secInt != null) _customSecondary = Color(secInt);
    if (darkBool != null) _customDark = darkBool;

    notifyListeners();
  }

  Future<void> seleccionarPaleta(PaletaApp nuevaPaleta) async {
    _paleta = nuevaPaleta;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaleta, _paletaToString(nuevaPaleta));
    await prefs.setString(_keyLegacyTheme, isDarkMode ? 'dark' : 'light');
  }

  Future<void> configurarPersonalizado({
    required Color primary,
    required Color secondary,
    required bool esOscuro,
  }) async {
    _customPrimary = primary;
    _customSecondary = secondary;
    _customDark = esOscuro;
    _paleta = PaletaApp.personalizado;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaleta, _paletaToString(PaletaApp.personalizado));
    await prefs.setInt(_keyCustomPrimary, primary.toARGB32());
    await prefs.setInt(_keyCustomSecondary, secondary.toARGB32());
    await prefs.setBool(_keyCustomDark, esOscuro);
    await prefs.setString(_keyLegacyTheme, esOscuro ? 'dark' : 'light');
  }

  /// Alterna rápidamente entre Modo Claro y la paleta oscura principal (Verde Agrícola).
  Future<void> alternarTema() async {
    if (isDarkMode) {
      await seleccionarPaleta(PaletaApp.modoClaro);
    } else {
      await seleccionarPaleta(PaletaApp.verdeAgricola);
    }
  }

  static String nombrePaleta(PaletaApp p) {
    switch (p) {
      case PaletaApp.verdeAgricola:
        return 'Verde Agrícola';
      case PaletaApp.oscuroProfesional:
        return 'Modo Oscuro Profesional';
      case PaletaApp.modoClaro:
        return 'Modo Claro';
      case PaletaApp.azulTecnologico:
        return 'Azul Tecnológico';
      case PaletaApp.personalizado:
        return 'Personalizado';
    }
  }

  static String descripcionPaleta(PaletaApp p) {
    switch (p) {
      case PaletaApp.verdeAgricola:
        return 'Verde oscuro, verde natural y tonos neutros de cabina';
      case PaletaApp.oscuroProfesional:
        return 'Negro suave, gris grafito y acentos verde esmeralda';
      case PaletaApp.modoClaro:
        return 'Fondos blancos, grises claros y acentos verdes de alta visibilidad';
      case PaletaApp.azulTecnologico:
        return 'Azul profundo, azul cian tecnológico y tonos neutros';
      case PaletaApp.personalizado:
        return 'Elige libremente tus colores principal, secundario y fondo';
    }
  }

  static PaletaApp _parsePaleta(String raw) {
    switch (raw) {
      case 'oscuro_profesional':
        return PaletaApp.oscuroProfesional;
      case 'modo_claro':
        return PaletaApp.modoClaro;
      case 'azul_tecnologico':
        return PaletaApp.azulTecnologico;
      case 'personalizado':
        return PaletaApp.personalizado;
      case 'verde_agricola':
      default:
        return PaletaApp.verdeAgricola;
    }
  }

  static String _paletaToString(PaletaApp p) {
    switch (p) {
      case PaletaApp.verdeAgricola:
        return 'verde_agricola';
      case PaletaApp.oscuroProfesional:
        return 'oscuro_profesional';
      case PaletaApp.modoClaro:
        return 'modo_claro';
      case PaletaApp.azulTecnologico:
        return 'azul_tecnologico';
      case PaletaApp.personalizado:
        return 'personalizado';
    }
  }
}
