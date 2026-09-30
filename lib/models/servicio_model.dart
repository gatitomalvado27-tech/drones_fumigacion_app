import 'bitacora_vuelo_model.dart';

class ServicioModel {
  String? id;
  String clienteId;
  String clienteNombre;
  String clienteTelefono;
  String fincaUbicacion;
  DateTime fecha;
  double hectareas;
  String cultivo;
  String tipoAplicacion;
  String productoQuimico;
  double precioPorHectarea;
  double precioTotal;
  String estado; // 'PROGRAMADO', 'EN_PROCESO', 'COMPLETADO', 'CANCELADO'
  bool pagado;
  String notas;
  String metodoPago; // 'EFECTIVO', 'BANCOLOMBIA', 'NEQUI', 'DAVIPLATA', 'DAVIVIENDA', 'BANCO_BOGOTA', 'BBVA', 'PSE', 'EN_LINEA'
  String piloto;
  String? pilotoColorHex;
  String dron;
  double totalAbonado;
  double? litrosAplicados;
  BitacoraVueloModel? bitacora;

  ServicioModel({
    this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.fincaUbicacion,
    required this.fecha,
    required this.hectareas,
    required this.cultivo,
    required this.tipoAplicacion,
    required this.productoQuimico,
    required this.precioPorHectarea,
    required this.precioTotal,
    this.estado = 'PROGRAMADO',
    this.pagado = false,
    this.notas = '',
    this.metodoPago = 'EFECTIVO',
    this.piloto = '',
    this.pilotoColorHex,
    this.dron = '',
    double? totalAbonado,
    this.litrosAplicados,
    this.bitacora,
  }) : totalAbonado = totalAbonado ?? (pagado ? precioTotal : 0.0);

  double get saldoPendiente {
    final saldo = precioTotal - totalAbonado;
    return saldo > 0 ? saldo : 0.0;
  }

  int get diasMora {
    if (pagado || saldoPendiente <= 0 || estado == 'CANCELADO') return 0;
    final diff = DateTime.now().difference(fecha).inDays;
    return diff > 0 ? diff : 0;
  }

  String get estadoPago {
    if (pagado || saldoPendiente <= 0) return 'PAGADO';
    if (totalAbonado > 0) return 'PARCIAL';
    return 'PENDIENTE';
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'clienteTelefono': clienteTelefono,
      'fincaUbicacion': fincaUbicacion,
      'fecha': fecha.toIso8601String(),
      'hectareas': hectareas,
      'cultivo': cultivo,
      'tipoAplicacion': tipoAplicacion,
      'productoQuimico': productoQuimico,
      'precioPorHectarea': precioPorHectarea,
      'precioTotal': precioTotal,
      'estado': estado,
      'pagado': pagado,
      'notas': notas,
      'metodoPago': metodoPago,
      'piloto': piloto,
      if (pilotoColorHex != null) 'pilotoColorHex': pilotoColorHex,
      'dron': dron,
      'totalAbonado': totalAbonado,
      if (litrosAplicados != null) 'litrosAplicados': litrosAplicados,
      if (bitacora != null) 'bitacora': bitacora!.toMap(),
    };
  }

  factory ServicioModel.fromMap(String id, Map<String, dynamic> map) {
    final pagadoVal = map['pagado'] ?? false;
    final precioTotalVal = (map['precioTotal'] ?? 0).toDouble();
    final totalAbonadoVal = map['totalAbonado'] != null
        ? (map['totalAbonado'] as num).toDouble()
        : (pagadoVal ? precioTotalVal : 0.0);

    return ServicioModel(
      id: id,
      clienteId: map['clienteId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      clienteTelefono: map['clienteTelefono'] ?? '',
      fincaUbicacion: map['fincaUbicacion'] ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      hectareas: (map['hectareas'] ?? 0).toDouble(),
      cultivo: map['cultivo'] ?? '',
      tipoAplicacion: map['tipoAplicacion'] ?? '',
      productoQuimico: map['productoQuimico'] ?? '',
      precioPorHectarea: (map['precioPorHectarea'] ?? 0).toDouble(),
      precioTotal: precioTotalVal,
      estado: map['estado'] ?? 'PROGRAMADO',
      pagado: pagadoVal,
      notas: map['notas'] ?? '',
      metodoPago: map['metodoPago'] ?? 'EFECTIVO',
      piloto: map['piloto'] ?? '',
      pilotoColorHex: map['pilotoColorHex'],
      dron: map['dron'] ?? '',
      totalAbonado: totalAbonadoVal,
      litrosAplicados: map['litrosAplicados'] != null
          ? (map['litrosAplicados'] as num).toDouble()
          : null,
      bitacora: map['bitacora'] != null
          ? BitacoraVueloModel.fromMap(null, Map<String, dynamic>.from(map['bitacora']))
          : null,
    );
  }
}
