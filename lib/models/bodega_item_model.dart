class BodegaItemModel {
  String? id;
  String nombre;
  String categoria; // 'REPUESTO', 'INSUMO_QUIMICO', 'HERRAMIENTA', 'EQUIPO', 'OTRO'
  double cantidad;
  String unidad; // 'unidades', 'litros', 'kilos', 'paquetes', 'metros', 'kits'
  double cantidadMinimaAlerta;
  String ubicacionBodega;
  double costoUnitario;
  String descripcion;
  String? imagenBase64;
  DateTime fechaActualizacion;

  BodegaItemModel({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.cantidad,
    this.unidad = 'unidades',
    this.cantidadMinimaAlerta = 2.0,
    this.ubicacionBodega = 'Bodega Principal',
    this.costoUnitario = 0.0,
    this.descripcion = '',
    this.imagenBase64,
    DateTime? fechaActualizacion,
  }) : fechaActualizacion = fechaActualizacion ?? DateTime.now();

  bool get estaBajoStock => cantidad <= cantidadMinimaAlerta;

  double get valorTotal => cantidad * costoUnitario;

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'cantidad': cantidad,
      'unidad': unidad,
      'cantidadMinimaAlerta': cantidadMinimaAlerta,
      'ubicacionBodega': ubicacionBodega,
      'costoUnitario': costoUnitario,
      'descripcion': descripcion,
      if (imagenBase64 != null) 'imagenBase64': imagenBase64,
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  factory BodegaItemModel.fromMap(String id, Map<String, dynamic> map) {
    return BodegaItemModel(
      id: id,
      nombre: map['nombre'] ?? '',
      categoria: map['categoria'] ?? 'REPUESTO',
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      unidad: map['unidad'] ?? 'unidades',
      cantidadMinimaAlerta: (map['cantidadMinimaAlerta'] ?? 2.0).toDouble(),
      ubicacionBodega: map['ubicacionBodega'] ?? 'Bodega Principal',
      costoUnitario: (map['costoUnitario'] ?? 0).toDouble(),
      descripcion: map['descripcion'] ?? '',
      imagenBase64: map['imagenBase64'],
      fechaActualizacion: map['fechaActualizacion'] != null
          ? DateTime.parse(map['fechaActualizacion'])
          : DateTime.now(),
    );
  }
}
