import 'package:flutter/material.dart';

class PilotoModel {
  String? id;
  String nombre;
  String cedula;
  String telefono;
  String colorHex; // Ej. '#2196F3'
  String licencia;
  bool activo;
  String? firmaBase64;

  PilotoModel({
    this.id,
    required this.nombre,
    this.cedula = '',
    this.telefono = '',
    this.colorHex = '#2196F3',
    this.licencia = '',
    this.activo = true,
    this.firmaBase64,
  });

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF2196F3);
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'colorHex': colorHex,
      'licencia': licencia,
      'activo': activo,
      if (firmaBase64 != null) 'firmaBase64': firmaBase64,
    };
  }

  factory PilotoModel.fromMap(String id, Map<String, dynamic> map) {
    return PilotoModel(
      id: id,
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      telefono: map['telefono'] ?? '',
      colorHex: map['colorHex'] ?? '#2196F3',
      licencia: map['licencia'] ?? '',
      activo: map['activo'] ?? true,
      firmaBase64: map['firmaBase64'],
    );
  }
}
