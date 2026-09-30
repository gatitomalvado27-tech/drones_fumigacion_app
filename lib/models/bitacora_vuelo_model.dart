class BitacoraVueloModel {
  final String? id;
  final String servicioId;
  final String clienteNombre;
  final String cultivo;
  final String fincaUbicacion;
  final DateTime fechaVuelo;
  final DateTime fechaRegistro;

  // Datos operativos del vuelo
  final double hectareasProgramadas;
  final double hectareasReales;
  final double? litrosTotalesMezcla;
  final int bateriasUtilizadas;
  final int tiempoVueloMinutos;
  final String climaCondicion; // 'Óptimo', 'Viento Moderado', 'Caluroso / Seco', 'Llovizna / Húmedo', 'Viento Fuerte'
  final String velocidadViento; // '< 10 km/h', '10 - 15 km/h', '> 15 km/h'
  final String estadoResultado; // 'VUELO_EXITOSO', 'PARCIAL_NOVEDAD', 'INTERRUMPIDO'
  final String piloto;
  final String dron;
  final String novedades; // Incidencias, obstáculos, terreno, cables, etc.
  final String observaciones; // Notas adicionales del piloto

  BitacoraVueloModel({
    this.id,
    required this.servicioId,
    required this.clienteNombre,
    required this.cultivo,
    required this.fincaUbicacion,
    required this.fechaVuelo,
    required this.fechaRegistro,
    required this.hectareasProgramadas,
    required this.hectareasReales,
    this.litrosTotalesMezcla,
    this.bateriasUtilizadas = 1,
    this.tiempoVueloMinutos = 0,
    this.climaCondicion = 'Óptimo',
    this.velocidadViento = '< 10 km/h',
    this.estadoResultado = 'VUELO_EXITOSO',
    this.piloto = '',
    this.dron = '',
    this.novedades = '',
    this.observaciones = '',
  });

  bool get esVueloExitoso => estadoResultado == 'VUELO_EXITOSO';
  bool get tieneNovedades => novedades.trim().isNotEmpty;
  double get diferenciaHectareas => hectareasReales - hectareasProgramadas;

  Map<String, dynamic> toMap() {
    return {
      'servicioId': servicioId,
      'clienteNombre': clienteNombre,
      'cultivo': cultivo,
      'fincaUbicacion': fincaUbicacion,
      'fechaVuelo': fechaVuelo.toIso8601String(),
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'hectareasProgramadas': hectareasProgramadas,
      'hectareasReales': hectareasReales,
      if (litrosTotalesMezcla != null) 'litrosTotalesMezcla': litrosTotalesMezcla,
      'bateriasUtilizadas': bateriasUtilizadas,
      'tiempoVueloMinutos': tiempoVueloMinutos,
      'climaCondicion': climaCondicion,
      'velocidadViento': velocidadViento,
      'estadoResultado': estadoResultado,
      'piloto': piloto,
      'dron': dron,
      'novedades': novedades,
      'observaciones': observaciones,
    };
  }

  factory BitacoraVueloModel.fromMap(String? id, Map<String, dynamic> map) {
    return BitacoraVueloModel(
      id: id,
      servicioId: map['servicioId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      cultivo: map['cultivo'] ?? '',
      fincaUbicacion: map['fincaUbicacion'] ?? '',
      fechaVuelo: map['fechaVuelo'] != null
          ? DateTime.parse(map['fechaVuelo'])
          : (map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now()),
      fechaRegistro: map['fechaRegistro'] != null
          ? DateTime.parse(map['fechaRegistro'])
          : DateTime.now(),
      hectareasProgramadas: (map['hectareasProgramadas'] ?? map['hectareas'] ?? 0).toDouble(),
      hectareasReales: (map['hectareasReales'] ?? map['hectareas'] ?? 0).toDouble(),
      litrosTotalesMezcla: map['litrosTotalesMezcla'] != null
          ? (map['litrosTotalesMezcla'] as num).toDouble()
          : (map['litrosAplicados'] != null ? (map['litrosAplicados'] as num).toDouble() : null),
      bateriasUtilizadas: (map['bateriasUtilizadas'] ?? 1) is int
          ? (map['bateriasUtilizadas'] ?? 1) as int
          : ((map['bateriasUtilizadas'] as num?)?.toInt() ?? 1),
      tiempoVueloMinutos: (map['tiempoVueloMinutos'] ?? 0) is int
          ? (map['tiempoVueloMinutos'] ?? 0) as int
          : ((map['tiempoVueloMinutos'] as num?)?.toInt() ?? 0),
      climaCondicion: map['climaCondicion'] ?? 'Óptimo',
      velocidadViento: map['velocidadViento'] ?? '< 10 km/h',
      estadoResultado: map['estadoResultado'] ?? 'VUELO_EXITOSO',
      piloto: map['piloto'] ?? '',
      dron: map['dron'] ?? '',
      novedades: map['novedades'] ?? '',
      observaciones: map['observaciones'] ?? '',
    );
  }
}
