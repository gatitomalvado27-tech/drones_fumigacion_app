import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bitacora_vuelo_model.dart';
import '../models/servicio_model.dart';
import '../theme/agro_theme.dart';
import '../utils/crop_helper.dart';
import '../widgets/registro_bitacora_dialog.dart';
import 'bitacora_danos_screen.dart';
import 'repuestos_vida_util_screen.dart';

class BitacorasHistorialScreen extends StatefulWidget {
  const BitacorasHistorialScreen({super.key});

  @override
  State<BitacorasHistorialScreen> createState() => _BitacorasHistorialScreenState();
}

class _BitacorasHistorialScreenState extends State<BitacorasHistorialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _busqueda = '';
  String _filtroEstado = 'TODOS'; // 'TODOS', 'EXITOSOS', 'NOVEDADES'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _compartirPorWhatsApp(BitacoraVueloModel b) async {
    final fecha = DateFormat("dd/MM/yyyy - hh:mm a").format(b.fechaVuelo);
    final estadoStr = b.estadoResultado == 'VUELO_EXITOSO'
        ? '✅ 100% Exitoso'
        : (b.estadoResultado == 'PARCIAL_NOVEDAD' ? '⚠️ Parcial con Novedad' : '🛑 Interrumpido');

    final mensaje = StringBuffer()
      ..writeln('📋 *BITÁCORA DE VUELO AGRÍCOLA*')
      ..writeln('🗓️ *Fecha:* $fecha')
      ..writeln('🧑‍🌾 *Cliente:* ${b.clienteNombre}')
      ..writeln('🌱 *Cultivo:* ${b.cultivo} • ${b.fincaUbicacion}')
      ..writeln('🛸 *Piloto:* ${b.piloto.isNotEmpty ? b.piloto : "Operador"} | *Dron:* ${b.dron.isNotEmpty ? b.dron : "DJI Agras"}')
      ..writeln('--------------------------------')
      ..writeln('📊 *DATOS OPERATIVOS:*')
      ..writeln('• Hectáreas aplicadas: *${b.hectareasReales} Ha* (Prog: ${b.hectareasProgramadas} Ha)')
      ..writeln('• Tiempo de vuelo: *${b.tiempoVueloMinutos} minutos*')
      ..writeln('• Baterías utilizadas: *${b.bateriasUtilizadas} ciclos*')
      ..writeln('• Caldo aplicado: *${b.litrosTotalesMezcla != null ? "${b.litrosTotalesMezcla!.toStringAsFixed(0)} Lts" : "N/D"}*')
      ..writeln('• Clima en campo: *${b.climaCondicion}* (Viento: ${b.velocidadViento})')
      ..writeln('• Calificación: *$estadoStr*');

    if (b.novedades.isNotEmpty) {
      mensaje
        ..writeln('--------------------------------')
        ..writeln('⚠️ *NOVEDADES EN LOTE:*')
        ..writeln(b.novedades);
    }

    if (b.observaciones.isNotEmpty) {
      mensaje
        ..writeln('📝 *OBSERVACIONES:*')
        ..writeln(b.observaciones);
    }

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensaje.toString())}');
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

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      appBar: AppBar(
        title: const Text('Historial Inteligente de Bitácoras'),
        backgroundColor: cardBg,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: subtext,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.history_edu_rounded, size: 20), text: 'Vuelos y Campo'),
            Tab(icon: Icon(Icons.car_crash_rounded, size: 20), text: 'Daños en Equipos'),
            Tab(icon: Icon(Icons.build_circle_rounded, size: 20), text: 'Vida Útil Repuestos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBitacorasVueloTab(cardBg, text, subtext, primary, border, isDark),
          const BitacoraDanosScreen(comoWidget: true),
          const RepuestosVidaUtilScreen(comoWidget: true),
        ],
      ),
    );
  }

  Widget _buildBitacorasVueloTab(
    Color cardBg,
    Color text,
    Color subtext,
    Color primary,
    Color border,
    bool isDark,
  ) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primary));
            }

            final docs = snapshot.data?.docs ?? [];
            final List<BitacoraVueloModel> todasBitacoras = [];
            final Map<String, ServicioModel> mapaServicios = {};

            for (var d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final s = ServicioModel.fromMap(d.id, data);
              mapaServicios[s.id ?? ''] = s;

              if (s.bitacora != null) {
                todasBitacoras.add(s.bitacora!);
              } else if (data['bitacora'] != null) {
                try {
                  todasBitacoras.add(BitacoraVueloModel.fromMap(s.id, Map<String, dynamic>.from(data['bitacora'])));
                } catch (_) {}
              }
            }

            // Ordenar de más reciente a más antigua
            todasBitacoras.sort((a, b) => b.fechaVuelo.compareTo(a.fechaVuelo));

            // Métricas agregadas
            final totalVuelos = todasBitacoras.length;
            final double haAcumuladas = todasBitacoras.fold(0.0, (acc, b) => acc + b.hectareasReales);
            final int minutosAcumulados = todasBitacoras.fold(0, (acc, b) => acc + b.tiempoVueloMinutos);
            final int bateriasAcumuladas = todasBitacoras.fold(0, (acc, b) => acc + b.bateriasUtilizadas);
            final exitosos = todasBitacoras.where((b) => b.estadoResultado == 'VUELO_EXITOSO').length;
            final tasaExito = totalVuelos > 0 ? ((exitosos / totalVuelos) * 100).toStringAsFixed(0) : '100';

            // Filtrado por búsqueda y categoría
            final filtradas = todasBitacoras.where((b) {
              if (_filtroEstado == 'EXITOSOS' && b.estadoResultado != 'VUELO_EXITOSO') return false;
              if (_filtroEstado == 'NOVEDADES' && (b.estadoResultado == 'VUELO_EXITOSO' && !b.tieneNovedades)) return false;

              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                final coincideCliente = b.clienteNombre.toLowerCase().contains(q);
                final coincideCultivo = b.cultivo.toLowerCase().contains(q);
                final coincideFinca = b.fincaUbicacion.toLowerCase().contains(q);
                final coincidePiloto = b.piloto.toLowerCase().contains(q);
                final coincideNovedades = b.novedades.toLowerCase().contains(q);
                return coincideCliente || coincideCultivo || coincideFinca || coincidePiloto || coincideNovedades;
              }
              return true;
            }).toList();

            return Column(
              children: [
                // HEADER RESUMEN OPERATIVO INTELIGENTE
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border.withValues(alpha: 0.5)),
                    boxShadow: AgroTheme.getShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.insights_rounded, color: primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Telemetría Operativa Acumulada',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$tasaExito% Éxito',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMetricaMini('Vuelos', '$totalVuelos', Icons.flight_takeoff, primary, text, subtext),
                          _buildMetricaMini('Hectáreas', '${haAcumuladas.toStringAsFixed(1)} Ha', Icons.crop_square, Colors.teal, text, subtext),
                          _buildMetricaMini('Tiempo', '${(minutosAcumulados / 60).toStringAsFixed(1)} hrs', Icons.timer_outlined, Colors.orange, text, subtext),
                          _buildMetricaMini('Baterías', '$bateriasAcumuladas', Icons.battery_charging_full, Colors.cyan, text, subtext),
                        ],
                      ),
                    ],
                  ),
                ),

                // BARRA DE BÚSQUEDA Y FILTROS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por cliente, cultivo, piloto o novedad...',
                            hintStyle: TextStyle(fontSize: 12, color: subtext),
                            prefixIcon: Icon(Icons.search, size: 18, color: subtext),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            fillColor: cardBg,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
                            ),
                          ),
                          onChanged: (val) => setState(() => _busqueda = val),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // CHIPS DE FILTRO DE ESTADO
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFiltroChip('TODOS', 'Todas ($totalVuelos)'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('EXITOSOS', 'Solo Exitosos ($exitosos)'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('NOVEDADES', 'Con Novedades (${totalVuelos - exitosos})'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // LISTA DE BITÁCORAS
                Expanded(
                  child: filtradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_edu_rounded, size: 48, color: primary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                totalVuelos == 0 ? 'Aún no hay bitácoras registradas' : 'No hay resultados con este filtro',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                totalVuelos == 0
                                    ? 'Al completar un vuelo desde el Cronograma, podrás registrar qué pasó en campo.'
                                    : 'Prueba cambiando el término de búsqueda o el filtro.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: subtext),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filtradas.length,
                          itemBuilder: (context, index) {
                            final b = filtradas[index];
                            final s = mapaServicios[b.servicioId];
                            return _buildBitacoraCard(context, b, s, isDark, primary, text, subtext, cardBg, border);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildMetricaMini(String label, String valor, IconData icon, Color color, Color text, Color subtext) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                valor,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: subtext)),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String key, String label) {
    final selected = _filtroEstado == key;
    final primary = AgroTheme.getPrimary(context);
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: primary.withValues(alpha: 0.2),
      onSelected: (val) {
        if (val) setState(() => _filtroEstado = key);
      },
    );
  }

  Widget _buildBitacoraCard(
    BuildContext context,
    BitacoraVueloModel b,
    ServicioModel? s,
    bool isDark,
    Color primary,
    Color text,
    Color subtext,
    Color cardBg,
    Color border,
  ) {
    final hora = DateFormat('hh:mm a').format(b.fechaVuelo);
    final fechaDia = DateFormat("d 'de' MMMM, yyyy", 'es').format(b.fechaVuelo);

    Color resColor = const Color(0xFF2E7D32);
    String resTexto = 'Vuelo 100% Exitoso';
    if (b.estadoResultado == 'PARCIAL_NOVEDAD') {
      resColor = Colors.orange;
      resTexto = 'Parcial con Novedad';
    } else if (b.estadoResultado == 'INTERRUMPIDO') {
      resColor = Colors.red;
      resTexto = 'Interrumpido';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: b.tieneNovedades ? resColor.withValues(alpha: 0.4) : border.withValues(alpha: 0.5),
          width: b.tieneNovedades ? 1.5 : 1.0,
        ),
        boxShadow: AgroTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA: CULTIVO, CLIENTE Y ESTADO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        CropHelper.getEmoji(b.cultivo),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b.cultivo} • ${b.fincaUbicacion}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
                      ),
                      Text(
                        'Cliente: ${b.clienteNombre}',
                        style: TextStyle(fontSize: 11, color: subtext),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: resColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  resTexto,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: resColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // FECHA Y CONDICIÓN CLIMA
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: subtext),
              const SizedBox(width: 4),
              Text('$fechaDia • $hora', style: TextStyle(fontSize: 11, color: text)),
              const Spacer(),
              Icon(Icons.wb_sunny_outlined, size: 13, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text('${b.climaCondicion} (${b.velocidadViento})', style: TextStyle(fontSize: 11, color: subtext)),
            ],
          ),

          const Divider(height: 18),

          // DATOS OPERATIVOS EN GRID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataPill('Ha Aplicadas', '${b.hectareasReales} Ha', primary),
              _buildDataPill('Caldo Total', b.litrosTotalesMezcla != null ? '${b.litrosTotalesMezcla!.toStringAsFixed(0)} Lts' : 'N/D', Colors.teal),
              _buildDataPill('Baterías', '${b.bateriasUtilizadas} c.', Colors.cyan),
              _buildDataPill('Tiempo Vuelo', '${b.tiempoVueloMinutos} min', Colors.orange),
            ],
          ),

          // NOVEDADES O INCIDENCIAS (QUÉ PASÓ EN EL VUELO)
          if (b.novedades.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.report_problem_outlined, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Novedades en Vuelo / Lote:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.novedades,
                          style: TextStyle(fontSize: 11, color: text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // OBSERVACIONES ADICIONALES
          if (b.observaciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Obs: ${b.observaciones}',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subtext),
            ),
          ],

          const SizedBox(height: 10),

          // PILOTO Y BOTONES DE ACCIÓN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (b.piloto.isNotEmpty)
                Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: primary),
                    const SizedBox(width: 5),
                    Text(
                      'Piloto: ${b.piloto}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtext),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  // Compartir por WhatsApp
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: BorderSide(color: Colors.green.withValues(alpha: 0.8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.share, size: 13, color: Colors.green),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _compartirPorWhatsApp(b),
                  ),
                  if (s != null) ...[
                    const SizedBox(width: 6),
                    // Editar bitácora
                    IconButton(
                      icon: Icon(Icons.edit_note_rounded, size: 20, color: subtext),
                      tooltip: 'Editar Bitácora',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        RegistroBitacoraDialog.mostrar(context, s);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AgroTheme.getSubtext(context)),
        ),
      ],
    );
  }
}
