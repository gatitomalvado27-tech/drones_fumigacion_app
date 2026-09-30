import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/repuesto_vida_util_model.dart';
import '../theme/agro_theme.dart';
import '../widgets/registro_repuesto_dialog.dart';

class RepuestosVidaUtilScreen extends StatefulWidget {
  final bool comoWidget;

  const RepuestosVidaUtilScreen({super.key, this.comoWidget = false});

  @override
  State<RepuestosVidaUtilScreen> createState() => _RepuestosVidaUtilScreenState();
}

class _RepuestosVidaUtilScreenState extends State<RepuestosVidaUtilScreen> {
  String _busqueda = '';
  String _filtroCategoria = 'TODOS';
  String _filtroEstado = 'TODOS';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  Future<void> _incrementarUsoRapido(RepuestoVidaUtilModel r) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: AgroTheme.getPrimary(context)),
            const SizedBox(width: 8),
            const Text('Añadir Uso / Jornada', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.nombre} (${r.nombreEquipo})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Uso actual: ${r.usoActual.toStringAsFixed(1)} ${r.unidadTexto}. Límite: ${r.vidaUtilEstimada.toStringAsFixed(0)} ${r.unidadTexto}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad a sumar (${r.unidadTexto})',
                hintText: 'Ej. 5.5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AgroTheme.getPrimary(context),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final suma = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
              if (suma > 0 && r.id != null) {
                final nuevoUso = r.usoActual + suma;
                await FirebaseFirestore.instance.collection('repuestos_vida_util').doc(r.id).update({
                  'usoActual': nuevoUso,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sumar'),
          ),
        ],
      ),
    );
  }

  void _verHistorialCambios(RepuestoVidaUtilModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Historial de Reemplazos', style: TextStyle(fontSize: 16)),
                  Text(r.nombre, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: r.historialReemplazos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No hay reemplazos previos archivados para esta pieza.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: r.historialReemplazos.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final h = r.historialReemplazos[r.historialReemplazos.length - 1 - i];
                    DateTime fecha = DateTime.now();
                    final rawF = h['fecha'];
                    if (rawF is Timestamp) fecha = rawF.toDate();
                    if (rawF is String) fecha = DateTime.tryParse(rawF) ?? DateTime.now();

                    final usoFinal = (h['usoFinal'] as num?)?.toDouble() ?? 0.0;
                    final costo = (h['costo'] as num?)?.toDouble() ?? 0.0;
                    final unidad = h['unidad'] ?? r.unidadTexto;
                    final motivo = h['motivo'] ?? 'Mantenimiento';
                    final tecnico = h['tecnico'] ?? 'No especificado';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy - hh:mm a').format(fecha),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (costo > 0)
                              Text(
                                _currencyFormat.format(costo),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('• Motivo: $motivo', style: const TextStyle(fontSize: 12)),
                        Text('• Técnico / Piloto: $tecnico', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        Text('• Ciclo cumplido: ${usoFinal.toStringAsFixed(1)} $unidad', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        if (h['observaciones'] != null && h['observaciones'].toString().isNotEmpty)
                          Text('• Obs: ${h['observaciones']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _compartirResumenWhatsApp(List<RepuestoVidaUtilModel> repuestos) async {
    final vencidos = repuestos.where((r) => r.estaVencido).toList();
    final revision = repuestos.where((r) => r.estaEnRevision).toList();

    final buffer = StringBuffer()
      ..writeln('🛠️ *REPORTE DE ESTADO Y VIDA ÚTIL DE REPUESTOS*')
      ..writeln('🗓️ *Fecha:* ${DateFormat("dd/MM/yyyy - hh:mm a").format(DateTime.now())}')
      ..writeln('🏢 *Empresa:* Ícaro Proagro')
      ..writeln('--------------------------------');

    if (vencidos.isNotEmpty) {
      buffer.writeln('🔴 *REPUESTOS VENCIDOS / CAMBIO URGENTE (${vencidos.length}):*');
      for (var r in vencidos) {
        buffer.writeln(' • *${r.nombre}* [${r.nombreEquipo}]: ${r.usoActual.toStringAsFixed(1)}/${r.vidaUtilEstimada.toStringAsFixed(0)} ${r.unidadTexto} (100% consumido)');
      }
      buffer.writeln('');
    }

    if (revision.isNotEmpty) {
      buffer.writeln('🟡 *REPUESTOS PRÓXIMOS A VENCER (${revision.length}):*');
      for (var r in revision) {
        buffer.writeln(' • *${r.nombre}* [${r.nombreEquipo}]: ${r.usoActual.toStringAsFixed(1)}/${r.vidaUtilEstimada.toStringAsFixed(0)} ${r.unidadTexto} (${(r.porcentajeRestante * 100).toStringAsFixed(0)}% restante)');
      }
      buffer.writeln('');
    }

    if (vencidos.isEmpty && revision.isEmpty) {
      buffer.writeln('🟢 *Todos los repuestos y componentes activos se encuentran en estado óptimo.*');
    }

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmarEliminarRepuesto(RepuestoVidaUtilModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Repuesto'),
        content: Text('¿Deseas eliminar el monitoreo de "${r.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (r.id != null) {
                await FirebaseFirestore.instance.collection('repuestos_vida_util').doc(r.id).delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    final content = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('repuestos_vida_util').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        final docs = snapshot.data?.docs ?? [];
        final todos = docs.map((d) => RepuestoVidaUtilModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();

        // Métricas
        int totalRepuestos = todos.length;
        int criticosVencidos = 0;
        int enRevision = 0;
        int optimos = 0;
        double valorTotalInvertido = 0;

        for (var r in todos) {
          valorTotalInvertido += r.costoAdquisicion;
          if (r.estaVencido) {
            criticosVencidos++;
          } else if (r.estaEnRevision) {
            enRevision++;
          } else {
            optimos++;
          }
        }

        // Filtros
        final filtrados = todos.where((r) {
          if (_filtroCategoria != 'TODOS' && r.categoriaEquipo != _filtroCategoria) {
            return false;
          }
          if (_filtroEstado == 'ALERTA' && (!r.estaVencido && !r.estaEnRevision)) {
            return false;
          }
          if (_filtroEstado == 'OPTIMO' && (r.estaVencido || r.estaEnRevision)) {
            return false;
          }
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            final matchNombre = r.nombre.toLowerCase().contains(q);
            final matchEquipo = r.nombreEquipo.toLowerCase().contains(q);
            final matchProv = r.proveedor.toLowerCase().contains(q);
            final matchSerial = r.numeroSerie.toLowerCase().contains(q);
            return matchNombre || matchEquipo || matchProv || matchSerial;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // TARJETAS DE RESUMEN
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: cardBg,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildKpiCard('Monitoreados', '$totalRepuestos', Colors.teal, Icons.inventory_2_outlined, isDark),
                        const SizedBox(width: 8),
                        _buildKpiCard('Óptimos', '$optimos', Colors.green, Icons.check_circle_outline, isDark),
                        const SizedBox(width: 8),
                        _buildKpiCard('En Revisión', '$enRevision', Colors.orange, Icons.warning_amber_rounded, isDark),
                        const SizedBox(width: 8),
                        _buildKpiCard('Vencidos / Cambio', '$criticosVencidos', Colors.red, Icons.alarm_on_rounded, isDark),
                        const SizedBox(width: 8),
                        _buildKpiCard('Inversión', _currencyFormat.format(valorTotalInvertido), Colors.indigo, Icons.attach_money_rounded, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BARRA DE BÚSQUEDA Y ACCIONES RÁPIDAS
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar repuesto, equipo o serial...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (v) => setState(() => _busqueda = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Compartir Alertas a WhatsApp',
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => _compartirResumenWhatsApp(todos),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: primary),
                        tooltip: 'Nuevo Repuesto',
                        icon: const Icon(Icons.add, color: Colors.white, size: 22),
                        onPressed: () => RegistroRepuestoDialog.mostrar(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // FILTRO DE CATEGORÍAS
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'TODOS',
                        'DRON',
                        'CAMIONETA',
                        'GENERADOR',
                        'BATERIAS',
                        'SISTEMA_MEZCLA',
                      ].map((cat) {
                        final sel = _filtroCategoria == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              cat == 'TODOS' ? 'Todos los Equipos' : RepuestoVidaUtilModel.nombreCategoria(cat),
                              style: TextStyle(fontSize: 11, color: sel ? Colors.white : text),
                            ),
                            selected: sel,
                            selectedColor: primary,
                            checkmarkColor: Colors.white,
                            onSelected: (val) {
                              setState(() => _filtroCategoria = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // FILTRO DE ESTADO
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        {'id': 'TODOS', 'label': 'Todos los Estados'},
                        {'id': 'ALERTA', 'label': '⚠️ En Alerta / Vencidos'},
                        {'id': 'OPTIMO', 'label': '✅ Estado Óptimo'},
                      ].map((st) {
                        final sel = _filtroEstado == st['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              st['label']!,
                              style: TextStyle(fontSize: 10.5, color: sel ? Colors.white : text),
                            ),
                            selected: sel,
                            selectedColor: Colors.teal.shade700,
                            onSelected: (val) {
                              if (val) setState(() => _filtroEstado = st['id']!);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // LISTA DE REPUESTOS
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build_circle_outlined, size: 48, color: primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            totalRepuestos == 0 ? 'Aún no monitoreas repuestos' : 'No se encontraron repuestos',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            totalRepuestos == 0
                                ? 'Toca el botón "+" para registrar hélices, bombas, aceite, frenos o baterías.'
                                : 'Prueba cambiando el filtro o la búsqueda.',
                            style: TextStyle(fontSize: 12, color: subtext),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final r = filtrados[index];
                        return _buildRepuestoCard(context, r, isDark, primary, text, subtext, cardBg, border);
                      },
                    ),
            ),
          ],
        );
      },
    );

    if (widget.comoWidget) {
      return content;
    }

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      appBar: AppBar(
        title: const Text('Vida Útil y Repuestos'),
        backgroundColor: cardBg,
        foregroundColor: text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Nuevo Repuesto',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => RegistroRepuestoDialog.mostrar(context),
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildRepuestoCard(
    BuildContext context,
    RepuestoVidaUtilModel r,
    bool isDark,
    Color primary,
    Color text,
    Color subtext,
    Color cardBg,
    Color border,
  ) {
    final colorGauge = r.colorAlerta;
    final pctRestante = (r.porcentajeRestante * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: r.estaVencido
              ? Colors.red.shade600
              : (r.estaEnRevision ? Colors.orange.shade500 : border),
          width: r.estaVencido ? 1.5 : 1,
        ),
      ),
      elevation: isDark ? 0 : 1.5,
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA SUPERIOR: CATEGORÍA Y ESTADO
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(RepuestoVidaUtilModel.iconoCategoria(r.categoriaEquipo), size: 20, color: primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.nombre,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: text),
                      ),
                      Text(
                        '${r.nombreEquipo} • ${RepuestoVidaUtilModel.nombreCategoria(r.categoriaEquipo)}',
                        style: TextStyle(fontSize: 11.5, color: subtext),
                      ),
                    ],
                  ),
                ),
                // BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorGauge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorGauge.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.estaVencido
                            ? Icons.error_outline
                            : (r.estaEnRevision ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                        size: 13,
                        color: colorGauge,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r.estaVencido ? 'VENCIDO' : (r.estaEnRevision ? 'REVISIÓN' : 'ÓPTIMO'),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorGauge),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // BARRA DE PROGRESO DE VIDA ÚTIL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uso: ${r.usoActual.toStringAsFixed(1)} / ${r.vidaUtilEstimada.toStringAsFixed(0)} ${r.unidadTexto}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                ),
                Text(
                  r.estaVencido
                      ? 'Sobrepasado ${(r.usoActual - r.vidaUtilEstimada).toStringAsFixed(1)} ${r.unidadTexto}'
                      : '$pctRestante% restante (${r.usoRestante.toStringAsFixed(1)} ${r.unidadTexto})',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colorGauge),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: r.porcentajeConsumido,
                minHeight: 9,
                backgroundColor: border.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(colorGauge),
              ),
            ),

            const SizedBox(height: 12),

            // METADATOS COMPLEMENTARIOS
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (r.costoAdquisicion > 0)
                  _buildEtiquetaInfo(Icons.attach_money, _currencyFormat.format(r.costoAdquisicion), text, subtext),
                if (r.proveedor.isNotEmpty)
                  _buildEtiquetaInfo(Icons.storefront_outlined, r.proveedor, text, subtext),
                _buildEtiquetaInfo(Icons.calendar_today_outlined, 'Instalado: ${DateFormat("dd/MM/yyyy").format(r.fechaInstalacion)}', text, subtext),
                if (r.historialReemplazos.isNotEmpty)
                  _buildEtiquetaInfo(Icons.history_rounded, '${r.historialReemplazos.length} cambio(s) previo(s)', text, Colors.teal),
              ],
            ),

            const Divider(height: 20),

            // ACCIONES
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, size: 18, color: AgroTheme.error),
                  onPressed: () => _confirmarEliminarRepuesto(r),
                ),
                if (r.historialReemplazos.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.history, size: 14),
                    label: const Text('Historial', style: TextStyle(fontSize: 11)),
                    onPressed: () => _verHistorialCambios(r),
                  ),
                ],
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Sumar Uso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _incrementarUsoRapido(r),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.estaVencido ? Colors.orange.shade700 : primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.published_with_changes_rounded, size: 14),
                  label: Text(
                    r.estaVencido ? 'Reemplazar Ya' : 'Reemplazar',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => RegistroRepuestoDialog.mostrar(context, repuestoExistente: r, modoReemplazo: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiquetaInfo(IconData icon, String valor, Color text, Color subtext) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: subtext),
        const SizedBox(width: 4),
        Text(valor, style: TextStyle(fontSize: 11, color: text)),
      ],
    );
  }

  Widget _buildKpiCard(String label, String valor, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
