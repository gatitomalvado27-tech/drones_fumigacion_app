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
import 'package:url_launcher/url_launcher.dart';
import 'servicios_screen.dart';
import '../widgets/gestion_pilotos_dialog.dart';
import '../models/piloto_model.dart';
import '../widgets/registro_bitacora_dialog.dart';
import '../widgets/registro_cobro_servicio_dialog.dart';
import 'bitacoras_historial_screen.dart';

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _focusedDay = DateTime.now();

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
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final todosServicios = docs.map((doc) {
              return ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();

            // Mapeo de eventos por fecha (solo año, mes, día)
            final Map<DateTime, List<ServicioModel>> serviciosPorDia = {};
            for (var s in todosServicios) {
              final fechaSinHora = DateTime(s.fecha.year, s.fecha.month, s.fecha.day);
              serviciosPorDia.putIfAbsent(fechaSinHora, () => []).add(s);
            }

            final fechaSeleccionadaSinHora = DateTime(_diaSeleccionado.year, _diaSeleccionado.month, _diaSeleccionado.day);
            final serviciosDelDia = serviciosPorDia[fechaSeleccionadaSinHora] ?? [];

            return Column(
              children: [
                // HEADER DE CRONOGRAMA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                              'Planificador de Vuelos',
                              style: TextStyle(fontSize: 11, color: subtext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // BOTONES SUPERIORES (PILOTOS, DISPONIBILIDAD Y AGENDAR)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primary.withValues(alpha: 0.8)),
                          backgroundColor: primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.badge_outlined, size: 14, color: primary),
                        label: Text(
                          'Pilotos',
                          style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => GestionPilotosDialog.mostrar(context),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.teal.withValues(alpha: 0.8)),
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.history_edu_rounded, size: 14, color: Colors.teal),
                        label: const Text(
                          'Bitácoras',
                          style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BitacorasHistorialScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primary.withValues(alpha: 0.8)),
                          backgroundColor: primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.share, size: 14, color: primary),
                        label: Text(
                          'Disponibilidad',
                          style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _mostrarDialogoDisponibilidad(context, todosServicios),
                      ),
                    ],
                  ),
                ),

                // CALENDARIO MENSUAL COMPLETO
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
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
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        locale: 'es_CO',
                        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
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
                          selectedDecoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          todayDecoration: BoxDecoration(
                            border: Border.all(color: primary, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          todayTextStyle: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
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
                            final bool tieneProgramacion = servicios != null && servicios.isNotEmpty;
                            final coloresPilotos = _obtenerColoresPilotos(servicios, primary);

                            if (tieneProgramacion) {
                              final hayCancelados = servicios.every((s) => s.estado == 'CANCELADO');
                              final Color bgTint = hayCancelados
                                  ? AgroTheme.error.withValues(alpha: 0.15)
                                  : primary.withValues(alpha: 0.18);
                              final Color borderTint = hayCancelados
                                  ? AgroTheme.error.withValues(alpha: 0.4)
                                  : primary.withValues(alpha: 0.45);

                              return Container(
                                margin: const EdgeInsets.all(3.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bgTint,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderTint, width: 1.2),
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
                            final bool tieneProgramacion = servicios != null && servicios.isNotEmpty;
                            final coloresPilotos = _obtenerColoresPilotos(servicios, primary);

                            return Container(
                              margin: const EdgeInsets.all(3.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tieneProgramacion ? primary.withValues(alpha: 0.22) : Colors.transparent,
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
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                          markerBuilder: (context, date, events) {
                            final dateKey = DateTime(date.year, date.month, date.day);
                            final serviciosEnDia = serviciosPorDia[dateKey];
                            if (serviciosEnDia != null && serviciosEnDia.isNotEmpty) {
                              return Positioned(
                                bottom: 4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: serviciosEnDia.take(3).map((s) {
                                    Color dotColor = primary;
                                    final cult = s.cultivo.toLowerCase();
                                    if (cult.contains('siembra')) {
                                      dotColor = Colors.lightBlueAccent;
                                    } else if (cult.contains('monitoreo') || cult.contains('mapeo')) {
                                      dotColor = Colors.orangeAccent;
                                    } else if (s.estado == 'CANCELADO') {
                                      dotColor = AgroTheme.error;
                                    }
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSameDay(_diaSeleccionado, date) ? Colors.white : dotColor,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),

                      const Divider(height: 16),

                      // LEYENDA (Fumigación • Siembra • Monitoreo • Piloto)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendDot(primary, 'Fumigación'),
                            const SizedBox(width: 12),
                            _buildLegendDot(Colors.lightBlueAccent, 'Siembra'),
                            const SizedBox(width: 12),
                            _buildLegendDot(Colors.orangeAccent, 'Monitoreo'),
                            const SizedBox(width: 12),
                            _buildLegendDot(const Color(0xFF1E88E5), 'Color Piloto (arriba)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // SECCIÓN: OPERACIONES DEL DÍA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: primary),
                          const SizedBox(width: 8),
                          Text(
                            'Operaciones - ${DateFormat("d 'de' MMMM", 'es').format(_diaSeleccionado)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${serviciosDelDia.length} Vuelo${serviciosDelDia.length == 1 ? "" : "s"}',
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

                // LISTA DE VUELOS (Con padding inferior amplio para que el botón flotante nunca tape las acciones)
                Expanded(
                  child: serviciosDelDia.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 44, color: primary.withValues(alpha: 0.6)),
                              const SizedBox(height: 8),
                              Text(
                                'Día disponible',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No hay vuelos agendados para esta fecha.',
                                style: TextStyle(fontSize: 12, color: subtext),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Agendar Vuelo para este día'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServiciosScreen(fechaInicial: _diaSeleccionado),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 4.0, bottom: 95.0),
                          itemCount: serviciosDelDia.length,
                          itemBuilder: (context, index) {
                            final s = serviciosDelDia[index];
                            return _buildFlightCard(context, s, isDark, primary, text, subtext, cardBg, border);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      // BOTÓN FLOTANTE COMPACTO Y ELEGANTE (No obstruye la pantalla)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        foregroundColor: Colors.white,
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
                // 1. Eliminar servicio de Firestore
                await FirebaseFirestore.instance.collection('servicios').doc(s.id).delete();

                // 2. Eliminar transacciones si existieran
                final snapTrans = await FirebaseFirestore.instance
                    .collection('transacciones')
                    .where('servicioId', isEqualTo: s.id)
                    .get();
                for (var doc in snapTrans.docs) {
                  await doc.reference.delete();
                }

                // 3. Eliminar bitacora_vuelo si existiera
                await FirebaseFirestore.instance.collection('bitacoras_vuelo').doc(s.id).delete();

                // 4. Cancelar notificación
                await NotificationService.instance.cancelarRecordatorioVuelo(s.id!);

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
                if (s.id != null) {
                  if (st == 'CANCELADO') {
                    // 1. Marcar estado como cancelado y pagado como false
                    await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                      'estado': 'CANCELADO',
                      'pagado': false,
                    });

                    // 2. Anular/eliminar cualquier ingreso o cobro en transacciones
                    final snapTrans = await FirebaseFirestore.instance
                        .collection('transacciones')
                        .where('servicioId', isEqualTo: s.id)
                        .get();
                    for (var doc in snapTrans.docs) {
                      await doc.reference.delete();
                    }

                    // 3. Cancelar recordatorio de vuelo
                    await NotificationService.instance.cancelarRecordatorioVuelo(s.id!);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Operación cancelada. El cobro e ingreso fueron anulados en Contabilidad.'),
                          backgroundColor: AgroTheme.error,
                        ),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } else if (st == 'COMPLETADO') {
                    if (ctx.mounted) Navigator.pop(ctx);
                    // Ofrecer registrar el cobro contable y luego la bitácora
                    if (context.mounted) {
                      RegistroCobroServicioDialog.mostrar(context, s, abrirBitacoraDespues: true);
                    }
                  } else {
                    await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                      'estado': st,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                } else {
                  if (ctx.mounted) Navigator.pop(ctx);
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
                            initialValue: ['DJI Agras T50', 'DJI Agras T40', 'DJI Agras T30', 'DJI Agras T25', 'DJI Agras T10', 'XAG P100 Pro', 'Otro Dron'].contains(dron)
                                ? dron
                                : 'DJI Agras T40',
                            decoration: const InputDecoration(labelText: 'Aeronave / Dron'),
                            items: ['DJI Agras T50', 'DJI Agras T40', 'DJI Agras T30', 'DJI Agras T25', 'DJI Agras T10', 'XAG P100 Pro', 'Otro Dron']
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
                    );
                    NotificationService.instance.programarRecordatorioVuelo(servicioActualizado);

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
    DateTime nuevaFecha = s.fecha;
    TimeOfDay nuevaHora = TimeOfDay(hour: s.fecha.hour, minute: s.fecha.minute);
    String motivoSeleccionado = '🌧️ Clima / Lluvia';
    final List<String> motivosComunes = [
      '🌧️ Clima / Lluvia',
      '💨 Viento excesivo (>15 km/h)',
      '👨‍🌾 Aplazamiento por el cliente',
      '🛸 Mantenimiento técnico / Baterías',
      '🧪 Insumos químicos no listos',
      '⚠️ Otro motivo',
    ];
    String detalleMotivo = '';
    bool avisarWhatsApp = s.clienteTelefono.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final text = AgroTheme.getText(context);
          final subtext = AgroTheme.getSubtext(context);
          final primary = AgroTheme.getPrimary(context);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_repeat_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reprogramar Vuelo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
                      Text('${s.cultivo} • ${s.fincaUbicacion}', style: TextStyle(fontSize: 11, color: subtext)),
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
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cliente: ${s.clienteNombre} (${s.hectareas} Ha)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('NUEVA FECHA Y HORA DE VUELO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
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
                          icon: Icon(Icons.calendar_today, size: 16, color: primary),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(nuevaFecha),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: nuevaFecha,
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setModalState(() => nuevaFecha = d);
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
                          icon: Icon(Icons.schedule, size: 16, color: primary),
                          label: Text(
                            nuevaHora.format(context),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                          ),
                          onPressed: () async {
                            final t = await TimePickerHelper.seleccionarHora(context, horaInicial: nuevaHora);
                            if (t != null) setModalState(() => nuevaHora = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('MOTIVO DE LA REPROGRAMACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: motivoSeleccionado,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: motivosComunes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => motivoSeleccionado = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Detalle o nota adicional (opcional)',
                      hintText: 'Ej: Se pospone para la tarde por lluvia fuerte',
                    ),
                    onChanged: (val) => detalleMotivo = val,
                  ),
                  if (s.clienteTelefono.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: avisarWhatsApp,
                      title: const Text('Notificar al cliente por WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text('Envía un mensaje cordial con la nueva fecha y motivo', style: TextStyle(fontSize: 10, color: subtext)),
                      onChanged: (val) => setModalState(() => avisarWhatsApp = val),
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Reprogramar'),
                onPressed: () async {
                  if (s.id == null) return;

                  final fechaCompleta = DateTime(
                    nuevaFecha.year,
                    nuevaFecha.month,
                    nuevaFecha.day,
                    nuevaHora.hour,
                    nuevaHora.minute,
                  );

                  final motivoFinal = detalleMotivo.trim().isNotEmpty
                      ? '$motivoSeleccionado (${detalleMotivo.trim()})'
                      : motivoSeleccionado;

                  final logReprog = '[Reprogramado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}: Nueva fecha: ${DateFormat('dd/MM/yyyy hh:mm a').format(fechaCompleta)} - Motivo: $motivoFinal]';
                  final notasActualizadas = s.notas.isNotEmpty ? '${s.notas}\n$logReprog' : logReprog;

                  // 1. Actualizar en Firestore
                  await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                    'fecha': fechaCompleta.toIso8601String(),
                    'estado': 'PROGRAMADO',
                    'notas': notasActualizadas,
                  });

                  // 2. Reprogramar recordatorio de vuelo en NotificationService
                  final servicioActualizado = ServicioModel(
                    id: s.id,
                    clienteId: s.clienteId,
                    clienteNombre: s.clienteNombre,
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
                    dron: s.dron,
                    totalAbonado: s.totalAbonado,
                  );
                  await NotificationService.instance.programarRecordatorioVuelo(servicioActualizado);

                  // 3. Notificación local inmediata de reprogramación
                  await NotificationService.instance.notificarReprogramacionVuelo(
                    servicioActualizado,
                    motivoFinal,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);

                  // 4. Notificar vía WhatsApp si está seleccionado
                  if (avisarWhatsApp && s.clienteTelefono.trim().isNotEmpty) {
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

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vuelo reprogramado para el ${DateFormat('dd/MM/yyyy hh:mm a').format(fechaCompleta)}'),
                        backgroundColor: Colors.orange.shade800,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
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
