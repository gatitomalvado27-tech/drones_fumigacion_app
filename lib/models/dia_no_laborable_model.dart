class DiaNoLaborableModel {
  String id; // Formato YYYY-MM-DD para evitar duplicados
  DateTime fecha;
  String motivo; // 'Festivo', 'Domingo / Descanso', 'Día personal', 'No disponible', 'Otro'
  String descripcion;
  DateTime creadoEn;

  DiaNoLaborableModel({
    String? id,
    required this.fecha,
    required this.motivo,
    this.descripcion = '',
    DateTime? creadoEn,
  })  : id = id ?? generarIdFecha(fecha),
        creadoEn = creadoEn ?? DateTime.now();

  static String generarIdFecha(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static const List<String> motivosComunes = [
    'Domingo / Descanso',
    'Día festivo',
    'Día personal',
    'Sin disponibilidad operativa',
    'Clima / Condiciones adversas',
    'Otro motivo',
  ];

  Map<String, dynamic> toMap() {
    final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
    return {
      'fecha': soloFecha.toIso8601String(),
      'motivo': motivo,
      'descripcion': descripcion,
      'creadoEn': creadoEn.toIso8601String(),
    };
  }

  factory DiaNoLaborableModel.fromMap(String id, Map<String, dynamic> map) {
    final parsed = map['fecha'] != null
        ? DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now()
        : DateTime.now();
    return DiaNoLaborableModel(
      id: id,
      fecha: DateTime(parsed.year, parsed.month, parsed.day),
      motivo: map['motivo']?.toString() ?? 'Día no laborable',
      descripcion: map['descripcion']?.toString() ?? '',
      creadoEn: map['creadoEn'] != null
          ? DateTime.tryParse(map['creadoEn'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
