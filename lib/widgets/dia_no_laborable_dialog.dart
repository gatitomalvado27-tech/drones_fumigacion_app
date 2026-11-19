import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/dia_no_laborable_model.dart';
import '../theme/agro_theme.dart';

class DiaNoLaborableDialog extends StatefulWidget {
  final DateTime fecha;
  final DiaNoLaborableModel? existente;

  const DiaNoLaborableDialog({
    super.key,
    required this.fecha,
    this.existente,
  });

  static Future<bool?> mostrar(
    BuildContext context, {
    required DateTime fecha,
    DiaNoLaborableModel? existente,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DiaNoLaborableDialog(fecha: fecha, existente: existente),
    );
  }

  @override
  State<DiaNoLaborableDialog> createState() => _DiaNoLaborableDialogState();
}

class _DiaNoLaborableDialogState extends State<DiaNoLaborableDialog> {
  late String _motivo;
  late TextEditingController _descripcionController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _motivo = widget.existente != null &&
            DiaNoLaborableModel.motivosComunes.contains(widget.existente!.motivo)
        ? widget.existente!.motivo
        : DiaNoLaborableModel.motivosComunes.first;
    _descripcionController = TextEditingController(
      text: widget.existente?.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final modelo = DiaNoLaborableModel(
        id: DiaNoLaborableModel.generarIdFecha(widget.fecha),
        fecha: DateTime(widget.fecha.year, widget.fecha.month, widget.fecha.day),
        motivo: _motivo,
        descripcion: _descripcionController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('dias_no_laborables')
          .doc(modelo.id)
          .set(modelo.toMap());

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existente == null
                  ? 'Día marcado como no laborable (${DateFormat('dd/MM/yyyy').format(widget.fecha)})'
                  : 'Día no laborable actualizado',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar día no laborable: $e'),
            backgroundColor: AgroTheme.getError(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    setState(() => _guardando = true);
    try {
      final id = widget.existente?.id ?? DiaNoLaborableModel.generarIdFecha(widget.fecha);
      await FirebaseFirestore.instance
          .collection('dias_no_laborables')
          .doc(id)
          .delete();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bloqueo de día no laborable eliminado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar bloqueo: $e'),
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
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final errorColor = AgroTheme.getError(context);
    final fechaStr = DateFormat("EEEE d 'de' MMMM, yyyy", 'es_CO').format(widget.fecha);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existente == null ? 'Marcar Día No Laborable' : 'Editar Día No Laborable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                ),
                Text(
                  fechaStr[0].toUpperCase() + fechaStr.substring(1),
                  style: TextStyle(fontSize: 11.5, color: subtext),
                ),
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
            Text(
              'Los días marcados como no laborables muestran una advertencia clara si se intenta agendar un vuelo.',
              style: TextStyle(fontSize: 12, color: subtext),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                prefixIcon: Icon(Icons.label_outline, size: 18),
              ),
              items: DiaNoLaborableModel.motivosComunes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _motivo = val);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción o detalle (opcional)',
                hintText: 'Ej: Festivo nacional, descanso del equipo, compromiso personal...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existente != null)
          TextButton.icon(
            onPressed: _guardando ? null : _eliminar,
            icon: Icon(Icons.delete_outline, size: 18, color: errorColor),
            label: Text('Quitar bloqueo', style: TextStyle(color: errorColor)),
          ),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
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
          label: Text(widget.existente == null ? 'Bloquear día' : 'Guardar'),
        ),
      ],
    );
  }
}
