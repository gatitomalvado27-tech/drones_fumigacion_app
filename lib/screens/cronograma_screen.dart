import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/agro_theme.dart';
import '../models/servicio_model.dart';
import '../utils/crop_helper.dart';
import '../utils/operaciones_helper.dart';
import '../services/notification_service.dart';
import '../utils/time_picker_helper.dart';
import 'servicios_screen.dart';
import '../widgets/gestion_pilotos_dialog.dart';
import '../models/piloto_model.dart';
import '../widgets/registro_bitacora_dialog.dart';
import '../widgets/registro_cobro_servicio_dialog.dart';
import '../widgets/progreso_predio_dialog.dart';
import '../services/contabilidad_auto_service.dart';
import 'bitacoras_historial_screen.dart';
import '../models/dia_no_laborable_model.dart';
import '../models/mantenimiento_equipo_model.dart';
import '../widgets/dia_no_laborable_dialog.dart';
import '../widgets/registro_mantenimiento_dialog.dart';
import '../widgets/reprogramar_vuelo_dialog.dart';
import '../widgets/registro_parametros_vuelo_dialog.dart';
import 'mantenimientos_equipos_screen.dart';

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String _vistaCalendario = 'MES'; // 'DIA', 'SEMANA', 'MES'

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
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
          builder: (context, snapshotServicios) {
            final docsServicios = snapshotServicios.data?.docs ?? [];
            final todosServicios = docsServicios.map((doc) {
              return ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();

            final Map<DateTime, List<ServicioModel>> serviciosPorDia = {};
            for (var s in todosServicios) {
              final fechaSinHora = DateTime(s.fecha.year, s.fecha.month, s.fecha.day);
              serviciosPorDia.putIfAbsent(fechaSinHora, () => []).add(s);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('dias_no_laborables').snapshots(),
              builder: (context, snapshotNoLab) {
                final Map<DateTime, DiaNoLaborableModel> noLaborablesPorDia = {};
                for (var doc in snapshotNoLab.data?.docs ?? []) {
                  final d = DiaNoLaborableModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                  noLaborablesPorDia[DateTime(d.fecha.year, d.fecha.month, d.fecha.day)] = d;
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('mantenimientos_equipos').snapshots(),
                  builder: (context, snapshotMant) {
                    final todosMantenimientos = (snapshotMant.data?.docs ?? [])
                        .map((doc) => MantenimientoEquipoModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                        .toList();

                    final fechaSeleccionadaSinHora = DateTime(
                      _diaSeleccionado.year,
                      _diaSeleccionado.month,
                      _diaSeleccionado.day,
                    );
                    final serviciosDelDia = [...(serviciosPorDia[fechaSeleccionadaSinHora] ?? [])]
                      ..sort((a, b) => a.fecha.compareTo(b.fecha));
                    final diaNoLaborableActual = noLaborablesPorDia[fechaSeleccionadaSinHora];
                    final mantenimientosDelDia = todosMantenimientos
                        .where((m) => m.cubreDia(fechaSeleccionadaSinHora))
                        .toList()
                      ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

                    final hoySinHora = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    );

                    List<MantenimientoEquipoModel> mantenimientosEnFecha(DateTime d) {
                      return todosMantenimientos.where((m) => m.cubreDia(d)).toList();
                    }

                    // CustomScrollView para desplazamiento libre, suave y natural de toda la pantalla
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        // 1. HEADER LIMPIO Y COMPACTO
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: primary.withValues(alpha: 0.5)),
                                    ),
                                    child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Cronograma',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Vuelos, mantenimientos y disponibilidad',
                                        style: TextStyle(fontSize: 11, color: subtext),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Pilotos',
                                  icon: Icon(Icons.badge_outlined, color: primary, size: 21),
                                  onPressed: () => GestionPilotosDialog.mostrar(context),
                                ),
                                IconButton(
                                  tooltip: 'Compartir Disponibilidad',
                                  icon: Icon(Icons.share_outlined, color: primary, size: 21),
                                  onPressed: () => _mostrarDialogoDisponibilidad(context, todosServicios),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Más opciones',
                                  icon: Icon(Icons.more_vert, color: text, size: 21),
                                  onSelected: (val) {
                                    if (val == 'bitacoras') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const BitacorasHistorialScreen()),
                                      );
                                    } else if (val == 'mantenimientos') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const MantenimientosEquiposScreen()),
                                      );
                                    } else if (val == 'hoy') {
                                      setState(() {
                                        _diaSeleccionado = DateTime.now();
                                        _focusedDay = DateTime.now();
                                      });
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'hoy', child: Text('Ir a hoy')),
                                    PopupMenuItem(value: 'mantenimientos', child: Text('Historial de mantenimientos')),
                                    PopupMenuItem(value: 'bitacoras', child: Text('Bitácoras y parámetros')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. SELECTOR DE VISTA (MES / SEMANA / DÍA)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'MES', label: Text('Mes', style: TextStyle(fontSize: 12))),
                                      ButtonSegment(value: 'SEMANA', label: Text('Semana', style: TextStyle(fontSize: 12))),
                                      ButtonSegment(value: 'DIA', label: Text('Día', style: TextStyle(fontSize: 12))),
                                    ],
                                    selected: {_vistaCalendario},
                                    onSelectionChanged: (sel) {
                                      setState(() => _vistaCalendario = sel.first);
                                    },
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 3. CALENDARIO (MES O SEMANA) O NAVEGADOR DIARIO
                        SliverToBoxAdapter(
                          child: _vistaCalendario == 'DIA'
                              ? Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: border.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.chevron_left, color: primary),
                                        onPressed: () {
                                          setState(() {
                                            _diaSeleccionado = _diaSeleccionado.subtract(const Duration(days: 1));
                                            _focusedDay = _diaSeleccionado;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: _diaSeleccionado,
                                              firstDate: DateTime(2023),
                                              lastDate: DateTime(2030),
                                            );
                                            if (d != null) {
                                              setState(() {
                                                _diaSeleccionado = d;
                                                _focusedDay = d;
                                              });
                                            }
                                          },
                                          child: Column(
                                            children: [
                                              Text(
                                                DateFormat("EEEE d 'de' MMMM", 'es_CO').format(_diaSeleccionado),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: text,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('yyyy').format(_diaSeleccionado),
                                                style: TextStyle(fontSize: 11.5, color: subtext),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.chevron_right, color: primary),
                                        onPressed: () {
                                          setState(() {
                                            _diaSeleccionado = _diaSeleccionado.add(const Duration(days: 1));
                                            _focusedDay = _diaSeleccionado;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: border.withValues(alpha: 0.5)),
                                    boxShadow: AgroTheme.getShadow(context),
                                  ),
                                  child: Column(
                                    children: [
                                      TableCalendar<ServicioModel>(
                                        firstDay: DateTime(2023, 1, 1),
                                        lastDay: DateTime(2030, 12, 31),
                                        focusedDay: _focusedDay,
                                        currentDay: DateTime.now(),
                                        calendarFormat: _vistaCalendario == 'SEMANA'
                                            ? CalendarFormat.week
                                            : CalendarFormat.month,
                                        // Permite que gestos verticales desplacen toda la pantalla sin bloqueo
                                        availableGestures: AvailableGestures.horizontalSwipe,
                                        startingDayOfWeek: StartingDayOfWeek.monday,
                                        locale: 'es_CO',
                                        availableCalendarFormats: const {
                                          CalendarFormat.month: 'Mes',
                                          CalendarFormat.week: 'Semana',
                                        },
                                        headerStyle: HeaderStyle(
                                          formatButtonVisible: false,
                                          titleCentered: true,
                                          titleTextStyle: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: text,
                                          ),
                                          leftChevronIcon: Icon(Icons.chevron_left, color: primary, size: 22),
                                          rightChevronIcon: Icon(Icons.chevron_right, color: primary, size: 22),
                                          headerPadding: const EdgeInsets.symmetric(vertical: 2),
                                        ),
                                        daysOfWeekStyle: DaysOfWeekStyle(
                                          weekdayStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: subtext,
                                          ),
                                          weekendStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: primary,
                                          ),
                                        ),
                                        calendarStyle: CalendarStyle(
                                          outsideDaysVisible: false,
                                          defaultTextStyle: TextStyle(color: text, fontSize: 13),
                                          weekendTextStyle: TextStyle(color: text, fontSize: 13),
                                          markerDecoration: const BoxDecoration(color: Colors.transparent),
                                        ),
                                        selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
                                        onDaySelected: (selectedDay, focusedDay) {
                                          setState(() {
                                            _diaSeleccionado = selectedDay;
                                            _focusedDay = focusedDay;
                                          });
                                        },
                                        onPageChanged: (focusedDay) {
                                          _focusedDay = focusedDay;
                                        },
                                        calendarBuilders: CalendarBuilders(
                                          defaultBuilder: (context, day, focusedDay) {
                                            final dateKey = DateTime(day.year, day.month, day.day);
                                            final servicios = serviciosPorDia[dateKey];
                                            final noLab = noLaborablesPorDia[dateKey];
                                            final mants = mantenimientosEnFecha(dateKey);
                                            final tieneServicios = servicios != null && servicios.isNotEmpty;
                                            final coloresPilotos = _obtenerColoresPilotos(servicios, primary);

                                            if (noLab != null) {
                                              return Container(
                                                margin: const EdgeInsets.all(3.0),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.redAccent.withValues(alpha: 0.7),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: _buildDayCellContent(
                                                  day.day,
                                                  coloresPilotos,
                                                  TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                              );
                                            }

                                            if (mants.isNotEmpty && !tieneServicios) {
                                              return Container(
                                                margin: const EdgeInsets.all(3.0),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.deepPurpleAccent.withValues(alpha: 0.55),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: _buildDayCellContent(
                                                  day.day,
                                                  const [],
                                                  TextStyle(
                                                    color: text,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }

                                            if (tieneServicios) {
                                              final hayCancelados = servicios.every((s) => s.estado == 'CANCELADO');
                                              final todosCompletados = servicios.every((s) => s.estado == 'COMPLETADO');
                                              final hayReprog = servicios.any((s) => s.reprogramado);
                                              final Color baseColor = hayCancelados
                                                  ? AgroTheme.getError(context)
                                                  : (todosCompletados
                                                      ? const Color(0xFF22C55E)
                                                      : (hayReprog ? Colors.orange : primary));

                                              return Container(
                                                margin: const EdgeInsets.all(3.0),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: baseColor.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: baseColor.withValues(alpha: 0.45), width: 1.2),
                                                ),
                                                child: _buildDayCellContent(
                                                  day.day,
                                                  coloresPilotos,
                                                  TextStyle(
                                                    color: text,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }
                                            return null;
                                          },
                                          todayBuilder: (context, day, focusedDay) {
                                            final dateKey = DateTime(day.year, day.month, day.day);
                                            final servicios = serviciosPorDia[dateKey];
                                            final noLab = noLaborablesPorDia[dateKey];
                                            final tieneProgramacion = servicios != null && servicios.isNotEmpty;
                                            final coloresPilotos = _obtenerColoresPilotos(servicios, primary);

                                            return Container(
                                              margin: const EdgeInsets.all(3.0),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: noLab != null
                                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                                    : (tieneProgramacion ? primary.withValues(alpha: 0.2) : Colors.transparent),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: primary, width: 2.0),
                                              ),
                                              child: _buildDayCellContent(
                                                day.day,
                                                coloresPilotos,
                                                TextStyle(
                                                  color: primary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            );
                                          },
                                          selectedBuilder: (context, day, focusedDay) {
                                            final dateKey = DateTime(day.year, day.month, day.day);
                                            final servicios = serviciosPorDia[dateKey];
                                            final coloresPilotos = _obtenerColoresPilotos(servicios, Colors.white);

                                            return Container(
                                              margin: const EdgeInsets.all(3.0),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: primary,
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primary.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: _buildDayCellContent(
                                                day.day,
                                                coloresPilotos,
                                                TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          },
                                          markerBuilder: (context, date, events) {
                                            final dateKey = DateTime(date.year, date.month, date.day);
                                            final serviciosEnDia = serviciosPorDia[dateKey] ?? const <ServicioModel>[];
                                            final noLab = noLaborablesPorDia[dateKey];
                                            final mants = mantenimientosEnFecha(dateKey);

                                            final puntos = <Color>[];
                                            if (noLab != null) puntos.add(Colors.redAccent);
                                            if (mants.isNotEmpty) puntos.add(Colors.deepPurpleAccent);

                                            for (final s in serviciosEnDia.take(3)) {
                                              if (s.estado == 'COMPLETADO') {
                                                puntos.add(const Color(0xFF22C55E));
                                              } else if (s.reprogramado) {
                                                puntos.add(Colors.orange);
                                              } else if (s.estado != 'CANCELADO' && dateKey.isBefore(hoySinHora)) {
                                                puntos.add(Colors.amber);
                                              } else if (s.estado == 'CANCELADO') {
                                                puntos.add(AgroTheme.getError(context));
                                              } else {
                                                puntos.add(primary);
                                              }
                                            }

                                            if (puntos.isEmpty) return null;
                                            final seleccionado = isSameDay(_diaSeleccionado, date);
                                            return Positioned(
                                              bottom: 3,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: puntos.take(4).map((c) {
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    width: 5,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: seleccionado
                                                          ? Theme.of(context).colorScheme.onPrimary
                                                          : c,
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      const Divider(height: 14),

                                      // LEYENDA DE LOS 6 TIPOS DE EVENTOS
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildLegendDot(primary, 'Programado'),
                                            const SizedBox(width: 10),
                                            _buildLegendDot(const Color(0xFF22C55E), 'Completado'),
                                            const SizedBox(width: 10),
                                            _buildLegendDot(Colors.amber, 'Pendiente'),
                                            const SizedBox(width: 10),
                                            _buildLegendDot(Colors.orange, 'Reprogramado'),
                                            const SizedBox(width: 10),
                                            _buildLegendDot(Colors.deepPurpleAccent, 'Mantenimiento'),
                                            const SizedBox(width: 10),
                                            _buildLegendDot(Colors.redAccent, 'No laborable'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        // 4. ACCIONES RÁPIDAS DEL DÍA SELECCIONADO (Sin salir del calendario)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.flight_takeoff, size: 15),
                                    label: const Text('+ Vuelo', style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ServiciosScreen(fechaInicial: _diaSeleccionado),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(color: Colors.deepPurpleAccent.withValues(alpha: 0.7)),
                                      foregroundColor: Colors.deepPurpleAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.build_circle_outlined, size: 15),
                                    label: const Text('+ Mantenimiento', style: TextStyle(fontSize: 12)),
                                    onPressed: () => RegistroMantenimientoDialog.mostrar(
                                      context,
                                      fechaInicial: _diaSeleccionado,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.7)),
                                      foregroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: Icon(
                                      diaNoLaborableActual == null ? Icons.event_busy_outlined : Icons.edit_calendar,
                                      size: 15,
                                    ),
                                    label: Text(
                                      diaNoLaborableActual == null ? 'No laborable' : 'Editar bloqueo',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => DiaNoLaborableDialog.mostrar(
                                      context,
                                      fecha: _diaSeleccionado,
                                      existente: diaNoLaborableActual,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 5. BANNER SI ES DÍA NO LABORABLE
                        if (diaNoLaborableActual != null)
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Día no laborable: ${diaNoLaborableActual.motivo}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: text,
                                          ),
                                        ),
                                        if (diaNoLaborableActual.descripcion.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            diaNoLaborableActual.descripcion,
                                            style: TextStyle(fontSize: 12, color: subtext),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => DiaNoLaborableDialog.mostrar(
                                      context,
                                      fecha: _diaSeleccionado,
                                      existente: diaNoLaborableActual,
                                    ),
                                    child: const Text('Editar', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 6. CABECERA DE ACTIVIDADES DEL DÍA
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: primary),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Agenda • ${DateFormat("d 'de' MMMM", 'es').format(_diaSeleccionado)}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: text,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primary.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    '${serviciosDelDia.length} vuelo${serviciosDelDia.length == 1 ? '' : 's'}'
                                    '${mantenimientosDelDia.isNotEmpty ? ' • ${mantenimientosDelDia.length} mant.' : ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 7. MANTENIMIENTOS PROGRAMADOS DEL DÍA
                        if (mantenimientosDelDia.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildMantenimientoCard(
                                  context,
                                  mantenimientosDelDia[index],
                                  isDark,
                                  text,
                                  subtext,
                                  cardBg,
                                  border,
                                ),
                                childCount: mantenimientosDelDia.length,
                              ),
                            ),
                          ),

                        // 8. VUELOS DEL DÍA O ESTADO VACÍO
                        if (serviciosDelDia.isEmpty && mantenimientosDelDia.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      diaNoLaborableActual != null
                                          ? Icons.event_busy_rounded
                                          : Icons.event_available,
                                      size: 42,
                                      color: diaNoLaborableActual != null
                                          ? Colors.redAccent
                                          : primary.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      diaNoLaborableActual != null
                                          ? 'Jornada no laborable'
                                          : 'Día disponible',
                                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: text),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      diaNoLaborableActual != null
                                          ? 'Esta fecha está bloqueada como ${diaNoLaborableActual.motivo}.'
                                          : 'No hay vuelos ni mantenimientos agendados para esta fecha.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12.5, color: subtext),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final s = serviciosDelDia[index];
                                  return _buildFlightCard(
                                    context,
                                    s,
                                    isDark,
                                    primary,
                                    text,
                                    subtext,
                                    cardBg,
                                    border,
                                  );
                                },
                                childCount: serviciosDelDia.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 3,
        tooltip: 'Nuevo Vuelo',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiciosScreen(fechaInicial: _diaSeleccionado),
            ),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildMantenimientoCard(
    BuildContext context,
    MantenimientoEquipoModel m,
    bool isDark,
    Color text,
    Color subtext,
    Color cardBg,
    Color border,
  ) {
    final colorEst = MantenimientoEquipoModel.colorEstado(m.estado);
    final rango = m.esMultidia
        ? '${DateFormat('dd/MM hh:mm a').format(m.fechaInicio)} → ${DateFormat('dd/MM hh:mm a').format(m.fechaFin)}'
        : '${DateFormat('hh:mm a').format(m.fechaInicio)} - ${DateFormat('hh:mm a').format(m.fechaFin)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.deepPurpleAccent.withValues(alpha: isDark ? 0.12 : 0.05),
          cardBg,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  MantenimientoEquipoModel.iconoCategoria(m.categoriaEquipo),
                  color: Colors.deepPurpleAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mantenimiento • ${m.nombreEquipo}',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: text),
                    ),
                    Text(
                      '${m.tipoMantenimiento}${m.responsable.isNotEmpty ? ' • Resp: ${m.responsable}' : ''}',
                      style: TextStyle(fontSize: 12, color: subtext),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorEst.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  MantenimientoEquipoModel.nombreEstado(m.estado),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorEst),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.deepPurpleAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(rango, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text)),
              ),
            ],
          ),
          if (m.observaciones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(m.observaciones, style: TextStyle(fontSize: 12, color: subtext)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (m.estado != 'COMPLETADO')
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Completar', style: TextStyle(fontSize: 11.5)),
                  onPressed: () async {
                    if (m.id == null) return;
                    await FirebaseFirestore.instance
                        .collection('mantenimientos_equipos')
                        .doc(m.id)
                        .update({'estado': 'COMPLETADO'});
                  },
                ),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Editar', style: TextStyle(fontSize: 11.5)),
                onPressed: () => RegistroMantenimientoDialog.mostrar(context, existente: m),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _obtenerColoresPilotos(List<ServicioModel>? servicios, Color colorDefecto) {
    if (servicios == null || servicios.isEmpty) return [];
    final Set<Color> colores = {};
    for (var s in servicios) {
      if (s.estado == 'CANCELADO') continue;
      if (s.pilotoColorHex != null && s.pilotoColorHex!.isNotEmpty) {
        try {
          final hex = s.pilotoColorHex!.replaceAll('#', '');
          colores.add(Color(int.parse('FF$hex', radix: 16)));
        } catch (_) {}
      } else if (s.piloto.isNotEmpty) {
        colores.add(colorDefecto);
      }
    }
    return colores.toList();
  }

  Widget _buildDayCellContent(int dayNumber, List<Color> coloresPilotos, TextStyle textStyle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (coloresPilotos.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: coloresPilotos.take(3).map((col) {
              return Container(
                width: 5.5,
                height: 5.5,
                margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 0.6),
                  boxShadow: [
                    BoxShadow(
                      color: col.withValues(alpha: 0.4),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          const SizedBox(height: 7.5),
        Text(
          '$dayNumber',
          style: textStyle,
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AgroTheme.getSubtext(context)),
        ),
      ],
    );
  }

  Widget _buildFlightCard(
    BuildContext context,
    ServicioModel s,
    bool isDark,
    Color primary,
    Color text,
    Color subtext,
    Color cardBg,
    Color border,
  ) {
    final hora = DateFormat('hh:mm a').format(s.fecha);
    Color badgeColor = primary;
    Color badgeBg = primary.withValues(alpha: 0.15);
    Color cardBorder = border.withValues(alpha: 0.5);
    Color cardTint = Colors.transparent;
    String estadoText = s.estado;

    if (s.estado == 'COMPLETADO') {
      badgeColor = const Color(0xFF2E7D32);
      badgeBg = const Color(0xFF2E7D32).withValues(alpha: 0.15);
      cardBorder = const Color(0xFF2E7D32).withValues(alpha: 0.8);
      cardTint = const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.08 : 0.04);
      estadoText = 'COMPLETADO';
    } else if (s.estado == 'EN_PROCESO') {
      badgeColor = const Color(0xFF0288D1);
      badgeBg = const Color(0xFF0288D1).withValues(alpha: 0.15);
      cardBorder = const Color(0xFF0288D1).withValues(alpha: 0.8);
      cardTint = const Color(0xFF0288D1).withValues(alpha: isDark ? 0.08 : 0.04);
      estadoText = 'EN VUELO';
    } else if (s.estado == 'PENDIENTE' || s.estado == 'PROGRAMADO') {
      badgeColor = const Color(0xFFF57C00);
      badgeBg = const Color(0xFFF57C00).withValues(alpha: 0.15);
      cardBorder = const Color(0xFFF57C00).withValues(alpha: 0.8);
      cardTint = const Color(0xFFF57C00).withValues(alpha: isDark ? 0.08 : 0.04);
      estadoText = 'PROGRAMADO';
    } else if (s.estado == 'CANCELADO') {
      badgeColor = AgroTheme.error;
      badgeBg = AgroTheme.error.withValues(alpha: 0.15);
      cardBorder = AgroTheme.error.withValues(alpha: 0.6);
      cardTint = AgroTheme.error.withValues(alpha: isDark ? 0.08 : 0.03);
      estadoText = 'CANCELADO';
    }

    // Color del piloto
    Color pilotoColor = const Color(0xFF1E88E5);
    if (s.pilotoColorHex != null && s.pilotoColorHex!.isNotEmpty) {
      try {
        final hex = s.pilotoColorHex!.replaceAll('#', '');
        pilotoColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(cardTint, cardBg),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        CropHelper.getEmoji(s.cultivo),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.cultivo} • ${s.fincaUbicacion}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: text,
                        ),
                      ),
                      Text(
                        'Cliente: ${s.clienteNombre}',
                        style: TextStyle(fontSize: 12, color: subtext),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      ),
                    ),
                  ),
                  if (s.reprogramado) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'REPROG.',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  // BOTÓN DE ELIMINACIÓN INTELIGENTE (Diseño limpio y no agolpado)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: Colors.red.withValues(alpha: 0.8),
                    ),
                    tooltip: 'Eliminar programación',
                    onPressed: () => _confirmarEliminarServicio(context, s),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text(hora, style: TextStyle(fontSize: 12, color: text)),
                  const SizedBox(width: 12),
                  Icon(Icons.crop_square, size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text('${s.hectareas} Ha', style: TextStyle(fontSize: 12, color: text)),
                  if (s.litrosAplicados != null && s.litrosAplicados! > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '💧 ${s.litrosAplicados!.toStringAsFixed(0)} Lts',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.metodoPago == 'EN_LINEA' ? Colors.blue.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.metodoPago == 'EN_LINEA' ? '💳 En línea' : '💵 Efectivo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: s.metodoPago == 'EN_LINEA' ? Colors.blue : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(s.precioTotal),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary),
              ),
            ],
          ),

          // CHIPS DE PILOTO, DRON Y ACCESO A BITÁCORA
          if (s.piloto.isNotEmpty || s.dron.isNotEmpty || s.estado == 'COMPLETADO') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (s.piloto.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pilotoColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: pilotoColor.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: pilotoColor),
                        const SizedBox(width: 5),
                        Text(
                          'Piloto: ${s.piloto}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : pilotoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (s.dron.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🛸', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(s.dron, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text)),
                      ],
                    ),
                  ),
                if (s.estado == 'COMPLETADO') ...[
                  InkWell(
                    onTap: () => RegistroBitacoraDialog.mostrar(context, s),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (s.bitacora != null ? Colors.teal : Colors.amber).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (s.bitacora != null ? Colors.teal : Colors.amber).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.bitacora != null ? Icons.history_edu_rounded : Icons.note_add_outlined,
                            size: 12,
                            color: s.bitacora != null ? Colors.teal : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.bitacora != null ? 'Bitácora Registrada' : '+ Agregar Bitácora',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: s.bitacora != null ? Colors.teal : (isDark ? Colors.amber : Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const Divider(height: 18),

          // BOTONERA DE ACCIONES: CALCULADORA, WHATSAPP, REPROGRAMAR, EDITAR, ESTADO Y ELIMINAR
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Fotos de Progreso del Predio',
                  icon: const Icon(Icons.photo_camera_back_outlined, size: 20),
                  color: const Color(0xFF00897B),
                  onPressed: () => ProgresoPredioDialog.mostrar(
                    context,
                    clienteId: s.clienteId,
                    clienteNombre: s.clienteNombre,
                    clienteCedula: s.clienteCedula,
                    fincaUbicacion: s.fincaUbicacion,
                    cultivoInicial: s.cultivo,
                    servicioId: s.id,
                    pilotoInicial: s.piloto,
                  ),
                ),
                IconButton(
                  tooltip: 'Parámetros de Aplicación',
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  color: primary,
                  onPressed: () => RegistroParametrosVueloDialog.mostrar(context, servicio: s),
                ),
                IconButton(
                  tooltip: 'Calculadora de Insumos y Baterías',
                  icon: const Icon(Icons.calculate_outlined, size: 20),
                  color: primary,
                  onPressed: () => _mostrarCalculadoraInsumos(context, s),
                ),
                IconButton(
                  tooltip: 'Enviar Resumen o PDF por WhatsApp',
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  color: Colors.green,
                  onPressed: () => _mostrarOpcionesCompartir(context, s),
                ),
                IconButton(
                  tooltip: 'Eliminar Vuelo',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red.withValues(alpha: 0.75),
                  onPressed: () => _confirmarEliminarServicio(context, s),
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.event_repeat_rounded, size: 14, color: Colors.orange),
                  label: const Text('Reprogramar', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _mostrarDialogoReprogramarVuelo(context, s),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.edit, size: 14, color: text),
                  label: Text('Editar', style: TextStyle(color: text, fontSize: 12)),
                  onPressed: () => _mostrarDialogoEditarVuelo(context, s),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Estado', style: TextStyle(fontSize: 12)),
                  onPressed: () => _cambiarEstadoServicio(context, s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarServicio(BuildContext context, ServicioModel s) {
    final isDark = AgroTheme.isDark(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);

    final horaFormateada = DateFormat("EEEE, d 'de' MMMM - hh:mm a", 'es').format(s.fecha);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardBg,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¿Eliminar Programación?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de eliminar este vuelo agendado?',
              style: TextStyle(fontSize: 13, color: text),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AgroTheme.getBorder(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🌱 ${s.cultivo} • ${s.fincaUbicacion}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
                  Text('🧑‍🌾 Cliente: ${s.clienteNombre} (${s.hectareas} Ha)', style: TextStyle(fontSize: 11, color: subtext)),
                  Text('🗓️ $horaFormateada', style: TextStyle(fontSize: 11, color: subtext)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se removerá del calendario y se anularán los recordatorios vinculados a este vuelo.',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.red.shade200 : Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (s.id != null) {
                // Elimina servicio, transacciones, bitácora y recordatorios
                await ContabilidadAutoService.eliminarServicio(s.id!);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vuelo de ${s.clienteNombre} eliminado del cronograma.'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _cambiarEstadoServicio(BuildContext context, ServicioModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar Estado de Vuelo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['PROGRAMADO', 'EN_PROCESO', 'COMPLETADO', 'CANCELADO'].map((st) {
            final seleccionado = s.estado == st;
            return ListTile(
              title: Text(
                st == 'EN_PROCESO' ? 'EN VUELO' : st,
                style: TextStyle(fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal),
              ),
              leading: Icon(
                seleccionado ? Icons.check_circle : Icons.radio_button_unchecked,
                color: seleccionado ? AgroTheme.getPrimary(context) : AgroTheme.getBorder(context),
              ),
              onTap: () async {
                if (ctx.mounted) Navigator.pop(ctx);
                if (s.id == null || s.estado == st) return;

                await ContabilidadAutoService.cambiarEstado(s, st);
                if (!context.mounted) return;

                final messenger = ScaffoldMessenger.of(context);
                if (st == 'CANCELADO') {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Vuelo cancelado. Sus ingresos y recordatorios se anularon automáticamente.'),
                      backgroundColor: AgroTheme.error,
                    ),
                  );
                } else if (st == 'COMPLETADO') {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(s.pagado
                          ? '¡Vuelo completado! Ya está reflejado en caja.'
                          : 'Vuelo completado. Quedó automáticamente en Cuentas por Cobrar.'),
                      backgroundColor: const Color(0xFF2E7D32),
                      duration: const Duration(seconds: 5),
                      action: s.pagado
                          ? null
                          : SnackBarAction(
                              label: 'COBRAR',
                              textColor: Colors.white,
                              onPressed: () => RegistroCobroServicioDialog.mostrar(context, s, abrirBitacoraDespues: true),
                            ),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _mostrarDialogoEditarVuelo(BuildContext context, ServicioModel s) {
    final formKey = GlobalKey<FormState>();

    String clienteNombre = s.clienteNombre;
    String clienteTelefono = s.clienteTelefono;
    String fincaUbicacion = s.fincaUbicacion;
    DateTime fecha = s.fecha;
    TimeOfDay hora = TimeOfDay(hour: s.fecha.hour, minute: s.fecha.minute);
    double hectareas = s.hectareas;
    double? litrosAplicados = s.litrosAplicados;
    String cultivo = s.cultivo;
    String tipoAplicacion = s.tipoAplicacion;
    String productoQuimico = s.productoQuimico;
    double precioPorHectarea = s.precioPorHectarea;
    String estado = s.estado;
    bool pagado = s.pagado;
    String metodoPago = s.metodoPago;
    String notas = s.notas;

    String piloto = s.piloto;
    String? pilotoColorHex = s.pilotoColorHex;
    String dron = s.dron.isNotEmpty ? s.dron : 'DJI Agras T40';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double totalCalculado = hectareas * precioPorHectarea;

          return AlertDialog(
            title: Row(
              children: [
                Text(CropHelper.getEmoji(cultivo), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text('Editar Vuelo Programado'),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: clienteNombre,
                      decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      onSaved: (val) => clienteNombre = val!,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: fincaUbicacion,
                      decoration: const InputDecoration(labelText: 'Finca / Municipio / Parcela'),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      onSaved: (val) => fincaUbicacion = val!,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: clienteTelefono,
                      decoration: const InputDecoration(labelText: 'Teléfono de Contacto'),
                      keyboardType: TextInputType.phone,
                      onSaved: (val) => clienteTelefono = val ?? '',
                    ),
                    const SizedBox(height: 10),

                    // PILOTO Y DRON ASIGNADO
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('pilotos').snapshots(),
                            builder: (context, snapPilotos) {
                              final docsPilotos = snapPilotos.data?.docs ?? [];
                              final pilotosList = docsPilotos
                                  .map((d) => PilotoModel.fromMap(d.id, d.data() as Map<String, dynamic>))
                                  .toList();

                              if (pilotosList.isNotEmpty) {
                                final nombresPilotos = pilotosList.map((p) => p.nombre).toList();
                                final valorPiloto = nombresPilotos.contains(piloto) ? piloto : (piloto.isNotEmpty ? piloto : null);

                                return DropdownButtonFormField<String>(
                                  initialValue: valorPiloto,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Piloto Asignado',
                                    prefixIcon: Icon(Icons.person, size: 16),
                                  ),
                                  hint: const Text('Seleccionar piloto', style: TextStyle(fontSize: 12)),
                                  items: [
                                    ...pilotosList.map((p) => DropdownMenuItem(
                                          value: p.nombre,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(radius: 5, backgroundColor: p.color),
                                              const SizedBox(width: 6),
                                              Flexible(child: Text(p.nombre, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        )),
                                    if (piloto.isNotEmpty && !nombresPilotos.contains(piloto))
                                      DropdownMenuItem(
                                        value: piloto,
                                        child: Text(piloto, style: const TextStyle(fontSize: 12)),
                                      ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      piloto = val;
                                      final match = pilotosList.where((p) => p.nombre == val).firstOrNull;
                                      if (match != null) pilotoColorHex = match.colorHex;
                                    }
                                  },
                                );
                              }

                              return TextFormField(
                                initialValue: piloto,
                                decoration: const InputDecoration(
                                  labelText: 'Piloto a Cargo',
                                  prefixIcon: Icon(Icons.person, size: 16),
                                ),
                                onSaved: (val) => piloto = val ?? '',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: ['DJI Agras T55', 'DJI Agras T50', 'DJI Agras T40', 'DJI Agras T30', 'DJI Agras T25', 'DJI Agras T10', 'XAG P100 Pro', 'Otro Dron'].contains(dron)
                                ? dron
                                : 'DJI Agras T40',
                            decoration: const InputDecoration(labelText: 'Aeronave / Dron'),
                            items: ['DJI Agras T55', 'DJI Agras T50', 'DJI Agras T40', 'DJI Agras T30', 'DJI Agras T25', 'DJI Agras T10', 'XAG P100 Pro', 'Otro Dron']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => dron = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: CropHelper.nombresCultivos.contains(cultivo) ? cultivo : 'Otro (Personalizado)',
                      decoration: const InputDecoration(labelText: 'Cultivo a Fumigar'),
                      items: CropHelper.listaCultivos.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['nombre'],
                          child: Row(
                            children: [
                              Text(c['emoji']!, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(c['nombre']!),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => cultivo = val!);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: ['Fungicida', 'Herbicida', 'Insecticida', 'Fertilizante Foliar', 'Madurante', 'Biológico', 'Siembra / Dispersión'].contains(tipoAplicacion)
                          ? tipoAplicacion
                          : 'Fungicida',
                      decoration: const InputDecoration(labelText: 'Tipo de Aplicación'),
                      items: ['Fungicida', 'Herbicida', 'Insecticida', 'Fertilizante Foliar', 'Madurante', 'Biológico', 'Siembra / Dispersión']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => tipoAplicacion = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: hectareas.toString(),
                            decoration: const InputDecoration(labelText: 'Hectáreas (Ha)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || double.tryParse(val) == null ? 'Inválido' : null,
                            onChanged: (val) {
                              final h = double.tryParse(val);
                              if (h != null) setModalState(() => hectareas = h);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: precioPorHectarea.toStringAsFixed(0),
                            decoration: const InputDecoration(labelText: 'Precio/Ha (\$)'),
                            keyboardType: TextInputType.number,
                            validator: (val) => val == null || double.tryParse(val) == null ? 'Inválido' : null,
                            onChanged: (val) {
                              final p = double.tryParse(val);
                              if (p != null) setModalState(() => precioPorHectarea = p);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // LITROS APLICADOS
                    TextFormField(
                      initialValue: litrosAplicados != null && litrosAplicados! > 0 ? litrosAplicados!.toStringAsFixed(1) : '',
                      decoration: const InputDecoration(
                        labelText: 'Litros Aplicados (L)',
                        prefixIcon: Icon(Icons.water_drop, size: 16, color: Colors.teal),
                        hintText: 'Ej: 180',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        litrosAplicados = double.tryParse(val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AgroTheme.getPrimary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total calculado: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(totalCalculado)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AgroTheme.getPrimary(context)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: productoQuimico,
                      decoration: const InputDecoration(labelText: 'Producto / Químico / Insumo'),
                      onSaved: (val) => productoQuimico = val ?? '',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(DateFormat('dd/MM/yyyy').format(fecha), style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: fecha,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setModalState(() => fecha = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.schedule, size: 14),
                            label: Text(hora.format(context), style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final t = await TimePickerHelper.seleccionarHora(context, horaInicial: hora);
                              if (t != null) setModalState(() => hora = t);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: metodoPago,
                      decoration: const InputDecoration(labelText: 'Método de Pago'),
                      items: const [
                        DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Pago en Efectivo')),
                        DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 En Línea / Transferencia')),
                      ],
                      onChanged: (val) => setModalState(() => metodoPago = val!),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('¿Servicio Pagado?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: pagado,
                      onChanged: (val) => setModalState(() => pagado = val),
                    ),
                    TextFormField(
                      initialValue: notas,
                      decoration: const InputDecoration(labelText: 'Notas u Observaciones'),
                      maxLines: 2,
                      onSaved: (val) => notas = val ?? '',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();

                    final fechaCompleta = DateTime(
                      fecha.year,
                      fecha.month,
                      fecha.day,
                      hora.hour,
                      hora.minute,
                    );

                    await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                      'clienteNombre': clienteNombre,
                      'clienteTelefono': clienteTelefono,
                      'fincaUbicacion': fincaUbicacion,
                      'cultivo': cultivo,
                      'tipoAplicacion': tipoAplicacion,
                      'hectareas': hectareas,
                      'litrosAplicados': litrosAplicados,
                      'precioPorHectarea': precioPorHectarea,
                      'precioTotal': totalCalculado,
                      'productoQuimico': productoQuimico,
                      'fecha': fechaCompleta.toIso8601String(),
                      'metodoPago': metodoPago,
                      'pagado': pagado,
                      'estado': estado,
                      'notas': notas,
                      'piloto': piloto,
                      'pilotoColorHex': pilotoColorHex,
                      'dron': dron,
                    });

                    // Actualizar recordatorio
                    final servicioActualizado = ServicioModel(
                      id: s.id,
                      clienteId: s.clienteId,
                      clienteNombre: clienteNombre,
                      clienteTelefono: clienteTelefono,
                      fincaUbicacion: fincaUbicacion,
                      fecha: fechaCompleta,
                      hectareas: hectareas,
                      litrosAplicados: litrosAplicados,
                      cultivo: cultivo,
                      tipoAplicacion: tipoAplicacion,
                      productoQuimico: productoQuimico,
                      precioPorHectarea: precioPorHectarea,
                      precioTotal: totalCalculado,
                      estado: estado,
                      pagado: pagado,
                      notas: notas,
                      metodoPago: metodoPago,
                      piloto: piloto,
                      pilotoColorHex: pilotoColorHex,
                      dron: dron,
                      totalAbonado: s.totalAbonado,
                    );
                    NotificationService.instance.programarRecordatorioVuelo(servicioActualizado);
                    // Reflejar automáticamente en caja / cartera
                    await ContabilidadAutoService.sincronizarServicio(servicioActualizado);

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Vuelo programado actualizado con éxito!')),
                      );
                    }
                  }
                },
                child: const Text('Guardar Cambios'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoReprogramarVuelo(BuildContext context, ServicioModel s) {
    ReprogramarVueloDialog.mostrar(context, s);
  }

  void _mostrarCalculadoraInsumos(BuildContext context, ServicioModel s) {
    final calc = CalculoInsumosBaterias(
      hectareas: s.hectareas,
      dronModelo: s.dron.isNotEmpty ? s.dron : 'DJI Agras T40',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AgroTheme.getCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AgroTheme.getPrimary(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calculadora de Vuelo & Baterías',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${s.cultivo} (${s.hectareas} Ha) • Dron: ${calc.dronModelo}',
                        style: TextStyle(fontSize: 12, color: AgroTheme.getSubtext(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildCalcTile('Tanques Est.', '${calc.tanquesEstimados}', 'despegues (${calc.capacidadTanqueLitros}L c/u)'),
                const SizedBox(width: 12),
                _buildCalcTile('Mezcla Caldo', '${calc.totalLitrosCaldo.toStringAsFixed(0)} L', 'a 15 L/Ha promedio'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCalcTile('Baterías / Vuelos', '${calc.ciclosBateriaEstimados}', 'ciclos requeridos'),
                const SizedBox(width: 12),
                _buildCalcTile('Insumo Químico', '${calc.totalProductoQuimico.toStringAsFixed(1)} L/Kg', 'estimado a 1.0/Ha'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      calc.recomendacionLogistica,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgroTheme.getPrimary(context),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcTile(String title, String valor, String subtitulo) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AgroTheme.getBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AgroTheme.getBorder(context).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: AgroTheme.getSubtext(context))),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text(subtitulo, style: TextStyle(fontSize: 9.5, color: AgroTheme.getSubtext(context))),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesCompartir(BuildContext context, ServicioModel s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AgroTheme.getCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Compartir Comprobante / Reporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text('Enviar Resumen por WhatsApp'),
              subtitle: Text('Mensaje formateado al cliente: ${s.clienteNombre}'),
              onTap: () {
                Navigator.pop(ctx);
                WhatsAppService.compartirResumenWhatsApp(context: context, servicio: s);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.picture_as_pdf, color: Colors.white),
              ),
              title: const Text('Compartir Orden de Servicio en PDF'),
              subtitle: const Text('Comprobante oficial con firmas y detalle'),
              onTap: () {
                Navigator.pop(ctx);
                WhatsAppService.compartirPdf(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoDisponibilidad(BuildContext context, List<ServicioModel> todosServicios) {
    final ahora = DateTime.now();
    final hoySinHora = DateTime(ahora.year, ahora.month, ahora.day);

    final Map<DateTime, int> vuelosPorDia = {};
    for (int i = 0; i < 14; i++) {
      final dia = hoySinHora.add(Duration(days: i));
      vuelosPorDia[dia] = 0;
    }

    for (var s in todosServicios) {
      if (s.estado != 'CANCELADO') {
        final diaS = DateTime(s.fecha.year, s.fecha.month, s.fecha.day);
        if (vuelosPorDia.containsKey(diaS)) {
          vuelosPorDia[diaS] = (vuelosPorDia[diaS] ?? 0) + 1;
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('🚁 *ICARO PROAGRO - DISPONIBILIDAD DE VUELOS* 🌾');
    buffer.writeln('Fechas disponibles para servicios de fumigación y fertilización con dron:\n');

    vuelosPorDia.forEach((dia, cantVuelos) {
      final diaNombre = DateFormat('EEE dd/MMM', 'es').format(dia);
      if (cantVuelos == 0) {
        buffer.writeln('📅 $diaNombre: 🟢 Disponible (Jornada Completa)');
      } else if (cantVuelos == 1) {
        buffer.writeln('📅 $diaNombre: 🟡 Disponible Turno Tarde (1 cupo)');
      } else {
        buffer.writeln('📅 $diaNombre: 🔴 Ocupado / Reservado');
      }
    });

    buffer.writeln('\n📲 Agenda tus hectáreas con anticipación con el equipo de Icaro Proagro.');
    final textoParaCompartir = buffer.toString();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AgroTheme.getBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.campaign, color: AgroTheme.getPrimary(context), size: 26),
                const SizedBox(width: 10),
                Text(
                  'Agenda Pública de Disponibilidad',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AgroTheme.getText(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Este resumen muestra los días libres y ocupados sin mostrar nombres de clientes ni precios. Ideal para enviar a agricultores interesados por WhatsApp.',
              style: TextStyle(fontSize: 12, color: AgroTheme.getSubtext(context)),
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AgroTheme.getSurfaceContainerHigh(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AgroTheme.getBorder(context).withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  textoParaCompartir,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AgroTheme.getText(context)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar Mensaje para WhatsApp'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: textoParaCompartir));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Mensaje copiado! Listo para pegar en WhatsApp.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
