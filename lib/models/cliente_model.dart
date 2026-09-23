class ClienteModel {
  String? id;
  String nombre;
  String telefono;
  String ubicacion;
  String? cultivoPrincipal;
  bool activo;

  ClienteModel({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.ubicacion,
    this.cultivoPrincipal,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'ubicacion': ubicacion,
      'cultivoPrincipal': cultivoPrincipal,
      'activo': activo,
    };
  }

  factory ClienteModel.fromMap(String id, Map<String, dynamic> map) {
    return ClienteModel(
      id: id,
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'] ?? '',
      ubicacion: map['ubicacion'] ?? '',
      cultivoPrincipal: map['cultivoPrincipal'],
      activo: map['activo'] ?? true,
    );
  }
}