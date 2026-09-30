import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/repuesto_vida_util_model.dart';
import '../theme/agro_theme.dart';
import '../models/piloto_model.dart';
import '../models/transaccion_model.dart';

class RegistroRepuestoDialog extends StatefulWidget {
  final RepuestoVidaUtilModel? repuestoExistente;
  final bool modoReemplazo;

  const RegistroRepuestoDialog({
    super.key,
    this.repuestoExistente,
    this.modoReemplazo = false,
  });

  static Future<void> mostrar(
    BuildContext context, {
    RepuestoVidaUtilModel? repuestoExistente,
    bool modoReemplazo = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegistroRepuestoDialog(
        repuestoExistente: repuestoExistente,
        modoReemplazo: modoReemplazo,
      ),
    );
  }

  @override
  State<RegistroRepuestoDialog> createState() => _RegistroRepuestoDialogState();
}

class _RegistroRepuestoDialogState extends State<RegistroRepuestoDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _categoria;
  late String _tipoMedicion;
  late TextEditingController _nombreCtrl;
  late TextEditingController _equipoCtrl;
  late TextEditingController _serialCtrl;
  late TextEditingController _proveedorCtrl;
  late TextEditingController _costoCtrl;
  late TextEditingController _usoActualCtrl;
  late TextEditingController _vidaUtilCtrl;
  late TextEditingController _obsCtrl;
  DateTime _fechaInstalacion = DateTime.now();

  // Para modo Reemplazo
  late TextEditingController _motivoReemplazoCtrl;
  late TextEditingController _tecnicoReemplazoCtrl;
  bool _registrarGastoContable = false;
  String _metodoPagoGasto = 'BANCOLOMBIA';
  bool _guardando = false;

  final Map<String, List<Map<String, dynamic>>> _plantillas = {
    'DRON': [
      {'nombre': 'Hélices Plegables (Juego CW/CCW)', 'tipo': 'HORAS', 'vida': 150.0},
      {'nombre': 'Bomba Centrífuga de Aspersión', 'tipo': 'HECTAREAS', 'vida': 350.0},
      {'nombre': 'Boquillas Centrífugas / Atomizadores', 'tipo': 'HECTAREAS', 'vida': 500.0},
      {'nombre': 'Kit Mangueras y Conectores de Presión', 'tipo': 'HORAS', 'vida': 100.0},
      {'nombre': 'Motores y Rodamientos de Brazo', 'tipo': 'HORAS', 'vida': 600.0},
    ],
    'CAMIONETA': [
      {'nombre': 'Cambio Aceite Motor y Filtros', 'tipo': 'KILOMETRAJE', 'vida': 5000.0},
      {'nombre': 'Pastillas de Freno Delanteras/Traseras', 'tipo': 'KILOMETRAJE', 'vida': 20000.0},
      {'nombre': 'Kit de Neumáticos / Llantas', 'tipo': 'KILOMETRAJE', 'vida': 45000.0},
      {'nombre': 'Batería de Arranque 12V', 'tipo': 'DIAS', 'vida': 730.0},
      {'nombre': 'Filtro de Combustible / Trampa de Agua', 'tipo': 'KILOMETRAJE', 'vida': 10000.0},
    ],
    'GENERADOR': [
      {'nombre': 'Cambio de Aceite 10W30 / 15W40', 'tipo': 'HORAS', 'vida': 50.0},
      {'nombre': 'Bujía de Encendido', 'tipo': 'HORAS', 'vida': 100.0},
      {'nombre': 'Filtro de Aire / Espuma', 'tipo': 'HORAS', 'vida': 100.0},
      {'nombre': 'Limpieza y Calibración de Carburador', 'tipo': 'HORAS', 'vida': 250.0},
    ],
    'BATERIAS': [
      {'nombre': 'Vida de Batería Inteligente Agras', 'tipo': 'CICLOS', 'vida': 1000.0},
      {'nombre': 'Cables y Terminales de Alta Corriente', 'tipo': 'HORAS', 'vida': 300.0},
    ],
  };

  @override
  void initState() {
    super.initState();
    final r = widget.repuestoExistente;
    _categoria = r?.categoriaEquipo ?? 'DRON';
    _tipoMedicion = r?.tipoMedicion ?? 'HORAS';
    _fechaInstalacion = r?.fechaInstalacion ?? DateTime.now();

    _nombreCtrl = TextEditingController(text: r?.nombre ?? '');
    _equipoCtrl = TextEditingController(text: r?.nombreEquipo ?? 'Dron Agras T40 #1');
    _serialCtrl = TextEditingController(text: r?.numeroSerie ?? '');
    _proveedorCtrl = TextEditingController(text: r?.proveedor ?? '');
    _costoCtrl = TextEditingController(text: r != null && r.costoAdquisicion > 0 ? r.costoAdquisicion.toStringAsFixed(0) : '');
    _usoActualCtrl = TextEditingController(text: r != null ? r.usoActual.toStringAsFixed(1) : '0');
    _vidaUtilCtrl = TextEditingController(text: r != null ? r.vidaUtilEstimada.toStringAsFixed(0) : '150');
    _obsCtrl = TextEditingController(text: r?.observaciones ?? '');

    _motivoReemplazoCtrl = TextEditingController(text: widget.modoReemplazo ? 'Reemplazo por cumplimiento de vida útil' : '');
    _tecnicoReemplazoCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _equipoCtrl.dispose();
    _serialCtrl.dispose();
    _proveedorCtrl.dispose();
    _costoCtrl.dispose();
    _usoActualCtrl.dispose();
    _vidaUtilCtrl.dispose();
    _obsCtrl.dispose();
    _motivoReemplazoCtrl.dispose();
    _tecnicoReemplazoCtrl.dispose();
    super.dispose();
  }

  void _aplicarPlantilla(Map<String, dynamic> plan) {
    setState(() {
      _nombreCtrl.text = plan['nombre'];
      _tipoMedicion = plan['tipo'];
      _vidaUtilCtrl.text = (plan['vida'] as double).toStringAsFixed(0);
      _usoActualCtrl.text = '0';
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final costo = double.tryParse(_costoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final usoActual = double.tryParse(_usoActualCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final vidaUtil = double.tryParse(_vidaUtilCtrl.text.replaceAll(',', '.')) ?? 100.0;

      if (widget.modoReemplazo && widget.repuestoExistente != null) {
        // MODO REEMPLAZO: Archivar ciclo previo e iniciar nuevo
        final r = widget.repuestoExistente!;
        final nuevoRegistroHistorial = {
          'fecha': Timestamp.fromDate(DateTime.now()),
          'usoFinal': r.usoActual,
          'vidaEstimada': r.vidaUtilEstimada,
          'unidad': r.unidadTexto,
          'costo': costo > 0 ? costo : r.costoAdquisicion,
          'tecnico': _tecnicoReemplazoCtrl.text.trim().isNotEmpty ? _tecnicoReemplazoCtrl.text.trim() : 'Piloto / Técnico',
          'motivo': _motivoReemplazoCtrl.text.trim().isNotEmpty ? _motivoReemplazoCtrl.text.trim() : 'Mantenimiento preventivo',
          'observaciones': _obsCtrl.text.trim(),
        };

        final nuevoHistorial = List<Map<String, dynamic>>.from(r.historialReemplazos)..add(nuevoRegistroHistorial);

        await FirebaseFirestore.instance.collection('repuestos_vida_util').doc(r.id).update({
          'costoAdquisicion': costo > 0 ? costo : r.costoAdquisicion,
          'fechaInstalacion': Timestamp.fromDate(DateTime.now()),
          'usoActual': 0.0,
          'vidaUtilEstimada': vidaUtil,
          'estado': 'OPTIMO',
          'observaciones': 'Reemplazado el ${DateFormat("dd/MM/yyyy").format(DateTime.now())}. ${_obsCtrl.text.trim()}',
          'historialReemplazos': nuevoHistorial,
        });

        // Registrar egreso contable opcional
        if (_registrarGastoContable && costo > 0) {
          await FirebaseFirestore.instance.collection('transacciones').add({
            'tipo': 'EGRESO',
            'monto': costo,
            'categoria': 'MANTENIMIENTO',
            'metodoPago': _metodoPagoGasto,
            'fecha': Timestamp.fromDate(DateTime.now()),
            'descripcion': 'Repuesto y mantenimiento: ${_nombreCtrl.text.trim()} (${_equipoCtrl.text.trim()})',
            'usuario': _tecnicoReemplazoCtrl.text.trim().isNotEmpty ? _tecnicoReemplazoCtrl.text.trim() : 'Mantenimiento',
          });
        }
      } else if (widget.repuestoExistente != null) {
        // EDICIÓN SIMPLE
        await FirebaseFirestore.instance.collection('repuestos_vida_util').doc(widget.repuestoExistente!.id).update({
          'nombre': _nombreCtrl.text.trim(),
          'categoriaEquipo': _categoria,
          'nombreEquipo': _equipoCtrl.text.trim(),
          'numeroSerie': _serialCtrl.text.trim(),
          'proveedor': _proveedorCtrl.text.trim(),
          'costoAdquisicion': costo,
          'fechaInstalacion': Timestamp.fromDate(_fechaInstalacion),
          'tipoMedicion': _tipoMedicion,
          'usoActual': usoActual,
          'vidaUtilEstimada': vidaUtil,
          'observaciones': _obsCtrl.text.trim(),
        });
      } else {
        // CREACIÓN NUEVA
        final nuevo = RepuestoVidaUtilModel(
          nombre: _nombreCtrl.text.trim(),
          categoriaEquipo: _categoria,
          nombreEquipo: _equipoCtrl.text.trim(),
          numeroSerie: _serialCtrl.text.trim(),
          proveedor: _proveedorCtrl.text.trim(),
          costoAdquisicion: costo,
          fechaInstalacion: _fechaInstalacion,
          tipoMedicion: _tipoMedicion,
          usoActual: usoActual,
          vidaUtilEstimada: vidaUtil,
          observaciones: _obsCtrl.text.trim(),
          estado: 'OPTIMO',
          historialReemplazos: [],
        );

        await FirebaseFirestore.instance.collection('repuestos_vida_util').add(nuevo.toMap());

        // Asentar gasto inicial opcional
        if (_registrarGastoContable && costo > 0) {
          await FirebaseFirestore.instance.collection('transacciones').add({
            'tipo': 'EGRESO',
            'monto': costo,
            'categoria': 'MANTENIMIENTO',
            'metodoPago': _metodoPagoGasto,
            'fecha': Timestamp.fromDate(DateTime.now()),
            'descripcion': 'Adquisición repuesto: ${_nombreCtrl.text.trim()} (${_equipoCtrl.text.trim()})',
            'usuario': 'Inventario',
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.modoReemplazo
                ? '✅ Reemplazo registrado y ciclo reiniciado exitosamente.'
                : '✅ Repuesto guardado en monitoreo de vida útil.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar repuesto: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final cardBg = AgroTheme.getCard(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final primary = AgroTheme.getPrimary(context);
    final border = AgroTheme.getBorder(context);

    final esReemplazo = widget.modoReemplazo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ENCABEZADO
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (esReemplazo ? Colors.orange : primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          esReemplazo ? Icons.published_with_changes_rounded : Icons.build_circle_rounded,
                          color: esReemplazo ? Colors.orange.shade700 : primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esReemplazo
                                  ? 'Registrar Reemplazo de Repuesto'
                                  : (widget.repuestoExistente != null ? 'Editar Monitoreo' : 'Nuevo Repuesto a Monitorear'),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                            ),
                            Text(
                              esReemplazo
                                  ? 'Archiva el ciclo cumplido, reinicia el medidor y anota el técnico'
                                  : 'Control preventivo de horas, hectáreas o km de vida útil',
                              style: TextStyle(fontSize: 11, color: subtext),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (esReemplazo) ...[
                    // BANNER DE REEMPLAZO
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade600),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔄 Repuesto a Renovar: ${widget.repuestoExistente!.nombre}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Uso acumulado final: ${widget.repuestoExistente!.usoActual.toStringAsFixed(1)} / ${widget.repuestoExistente!.vidaUtilEstimada.toStringAsFixed(0)} ${widget.repuestoExistente!.unidadTexto} (${(widget.repuestoExistente!.porcentajeConsumido * 100).toStringAsFixed(0)}% consumido)',
                            style: TextStyle(fontSize: 11.5, color: subtext),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MOTIVO DE REEMPLAZO
                    TextFormField(
                      controller: _motivoReemplazoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Motivo del Cambio / Reemplazo *',
                        prefixIcon: const Icon(Icons.help_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el motivo' : null,
                    ),

                    const SizedBox(height: 12),

                    // TÉCNICO O PILOTO RESPONSABLE
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('pilotos').snapshots(),
                      builder: (context, snap) {
                        final pilotosDocs = snap.data?.docs ?? [];
                        final pilotos = pilotosDocs.map((d) => PilotoModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();

                        return DropdownButtonFormField<String>(
                          initialValue: _tecnicoReemplazoCtrl.text.isNotEmpty ? _tecnicoReemplazoCtrl.text : null,
                          decoration: InputDecoration(
                            labelText: 'Técnico / Piloto que realiza el cambio',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: pilotos.map((p) => DropdownMenuItem(value: p.nombre, child: Text(p.nombre))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _tecnicoReemplazoCtrl.text = val);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                  ] else ...[
                    // SELECTOR DE CATEGORÍA
                    const Text('Categoría del Equipo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['DRON', 'CAMIONETA', 'GENERADOR', 'BATERIAS', 'SISTEMA_MEZCLA', 'OTRO'].map((cat) {
                          final sel = _categoria == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              avatar: Icon(RepuestoVidaUtilModel.iconoCategoria(cat), size: 16, color: sel ? Colors.white : primary),
                              label: Text(RepuestoVidaUtilModel.nombreCategoria(cat), style: TextStyle(fontSize: 11, color: sel ? Colors.white : text)),
                              selected: sel,
                              selectedColor: primary,
                              onSelected: (val) {
                                if (val) setState(() => _categoria = cat);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PLANTILLAS RÁPIDAS
                    if (_plantillas.containsKey(_categoria)) ...[
                      Row(
                        children: [
                          Icon(Icons.flash_on_rounded, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          const Text('Sugerencias frecuentes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _plantillas[_categoria]!.map((plan) {
                          return ActionChip(
                            label: Text(plan['nombre'], style: const TextStyle(fontSize: 10.5)),
                            backgroundColor: border.withValues(alpha: 0.3),
                            onPressed: () => _aplicarPlantilla(plan),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // NOMBRE DEL REPUESTO
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Repuesto / Pieza *',
                        prefixIcon: const Icon(Icons.settings_suggest_rounded),
                        hintText: 'Ej. Juego de Hélices 5413 CW/CCW',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 12),

                    // NOMBRE DEL EQUIPO
                    TextFormField(
                      controller: _equipoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Equipo Asociado *',
                        prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
                        hintText: 'Ej. Dron Agras T40 Alfa / Hilux Placa XYZ-123',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 12),

                    // TIPO DE MEDICIÓN
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _tipoMedicion,
                            decoration: InputDecoration(
                              labelText: 'Unidad de Vida Útil',
                              prefixIcon: const Icon(Icons.av_timer_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'HORAS', child: Text('Horas de Uso (hrs)')),
                              DropdownMenuItem(value: 'HECTAREAS', child: Text('Hectáreas (Ha)')),
                              DropdownMenuItem(value: 'KILOMETRAJE', child: Text('Kilómetros (km)')),
                              DropdownMenuItem(value: 'CICLOS', child: Text('Ciclos de Carga')),
                              DropdownMenuItem(value: 'DIAS', child: Text('Días / Tiempo')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _tipoMedicion = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],

                  // VALORES DE VIDA ÚTIL
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usoActualCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: esReemplazo ? 'Nuevo Uso Inicial' : 'Uso Acumulado',
                            prefixIcon: const Icon(Icons.speed_rounded),
                            helperText: esReemplazo ? 'Reiniciado a 0' : 'Uso que lleva hoy',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _vidaUtilCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Vida Útil Estimada *',
                            prefixIcon: const Icon(Icons.timer_off_rounded),
                            helperText: 'Límite fabricante',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // COSTO Y PROVEEDOR
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: esReemplazo ? 'Costo del Nuevo Repuesto (\$)' : 'Costo Adquisición (\$)',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _proveedorCtrl,
                          decoration: InputDecoration(
                            labelText: 'Proveedor / Taller',
                            prefixIcon: const Icon(Icons.store_mall_directory),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // NÚMERO DE SERIE / OBS
                  TextFormField(
                    controller: _serialCtrl,
                    decoration: InputDecoration(
                      labelText: 'Número de Serie / Lote de Fábrica',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notas u Observaciones Técnicas',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // REGISTRAR EN CONTABILIDAD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Registrar Egreso en Contabilidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Asienta el costo del repuesto bajo "MANTENIMIENTO"', style: TextStyle(fontSize: 11)),
                          value: _registrarGastoContable,
                          onChanged: (val) => setState(() => _registrarGastoContable = val),
                        ),
                        if (_registrarGastoContable) ...[
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _metodoPagoGasto,
                            decoration: InputDecoration(
                              labelText: 'Cuenta de Salida de Dinero',
                              prefixIcon: const Icon(Icons.account_balance_wallet),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            items: TransaccionModel.metodosPagoMap.entries.map((e) {
                              return DropdownMenuItem(value: e.key, child: Text(e.value));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _metodoPagoGasto = v);
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // BOTONES INFERIORES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _guardando ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esReemplazo ? Colors.orange.shade700 : primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _guardando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(esReemplazo ? Icons.published_with_changes_rounded : Icons.save_rounded, size: 18),
                        label: Text(
                          _guardando ? 'Guardando...' : (esReemplazo ? 'Guardar y Reiniciar Ciclo' : 'Guardar Repuesto'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _guardando ? null : _guardar,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
