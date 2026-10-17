class ProgresoPredioModel {
  String? id;
  String clienteId;
  String clienteNombre;
  String clienteCedula;
  String fincaUbicacion;
  String cultivo;
  String? servicioId;
  DateTime fecha;
  String etapa; // 'PRE_VUELO', 'DURANTE', 'POST_APLICACION'
  List<String> fotosBase64;
  String observaciones;
  String piloto;

  ProgresoPredioModel({
    this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteCedula = '',
    this.fincaUbicacion = '',
    this.cultivo = '',
    this.servicioId,
    required this.fecha,
    this.etapa = 'POST_APLICACION',
    this.fotosBase64 = const [],
    this.observaciones = '',
    this.piloto = '',
  });

  String get etapaLabel {
    switch (etapa) {
      case 'PRE_VUELO':
        return 'Antes / Diagnóstico';
      case 'DURANTE':
        return 'Durante Aplicación';
      case 'POST_APLICACION':
      default:
        return 'Después / Evolución';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'clienteCedula': clienteCedula,
      'fincaUbicacion': fincaUbicacion,
      'cultivo': cultivo,
      if (servicioId != null) 'servicioId': servicioId,
      'fecha': fecha.toIso8601String(),
      'etapa': etapa,
      'fotosBase64': fotosBase64,
      'observaciones': observaciones,
      'piloto': piloto,
    };
  }

  factory ProgresoPredioModel.fromMap(String id, Map<String, dynamic> map) {
    return ProgresoPredioModel(
      id: id,
      clienteId: map['clienteId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      clienteCedula: map['clienteCedula'] ?? '',
      fincaUbicacion: map['fincaUbicacion'] ?? '',
      cultivo: map['cultivo'] ?? '',
      servicioId: map['servicioId'],
      fecha: map['fecha'] != null
          ? DateTime.parse(map['fecha'])
          : DateTime.now(),
      etapa: map['etapa'] ?? 'POST_APLICACION',
      fotosBase64: map['fotosBase64'] != null
          ? List<String>.from(map['fotosBase64'])
          : [],
      observaciones: map['observaciones'] ?? '',
      piloto: map['piloto'] ?? '',
    );
  }
}
