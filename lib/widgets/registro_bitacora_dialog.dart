import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/servicio_model.dart';
import '../models/bitacora_vuelo_model.dart';
import '../theme/agro_theme.dart';
import '../utils/crop_helper.dart';
import 'registro_dano_equipo_dialog.dart';
import 'registro_cobro_servicio_dialog.dart';

class RegistroBitacoraDialog extends StatefulWidget {
  final ServicioModel servicio;
  final VoidCallback? onGuardado;

  const RegistroBitacoraDialog({
    super.key,
    required this.servicio,
    this.onGuardado,
  });

  static Future<bool?> mostrar(BuildContext context, ServicioModel servicio) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RegistroBitacoraDialog(servicio: servicio),
    );
  }

  @override
  State<RegistroBitacoraDialog> createState() => _RegistroBitacoraDialogState();
}

class _RegistroBitacoraDialogState extends State<RegistroBitacoraDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _hectareasController;
  late TextEditingController _litrosController;
  late TextEditingController _tiempoMinutosController;
  late TextEditingController _novedadesController;
  late TextEditingController _observacionesController;

  int _baterias = 1;
  String _clima = 'Óptimo';
  String _viento = '< 10 km/h';
  String _resultado = 'VUELO_EXITOSO';
  bool _actualizarHectareasEnServicio = false;
  bool _guardando = false;

  final List<String> _opcionesClima = [
    'Óptimo',
    'Viento Moderado',
    'Caluroso / Seco',
    'Llovizna / Húmedo',
    'Viento Fuerte',
  ];

  final List<String> _opcionesViento = [
    '< 10 km/h',
    '10 - 15 km/h',
    '> 15 km/h',
  ];

  final List<String> _tagsNovedadesRapidas = [
    'Sin novedades',
    'Cables eléctricos',
    'Árboles altos en borde',
    'Viento cruzado',
    'Llovizna intermitente',
    'Terreno con pendiente',
    'Batería con bajo rendimiento',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.servicio.bitacora;
    final haInicial = b != null ? b.hectareasReales : widget.servicio.hectareas;
    final litrosInicial = b != null
        ? (b.litrosTotalesMezcla ?? widget.servicio.litrosAplicados ?? (widget.servicio.hectareas * 10))
        : (widget.servicio.litrosAplicados ?? (widget.servicio.hectareas * 10));
    final tiempoInicial = b != null ? b.tiempoVueloMinutos : (widget.servicio.hectareas * 4).round();

    _hectareasController = TextEditingController(text: haInicial.toStringAsFixed(1));
    _litrosController = TextEditingController(text: litrosInicial.toStringAsFixed(0));
    _tiempoMinutosController = TextEditingController(text: tiempoInicial.toString());
    _novedadesController = TextEditingController(text: b?.novedades ?? '');
    _observacionesController = TextEditingController(text: b?.observaciones ?? '');

    _baterias = b?.bateriasUtilizadas ?? (widget.servicio.hectareas / 3).ceil().clamp(1, 20);
    _clima = b?.climaCondicion ?? 'Óptimo';
    _viento = b?.velocidadViento ?? '< 10 km/h';
    _resultado = b?.estadoResultado ?? 'VUELO_EXITOSO';
  }

  @override
  void dispose() {
    _hectareasController.dispose();
    _litrosController.dispose();
    _tiempoMinutosController.dispose();
    _novedadesController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _agregarTagNovedad(String tag) {
    if (tag == 'Sin novedades') {
      _novedadesController.text = 'Sin novedades. Operación normal y dentro de los parámetros esperados.';
      setState(() {});
      return;
    }
    final actual = _novedadesController.text.trim();
    if (actual.isEmpty || actual.startsWith('Sin novedades')) {
      _novedadesController.text = tag;
    } else if (!actual.contains(tag)) {
      _novedadesController.text = '$actual, $tag';
    }
    setState(() {});
  }

  Future<void> _guardarBitacora() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final double haReales = double.tryParse(_hectareasController.text.replaceAll(',', '.')) ?? widget.servicio.hectareas;
      final double? litros = double.tryParse(_litrosController.text.replaceAll(',', '.'));
      final int tiempoMin = int.tryParse(_tiempoMinutosController.text) ?? 0;

      final bitacora = BitacoraVueloModel(
        servicioId: widget.servicio.id ?? '',
        clienteNombre: widget.servicio.clienteNombre,
        cultivo: widget.servicio.cultivo,
        fincaUbicacion: widget.servicio.fincaUbicacion,
        fechaVuelo: widget.servicio.fecha,
        fechaRegistro: DateTime.now(),
        hectareasProgramadas: widget.servicio.hectareas,
        hectareasReales: haReales,
        litrosTotalesMezcla: litros,
        bateriasUtilizadas: _baterias,
        tiempoVueloMinutos: tiempoMin,
        climaCondicion: _clima,
        velocidadViento: _viento,
        estadoResultado: _resultado,
        piloto: widget.servicio.piloto,
        dron: widget.servicio.dron,
        novedades: _novedadesController.text.trim(),
        observaciones: _observacionesController.text.trim(),
      );

      final Map<String, dynamic> updateData = {
        'bitacora': bitacora.toMap(),
        'estado': 'COMPLETADO',
      };

      if (litros != null && litros > 0) {
        updateData['litrosAplicados'] = litros;
      }

      if (_actualizarHectareasEnServicio && haReales != widget.servicio.hectareas) {
        updateData['hectareas'] = haReales;
        final nuevoTotal = haReales * widget.servicio.precioPorHectarea;
        updateData['precioTotal'] = nuevoTotal;
        widget.servicio.hectareas = haReales;
        widget.servicio.precioTotal = nuevoTotal;

        // Si ya existían transacciones de ingreso de este servicio, sincronizar el monto
        if (widget.servicio.id != null) {
          final snapTrans = await FirebaseFirestore.instance
              .collection('transacciones')
              .where('servicioId', isEqualTo: widget.servicio.id)
              .get();
          for (var doc in snapTrans.docs) {
            final data = doc.data();
            if (data['tipo'] == 'INGRESO') {
              await doc.reference.update({
                'monto': nuevoTotal,
                'descripcion': 'Fumigación ${widget.servicio.cultivo} ($haReales Ha) - ${widget.servicio.clienteNombre}',
              });
            }
          }
        }
      }

      // Guardar en el servicio
      if (widget.servicio.id != null) {
        await FirebaseFirestore.instance
            .collection('servicios')
            .doc(widget.servicio.id)
            .update(updateData);

        // Guardar copia directa en la colección 'bitacoras_vuelo' para consultas del historial
        await FirebaseFirestore.instance
            .collection('bitacoras_vuelo')
            .doc(widget.servicio.id)
            .set(bitacora.toMap());
      }

      widget.servicio.bitacora = bitacora;
      widget.servicio.estado = 'COMPLETADO';

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bitácora de vuelo guardada en el historial inteligente.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onGuardado?.call();

        // Si el servicio aún no tiene registrado su cobro en caja o no está pagado, ofrecer la gestión contable
        if (!widget.servicio.pagado && context.mounted) {
          RegistroCobroServicioDialog.mostrar(context, widget.servicio, abrirBitacoraDespues: false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar bitácora: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    final fechaFormateada = DateFormat("d 'de' MMMM, yyyy - hh:mm a", 'es').format(widget.servicio.fecha);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // HEADER DEL DIÁLOGO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bitácora de Vuelo Operativa',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                            ),
                            const SizedBox(width: 6),
                            Text(CropHelper.getEmoji(widget.servicio.cultivo), style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Text(
                          '${widget.servicio.cultivo} • ${widget.servicio.clienteNombre} (${widget.servicio.fincaUbicacion})',
                          style: TextStyle(fontSize: 12, color: subtext),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: subtext, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Cerrar sin guardar',
                  ),
                ],
              ),
            ),

            // CUERPO CON FORMULARIO
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Resumen de cabecera
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: border.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Fecha de Operación: $fechaFormateada',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
                            ),
                          ),
                          if (widget.servicio.piloto.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Piloto: ${widget.servicio.piloto}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // RESULTADO GENERAL DEL VUELO
                    Text('Calificación del Vuelo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip(
                          label: '✅ 100% Exitoso',
                          selected: _resultado == 'VUELO_EXITOSO',
                          color: const Color(0xFF2E7D32),
                          onTap: () => setState(() => _resultado = 'VUELO_EXITOSO'),
                        ),
                        _buildChoiceChip(
                          label: '⚠️ Parcial con Novedad',
                          selected: _resultado == 'PARCIAL_NOVEDAD',
                          color: Colors.orange,
                          onTap: () => setState(() => _resultado = 'PARCIAL_NOVEDAD'),
                        ),
                        _buildChoiceChip(
                          label: '🛑 Interrumpido',
                          selected: _resultado == 'INTERRUMPIDO',
                          color: Colors.red,
                          onTap: () => setState(() => _resultado = 'INTERRUMPIDO'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // DATOS OPERATIVOS (HECTÁREAS, LITROS, TIEMPO, BATERÍAS)
                    Text('Datos Operativos Reales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        // Hectáreas Reales
                        Expanded(
                          child: TextFormField(
                            controller: _hectareasController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Ha Reales Aplicadas',
                              labelStyle: const TextStyle(fontSize: 12),
                              helperText: 'Programadas: ${widget.servicio.hectareas} Ha',
                              helperStyle: TextStyle(fontSize: 10, color: subtext),
                              suffixText: 'Ha',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Requerido';
                              if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Litros Totales de Mezcla
                        Expanded(
                          child: TextFormField(
                            controller: _litrosController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Caldo Total Aplicado',
                              labelStyle: const TextStyle(fontSize: 12),
                              suffixText: 'Lts',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Tiempo de vuelo en minutos
                        Expanded(
                          child: TextFormField(
                            controller: _tiempoMinutosController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tiempo de Vuelo Total',
                              labelStyle: const TextStyle(fontSize: 12),
                              suffixText: 'min',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Ciclos de batería utilizados
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Baterías', style: TextStyle(fontSize: 10, color: subtext)),
                                    Text(
                                      '$_baterias ciclos',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (_baterias > 1) setState(() => _baterias--);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: border.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => setState(() => _baterias++),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.add, size: 16, color: primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // CONDICIONES CLIMÁTICAS
                    Text('Condición Climática en Campo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _opcionesClima.map((c) {
                        return _buildChoiceChip(
                          label: c,
                          selected: _clima == c,
                          color: primary,
                          onTap: () => setState(() => _clima = c),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),
                    Text('Velocidad Estimada del Viento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _opcionesViento.map((v) {
                        return _buildChoiceChip(
                          label: '💨 $v',
                          selected: _viento == v,
                          color: Colors.cyan,
                          onTap: () => setState(() => _viento = v),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // NOVEDADES E INCIDENCIAS (QUÉ PASÓ EN EL LOTE)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('¿Qué pasó en el vuelo? (Novedades)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                        Text('Opcional', style: TextStyle(fontSize: 11, color: subtext)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pulsa para agregar etiquetas rápidas de campo:',
                      style: TextStyle(fontSize: 11, color: subtext),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tagsNovedadesRapidas.map((t) {
                        return ActionChip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          backgroundColor: border.withValues(alpha: isDark ? 0.3 : 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          onPressed: () => _agregarTagNovedad(t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _novedadesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ej: Viento calmado, lote limpio, presencia de cuerdas eléctricas en linde este...',
                        hintStyle: TextStyle(fontSize: 12, color: subtext),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ACCESO A REPORTE DE DAÑOS EN EQUIPOS
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => RegistroDanoEquipoDialog.mostrar(context, servicioAsociado: widget.servicio),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.car_crash_outlined, size: 18, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Hubo daño en Dron, Camioneta o Baterías?',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : Colors.red.shade800),
                                  ),
                                  Text(
                                    'Toca aquí para registrar fotos, piezas y reporte en la Bitácora de Daños',
                                    style: TextStyle(fontSize: 10, color: subtext),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? Colors.red.shade200 : Colors.red.shade800),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // OBSERVACIONES ADICIONALES
                    Text('Observaciones Adicionales del Piloto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _observacionesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Anotaciones sobre producto aplicado, cliente o recomendaciones...',
                        hintStyle: TextStyle(fontSize: 12, color: subtext),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Opción de sincronizar el precio total del servicio si cambiaron las Ha
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _actualizarHectareasEnServicio,
                      onChanged: (val) => setState(() => _actualizarHectareasEnServicio = val ?? false),
                      title: Text(
                        'Actualizar hectáreas y valor facturado del servicio con el dato real aplicado',
                        style: TextStyle(fontSize: 12, color: text),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),

            // BOTONERA INFERIOR (Omitir vs Guardar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: border.withValues(alpha: isDark ? 0.15 : 0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  // Botón inteligente de no querer agregarlo
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Omitir Bitácora',
                      style: TextStyle(color: subtext, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _guardando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _guardando ? 'Guardando...' : 'Guardar en Historial',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _guardando ? null : _guardarBitacora,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : AgroTheme.getText(context),
          ),
        ),
      ),
    );
  }
}
