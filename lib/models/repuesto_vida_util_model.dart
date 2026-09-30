import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RepuestoVidaUtilModel {
  final String? id;
  final String nombre;
  final String categoriaEquipo; // DRON, CAMIONETA, GENERADOR, BATERIAS, SISTEMA_MEZCLA, OTRO
  final String nombreEquipo;
  final String numeroSerie;
  final String proveedor;
  final double costoAdquisicion;
  final DateTime fechaInstalacion;
  final String tipoMedicion; // HORAS, HECTAREAS, KILOMETRAJE, CICLOS, DIAS
  final double usoActual;
  final double vidaUtilEstimada;
  final String observaciones;
  final String estado; // OPTIMO, REVISION, CRITICO, REEMPLAZADO
  final List<Map<String, dynamic>> historialReemplazos;

  RepuestoVidaUtilModel({
    this.id,
    required this.nombre,
    required this.categoriaEquipo,
    required this.nombreEquipo,
    this.numeroSerie = '',
    this.proveedor = '',
    this.costoAdquisicion = 0.0,
    required this.fechaInstalacion,
    this.tipoMedicion = 'HORAS',
    this.usoActual = 0.0,
    required this.vidaUtilEstimada,
    this.observaciones = '',
    this.estado = 'OPTIMO',
    this.historialReemplazos = const [],
  });

  double get porcentajeConsumido {
    if (vidaUtilEstimada <= 0) return 0.0;
    return (usoActual / vidaUtilEstimada).clamp(0.0, 1.0);
  }

  double get porcentajeRestante {
    return (1.0 - porcentajeConsumido).clamp(0.0, 1.0);
  }

  double get usoRestante {
    final rest = vidaUtilEstimada - usoActual;
    return rest < 0 ? 0.0 : rest;
  }

  bool get estaVencido => usoActual >= vidaUtilEstimada && vidaUtilEstimada > 0;
  bool get estaEnRevision => porcentajeRestante <= 0.25 && !estaVencido;

  String get unidadTexto {
    switch (tipoMedicion) {
      case 'HECTAREAS':
        return 'Ha';
      case 'KILOMETRAJE':
        return 'km';
      case 'CICLOS':
        return 'ciclos';
      case 'DIAS':
        return 'días';
      case 'HORAS':
      default:
        return 'hrs';
    }
  }

  Color get colorAlerta {
    if (estaVencido) return Colors.red.shade700;
    if (estaEnRevision) return Colors.orange.shade700;
    return Colors.green.shade600;
  }

  String get estadoCalculado {
    if (estado == 'REEMPLAZADO') return 'REEMPLAZADO';
    if (estaVencido) return 'CRITICO';
    if (estaEnRevision) return 'REVISION';
    return 'OPTIMO';
  }

  static String nombreCategoria(String cat) {
    switch (cat.toUpperCase()) {
      case 'DRON':
        return 'Dron Agrícola';
      case 'CAMIONETA':
        return 'Camioneta / Vehículo';
      case 'GENERADOR':
        return 'Generador Eléctrico';
      case 'BATERIAS':
        return 'Baterías y Cargadores';
      case 'SISTEMA_MEZCLA':
        return 'Sistema de Mezcla / Tanques';
      default:
        return 'Otro Equipo';
    }
  }

  static IconData iconoCategoria(String cat) {
    switch (cat.toUpperCase()) {
      case 'DRON':
        return Icons.flight_takeoff_rounded;
      case 'CAMIONETA':
        return Icons.local_shipping_rounded;
      case 'GENERADOR':
        return Icons.power_rounded;
      case 'BATERIAS':
        return Icons.battery_charging_full_rounded;
      case 'SISTEMA_MEZCLA':
        return Icons.water_drop_rounded;
      default:
        return Icons.build_circle_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoriaEquipo': categoriaEquipo,
      'nombreEquipo': nombreEquipo,
      'numeroSerie': numeroSerie,
      'proveedor': proveedor,
      'costoAdquisicion': costoAdquisicion,
      'fechaInstalacion': Timestamp.fromDate(fechaInstalacion),
      'tipoMedicion': tipoMedicion,
      'usoActual': usoActual,
      'vidaUtilEstimada': vidaUtilEstimada,
      'observaciones': observaciones,
      'estado': estado,
      'historialReemplazos': historialReemplazos,
    };
  }

  factory RepuestoVidaUtilModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseFecha(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawHist = map['historialReemplazos'];
    final List<Map<String, dynamic>> hist = [];
    if (rawHist is List) {
      for (var item in rawHist) {
        if (item is Map) {
          hist.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return RepuestoVidaUtilModel(
      id: id,
      nombre: map['nombre'] ?? '',
      categoriaEquipo: map['categoriaEquipo'] ?? 'DRON',
      nombreEquipo: map['nombreEquipo'] ?? '',
      numeroSerie: map['numeroSerie'] ?? '',
      proveedor: map['proveedor'] ?? '',
      costoAdquisicion: (map['costoAdquisicion'] as num?)?.toDouble() ?? 0.0,
      fechaInstalacion: parseFecha(map['fechaInstalacion']),
      tipoMedicion: map['tipoMedicion'] ?? 'HORAS',
      usoActual: (map['usoActual'] as num?)?.toDouble() ?? 0.0,
      vidaUtilEstimada: (map['vidaUtilEstimada'] as num?)?.toDouble() ?? 100.0,
      observaciones: map['observaciones'] ?? '',
      estado: map['estado'] ?? 'OPTIMO',
      historialReemplazos: hist,
    );
  }
}
