class TransaccionModel {
  String? id;
  String tipo; // 'INGRESO', 'EGRESO', 'DEUDA'
  String categoria; // 'SERVICIO', 'COMBUSTIBLE', 'MANTENIMIENTO', 'PILOTO', 'INSUMOS', 'BATERIAS', 'VIATICOS', 'CASA', 'OTROS'
  double monto;
  String descripcion;
  DateTime fecha;
  String? clienteNombre;
  String? servicioId;
  String metodoPago; // 'EFECTIVO', 'BANCOLOMBIA', 'NEQUI', 'DAVIPLATA', 'DAVIVIENDA', 'BANCO_BOGOTA', 'BBVA', 'PSE', 'EN_LINEA', 'OTROS'

  TransaccionModel({
    this.id,
    required this.tipo,
    required this.categoria,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    this.clienteNombre,
    this.servicioId,
    this.metodoPago = 'EFECTIVO',
  });

  bool get esEfectivo => metodoPago == 'EFECTIVO';
  bool get esEnLinea => !esEfectivo;

  static const Map<String, String> metodosPagoMap = {
    'EFECTIVO': 'Efectivo (Caja General)',
    'BANCOLOMBIA': 'Bancolombia',
    'NEQUI': 'Nequi',
    'DAVIPLATA': 'Daviplata',
    'DAVIVIENDA': 'Davivienda',
    'BANCO_BOGOTA': 'Banco de Bogotá',
    'BBVA': 'BBVA',
    'PSE': 'PSE / Transferencia',
    'EN_LINEA': 'En Línea (General)',
    'OTROS': 'Otras Cuentas',
  };

  static String nombreMetodo(String key) {
    return metodosPagoMap[key] ?? key;
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'categoria': categoria,
      'monto': monto,
      'descripcion': descripcion,
      'fecha': fecha.toIso8601String(),
      'clienteNombre': clienteNombre,
      'servicioId': servicioId,
      'metodoPago': metodoPago,
    };
  }

  factory TransaccionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransaccionModel(
      id: id,
      tipo: map['tipo'] ?? 'INGRESO',
      categoria: map['categoria'] ?? 'OTROS',
      monto: (map['monto'] ?? 0).toDouble(),
      descripcion: map['descripcion'] ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      clienteNombre: map['clienteNombre'],
      servicioId: map['servicioId'],
      metodoPago: map['metodoPago'] ?? 'EFECTIVO',
    );
  }
}