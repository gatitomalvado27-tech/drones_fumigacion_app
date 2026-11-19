import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/servicio_model.dart';
import '../services/agenda_validacion_service.dart';
import '../services/notification_service.dart';
import '../theme/agro_theme.dart';
import '../utils/time_picker_helper.dart';

class ReprogramarVueloDialog extends StatefulWidget {
  final ServicioModel servicio;

  const ReprogramarVueloDialog({super.key, required this.servicio});

  static Future<bool?> mostrar(BuildContext context, ServicioModel servicio) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReprogramarVueloDialog(servicio: servicio),
    );
  }

  @override
  State<ReprogramarVueloDialog> createState() => _ReprogramarVueloDialogState();
}

class _ReprogramarVueloDialogState extends State<ReprogramarVueloDialog> {
  late DateTime _nuevaFecha;
  late TimeOfDay _nuevaHora;
  String _motivoSeleccionado = '🌧️ Clima / Lluvia';
  late TextEditingController _detalleMotivoController;
  late TextEditingController _observacionesController;
  late bool _avisarWhatsApp;
  bool _guardando = false;
  ResultadoValidacionAgenda? _validacion;

  static const List<String> _motivosComunes = [
    '🌧️ Clima / Lluvia',
    '💨 Viento excesivo (>15 km/h)',
    '👨‍🌾 Disponibilidad / Aplazamiento del cliente',
    '🛸 Problema técnico / Mantenimiento de equipo',
    '🧪 Insumos químicos no listos',
    '🔁 Continuación / Nueva jornada de aplicación',
    '⚠️ Otro motivo',
  ];

  @override
  void initState() {
    super.initState();
    final base = widget.servicio.fecha.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(days: 1))
        : widget.servicio.fecha;
    _nuevaFecha = DateTime(base.year, base.month, base.day);
    _nuevaHora = TimeOfDay(
      hour: widget.servicio.fecha.hour,
      minute: widget.servicio.fecha.minute,
    );
    _detalleMotivoController = TextEditingController();
    _observacionesController = TextEditingController(text: widget.servicio.notas);
    _avisarWhatsApp = widget.servicio.clienteTelefono.trim().isNotEmpty;
    _verificarConflictos();
  }

  @override
  void dispose() {
    _detalleMotivoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  DateTime get _fechaHoraCompleta => DateTime(
        _nuevaFecha.year,
        _nuevaFecha.month,
        _nuevaFecha.day,
        _nuevaHora.hour,
        _nuevaHora.minute,
      );

  Future<void> _verificarConflictos() async {
    final res = await AgendaValidacionService.validarEnFirestore(
      fechaHoraVuelo: _fechaHoraCompleta,
      dronAsignado: widget.servicio.dron,
    );
    if (mounted) {
      setState(() => _validacion = res);
    }
  }

  Future<void> _confirmarReprogramacion() async {
    final s = widget.servicio;
    if (s.id == null) return;

    // Verificar advertencias en tiempo real antes de guardar
    final validacion = await AgendaValidacionService.validarEnFirestore(
      fechaHoraVuelo: _fechaHoraCompleta,
      dronAsignado: s.dron,
    );

    if (validacion.tieneAdvertencias && mounted) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (warnCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Expanded(child: Text('Advertencia de Cronograma', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (validacion.diaNoLaborable != null) ...[
                Text(
                  '• Día no laborable: ${validacion.diaNoLaborable!.motivo}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (validacion.diaNoLaborable!.descripcion.isNotEmpty)
                  Text('  ${validacion.diaNoLaborable!.descripcion}'),
                const SizedBox(height: 8),
              ],
              if (validacion.mantenimientosConflicto.isNotEmpty) ...[
                const Text(
                  '• Equipo en mantenimiento programado:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final m in validacion.mantenimientosConflicto)
                  Text(
                    '  - ${m.nombreEquipo} (${m.tipoMantenimiento}: ${DateFormat('dd/MM HH:mm').format(m.fechaInicio)} - ${DateFormat('dd/MM HH:mm').format(m.fechaFin)})',
                  ),
              ],
              const SizedBox(height: 12),
              const Text('¿Deseas reprogramar el vuelo en esta fecha de todas formas?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(warnCtx, false),
              child: const Text('Cambiar fecha'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(warnCtx, true),
              child: const Text('Sí, reprogramar'),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    setState(() => _guardando = true);
    try {
      final fechaCompleta = _fechaHoraCompleta;
      final motivoFinal = _detalleMotivoController.text.trim().isNotEmpty
          ? '$_motivoSeleccionado (${_detalleMotivoController.text.trim()})'
          : _motivoSeleccionado;

      final nuevoRegistroHistorial = <String, dynamic>{
        'fechaAnterior': s.fecha.toIso8601String(),
        'fechaNueva': fechaCompleta.toIso8601String(),
        'estadoAnterior': s.estado,
        'motivo': motivoFinal,
        'registradoEn': DateTime.now().toIso8601String(),
      };

      final historialActualizado = [
        ...s.historialReprogramaciones,
        nuevoRegistroHistorial,
      ];

      final notasActualizadas = _observacionesController.text.trim();
      final fechaOriginalFinal = s.fechaOriginal ?? s.fecha;

      // Actualización in-place del mismo documento (sin duplicados y manteniendo relación con cliente/servicio)
      await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
        'fecha': fechaCompleta.toIso8601String(),
        'estado': 'PROGRAMADO',
        'notas': notasActualizadas,
        'reprogramado': true,
        'fechaOriginal': fechaOriginalFinal.toIso8601String(),
        'historialReprogramaciones': historialActualizado,
      });

      final servicioActualizado = ServicioModel(
        id: s.id,
        clienteId: s.clienteId,
        clienteNombre: s.clienteNombre,
        clienteCedula: s.clienteCedula,
        clienteTelefono: s.clienteTelefono,
        fincaUbicacion: s.fincaUbicacion,
        fecha: fechaCompleta,
        hectareas: s.hectareas,
        litrosAplicados: s.litrosAplicados,
        cultivo: s.cultivo,
        tipoAplicacion: s.tipoAplicacion,
        productoQuimico: s.productoQuimico,
        precioPorHectarea: s.precioPorHectarea,
        precioTotal: s.precioTotal,
        estado: 'PROGRAMADO',
        pagado: s.pagado,
        notas: notasActualizadas,
        metodoPago: s.metodoPago,
        piloto: s.piloto,
        pilotoColorHex: s.pilotoColorHex,
        dron: s.dron,
        totalAbonado: s.totalAbonado,
        reprogramado: true,
        fechaOriginal: fechaOriginalFinal,
        historialReprogramaciones: historialActualizado,
        parametrosAplicacion: s.parametrosAplicacion,
      );

      await NotificationService.instance.programarRecordatorioVuelo(servicioActualizado);
      await NotificationService.instance.notificarReprogramacionVuelo(
        servicioActualizado,
        motivoFinal,
      );

      if (mounted) Navigator.pop(context, true);

      if (_avisarWhatsApp && s.clienteTelefono.trim().isNotEmpty) {
        final fechaTexto = DateFormat("EEEE d 'de' MMMM 'a las' hh:mm a", 'es').format(fechaCompleta);
        final mensaje = 'Estimado(a) *${s.clienteNombre}*, le informamos de *Icaro Proagro* que su servicio de vuelo (${s.cultivo} en ${s.fincaUbicacion}) ha sido reprogramado.\n\n'
            '🗓️ *Nueva Fecha y Hora:* $fechaTexto\n'
            '📝 *Motivo:* $motivoFinal\n\n'
            'Estamos atentos para confirmar o atender cualquier duda. ¡Muchas gracias por su confianza!';

        final telefonoLimpio = s.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
        final url = Uri.parse('https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(mensaje)}');
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vuelo reprogramado para el ${DateFormat('dd/MM/yyyy hh:mm a').format(fechaCompleta)}',
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reprogramar vuelo: $e'),
            backgroundColor: AgroTheme.getError(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.servicio;
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final primary = AgroTheme.getPrimary(context);
    final border = AgroTheme.getBorder(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_repeat_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reprogramar Vuelo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text)),
                Text('${s.cultivo} • ${s.fincaUbicacion}', style: TextStyle(fontSize: 11.5, color: subtext)),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 15, color: primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s.clienteNombre} (${s.hectareas} Ha)',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha actual: ${DateFormat('dd/MM/yyyy • hh:mm a').format(s.fecha)} (${s.estado})',
                    style: TextStyle(fontSize: 11.5, color: subtext),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('NUEVA FECHA Y HORA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      side: BorderSide(color: primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.calendar_today, size: 15, color: primary),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_nuevaFecha),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _nuevaFecha,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) {
                        setState(() => _nuevaFecha = d);
                        _verificarConflictos();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      side: BorderSide(color: primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.schedule, size: 15, color: primary),
                    label: Text(
                      _nuevaHora.format(context),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                    ),
                    onPressed: () async {
                      final t = await TimePickerHelper.seleccionarHora(context, horaInicial: _nuevaHora);
                      if (t != null) {
                        setState(() => _nuevaHora = t);
                        _verificarConflictos();
                      }
                    },
                  ),
                ),
              ],
            ),

            // Banner en vivo si la fecha elegida es no laborable o tiene mantenimiento
            if (_validacion != null && _validacion!.tieneAdvertencias) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_validacion!.diaNoLaborable != null)
                      Text(
                        '⚠️ Día no laborable: ${_validacion!.diaNoLaborable!.motivo}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: text),
                      ),
                    if (_validacion!.mantenimientosConflicto.isNotEmpty)
                      Text(
                        '🔧 Conflicto de mantenimiento: ${_validacion!.mantenimientosConflicto.map((m) => m.nombreEquipo).join(', ')}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: text),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Text('MOTIVO DE REPROGRAMACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _motivoSeleccionado,
              items: _motivosComunes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _motivoSeleccionado = val);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _detalleMotivoController,
              decoration: const InputDecoration(
                labelText: 'Detalle del motivo (opcional)',
                hintText: 'Ej: Lluvia intensa en la mañana, cliente solicita martes',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _observacionesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones del servicio',
                hintText: 'Puedes actualizar las notas operativas del vuelo',
              ),
            ),

            if (s.historialReprogramaciones.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'HISTORIAL DE FECHAS ANTERIORES (${s.historialReprogramaciones.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtext),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: s.historialReprogramaciones.reversed.take(3).map((item) {
                    final fAnt = DateTime.tryParse(item['fechaAnterior']?.toString() ?? '');
                    final fNva = DateTime.tryParse(item['fechaNueva']?.toString() ?? '');
                    final mot = item['motivo']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '• ${fAnt != null ? DateFormat('dd/MM HH:mm').format(fAnt) : '?'} → ${fNva != null ? DateFormat('dd/MM HH:mm').format(fNva) : '?'} ($mot)',
                        style: TextStyle(fontSize: 11, color: subtext),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (s.clienteTelefono.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _avisarWhatsApp,
                title: const Text('Notificar al cliente por WhatsApp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                subtitle: Text('Envía la nueva fecha y motivo al cliente', style: TextStyle(fontSize: 11, color: subtext)),
                onChanged: (val) => setState(() => _avisarWhatsApp = val),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Reprogramar'),
          onPressed: _guardando ? null : _confirmarReprogramacion,
        ),
      ],
    );
  }
}
