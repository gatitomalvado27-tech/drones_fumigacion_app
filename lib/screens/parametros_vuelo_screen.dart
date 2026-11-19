import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/parametro_vuelo_model.dart';
import '../theme/agro_theme.dart';
import '../utils/crop_helper.dart';
import '../widgets/registro_parametros_vuelo_dialog.dart';

class ParametrosVueloScreen extends StatefulWidget {
  final bool comoWidget;

  const ParametrosVueloScreen({super.key, this.comoWidget = false});

  @override
  State<ParametrosVueloScreen> createState() => _ParametrosVueloScreenState();
}

class _ParametrosVueloScreenState extends State<ParametrosVueloScreen> {
  String _busqueda = '';
  String _filtroCultivo = 'TODOS';
  DateTimeRange? _rangoFechas;

  Future<void> _seleccionarRangoFechas() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
      initialDateRange: _rangoFechas ??
          DateTimeRange(
            start: ahora.subtract(const Duration(days: 30)),
            end: ahora,
          ),
      locale: const Locale('es', 'CO'),
    );
    if (rango != null) {
      setState(() => _rangoFechas = rango);
    }
  }

  Future<void> _confirmarEliminar(ParametroVueloModel item) async {
    if (item.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Deseas eliminar los parámetros registrados para ${item.cultivo} (${item.clienteNombre})?'),
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
      await FirebaseFirestore.instance.collection('parametros_vuelo').doc(item.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro de parámetros eliminado.'), behavior: SnackBarBehavior.floating),
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
          .collection('parametros_vuelo')
          .orderBy('fechaAplicacion', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        final todos = (snapshot.data?.docs ?? [])
            .map((d) => ParametroVueloModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();

        // Lista dinámica de cultivos disponibles
        final cultivosSet = <String>{};
        for (final p in todos) {
          if (p.cultivo.trim().isNotEmpty) cultivosSet.add(p.cultivo.trim());
        }
        final cultivosOrdenados = ['TODOS', ...cultivosSet.toList()..sort()];
        final cultivoActivo = cultivosOrdenados.contains(_filtroCultivo) ? _filtroCultivo : 'TODOS';

        final filtrados = todos.where((p) {
          if (cultivoActivo != 'TODOS' && p.cultivo.trim() != cultivoActivo) return false;
          if (_rangoFechas != null) {
            final f = DateTime(p.fechaAplicacion.year, p.fechaAplicacion.month, p.fechaAplicacion.day);
            final ini = DateTime(_rangoFechas!.start.year, _rangoFechas!.start.month, _rangoFechas!.start.day);
            final fin = DateTime(_rangoFechas!.end.year, _rangoFechas!.end.month, _rangoFechas!.end.day);
            if (f.isBefore(ini) || f.isAfter(fin)) return false;
          }
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return p.clienteNombre.toLowerCase().contains(q) ||
                p.cultivo.toLowerCase().contains(q) ||
                p.loteUbicacion.toLowerCase().contains(q) ||
                p.tipoProducto.toLowerCase().contains(q) ||
                p.dron.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Barra de búsqueda y filtro de fecha
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por cliente, cultivo, lote o producto...',
                        prefixIcon: Icon(Icons.search, size: 19, color: subtext),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Filtrar por fecha',
                    icon: Icon(
                      _rangoFechas == null ? Icons.date_range_outlined : Icons.event_available,
                      size: 20,
                      color: _rangoFechas == null ? subtext : primary,
                    ),
                    onPressed: _seleccionarRangoFechas,
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => RegistroParametrosVueloDialog.mostrar(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo', style: TextStyle(fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            if (_rangoFechas != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: Icon(Icons.calendar_today, size: 14, color: primary),
                    label: Text(
                      '${DateFormat('dd/MM/yy').format(_rangoFechas!.start)} - ${DateFormat('dd/MM/yy').format(_rangoFechas!.end)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onDeleted: () => setState(() => _rangoFechas = null),
                  ),
                ),
              ),

            // Chips de filtro por cultivo
            if (cultivosOrdenados.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: cultivosOrdenados.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final cult = cultivosOrdenados[idx];
                    final sel = cultivoActivo == cult;
                    return ChoiceChip(
                      selected: sel,
                      label: Text(
                        cult == 'TODOS' ? 'Todos los cultivos' : '${CropHelper.getEmoji(cult)} $cult',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      onSelected: (_) => setState(() => _filtroCultivo = cult),
                    );
                  },
                ),
              ),

            const SizedBox(height: 6),

            // Lista de registros
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune_rounded, size: 52, color: subtext.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No hay parámetros registrados',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Guarda velocidad, altura, franja, caudal y dosis por cultivo para reutilizarlos como referencia.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: subtext),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => RegistroParametrosVueloDialog.mostrar(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Registrar parámetros'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final p = filtrados[index];
                        return _buildTarjetaParametro(p, cardBg, border, primary, text, subtext);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTarjetaParametro(
    ParametroVueloModel p,
    Color cardBg,
    Color border,
    Color primary,
    Color text,
    Color subtext,
  ) {
    final chipsTecnicos = <Widget>[];
    void addMetric(String label, String value) {
      chipsTecnicos.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$label: $value',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: text),
          ),
        ),
      );
    }

    if (p.velocidadVuelo != null) {
      addMetric('Velocidad', '${p.velocidadVuelo!.toStringAsFixed(1)} ${p.unidadVelocidadVuelo}');
    }
    if (p.alturaVuelo != null) addMetric('Altura', '${p.alturaVuelo!.toStringAsFixed(1)} m');
    if (p.anchoFranja != null) addMetric('Franja', '${p.anchoFranja!.toStringAsFixed(1)} m');
    if (p.caudalAplicacion != null) addMetric('Caudal', '${p.caudalAplicacion!.toStringAsFixed(1)} L/min');
    if (p.volumenPorHectarea != null) addMetric('Volumen', '${p.volumenPorHectarea!.toStringAsFixed(1)} L/Ha');
    if (p.velocidadAplicacion != null) addMetric('Rendimiento', '${p.velocidadAplicacion!.toStringAsFixed(1)} Ha/h');
    for (final extra in p.camposExtra.entries) {
      addMetric(extra.key, extra.value);
    }

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
              Text(CropHelper.getEmoji(p.cultivo), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.cultivo} • ${p.clienteNombre}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(p.fechaAplicacion)}'
                      '${p.loteUbicacion.isNotEmpty ? ' • ${p.loteUbicacion}' : ''}'
                      '${p.hectareas != null ? ' • ${p.hectareas!.toStringAsFixed(1)} Ha' : ''}',
                      style: TextStyle(fontSize: 12, color: subtext),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: subtext, size: 20),
                onSelected: (val) {
                  if (val == 'editar') {
                    RegistroParametrosVueloDialog.mostrar(context, existente: p);
                  } else if (val == 'referencia') {
                    RegistroParametrosVueloDialog.mostrar(context, referenciaInicial: p);
                  } else if (val == 'eliminar') {
                    _confirmarEliminar(p);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'referencia', child: Text('Usar como referencia')),
                  PopupMenuItem(value: 'editar', child: Text('Editar registro')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          if (p.tipoServicio.isNotEmpty || p.dron.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (p.tipoServicio.isNotEmpty) 'Servicio: ${p.tipoServicio}',
                if (p.dron.isNotEmpty) 'Equipo: ${p.dron}',
              ].join('  •  '),
              style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600),
            ),
          ],
          if (chipsTecnicos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: chipsTecnicos),
          ],
          if (p.tipoProducto.isNotEmpty || p.dosisProducto.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.science_outlined, size: 15, color: subtext),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Producto: ${p.tipoProducto.isNotEmpty ? p.tipoProducto : 'N/D'}'
                    '${p.dosisProducto.isNotEmpty ? '  •  Dosis: ${p.dosisProducto}' : ''}',
                    style: TextStyle(fontSize: 12, color: text),
                  ),
                ),
              ],
            ),
          ],
          if (p.observaciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              p.observaciones,
              style: TextStyle(fontSize: 12, color: subtext, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                ),
                onPressed: () => RegistroParametrosVueloDialog.mostrar(context, referenciaInicial: p),
                icon: Icon(Icons.copy_rounded, size: 14, color: primary),
                label: Text('Tomar referencia', style: TextStyle(fontSize: 11.5, color: primary)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => RegistroParametrosVueloDialog.mostrar(context, existente: p),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Editar', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
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
        title: const Text('Parámetros de Aplicación'),
      ),
      body: SafeArea(child: _buildContenido(context)),
    );
  }
}
