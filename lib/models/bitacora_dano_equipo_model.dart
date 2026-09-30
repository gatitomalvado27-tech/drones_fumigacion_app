import 'package:flutter/material.dart';

class BitacoraDanoEquipoModel {
  String? id;
  String categoriaEquipo; // 'DRON', 'CAMIONETA', 'GENERADOR', 'BATERIAS', 'SISTEMA_MEZCLA', 'OTRO'
  String nombreEquipo; // Ej: 'DJI Agras T40 #1', 'Camioneta Toyota Hilux', 'Generador D12000iE'
  DateTime fecha;
  String gravedad; // 'LEVE', 'MODERADA', 'CRITICA'
  String tipoDano; // Ej: 'Hélice fisurada', 'Pinchazo en llanta', 'Brazo M3 quebrado', etc.
  String descripcion;
  String? servicioId; // Vuelo asociado si ocurrió en jornada de trabajo
  String? clienteNombre;
  String pilotoReporta;
  List<String> fotosBase64; // Lista de imágenes en Base64
  String? videoUrl; // Enlace a video de evidencia (Drive, YouTube, WhatsApp, etc.)
  double costoReparacion;
  bool gastoContableRegistrado;
  String estado; // 'REPORTADO', 'EN_REPARACION', 'REPARADO'
  String piezasCambiadas;
  String notasReparacion;
  DateTime? fechaReparacion;

  BitacoraDanoEquipoModel({
    this.id,
    required this.categoriaEquipo,
    required this.nombreEquipo,
    required this.fecha,
    required this.gravedad,
    required this.tipoDano,
    required this.descripcion,
    this.servicioId,
    this.clienteNombre,
    required this.pilotoReporta,
    List<String>? fotosBase64,
    this.videoUrl,
    this.costoReparacion = 0.0,
    this.gastoContableRegistrado = false,
    this.estado = 'REPORTADO',
    this.piezasCambiadas = '',
    this.notasReparacion = '',
    this.fechaReparacion,
  }) : fotosBase64 = fotosBase64 ?? [];

  static const Map<String, String> categoriasMap = {
    'DRON': 'Dron de Fumigación',
    'CAMIONETA': 'Camioneta / Vehículo',
    'GENERADOR': 'Generador / Planta Eléctrica',
    'BATERIAS': 'Baterías Inteligentes',
    'SISTEMA_MEZCLA': 'Tanque / Sistema de Mezcla',
    'OTRO': 'Herramienta u Otro Equipo',
  };

  static String nombreCategoria(String cat) {
    return categoriasMap[cat] ?? cat;
  }

  static IconData iconoCategoria(String cat) {
    switch (cat) {
      case 'DRON':
        return Icons.flight_takeoff;
      case 'CAMIONETA':
        return Icons.local_shipping_outlined;
      case 'GENERADOR':
        return Icons.bolt;
      case 'BATERIAS':
        return Icons.battery_alert_outlined;
      case 'SISTEMA_MEZCLA':
        return Icons.water_drop_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  static Color colorGravedad(String g) {
    switch (g) {
      case 'CRITICA':
        return Colors.redAccent;
      case 'MODERADA':
        return Colors.orangeAccent;
      case 'LEVE':
      default:
        return Colors.green;
    }
  }

  static String nombreGravedad(String g) {
    switch (g) {
      case 'CRITICA':
        return 'Crítica (Inoperativo)';
      case 'MODERADA':
        return 'Moderada (Requiere revisión)';
      case 'LEVE':
      default:
        return 'Leve (Operativo)';
    }
  }

  static Color colorEstado(String est) {
    switch (est) {
      case 'REPARADO':
        return const Color(0xFF2E7D32);
      case 'EN_REPARACION':
        return Colors.amber.shade800;
      case 'REPORTADO':
      default:
        return Colors.red.shade700;
    }
  }

  static String nombreEstado(String est) {
    switch (est) {
      case 'REPARADO':
        return 'Reparado / Operativo';
      case 'EN_REPARACION':
        return 'En Taller / Reparación';
      case 'REPORTADO':
      default:
        return 'Reportado (Pendiente)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'categoriaEquipo': categoriaEquipo,
      'nombreEquipo': nombreEquipo,
      'fecha': fecha.toIso8601String(),
      'gravedad': gravedad,
      'tipoDano': tipoDano,
      'descripcion': descripcion,
      'servicioId': servicioId,
      'clienteNombre': clienteNombre,
      'pilotoReporta': pilotoReporta,
      'fotosBase64': fotosBase64,
      'videoUrl': videoUrl,
      'costoReparacion': costoReparacion,
      'gastoContableRegistrado': gastoContableRegistrado,
      'estado': estado,
      'piezasCambiadas': piezasCambiadas,
      'notasReparacion': notasReparacion,
      'fechaReparacion': fechaReparacion?.toIso8601String(),
    };
  }

  factory BitacoraDanoEquipoModel.fromMap(String id, Map<String, dynamic> map) {
    List<String> fotos = [];
    if (map['fotosBase64'] != null) {
      fotos = List<String>.from(map['fotosBase64']);
    }

    return BitacoraDanoEquipoModel(
      id: id,
      categoriaEquipo: map['categoriaEquipo'] ?? 'DRON',
      nombreEquipo: map['nombreEquipo'] ?? 'Dron de Fumigación',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      gravedad: map['gravedad'] ?? 'LEVE',
      tipoDano: map['tipoDano'] ?? '',
      descripcion: map['descripcion'] ?? '',
      servicioId: map['servicioId'],
      clienteNombre: map['clienteNombre'],
      pilotoReporta: map['pilotoReporta'] ?? 'Piloto',
      fotosBase64: fotos,
      videoUrl: map['videoUrl'],
      costoReparacion: (map['costoReparacion'] ?? 0).toDouble(),
      gastoContableRegistrado: map['gastoContableRegistrado'] ?? false,
      estado: map['estado'] ?? 'REPORTADO',
      piezasCambiadas: map['piezasCambiadas'] ?? '',
      notasReparacion: map['notasReparacion'] ?? '',
      fechaReparacion: map['fechaReparacion'] != null ? DateTime.parse(map['fechaReparacion']) : null,
    );
  }
}
