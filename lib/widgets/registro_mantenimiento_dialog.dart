import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/mantenimiento_equipo_model.dart';
import '../theme/agro_theme.dart';
import '../utils/time_picker_helper.dart';

class RegistroMantenimientoDialog extends StatefulWidget {
  final MantenimientoEquipoModel? existente;
  final DateTime? fechaInicial;

  const RegistroMantenimientoDialog({
    super.key,
    this.existente,
    this.fechaInicial,
  });

  static Future<bool?> mostrar(
    BuildContext context, {
    MantenimientoEquipoModel? existente,
    DateTime? fechaInicial,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegistroMantenimientoDialog(
        existente: existente,
        fechaInicial: fechaInicial,
      ),
    );
  }

  @override
  State<RegistroMantenimientoDialog> createState() => _RegistroMantenimientoDialogState();
}

class _RegistroMantenimientoDialogState extends State<RegistroMantenimientoDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _categoriaEquipo;
  late TextEditingController _nombreEquipoController;
  late String _tipoMantenimiento;
  late TextEditingController _responsableController;
  late TextEditingController _observacionesController;
  late String _estado;

  late DateTime _fechaInicio;
  late TimeOfDay _horaInicio;
  late DateTime _fechaFin;
  late TimeOfDay _horaFin;

  bool _guardando = false;

  static const Map<String, List<String>> _equiposSugeridos = {
    'DRON': ['DJI Agras T55', 'DJI Agras T50', 'DJI Agras T40', 'DJI Agras T30', 'DJI Agras T25', 'DJI Agras T20P', 'XAG P100 Pro'],
    'VEHICULO': ['Camioneta de Operaciones', 'Vehículo de Apoyo', 'Remolque'],
    'PLANTA_ELECTRICA': ['Generador DJI D12000iE', 'Planta Eléctrica Principal', 'Generador de Respaldo'],
    'ASPERSION': ['Sistema de Aspersión / Boquillas', 'Tanque de Mezcla', 'Bomba de Carga'],
    'BATERIAS': ['Banco de Baterías Inteligentes', 'Cargador Rápido', 'Batería T40'],
    'HERRAMIENTAS': ['Kit de Herramientas de Campo', 'Anemómetro / Estación', 'Caja de Repuestos'],
    'OTRO': ['Equipo Auxiliar'],
  };

  @override
  void initState() {
    super.initState();
    final ex = widget.existente;
    final baseDate = ex?.fechaInicio ?? widget.fechaInicial ?? DateTime.now();

    _categoriaEquipo = ex?.categoriaEquipo ?? 'DRON';
    _nombreEquipoController = TextEditingController(text: ex?.nombreEquipo ?? 'DJI Agras T40');
    _tipoMantenimiento = ex != null &&
            MantenimientoEquipoModel.tiposMantenimiento.contains(ex.tipoMantenimiento)
        ? ex.tipoMantenimiento
        : MantenimientoEquipoModel.tiposMantenimiento.first;
    _responsableController = TextEditingController(text: ex?.responsable ?? '');
    _observacionesController = TextEditingController(text: ex?.observaciones ?? '');
    _estado = ex?.estado ?? 'PENDIENTE';

    _fechaInicio = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _horaInicio = ex != null
        ? TimeOfDay(hour: ex.fechaInicio.hour, minute: ex.fechaInicio.minute)
        : const TimeOfDay(hour: 8, minute: 0);

    final finBase = ex?.fechaFin ?? baseDate;
    _fechaFin = DateTime(finBase.year, finBase.month, finBase.day);
    _horaFin = ex != null
        ? TimeOfDay(hour: ex.fechaFin.hour, minute: ex.fechaFin.minute)
        : const TimeOfDay(hour: 12, minute: 0);
  }

  @override
  void dispose() {
    _nombreEquipoController.dispose();
    _responsableController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final inicio = DateTime(
      _fechaInicio.year,
      _fechaInicio.month,
      _fechaInicio.day,
      _horaInicio.hour,
      _horaInicio.minute,
    );
    final fin = DateTime(
      _fechaFin.year,
      _fechaFin.month,
      _fechaFin.day,
      _horaFin.hour,
      _horaFin.minute,
    );

    if (!fin.isAfter(inicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de finalización debe ser posterior al inicio.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final modelo = MantenimientoEquipoModel(
        id: widget.existente?.id,
        categoriaEquipo: _categoriaEquipo,
        nombreEquipo: _nombreEquipoController.text.trim(),
        fechaInicio: inicio,
        fechaFin: fin,
        tipoMantenimiento: _tipoMantenimiento,
        observaciones: _observacionesController.text.trim(),
        responsable: _responsableController.text.trim(),
        estado: _estado,
        creadoEn: widget.existente?.creadoEn,
      );

      final col = FirebaseFirestore.instance.collection('mantenimientos_equipos');
      if (widget.existente?.id != null) {
        await col.doc(widget.existente!.id).update(modelo.toMap());
      } else {
        await col.add(modelo.toMap());
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existente == null
                  ? 'Mantenimiento programado para ${modelo.nombreEquipo}'
                  : 'Mantenimiento actualizado correctamente',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar mantenimiento: $e'),
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
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final sugerencias = _equiposSugeridos[_categoriaEquipo] ?? const <String>[];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.build_circle_outlined, color: Colors.deepPurpleAccent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existente == null ? 'Programar Mantenimiento' : 'Editar Mantenimiento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                ),
                Text(
                  'Equipos físicos y herramientas',
                  style: TextStyle(fontSize: 11.5, color: subtext),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoriaEquipo,
                decoration: const InputDecoration(
                  labelText: 'Categoría de equipo',
                  prefixIcon: Icon(Icons.category_outlined, size: 18),
                ),
                items: MantenimientoEquipoModel.categoriasMap.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _categoriaEquipo = val;
                      final lista = _equiposSugeridos[val];
                      if (lista != null && lista.isNotEmpty && widget.existente == null) {
                        _nombreEquipoController.text = lista.first;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreEquipoController,
                decoration: const InputDecoration(
                  labelText: 'Nombre o identificador del equipo *',
                  hintText: 'Ej: DJI Agras T40, Generador D12000iE...',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el equipo' : null,
              ),
              if (sugerencias.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sugerencias.take(4).map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _nombreEquipoController.text = s),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'INICIO DEL MANTENIMIENTO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.calendar_today, size: 15, color: primary),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(_fechaInicio),
                        style: TextStyle(fontSize: 12, color: text),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fechaInicio,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() {
                            _fechaInicio = d;
                            if (_fechaFin.isBefore(d)) _fechaFin = d;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.schedule, size: 15, color: primary),
                      label: Text(
                        _horaInicio.format(context),
                        style: TextStyle(fontSize: 12, color: text),
                      ),
                      onPressed: () async {
                        final t = await TimePickerHelper.seleccionarHora(
                          context,
                          horaInicial: _horaInicio,
                        );
                        if (t != null) setState(() => _horaInicio = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'FIN ESTIMADO (HORAS O VARIOS DÍAS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.event_available, size: 15, color: primary),
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(_fechaFin),
                        style: TextStyle(fontSize: 12, color: text),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fechaFin.isBefore(_fechaInicio) ? _fechaInicio : _fechaFin,
                          firstDate: _fechaInicio,
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _fechaFin = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.schedule, size: 15, color: primary),
                      label: Text(
                        _horaFin.format(context),
                        style: TextStyle(fontSize: 12, color: text),
                      ),
                      onPressed: () async {
                        final t = await TimePickerHelper.seleccionarHora(
                          context,
                          horaInicial: _horaFin,
                        );
                        if (t != null) setState(() => _horaFin = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _tipoMantenimiento,
                decoration: const InputDecoration(
                  labelText: 'Tipo de mantenimiento',
                  prefixIcon: Icon(Icons.handyman_outlined, size: 18),
                ),
                items: MantenimientoEquipoModel.tiposMantenimiento
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _tipoMantenimiento = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _responsableController,
                decoration: const InputDecoration(
                  labelText: 'Responsable / Técnico',
                  hintText: 'Ej: Piloto titular, Taller autorizado...',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _estado,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.flag_outlined, size: 18),
                ),
                items: MantenimientoEquipoModel.estados
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          MantenimientoEquipoModel.nombreEstado(e),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _estado = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacionesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones / Trabajos a realizar',
                  hintText: 'Ej: Cambio de hélices, calibración de radar, limpieza de filtros...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 16),
          label: Text(widget.existente == null ? 'Programar' : 'Guardar cambios'),
        ),
      ],
    );
  }
}
