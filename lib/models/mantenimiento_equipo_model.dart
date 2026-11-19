import 'package:flutter/material.dart';

class MantenimientoEquipoModel {
  String? id;
  String categoriaEquipo; // 'DRON', 'VEHICULO', 'PLANTA_ELECTRICA', 'ASPERSION', 'BATERIAS', 'HERRAMIENTAS', 'OTRO'
  String nombreEquipo;
  DateTime fechaInicio;
  DateTime fechaFin;
  String tipoMantenimiento; // 'Preventivo', 'Correctivo', 'Calibración', 'Limpieza profunda', 'Revisión técnica', 'Otro'
  String observaciones;
  String responsable;
  String estado; // 'PENDIENTE', 'EN_PROCESO', 'COMPLETADO'
  DateTime creadoEn;

  MantenimientoEquipoModel({
    this.id,
    required this.categoriaEquipo,
    required this.nombreEquipo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.tipoMantenimiento,
    this.observaciones = '',
    this.responsable = '',
    this.estado = 'PENDIENTE',
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  bool get estaActivo => estado == 'PENDIENTE' || estado == 'EN_PROCESO';

  bool get esMultidia {
    final ini = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    return fin.isAfter(ini);
  }

  /// Verifica si este mantenimiento cubre el día [dia] (solo fecha).
  bool cubreDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    final ini = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    return !d.isBefore(ini) && !d.isAfter(fin);
  }

  /// Verifica si un vuelo en [fechaHoraVuelo] entra en conflicto con este mantenimiento activo.
  bool entraEnConflictoCon(DateTime fechaHoraVuelo, {String? equipoVuelo}) {
    if (!estaActivo) return false;
    if (equipoVuelo != null && equipoVuelo.trim().isNotEmpty) {
      final a = nombreEquipo.trim().toLowerCase();
      final b = equipoVuelo.trim().toLowerCase();
      if (!(a == b || a.contains(b) || b.contains(a))) {
        return false;
      }
    }
    // Si el mantenimiento abarca varios días o un rango de horas, verificar solapamiento
    final vueloFin = fechaHoraVuelo.add(const Duration(hours: 2));
    return fechaHoraVuelo.isBefore(fechaFin.add(const Duration(minutes: 1))) &&
        vueloFin.isAfter(fechaInicio.subtract(const Duration(minutes: 1)));
  }

  static const Map<String, String> categoriasMap = {
    'DRON': 'Dron agrícola',
    'VEHICULO': 'Vehículo / Camioneta',
    'PLANTA_ELECTRICA': 'Planta eléctrica / Generador',
    'ASPERSION': 'Equipo de aspersión / Mezcla',
    'BATERIAS': 'Baterías y cargadores',
    'HERRAMIENTAS': 'Herramientas',
    'OTRO': 'Otro equipo',
  };

  static const List<String> tiposMantenimiento = [
    'Preventivo',
    'Correctivo',
    'Calibración y boquillas',
    'Limpieza profunda',
    'Revisión técnica general',
    'Actualización / Diagnóstico de hardware',
    'Otro',
  ];

  static const List<String> estados = [
    'PENDIENTE',
    'EN_PROCESO',
    'COMPLETADO',
  ];

  static String nombreCategoria(String cat) => categoriasMap[cat] ?? cat;

  static String nombreEstado(String est) {
    switch (est) {
      case 'COMPLETADO':
        return 'Completado';
      case 'EN_PROCESO':
        return 'En proceso';
      case 'PENDIENTE':
      default:
        return 'Pendiente';
    }
  }

  static Color colorEstado(String est) {
    switch (est) {
      case 'COMPLETADO':
        return const Color(0xFF2E7D32);
      case 'EN_PROCESO':
        return Colors.amber.shade800;
      case 'PENDIENTE':
      default:
        return Colors.deepPurpleAccent;
    }
  }

  static IconData iconoCategoria(String cat) {
    switch (cat) {
      case 'DRON':
        return Icons.flight_takeoff_rounded;
      case 'VEHICULO':
        return Icons.local_shipping_outlined;
      case 'PLANTA_ELECTRICA':
        return Icons.bolt_rounded;
      case 'ASPERSION':
        return Icons.water_drop_outlined;
      case 'BATERIAS':
        return Icons.battery_charging_full_rounded;
      case 'HERRAMIENTAS':
        return Icons.handyman_outlined;
      default:
        return Icons.build_circle_outlined;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'categoriaEquipo': categoriaEquipo,
      'nombreEquipo': nombreEquipo,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
      'tipoMantenimiento': tipoMantenimiento,
      'observaciones': observaciones,
      'responsable': responsable,
      'estado': estado,
      'creadoEn': creadoEn.toIso8601String(),
    };
  }

  factory MantenimientoEquipoModel.fromMap(String id, Map<String, dynamic> map) {
    final ini = map['fechaInicio'] != null
        ? DateTime.tryParse(map['fechaInicio'].toString()) ?? DateTime.now()
        : DateTime.now();
    final fin = map['fechaFin'] != null
        ? DateTime.tryParse(map['fechaFin'].toString()) ?? ini.add(const Duration(hours: 2))
        : ini.add(const Duration(hours: 2));

    return MantenimientoEquipoModel(
      id: id,
      categoriaEquipo: map['categoriaEquipo']?.toString() ?? 'DRON',
      nombreEquipo: map['nombreEquipo']?.toString() ?? '',
      fechaInicio: ini,
      fechaFin: fin.isBefore(ini) ? ini.add(const Duration(hours: 2)) : fin,
      tipoMantenimiento: map['tipoMantenimiento']?.toString() ?? 'Preventivo',
      observaciones: map['observaciones']?.toString() ?? '',
      responsable: map['responsable']?.toString() ?? '',
      estado: map['estado']?.toString() ?? 'PENDIENTE',
      creadoEn: map['creadoEn'] != null
          ? DateTime.tryParse(map['creadoEn'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
