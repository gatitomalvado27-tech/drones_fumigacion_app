import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bitacora_dano_equipo_model.dart';
import '../theme/agro_theme.dart';
import '../widgets/registro_dano_equipo_dialog.dart';
import '../services/pdf_service.dart';

class BitacoraDanosScreen extends StatefulWidget {
  final bool comoWidget;

  const BitacoraDanosScreen({super.key, this.comoWidget = false});

  @override
  State<BitacoraDanosScreen> createState() => _BitacoraDanosScreenState();
}

class _BitacoraDanosScreenState extends State<BitacoraDanosScreen> {
  String _busqueda = '';
  String _filtroCategoria = 'TODOS';
  String _filtroEstado = 'TODOS';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  Future<void> _compartirPorWhatsApp(BitacoraDanoEquipoModel d) async {
    final fecha = DateFormat("dd/MM/yyyy - hh:mm a").format(d.fecha);
    final buffer = StringBuffer()
      ..writeln('🛠️ *REPORTE TÉCNICO DE DAÑO EN EQUIPO*')
      ..writeln('🗓️ *Fecha:* $fecha')
      ..writeln('📦 *Equipo:* ${BitacoraDanoEquipoModel.nombreCategoria(d.categoriaEquipo)} - ${d.nombreEquipo}')
      ..writeln('⚠️ *Severidad:* ${BitacoraDanoEquipoModel.nombreGravedad(d.gravedad)}')
      ..writeln('🚦 *Estado:* ${BitacoraDanoEquipoModel.nombreEstado(d.estado)}')
      ..writeln('🧑‍✈️ *Reportado por:* ${d.pilotoReporta}')
      ..writeln('--------------------------------')
      ..writeln('💥 *Tipo de Daño:* ${d.tipoDano}');

    if (d.descripcion.isNotEmpty) {
      buffer.writeln('📝 *Detalle:* ${d.descripcion}');
    }

    if (d.costoReparacion > 0) {
      buffer.writeln('💰 *Costo estimado/real:* ${_currencyFormat.format(d.costoReparacion)}');
    }

    if (d.piezasCambiadas.isNotEmpty) {
      buffer.writeln('🔧 *Repuestos/Piezas:* ${d.piezasCambiadas}');
    }

    if (d.videoUrl != null && d.videoUrl!.isNotEmpty) {
      buffer.writeln('🎥 *Video Evidencia:* ${d.videoUrl}');
    }

    if (d.fotosBase64.isNotEmpty) {
      buffer.writeln('📸 Contiene ${d.fotosBase64.length} foto(s) de evidencia en el sistema.');
    }

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  Future<void> _exportarFichaTecnicaPdf(BitacoraDanoEquipoModel d) async {
    try {
      await PdfService.generarYCompartirFichaTecnicaDano(d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar la Ficha Técnica en PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _mostrarFotoAmpliada(String base64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.memory(base64Decode(base64), fit: BoxFit.contain),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarDano(BitacoraDanoEquipoModel d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar novedad de equipo?'),
        content: Text('Se eliminará el reporte de daño de ${d.nombreEquipo} (${d.tipoDano}). Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              if (d.id != null) {
                await FirebaseFirestore.instance.collection('bitacoras_danos').doc(d.id).delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registro de daño eliminado.')),
                );
              }
            },
            child: const Text('Eliminar'),
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

    Widget contenido = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bitacoras_danos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        final docs = snapshot.data?.docs ?? [];
        final todosDanos = docs.map((d) {
          return BitacoraDanoEquipoModel.fromMap(d.id, d.data() as Map<String, dynamic>);
        }).toList();

        // Ordenar por fecha descendente
        todosDanos.sort((a, b) => b.fecha.compareTo(a.fecha));

        // Métricas
        final totalRegistros = todosDanos.length;
        final criticos = todosDanos.where((d) => d.gravedad == 'CRITICA' && d.estado != 'REPARADO').length;
        final enTaller = todosDanos.where((d) => d.estado == 'EN_REPARACION').length;
        final reparados = todosDanos.where((d) => d.estado == 'REPARADO').length;
        final double costoTotal = todosDanos.fold(0.0, (acc, d) => acc + d.costoReparacion);

        // Filtrado
        final filtrados = todosDanos.where((d) {
          if (_filtroCategoria != 'TODOS' && d.categoriaEquipo != _filtroCategoria) return false;
          if (_filtroEstado != 'TODOS' && d.estado != _filtroEstado) return false;

          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            final matchEquipo = d.nombreEquipo.toLowerCase().contains(q);
            final matchTipo = d.tipoDano.toLowerCase().contains(q);
            final matchDesc = d.descripcion.toLowerCase().contains(q);
            final matchPiloto = d.pilotoReporta.toLowerCase().contains(q);
            return matchEquipo || matchTipo || matchDesc || matchPiloto;
          }
          return true;
        }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TARJETAS DE RESUMEN
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMetricaCard(
                            titulo: 'Total Novedades',
                            valor: '$totalRegistros',
                            color: Colors.blueAccent,
                            icono: Icons.report_problem_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricaCard(
                            titulo: 'Inoperativos',
                            valor: '$criticos',
                            color: Colors.redAccent,
                            icono: Icons.dangerous_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricaCard(
                            titulo: 'En Reparación',
                            valor: '$enTaller',
                            color: Colors.amber.shade800,
                            icono: Icons.build_circle_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricaCard(
                            titulo: 'Reparados',
                            valor: '$reparados',
                            color: const Color(0xFF2E7D32),
                            icono: Icons.check_circle_outline,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildMetricaCard(
                            titulo: 'Costo Invertido',
                            valor: _currencyFormat.format(costoTotal),
                            color: Colors.purpleAccent,
                            icono: Icons.attach_money,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // BUSCADOR
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar por equipo, daño, piloto o pieza...',
                        hintStyle: TextStyle(fontSize: 12, color: subtext),
                        prefixIcon: Icon(Icons.search, size: 18, color: subtext),
                        suffixIcon: _busqueda.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() => _busqueda = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border.withValues(alpha: 0.3)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _busqueda = val),
                    ),

                    const SizedBox(height: 10),

                    // CHIPS DE FILTRO POR CATEGORÍA
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFiltroChip('TODOS', 'Todos los Equipos'),
                          ...BitacoraDanoEquipoModel.categoriasMap.entries.map((e) {
                            return _buildFiltroChip(e.key, e.value);
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // FILTRO DE ESTADO
                    Row(
                      children: [
                        Text('Estado:', style: TextStyle(fontSize: 11.5, color: subtext, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        _buildEstadoChip('TODOS', 'Todos'),
                        const SizedBox(width: 6),
                        _buildEstadoChip('REPORTADO', 'Pendientes'),
                        const SizedBox(width: 6),
                        _buildEstadoChip('EN_REPARACION', 'En Taller'),
                        const SizedBox(width: 6),
                        _buildEstadoChip('REPARADO', 'Reparados'),
                      ],
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            if (filtrados.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined, size: 54, color: primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No hay novedades de daños registradas',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tus equipos (drones, camionetas, generadores y baterías) están 100% operativos o no coinciden con los filtros aplicados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: subtext),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Reportar Novedad de Equipo', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => RegistroDanoEquipoDialog.mostrar(context),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 85),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final d = filtrados[index];
                      return _buildDanoCard(d, cardBg, text, subtext, border, isDark, primary);
                    },
                    childCount: filtrados.length,
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (widget.comoWidget) {
      return Stack(
        children: [
          contenido,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              onPressed: () => RegistroDanoEquipoDialog.mostrar(context),
              icon: const Icon(Icons.add),
              label: const Text('Reportar Daño', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      appBar: AppBar(
        title: const Text('Bitácora de Daños e Incidentes'),
        backgroundColor: cardBg,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: border.withValues(alpha: 0.5), height: 1),
        ),
      ),
      body: SafeArea(child: contenido),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        onPressed: () => RegistroDanoEquipoDialog.mostrar(context),
        icon: const Icon(Icons.add),
        label: const Text('Reportar Daño', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDanoCard(
    BitacoraDanoEquipoModel d,
    Color cardBg,
    Color text,
    Color subtext,
    Color border,
    bool isDark,
    Color primary,
  ) {
    final colorGrav = BitacoraDanoEquipoModel.colorGravedad(d.gravedad);
    final colorEst = BitacoraDanoEquipoModel.colorEstado(d.estado);
    final iconoCat = BitacoraDanoEquipoModel.iconoCategoria(d.categoriaEquipo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.gravedad == 'CRITICA' && d.estado != 'REPARADO'
              ? Colors.redAccent.withValues(alpha: 0.8)
              : border.withValues(alpha: 0.6),
          width: d.gravedad == 'CRITICA' && d.estado != 'REPARADO' ? 1.5 : 1.0,
        ),
        boxShadow: AgroTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA DE LA TARJETA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorGrav.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Icon(iconoCat, size: 20, color: colorGrav),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nombreEquipo,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
                      ),
                      Text(
                        '${BitacoraDanoEquipoModel.nombreCategoria(d.categoriaEquipo)} • ${DateFormat('dd/MM/yyyy - hh:mm a').format(d.fecha)}',
                        style: TextStyle(fontSize: 10.5, color: subtext),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEst.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorEst.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    BitacoraDanoEquipoModel.nombreEstado(d.estado),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorEst),
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIPO DE DAÑO Y GRAVEDAD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        d.tipoDano,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorGrav.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        BitacoraDanoEquipoModel.nombreGravedad(d.gravedad),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorGrav),
                      ),
                    ),
                  ],
                ),

                if (d.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.descripcion,
                    style: TextStyle(fontSize: 12, color: subtext),
                  ),
                ],

                const SizedBox(height: 10),

                // METADATOS TÉCNICOS
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_circle_outlined, size: 14, color: subtext),
                        const SizedBox(width: 4),
                        Text('Piloto: ${d.pilotoReporta}', style: TextStyle(fontSize: 11, color: subtext)),
                      ],
                    ),
                    if (d.costoReparacion > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined, size: 14, color: Colors.purpleAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Costo: ${_currencyFormat.format(d.costoReparacion)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                          ),
                          if (d.gastoContableRegistrado) ...[
                            const SizedBox(width: 4),
                            const Text('(en Contabilidad)', style: TextStyle(fontSize: 9.5, color: Colors.green)),
                          ],
                        ],
                      ),
                    if (d.clienteNombre != null && d.clienteNombre!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.agriculture_outlined, size: 14, color: subtext),
                          const SizedBox(width: 4),
                          Text('Lote de: ${d.clienteNombre}', style: TextStyle(fontSize: 11, color: subtext)),
                        ],
                      ),
                  ],
                ),

                // PIEZAS CAMBIADAS (SI ESTÁ REPARADO)
                if (d.piezasCambiadas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔧 Repuestos aplicados: ${d.piezasCambiadas}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                // GALERÍA DE FOTOS
                if (d.fotosBase64.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 65,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: d.fotosBase64.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        return GestureDetector(
                          onTap: () => _mostrarFotoAmpliada(d.fotosBase64[i]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(d.fotosBase64[i]),
                              width: 65,
                              height: 65,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ENLACE A VIDEO
                if (d.videoUrl != null && d.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final uri = Uri.tryParse(d.videoUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo abrir el enlace del video.')),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Ver Video de Evidencia',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const Divider(height: 20),

                // BOTONES DE ACCIÓN
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Eliminar reporte',
                      icon: const Icon(Icons.delete_outline, size: 18, color: AgroTheme.error),
                      onPressed: () => _confirmarEliminarDano(d),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Colors.green),
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.chat, size: 14, color: Colors.green),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _compartirPorWhatsApp(d),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: Colors.red.shade400),
                        foregroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.red),
                      label: const Text('Ficha PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _exportarFichaTecnicaPdf(d),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: d.estado == 'REPARADO' ? Colors.grey.shade700 : primary,
                        foregroundColor: d.estado == 'REPARADO' ? Colors.white : Colors.black,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.edit_note, size: 15),
                      label: Text(
                        d.estado == 'REPARADO' ? 'Editar' : 'Gestionar / Reparar',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => RegistroDanoEquipoDialog.mostrar(context, danoExistente: d),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaCard({
    required String titulo,
    required String valor,
    required Color color,
    required IconData icono,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 10, color: AgroTheme.getSubtext(context))),
              Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String key, String label) {
    final sel = _filtroCategoria == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        selected: sel,
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        onSelected: (_) => setState(() => _filtroCategoria = key),
        selectedColor: AgroTheme.getPrimary(context).withValues(alpha: 0.25),
        side: BorderSide(color: sel ? AgroTheme.getPrimary(context) : AgroTheme.getBorder(context).withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }

  Widget _buildEstadoChip(String key, String label) {
    final sel = _filtroEstado == key;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _filtroEstado = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AgroTheme.getPrimary(context).withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? AgroTheme.getPrimary(context) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            color: sel ? AgroTheme.getPrimary(context) : AgroTheme.getSubtext(context),
          ),
        ),
      ),
    );
  }
}
