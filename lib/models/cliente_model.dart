class ClienteModel {
  String? id;
  String nombre;
  String cedula;
  String telefono;
  String ubicacion;
  String? cultivoPrincipal;
  bool activo;
  double saldoAFavor;

  ClienteModel({
    this.id,
    required this.nombre,
    this.cedula = '',
    required this.telefono,
    required this.ubicacion,
    this.cultivoPrincipal,
    this.activo = true,
    this.saldoAFavor = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'ubicacion': ubicacion,
      'cultivoPrincipal': cultivoPrincipal,
      'activo': activo,
      'saldoAFavor': saldoAFavor,
    };
  }

  factory ClienteModel.fromMap(String id, Map<String, dynamic> map) {
    return ClienteModel(
      id: id,
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      telefono: map['telefono'] ?? '',
      ubicacion: map['ubicacion'] ?? '',
      cultivoPrincipal: map['cultivoPrincipal'],
      activo: map['activo'] ?? true,
      saldoAFavor: (map['saldoAFavor'] ?? 0).toDouble(),
    );
  }
}