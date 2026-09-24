import 'package:cloud_firestore/cloud_firestore.dart';

class DeudaModel {
  final String? id;
  final String? clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final String concepto;
  final double montoTotal;
  final double abonos;
  final DateTime fechaEmision;
  final DateTime? fechaVencimiento;
  final bool pagada;
  final String notas;

  DeudaModel({
    this.id,
    this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono = '',
    required this.concepto,
    required this.montoTotal,
    this.abonos = 0.0,
    required this.fechaEmision,
    this.fechaVencimiento,
    this.pagada = false,
    this.notas = '',
  });

  double get saldoPendiente => (montoTotal - abonos).clamp(0.0, double.infinity);

  bool get estaVencida {
    if (pagada || saldoPendiente <= 0) return false;
    if (fechaVencimiento == null) return false;
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final venc = DateTime(fechaVencimiento!.year, fechaVencimiento!.month, fechaVencimiento!.day);
    return hoy.isAfter(venc);
  }

  int get diasDeuda {
    final now = DateTime.now();
    return now.difference(fechaEmision).inDays;
  }

  int? get diasRestantesVencimiento {
    if (fechaVencimiento == null) return null;
    final now = DateTime.now();
    return fechaVencimiento!.difference(now).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'clienteTelefono': clienteTelefono,
      'concepto': concepto,
      'montoTotal': montoTotal,
      'abonos': abonos,
      'fechaEmision': Timestamp.fromDate(fechaEmision),
      'fechaVencimiento': fechaVencimiento != null ? Timestamp.fromDate(fechaVencimiento!) : null,
      'pagada': pagada || saldoPendiente <= 0,
      'notas': notas,
    };
  }

  factory DeudaModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseFecha(dynamic f) {
      if (f is Timestamp) return f.toDate();
      if (f is String) return DateTime.tryParse(f) ?? DateTime.now();
      return DateTime.now();
    }

    final monto = (map['montoTotal'] as num?)?.toDouble() ?? 0.0;
    final abn = (map['abonos'] as num?)?.toDouble() ?? 0.0;

    return DeudaModel(
      id: id,
      clienteId: map['clienteId'] as String?,
      clienteNombre: map['clienteNombre'] as String? ?? 'Cliente sin nombre',
      clienteTelefono: map['clienteTelefono'] as String? ?? '',
      concepto: map['concepto'] as String? ?? 'Deuda general',
      montoTotal: monto,
      abonos: abn,
      fechaEmision: parseFecha(map['fechaEmision']),
      fechaVencimiento: map['fechaVencimiento'] != null ? parseFecha(map['fechaVencimiento']) : null,
      pagada: map['pagada'] as bool? ?? (monto - abn <= 0),
      notas: map['notas'] as String? ?? '',
    );
  }
}
