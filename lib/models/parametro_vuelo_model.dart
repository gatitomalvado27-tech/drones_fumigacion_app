class ParametroVueloModel {
  String? id;
  String? servicioId;
  String clienteId;
  String clienteNombre;
  String cultivo;
  DateTime fechaAplicacion;
  String loteUbicacion;
  double? hectareas;
  String tipoServicio;
  String dron;

  // Parámetros técnicos (todos opcionales y configurables)
  double? velocidadVuelo; // m/s o km/h (configurable)
  String unidadVelocidadVuelo; // 'm/s' o 'km/h'
  double? alturaVuelo; // metros
  double? anchoFranja; // metros
  double? caudalAplicacion; // L/min
  double? volumenPorHectarea; // L/Ha
  double? velocidadAplicacion; // Ha/h
  String tipoProducto;
  String dosisProducto; // Ej: '250 ml/Ha', '1.5 kg/Ha'
  String observaciones;
  Map<String, String> camposExtra;
  DateTime fechaRegistro;

  ParametroVueloModel({
    this.id,
    this.servicioId,
    this.clienteId = '',
    required this.clienteNombre,
    required this.cultivo,
    required this.fechaAplicacion,
    this.loteUbicacion = '',
    this.hectareas,
    this.tipoServicio = '',
    this.dron = '',
    this.velocidadVuelo,
    this.unidadVelocidadVuelo = 'm/s',
    this.alturaVuelo,
    this.anchoFranja,
    this.caudalAplicacion,
    this.volumenPorHectarea,
    this.velocidadAplicacion,
    this.tipoProducto = '',
    this.dosisProducto = '',
    this.observaciones = '',
    Map<String, String>? camposExtra,
    DateTime? fechaRegistro,
  })  : camposExtra = camposExtra ?? {},
        fechaRegistro = fechaRegistro ?? DateTime.now();

  bool get tieneParametrosTecnicos =>
      velocidadVuelo != null ||
      alturaVuelo != null ||
      anchoFranja != null ||
      caudalAplicacion != null ||
      volumenPorHectarea != null ||
      velocidadAplicacion != null ||
      tipoProducto.trim().isNotEmpty ||
      dosisProducto.trim().isNotEmpty ||
      camposExtra.isNotEmpty;

  String get resumenTecnico {
    final partes = <String>[];
    if (velocidadVuelo != null) {
      partes.add('Vel: ${velocidadVuelo!.toStringAsFixed(1)} $unidadVelocidadVuelo');
    }
    if (alturaVuelo != null) {
      partes.add('Alt: ${alturaVuelo!.toStringAsFixed(1)} m');
    }
    if (anchoFranja != null) {
      partes.add('Franja: ${anchoFranja!.toStringAsFixed(1)} m');
    }
    if (caudalAplicacion != null) {
      partes.add('Caudal: ${caudalAplicacion!.toStringAsFixed(1)} L/min');
    }
    if (volumenPorHectarea != null) {
      partes.add('Vol: ${volumenPorHectarea!.toStringAsFixed(1)} L/Ha');
    }
    if (velocidadAplicacion != null) {
      partes.add('Rend: ${velocidadAplicacion!.toStringAsFixed(1)} Ha/h');
    }
    return partes.isEmpty ? 'Sin parámetros numéricos registrados' : partes.join(' • ');
  }

  Map<String, dynamic> toMap() {
    return {
      if (servicioId != null && servicioId!.isNotEmpty) 'servicioId': servicioId,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'cultivo': cultivo,
      'fechaAplicacion': fechaAplicacion.toIso8601String(),
      'loteUbicacion': loteUbicacion,
      if (hectareas != null) 'hectareas': hectareas,
      'tipoServicio': tipoServicio,
      'dron': dron,
      if (velocidadVuelo != null) 'velocidadVuelo': velocidadVuelo,
      'unidadVelocidadVuelo': unidadVelocidadVuelo,
      if (alturaVuelo != null) 'alturaVuelo': alturaVuelo,
      if (anchoFranja != null) 'anchoFranja': anchoFranja,
      if (caudalAplicacion != null) 'caudalAplicacion': caudalAplicacion,
      if (volumenPorHectarea != null) 'volumenPorHectarea': volumenPorHectarea,
      if (velocidadAplicacion != null) 'velocidadAplicacion': velocidadAplicacion,
      'tipoProducto': tipoProducto,
      'dosisProducto': dosisProducto,
      'observaciones': observaciones,
      'camposExtra': camposExtra,
      'fechaRegistro': fechaRegistro.toIso8601String(),
    };
  }

  factory ParametroVueloModel.fromMap(String? id, Map<String, dynamic> map) {
    double? toDoubleOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

    Map<String, String> parseExtra(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return {};
    }

    return ParametroVueloModel(
      id: id,
      servicioId: map['servicioId']?.toString(),
      clienteId: map['clienteId']?.toString() ?? '',
      clienteNombre: map['clienteNombre']?.toString() ?? '',
      cultivo: map['cultivo']?.toString() ?? '',
      fechaAplicacion: map['fechaAplicacion'] != null
          ? DateTime.tryParse(map['fechaAplicacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      loteUbicacion: map['loteUbicacion']?.toString() ?? '',
      hectareas: toDoubleOrNull(map['hectareas']),
      tipoServicio: map['tipoServicio']?.toString() ?? '',
      dron: map['dron']?.toString() ?? '',
      velocidadVuelo: toDoubleOrNull(map['velocidadVuelo']),
      unidadVelocidadVuelo: map['unidadVelocidadVuelo']?.toString() ?? 'm/s',
      alturaVuelo: toDoubleOrNull(map['alturaVuelo']),
      anchoFranja: toDoubleOrNull(map['anchoFranja']),
      caudalAplicacion: toDoubleOrNull(map['caudalAplicacion']),
      volumenPorHectarea: toDoubleOrNull(map['volumenPorHectarea']),
      velocidadAplicacion: toDoubleOrNull(map['velocidadAplicacion']),
      tipoProducto: map['tipoProducto']?.toString() ?? '',
      dosisProducto: map['dosisProducto']?.toString() ?? '',
      observaciones: map['observaciones']?.toString() ?? '',
      camposExtra: parseExtra(map['camposExtra']),
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.tryParse(map['fechaRegistro'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
