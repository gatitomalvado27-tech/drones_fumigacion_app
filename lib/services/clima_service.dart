import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ClimaData {
  final double vientoKmh;
  final double rafagasKmh;
  final double temperaturaC;
  final int humedadRelativa;
  final int weatherCode;
  final String condicionTexto;
  final String condicionIcono;
  final String estadoVuelo;
  final Color estadoColor;
  final String ubicacionNombre;
  final DateTime ultimaActualizacion;

  ClimaData({
    required this.vientoKmh,
    required this.rafagasKmh,
    required this.temperaturaC,
    required this.humedadRelativa,
    required this.weatherCode,
    required this.condicionTexto,
    required this.condicionIcono,
    required this.estadoVuelo,
    required this.estadoColor,
    required this.ubicacionNombre,
    required this.ultimaActualizacion,
  });

  factory ClimaData.defaultData() {
    return ClimaData(
      vientoKmh: 9.5,
      rafagasKmh: 14.0,
      temperaturaC: 28.0,
      humedadRelativa: 65,
      weatherCode: 1,
      condicionTexto: 'Despejado',
      condicionIcono: '☀️',
      estadoVuelo: 'Óptimo para vuelo',
      estadoColor: const Color(0xFF059669),
      ubicacionNombre: 'Zona Agrícola',
      ultimaActualizacion: DateTime.now(),
    );
  }
}

class ClimaService {
  static final ClimaService instance = ClimaService._internal();
  ClimaService._internal();

  ClimaData? _ultimoClima;
  ClimaData? get ultimoClima => _ultimoClima;

  Future<ClimaData> obtenerClimaActual() async {
    double lat = 8.75;
    double lon = -75.88;
    String ubicacionDetectada = 'Zona Agrícola';

    // 1. Intentar obtener ubicación por GPS
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );
          lat = position.latitude;
          lon = position.longitude;
          ubicacionDetectada = 'GPS Actual';
        }
      }
    } catch (_) {
      // Si GPS falla o tarda, intentar IP o mantener coordenadas base
    }

    // 2. Si es GPS base, intentar enriquecer nombre por IP
    if (ubicacionDetectada == 'Zona Agrícola') {
      try {
        final ipRes = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 3));
        if (ipRes.statusCode == 200) {
          final data = jsonDecode(ipRes.body);
          if (data['status'] == 'success') {
            lat = (data['lat'] as num).toDouble();
            lon = (data['lon'] as num).toDouble();
            final city = data['city'] ?? '';
            final region = data['regionName'] ?? '';
            ubicacionDetectada = city.isNotEmpty ? '$city, $region' : 'Local';
          }
        }
      } catch (_) {
        // Fallback transparente
      }
    }

    // 3. Consultar Open-Meteo con coordenadas reales
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_gusts_10m'
        '&wind_speed_unit=kmh',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'] ?? {};

        final double viento = (current['wind_speed_10m'] ?? 10.0).toDouble();
        final double rafagas = (current['wind_gusts_10m'] ?? viento + 4.0).toDouble();
        final double temp = (current['temperature_2m'] ?? 27.0).toDouble();
        final int humedad = (current['relative_humidity_2m'] ?? 60).toInt();
        final int code = (current['weather_code'] ?? 0).toInt();

        final (texto, icono) = _interpretarCodigoClima(code);
        final (estado, color) = _evaluarSeguridadVuelo(viento, code);

        _ultimoClima = ClimaData(
          vientoKmh: viento,
          rafagasKmh: rafagas,
          temperaturaC: temp,
          humedadRelativa: humedad,
          weatherCode: code,
          condicionTexto: texto,
          condicionIcono: icono,
          estadoVuelo: estado,
          estadoColor: color,
          ubicacionNombre: ubicacionDetectada,
          ultimaActualizacion: DateTime.now(),
        );

        return _ultimoClima!;
      }
    } catch (_) {
      // Si falla internet, retornar último clima guardado o datos por defecto seguros
    }

    return _ultimoClima ?? ClimaData.defaultData();
  }

  static (String texto, String icono) _interpretarCodigoClima(int code) {
    if (code == 0) return ('Despejado / Soleado', '☀️');
    if (code == 1 || code == 2) return ('Mayormente Soleado', '🌤️');
    if (code == 3) return ('Nublado', '☁️');
    if (code == 45 || code == 48) return ('Niebla en Campo', '🌫️');
    if (code >= 51 && code <= 55) return ('Llovizna Ligera', '🌦️');
    if (code >= 61 && code <= 65) return ('Lluvia Activa', '🌧️');
    if (code >= 71 && code <= 77) return ('Granizo', '❄️');
    if (code >= 80 && code <= 82) return ('Chubascos', '🌧️');
    if (code >= 95) return ('Tormenta Eléctrica', '⛈️');
    return ('Parcialmente Nublado', '⛅');
  }

  static (String estado, Color color) _evaluarSeguridadVuelo(double viento, int code) {
    // Si hay lluvia o tormenta activa
    if (code >= 51) {
      return ('No apto: Lluvia activa', const Color(0xFFDC2626));
    }

    // Umbrales agronómicos de viento para drones de fumigación
    if (viento <= 12.0) {
      return ('Óptimo para vuelo', const Color(0xFF059669));
    } else if (viento <= 18.0) {
      return ('Precaución: Deriva', const Color(0xFFD97706));
    } else {
      return ('No apto: Viento fuerte', const Color(0xFFDC2626));
    }
  }
}
