import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/agro_theme.dart';
import '../theme/theme_controller.dart';
import '../models/servicio_model.dart';
import '../services/clima_service.dart';
import '../utils/crop_helper.dart';
import 'servicios_screen.dart';
import 'herramientas_screen.dart';
import 'pin_login_screen.dart';
import '../utils/operaciones_helper.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onVerTodasTareas;

  const DashboardScreen({super.key, required this.onVerTodasTareas});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ClimaData? _clima;
  bool _cargandoClima = false;

  @override
  void initState() {
    super.initState();
    _cargarClima();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarActualizacionSilenciosa();
    });
  }

  Future<void> _verificarActualizacionSilenciosa() async {
    try {
      final nuevaVersion = await UpdateService.verificarSiHayActualizacion();
      if (nuevaVersion != null && mounted) {
        UpdateDialog.mostrar(context, nuevaVersion);
      }
    } catch (e) {
      debugPrint('Error en verificación de actualización: $e');
    }
  }

  Future<void> _cargarClima() async {
    if (!mounted) return;
    setState(() => _cargandoClima = true);
    final data = await ClimaService.instance.obtenerClimaActual();
    if (mounted) {
      setState(() {
        _clima = data;
        _cargandoClima = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    final climaActual = _clima ?? ClimaData.defaultData();

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER DE USUARIO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Icaro Proagro',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const IndicadorModoOffline(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
                        builder: (context, snapshot) {
                          int countNotif = 0;
                          final list = <ServicioModel>[];
                          if (snapshot.hasData) {
                            final now = DateTime.now();
                            final limit = now.add(const Duration(days: 2));
                            for (var doc in snapshot.data!.docs) {
                              final s = ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                              if (s.estado != 'CANCELADO' &&
                                  s.fecha.isAfter(now.subtract(const Duration(hours: 12))) &&
                                  s.fecha.isBefore(limit)) {
                                countNotif++;
                                list.add(s);
                              }
                            }
                          }
                          list.sort((a, b) => a.fecha.compareTo(b.fecha));

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                padding: const EdgeInsets.all(7),
                                tooltip: 'Notificaciones y Recordatorios',
                                icon: Icon(Icons.notifications_outlined, color: primary, size: 22),
                                onPressed: () => _mostrarPanelNotificaciones(context, list),
                              ),
                              if (countNotif > 0)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AgroTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$countNotif',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: const EdgeInsets.all(7),
                        tooltip: ThemeController.instance.isDarkMode ? 'Cambiar a Modo Blanco' : 'Cambiar a Modo Oscuro',
                        icon: Icon(
                          ThemeController.instance.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: primary,
                          size: 22,
                        ),
                        onPressed: () {
                          ThemeController.instance.alternarTema();
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _mostrarMenuSeguridad(context),
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: primary.withValues(alpha: 0.15),
                          child: Icon(Icons.person, color: primary, size: 19),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // SALUDO AL PILOTO
              Text(
                'Hola, Piloto',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Resumen de operaciones y telemetría de hoy',
                style: TextStyle(
                  fontSize: 14,
                  color: subtext,
                ),
              ),

              const SizedBox(height: 18),

              // HERO CARD: HECTÁREAS HOY (Aplicadas vs Programadas en tiempo real)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
                builder: (context, snapshot) {
                  double haCompletadas = 0.0;
                  double haProgramadas = 0.0;
                  int tareasCompletadas = 0;
                  int tareasHoy = 0;
                  final hoy = DateTime.now();

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final s = ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                      if (s.fecha.year == hoy.year && s.fecha.month == hoy.month && s.fecha.day == hoy.day) {
                        haProgramadas += s.hectareas;
                        tareasHoy++;
                        if (s.estado == 'COMPLETADO') {
                          haCompletadas += s.hectareas;
                          tareasCompletadas++;
                        }
                      }
                    }
                  }

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AgroTheme.getShadow(context),
                      border: Border.all(color: border.withValues(alpha: 0.5)),
                    ),
                    child: Stack(
                      children: [
                        // Gráfico de onda de fondo
                        Positioned(
                          right: -10,
                          bottom: -15,
                          child: Icon(
                            Icons.waves,
                            size: 140,
                            color: primary.withValues(alpha: 0.07),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.eco, color: primary, size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'APLICACIONES DE HOY',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: subtext,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$tareasCompletadas/$tareasHoy hechas',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    haCompletadas.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ha aplicadas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'De ${haProgramadas.toStringAsFixed(1)} ha agendadas para la jornada',
                                style: TextStyle(fontSize: 12, color: subtext),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // GRID DE 2 TARJETAS: BATERÍAS Y CLIMA / VIENTO EN VIVO
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta Baterías
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('baterias').snapshots(),
                      builder: (context, snapBat) {
                        int listas = snapBat.hasData ? snapBat.data!.docs.length : 0;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HerramientasScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
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
                                    Text('BATERÍAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtext)),
                                    Icon(Icons.battery_charging_full, size: 18, color: primary),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('$listas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: text)),
                                    const SizedBox(width: 4),
                                    Text('listas', style: TextStyle(fontSize: 12, color: subtext)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Toca para ver ciclos', style: TextStyle(fontSize: 11, color: primary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Tarjeta Clima / Viento en Tiempo Real
                  Expanded(
                    child: InkWell(
                      onTap: () => _mostrarDetalleClima(context, climaActual),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
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
                                    Text('VIENTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtext)),
                                    const SizedBox(width: 4),
                                    Text(climaActual.condicionIcono, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                _cargandoClima
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                                      )
                                    : Icon(Icons.air, size: 18, color: climaActual.estadoColor),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  climaActual.vientoKmh.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text),
                                ),
                                const SizedBox(width: 3),
                                Text('km/h', style: TextStyle(fontSize: 11, color: subtext)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(color: climaActual.estadoColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    climaActual.estadoVuelo,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: climaActual.estadoColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // BOTONES DE ACCIÓN RÁPIDA
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.flight, size: 18),
                      label: const Text('Nuevo Vuelo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ServiciosScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: text,
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      icon: Icon(Icons.calculate, size: 18, color: primary),
                      label: const Text('Calcular Caldo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HerramientasScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // SECCIÓN: PRÓXIMAS TAREAS INTELIGENTE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Próximas Tareas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onVerTodasTareas,
                    child: Text(
                      'VER TODAS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // LISTA DE TAREAS EN TIEMPO REAL (Filtrada inteligentemente)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primary));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final todosServicios = docs.map((d) => ServicioModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();

                  // Filtrar servicios activos (excluyendo completados y cancelados para "Próximas")
                  final serviciosPendientes = todosServicios.where((s) {
                    return s.estado != 'COMPLETADO' && s.estado != 'CANCELADO';
                  }).toList();

                  // Ordenar: primero EN_PROCESO, luego por fecha ascendente
                  serviciosPendientes.sort((a, b) {
                    if (a.estado == 'EN_PROCESO' && b.estado != 'EN_PROCESO') return -1;
                    if (b.estado == 'EN_PROCESO' && a.estado != 'EN_PROCESO') return 1;
                    return a.fecha.compareTo(b.fecha);
                  });

                  if (serviciosPendientes.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border.withValues(alpha: 0.5)),
                        boxShadow: AgroTheme.getShadow(context),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: primary, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '¡Al día con las aplicaciones!',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No hay vuelos pendientes en este momento.',
                            style: TextStyle(fontSize: 12, color: subtext),
                          ),
                        ],
                      ),
                    );
                  }

                  final proximas = serviciosPendientes.take(4).toList();

                  return Column(
                    children: proximas.map((s) => _buildProximaTareaCard(context, s)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProximaTareaCard(BuildContext context, ServicioModel s) {
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    Color badgeColor = primary;
    Color badgeBg = primary.withValues(alpha: 0.15);
    String estadoText = 'PENDIENTE';

    if (s.estado == 'EN_PROCESO') {
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFD97706).withValues(alpha: 0.15);
      estadoText = 'EN VUELO';
    } else if (s.estado == 'PROGRAMADO') {
      badgeColor = primary;
      badgeBg = primary.withValues(alpha: 0.12);
      estadoText = 'PROGRAMADO';
    }

    final hora = DateFormat('hh:mm a').format(s.fecha);
    final fechaDia = DateFormat("d 'de' MMMM", 'es').format(s.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.5)),
        boxShadow: AgroTheme.getShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barra vertical indicadora
              Container(
                width: 4,
                color: s.estado == 'EN_PROCESO' ? const Color(0xFFD97706) : primary,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            CropHelper.getEmoji(s.cultivo),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.cultivo} • ${s.fincaUbicacion}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Cliente: ${s.clienteNombre} (${s.hectareas} Ha)',
                              style: TextStyle(fontSize: 12, color: subtext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '📅 $fechaDia - $hora',
                              style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          estadoText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleClima(BuildContext context, ClimaData clima) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(clima.condicionIcono, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Text('Telemetría Climática'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ubicación: ${clima.ubicacionNombre}',
              style: TextStyle(fontWeight: FontWeight.bold, color: AgroTheme.getText(context)),
            ),
            const SizedBox(height: 8),
            _buildClimaFila(Icons.air, 'Viento en Superficie', '${clima.vientoKmh.toStringAsFixed(1)} km/h'),
            _buildClimaFila(Icons.waves, 'Ráfagas Máximas', '${clima.rafagasKmh.toStringAsFixed(1)} km/h'),
            _buildClimaFila(Icons.thermostat, 'Temperatura', '${clima.temperaturaC.toStringAsFixed(1)} °C'),
            _buildClimaFila(Icons.water_drop, 'Humedad Relativa', '${clima.humedadRelativa}%'),
            _buildClimaFila(Icons.cloud, 'Condición General', clima.condicionTexto),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: clima.estadoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: clima.estadoColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flight_takeoff, color: clima.estadoColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clima.estadoVuelo,
                      style: TextStyle(fontWeight: FontWeight.bold, color: clima.estadoColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar Ahora'),
            onPressed: () {
              Navigator.pop(ctx);
              _cargarClima();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClimaFila(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AgroTheme.getSubtext(context)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: AgroTheme.getSubtext(context))),
            ],
          ),
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AgroTheme.getText(context))),
        ],
      ),
    );
  }

  void _mostrarMenuSeguridad(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    final pinActual = prefs.getString('proicaro_pin_personalizado') ?? '2026';
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final border = AgroTheme.getBorder(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.shield, color: primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Seguridad & Acceso Icaro Proagro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Protección por PIN:', style: TextStyle(fontSize: 13, color: subtext)),
                  Row(
                    children: [
                      Icon(Icons.lock, size: 14, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'Activo (••••)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeController.instance.isDarkMode ? Colors.amber.withValues(alpha: 0.15) : primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ThemeController.instance.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: ThemeController.instance.isDarkMode ? Colors.amber : primary,
                  size: 20,
                ),
              ),
              title: Text(
                ThemeController.instance.isDarkMode ? 'Modo Blanco (Luz Solar)' : 'Modo Oscuro (Nocturno)',
                style: TextStyle(fontWeight: FontWeight.bold, color: text),
              ),
              subtitle: Text(
                ThemeController.instance.isDarkMode ? 'Fondo claro con verde nítido para trabajo en campo' : 'Fondo oscuro de cabina Stitch',
                style: TextStyle(fontSize: 12, color: subtext),
              ),
              trailing: Switch(
                value: !ThemeController.instance.isDarkMode,
                activeThumbColor: primary,
                onChanged: (val) {
                  ThemeController.instance.alternarTema();
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
            ),
            Divider(color: border.withValues(alpha: 0.5)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.key, color: primary, size: 20),
              ),
              title: Text('Cambiar PIN de Acceso', style: TextStyle(color: text, fontWeight: FontWeight.bold)),
              subtitle: Text('Requiere ingresar el PIN actual por seguridad', style: TextStyle(color: subtext, fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: subtext),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarDialogoCambiarPin(context, pinActual);
              },
            ),
            Divider(color: border.withValues(alpha: 0.5)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AgroTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: AgroTheme.error, size: 20),
              ),
              title: const Text('Bloquear este celular', style: TextStyle(color: AgroTheme.error, fontWeight: FontWeight.bold)),
              subtitle: Text('Exigirá el PIN la próxima vez que se abra', style: TextStyle(color: subtext, fontSize: 12)),
              onTap: () async {
                await prefs.setBool('proicaro_dispositivo_autorizado', false);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PinLoginScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoCambiarPin(BuildContext context, String pinActualConfigurado) {
    String pinActualIngresado = '';
    String nuevoPin = '';
    String confirmarPin = '';
    String? errorLocal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 22, color: AgroTheme.primary),
              SizedBox(width: 8),
              Text('Cambiar PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIN Actual:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'PIN actual',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_clock, size: 18),
                  ),
                  onChanged: (val) {
                    pinActualIngresado = val;
                    if (errorLocal != null) setModalState(() => errorLocal = null);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nuevo PIN (4 dígitos):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Nuevo PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin, size: 18),
                  ),
                  onChanged: (val) {
                    nuevoPin = val;
                    if (errorLocal != null) setModalState(() => errorLocal = null);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Confirmar Nuevo PIN:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Repite el nuevo PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                  ),
                  onChanged: (val) {
                    confirmarPin = val;
                    if (errorLocal != null) setModalState(() => errorLocal = null);
                  },
                ),
                if (errorLocal != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AgroTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorLocal!,
                      style: const TextStyle(fontSize: 11.5, color: AgroTheme.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AgroTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (pinActualIngresado != pinActualConfigurado) {
                  setModalState(() => errorLocal = 'El PIN actual no es correcto.');
                  return;
                }
                if (nuevoPin.length != 4) {
                  setModalState(() => errorLocal = 'El nuevo PIN debe tener exactamente 4 dígitos.');
                  return;
                }
                if (nuevoPin != confirmarPin) {
                  setModalState(() => errorLocal = 'La confirmación del PIN no coincide.');
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('proicaro_pin_personalizado', nuevoPin);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡PIN de acceso actualizado con éxito!'),
                    backgroundColor: AgroTheme.primary,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarPanelNotificaciones(BuildContext context, List<ServicioModel> proximos) {
    final primary = AgroTheme.getPrimary(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Alertas y Vuelos Próximos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${proximos.length} pendientes',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recordatorios automáticos para el piloto 2 horas antes de cada despegue.',
                    style: TextStyle(fontSize: 12, color: subtext),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: proximos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 56, color: primary.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  '¡Todo al día!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No hay vuelos programados para las próximas 48 horas.',
                                  style: TextStyle(fontSize: 13, color: subtext),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: proximos.length,
                            itemBuilder: (context, index) {
                              final s = proximos[index];
                              final fechaStr = DateFormat('EEE d MMM • hh:mm a', 'es_CO').format(s.fecha);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: border.withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.clienteNombre,
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            s.dron,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '🕒 $fechaStr',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '📍 ${s.fincaUbicacion} • ${s.cultivo} (${s.hectareas} Ha) • Piloto: ${s.piloto}',
                                      style: TextStyle(fontSize: 12, color: subtext),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            side: BorderSide(color: primary.withValues(alpha: 0.5)),
                                          ),
                                          icon: const Icon(Icons.calculate_outlined, size: 14),
                                          label: const Text('Calcular', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            CalculoInsumosBaterias.mostrarDialogoCalculadora(context, s);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.send, size: 14),
                                          label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            WhatsAppService.enviarResumenWhatsApp(s, context);
                                          },
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
              ),
            );
          },
        );
      },
    );
  }
}
