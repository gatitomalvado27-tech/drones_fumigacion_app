import 'package:cloud_firestore/cloud_firestore.dart';

class AppVersionModel {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String novedades;
  final bool obligatoria;
  final bool habilitada;
  final DateTime fecha;

  AppVersionModel({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.novedades,
    this.obligatoria = false,
    this.habilitada = true,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'apkUrl': apkUrl,
      'novedades': novedades,
      'obligatoria': obligatoria,
      'habilitada': habilitada,
      'fecha': Timestamp.fromDate(fecha),
    };
  }

  factory AppVersionModel.fromMap(Map<String, dynamic> map) {
    DateTime f = DateTime.now();
    if (map['fecha'] is Timestamp) {
      f = (map['fecha'] as Timestamp).toDate();
    } else if (map['fecha'] is String) {
      f = DateTime.tryParse(map['fecha']) ?? DateTime.now();
    }

    return AppVersionModel(
      version: map['version']?.toString() ?? '1.0.0',
      buildNumber: (map['buildNumber'] is num) ? (map['buildNumber'] as num).toInt() : 1,
      apkUrl: map['apkUrl']?.toString() ?? '',
      novedades: map['novedades']?.toString() ?? 'Mejoras generales y corrección de errores.',
      obligatoria: map['obligatoria'] == true,
      habilitada: map['habilitada'] != false,
      fecha: f,
    );
  }
}
