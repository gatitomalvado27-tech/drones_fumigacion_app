class CierreMensualModel {
  String? id; // 'YYYY-MM'
  int mes;
  int anio;
  DateTime fechaCierre;
  double totalIngresos;
  double totalEgresos;
  double utilidadNeta;
  double totalHectareas;
  int totalVuelos;
  double totalPorCobrar;
  Map<String, double> desgloseBancos;
  Map<String, double> desgloseCategorias;

  CierreMensualModel({
    this.id,
    required this.mes,
    required this.anio,
    required this.fechaCierre,
    required this.totalIngresos,
    required this.totalEgresos,
    required this.utilidadNeta,
    required this.totalHectareas,
    required this.totalVuelos,
    required this.totalPorCobrar,
    this.desgloseBancos = const {},
    this.desgloseCategorias = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'mes': mes,
      'anio': anio,
      'fechaCierre': fechaCierre.toIso8601String(),
      'totalIngresos': totalIngresos,
      'totalEgresos': totalEgresos,
      'utilidadNeta': utilidadNeta,
      'totalHectareas': totalHectareas,
      'totalVuelos': totalVuelos,
      'totalPorCobrar': totalPorCobrar,
      'desgloseBancos': desgloseBancos,
      'desgloseCategorias': desgloseCategorias,
    };
  }

  factory CierreMensualModel.fromMap(String id, Map<String, dynamic> map) {
    Map<String, double> parseMap(dynamic source) {
      if (source is Map) {
        return source.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    }

    return CierreMensualModel(
      id: id,
      mes: map['mes'] ?? 1,
      anio: map['anio'] ?? DateTime.now().year,
      fechaCierre: map['fechaCierre'] != null
          ? DateTime.parse(map['fechaCierre'])
          : DateTime.now(),
      totalIngresos: (map['totalIngresos'] ?? 0).toDouble(),
      totalEgresos: (map['totalEgresos'] ?? 0).toDouble(),
      utilidadNeta: (map['utilidadNeta'] ?? 0).toDouble(),
      totalHectareas: (map['totalHectareas'] ?? 0).toDouble(),
      totalVuelos: map['totalVuelos'] ?? 0,
      totalPorCobrar: (map['totalPorCobrar'] ?? 0).toDouble(),
      desgloseBancos: parseMap(map['desgloseBancos']),
      desgloseCategorias: parseMap(map['desgloseCategorias']),
    );
  }
}
