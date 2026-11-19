import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/mantenimiento_equipo_model.dart';
import '../theme/agro_theme.dart';
import '../widgets/registro_mantenimiento_dialog.dart';

class MantenimientosEquiposScreen extends StatefulWidget {
  final bool comoWidget;

  const MantenimientosEquiposScreen({super.key, this.comoWidget = false});

  @override
  State<MantenimientosEquiposScreen> createState() => _MantenimientosEquiposScreenState();
}

class _MantenimientosEquiposScreenState extends State<MantenimientosEquiposScreen> {
  String _busqueda = '';
  String _filtroCategoria = 'TODAS';
  String _filtroEstado = 'TODOS';

  Future<void> _cambiarEstado(MantenimientoEquipoModel m, String nuevoEstado) async {
    if (m.id == null) return;
    await FirebaseFirestore.instance
        .collection('mantenimientos_equipos')
        .doc(m.id)
        .update({'estado': nuevoEstado});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a ${MantenimientoEquipoModel.nombreEstado(nuevoEstado)}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmarEliminar(MantenimientoEquipoModel m) async {
    if (m.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mantenimiento'),
        content: Text('¿Deseas eliminar el mantenimiento programado de "${m.nombreEquipo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.getError(ctx), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('mantenimientos_equipos').doc(m.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mantenimiento eliminado.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildContenido(BuildContext context) {
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mantenimientos_equipos')
          .orderBy('fechaInicio', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        final todos = (snapshot.data?.docs ?? [])
            .map((d) => MantenimientoEquipoModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();

        final filtrados = todos.where((m) {
          if (_filtroCategoria != 'TODAS' && m.categoriaEquipo != _filtroCategoria) return false;
          if (_filtroEstado != 'TODOS' && m.estado != _filtroEstado) return false;
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return m.nombreEquipo.toLowerCase().contains(q) ||
                m.tipoMantenimiento.toLowerCase().contains(q) ||
                m.responsable.toLowerCase().contains(q) ||
                m.observaciones.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por equipo, técnico o tipo...',
                        prefixIcon: Icon(Icons.search, size: 19, color: subtext),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => RegistroMantenimientoDialog.mostrar(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Programar', style: TextStyle(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Filtros de estado
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final est in ['TODOS', 'PENDIENTE', 'EN_PROCESO', 'COMPLETADO'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _filtroEstado == est,
                        label: Text(
                          est == 'TODOS' ? 'Todos' : MantenimientoEquipoModel.nombreEstado(est),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onSelected: (_) => setState(() => _filtroEstado = est),
                      ),
                    ),
                ],
              ),
            ),

            // Filtros de categoría de equipo
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _filtroCategoria == 'TODAS',
                      label: const Text('Todos los equipos', style: TextStyle(fontSize: 11.5)),
                      onSelected: (_) => setState(() => _filtroCategoria = 'TODAS'),
                    ),
                  ),
                  for (final entry in MantenimientoEquipoModel.categoriasMap.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _filtroCategoria == entry.key,
                        label: Text(entry.value, style: const TextStyle(fontSize: 11.5)),
                        onSelected: (_) => setState(() => _filtroCategoria = entry.key),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.build_circle_outlined, size: 52, color: subtext.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'Sin mantenimientos registrados',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Programa mantenimientos de drones, vehículos, plantas eléctricas o baterías para evitar conflictos con los vuelos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: subtext),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => RegistroMantenimientoDialog.mostrar(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Programar mantenimiento'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final m = filtrados[idx];
                        final colorEst = MantenimientoEquipoModel.colorEstado(m.estado);
                        final rangoStr = m.esMultidia
                            ? '${DateFormat('dd/MM/yy hh:mm a').format(m.fechaInicio)} → ${DateFormat('dd/MM/yy hh:mm a').format(m.fechaFin)}'
                            : '${DateFormat('dd/MM/yyyy').format(m.fechaInicio)} • ${DateFormat('hh:mm a').format(m.fechaInicio)} - ${DateFormat('hh:mm a').format(m.fechaFin)}';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border.withValues(alpha: 0.6)),
                            boxShadow: AgroTheme.getShadow(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: colorEst.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      MantenimientoEquipoModel.iconoCategoria(m.categoriaEquipo),
                                      color: colorEst,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.nombreEquipo,
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                                        ),
                                        Text(
                                          '${MantenimientoEquipoModel.nombreCategoria(m.categoriaEquipo)} • ${m.tipoMantenimiento}',
                                          style: TextStyle(fontSize: 12, color: subtext),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorEst.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      MantenimientoEquipoModel.nombreEstado(m.estado),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorEst),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 15, color: primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rangoStr,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
                                    ),
                                  ),
                                ],
                              ),
                              if (m.responsable.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 15, color: subtext),
                                    const SizedBox(width: 6),
                                    Text('Responsable: ${m.responsable}', style: TextStyle(fontSize: 12, color: subtext)),
                                  ],
                                ),
                              ],
                              if (m.observaciones.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  m.observaciones,
                                  style: TextStyle(fontSize: 12, color: subtext),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  if (m.estado == 'PENDIENTE')
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: () => _cambiarEstado(m, 'EN_PROCESO'),
                                      child: const Text('Iniciar', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  if (m.estado != 'COMPLETADO')
                                    FilledButton.tonal(
                                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                      onPressed: () => _cambiarEstado(m, 'COMPLETADO'),
                                      child: const Text('Completar', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  TextButton(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () => RegistroMantenimientoDialog.mostrar(context, existente: m),
                                    child: const Text('Editar', style: TextStyle(fontSize: 11.5)),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () => _confirmarEliminar(m),
                                    child: Text('Eliminar', style: TextStyle(fontSize: 11.5, color: AgroTheme.getError(context))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comoWidget) {
      return _buildContenido(context);
    }
    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      appBar: AppBar(
        title: const Text('Mantenimiento de Equipos'),
      ),
      body: SafeArea(child: _buildContenido(context)),
    );
  }
}
