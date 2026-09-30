import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/servicio_model.dart';
import '../models/cliente_model.dart';
import '../models/piloto_model.dart';
import '../widgets/gestion_pilotos_dialog.dart';
import '../utils/crop_helper.dart';
import '../utils/time_picker_helper.dart';
import '../services/notification_service.dart';
import '../utils/operaciones_helper.dart';
import '../services/pdf_service.dart';
import '../widgets/registro_bitacora_dialog.dart';

class ServiciosScreen extends StatefulWidget {
  final DateTime? fechaInicial;
  const ServiciosScreen({super.key, this.fechaInicial});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _filtroEstado = 'TODOS'; // 'TODOS', 'PROGRAMADO', 'EN_PROCESO', 'COMPLETADO'
  bool _filtrarPorDia = true;

  @override
  void initState() {
    super.initState();
    if (widget.fechaInicial != null) {
      _selectedDay = widget.fechaInicial!;
      _focusedDay = widget.fechaInicial!;
      _filtrarPorDia = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mostrarDialogoAgendarServicio(context);
        }
      });
    }
  }

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda y Servicios de Dron'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _filtrarPorDia ? 'Ver todos los días' : 'Filtrar por día seleccionado',
            icon: Icon(_filtrarPorDia ? Icons.calendar_today : Icons.view_agenda),
            onPressed: () {
              setState(() {
                _filtrarPorDia = !_filtrarPorDia;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendario interactivo
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: TableCalendar(
              locale: 'es_CO',
              startingDayOfWeek: StartingDayOfWeek.monday,
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _filtrarPorDia = true;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: themeColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                formatButtonTextStyle: TextStyle(color: themeColor, fontSize: 12),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Barra de Filtros de Estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              children: [
                _buildFiltroChip('TODOS', 'Todos'),
                const SizedBox(width: 8),
                _buildFiltroChip('PROGRAMADO', 'Programados'),
                const SizedBox(width: 8),
                _buildFiltroChip('EN_PROCESO', 'En Proceso'),
                const SizedBox(width: 8),
                _buildFiltroChip('COMPLETADO', 'Completados'),
              ],
            ),
          ),

          const Divider(height: 12),

          // Lista de servicios desde Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flight_takeoff, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay servicios registrados.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Toca el botón + para agendar una fumigación.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrar según el día seleccionado y el estado
                final todosServicios = snapshot.data!.docs.map((doc) {
                  return ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                }).toList();

                // Ordenar por fecha
                todosServicios.sort((a, b) => a.fecha.compareTo(b.fecha));

                final serviciosFiltrados = todosServicios.where((s) {
                  // Filtro de día
                  if (_filtrarPorDia) {
                    final mismoDia = s.fecha.year == _selectedDay.year &&
                        s.fecha.month == _selectedDay.month &&
                        s.fecha.day == _selectedDay.day;
                    if (!mismoDia) return false;
                  }

                  // Filtro de estado
                  if (_filtroEstado != 'TODOS' && s.estado != _filtroEstado) {
                    return false;
                  }

                  return true;
                }).toList();

                // Métricas rápidas (excluyendo cancelados de facturación y área efectiva)
                final serviciosActivos = serviciosFiltrados.where((s) => s.estado != 'CANCELADO').toList();
                final totalHa = serviciosActivos.fold<double>(0, (prev, s) => prev + s.hectareas);
                final totalDinero = serviciosActivos.fold<double>(0, (prev, s) => prev + s.precioTotal);

                return Column(
                  children: [
                    // Tarjeta resumen del filtro actual
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Text(
                            _filtrarPorDia
                                ? 'Día: ${DateFormat('dd MMM yyyy', 'es').format(_selectedDay)}'
                                : 'Todos los servicios',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '${serviciosFiltrados.length} trab. | ${totalHa.toStringAsFixed(1)} Ha | ${_currencyFormat.format(totalDinero)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista de tarjetas
                    Expanded(
                      child: serviciosFiltrados.isEmpty
                          ? Center(
                              child: Text(
                                _filtrarPorDia
                                    ? 'No hay fumigaciones para esta fecha.'
                                    : 'No hay servicios con el filtro seleccionado.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: serviciosFiltrados.length,
                              itemBuilder: (context, index) {
                                final servicio = serviciosFiltrados[index];
                                return _buildServicioCard(servicio);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        onPressed: () => _mostrarDialogoAgendarServicio(context),
        icon: const Icon(Icons.add_task),
        label: const Text('Agendar Vuelo'),
      ),
    );
  }

  Widget _buildFiltroChip(String estado, String etiqueta) {
    final seleccionado = _filtroEstado == estado;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado,
      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: seleccionado ? const Color(0xFF2E7D32) : Colors.black87,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _filtroEstado = estado;
          });
        }
      },
    );
  }

  Widget _buildServicioCard(ServicioModel servicio) {
    Color estadoColor;
    String estadoTexto;
    IconData estadoIcon;

    switch (servicio.estado) {
      case 'EN_PROCESO':
        estadoColor = Colors.orange;
        estadoTexto = 'En Proceso';
        estadoIcon = Icons.airplanemode_active;
        break;
      case 'COMPLETADO':
        estadoColor = Colors.green;
        estadoTexto = 'Completado';
        estadoIcon = Icons.check_circle;
        break;
      case 'CANCELADO':
        estadoColor = Colors.red;
        estadoTexto = 'Cancelado';
        estadoIcon = Icons.cancel;
        break;
      case 'PROGRAMADO':
      default:
        estadoColor = Colors.blue;
        estadoTexto = 'Programado';
        estadoIcon = Icons.schedule;
        break;
    }

    final horaFormateada = DateFormat('hh:mm a - dd/MM/yyyy').format(servicio.fecha);

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Cliente y Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio.clienteNombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '📍 ${servicio.fincaUbicacion}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 14, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        estadoTexto,
                        style: TextStyle(
                          color: estadoColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Detalles del servicio (Hectáreas, cultivo, producto, pago)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                CropBadge(cultivo: servicio.cultivo),
                _buildTag('🌾 ${servicio.hectareas.toStringAsFixed(1)} Ha', Colors.blue.shade100, Colors.blue.shade900),
                _buildTag('🧪 ${servicio.tipoAplicacion}', Colors.purple.shade100, Colors.purple.shade900),
                if (servicio.productoQuimico.isNotEmpty)
                  _buildTag('📦 ${servicio.productoQuimico}', Colors.orange.shade100, Colors.orange.shade900),
                if (servicio.piloto.isNotEmpty)
                  _buildTag('👨‍✈️ ${servicio.piloto}', Colors.indigo.shade100, Colors.indigo.shade900),
                if (servicio.dron.isNotEmpty)
                  _buildTag('🚁 ${servicio.dron}', Colors.teal.shade100, Colors.teal.shade900),
                _buildTag(
                  servicio.metodoPago == 'EN_LINEA' ? '💳 En línea' : '💵 Efectivo',
                  servicio.metodoPago == 'EN_LINEA' ? Colors.cyan.shade100 : Colors.teal.shade100,
                  servicio.metodoPago == 'EN_LINEA' ? Colors.cyan.shade900 : Colors.teal.shade900,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Hora y Precio Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(horaFormateada, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(
                  _currencyFormat.format(servicio.precioTotal),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
              ],
            ),

            if (servicio.notas.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Nota: ${servicio.notas}',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
              ),
            ],

            const Divider(height: 18),

            // Botones de acción rápida
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Calculadora de Insumos & Baterías
                IconButton(
                  tooltip: 'Calculadora Insumos & Baterías',
                  icon: const Icon(Icons.calculate_outlined, color: Color(0xFF1565C0)),
                  onPressed: () => CalculoInsumosBaterias.mostrarDialogoCalculadora(context, servicio),
                ),

                // Compartir por WhatsApp / PDF
                PopupMenuButton<String>(
                  tooltip: 'Compartir WhatsApp / PDF',
                  icon: const Icon(Icons.share, color: Color(0xFF25D366)),
                  onSelected: (val) {
                    if (val == 'WHATSAPP') {
                      WhatsAppService.enviarResumenWhatsApp(servicio);
                    } else if (val == 'PDF') {
                      PdfService.generarYCompartirOrdenServicio(servicio);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'WHATSAPP',
                      child: Row(
                        children: [
                          Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                          SizedBox(width: 8),
                          Text('Enviar Resumen WhatsApp'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'PDF',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Enviar Recibo PDF (WhatsApp)'),
                        ],
                      ),
                    ),
                  ],
                ),

                // Editar servicio programado
                IconButton(
                  tooltip: 'Editar Vuelo Programado',
                  icon: const Icon(Icons.edit, color: Color(0xFF2E7D32)),
                  onPressed: () => _mostrarDialogoAgendarServicio(context, servicioAEditar: servicio),
                ),

                // Menú para cambiar estado
                PopupMenuButton<String>(
                  tooltip: 'Cambiar Estado',
                  icon: const Icon(Icons.sync_alt, color: Color(0xFF2E7D32)),
                  onSelected: (nuevoEstado) {
                    _actualizarEstadoServicio(servicio, nuevoEstado);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'PROGRAMADO',
                      child: Text('Marcar como Programado'),
                    ),
                    const PopupMenuItem(
                      value: 'EN_PROCESO',
                      child: Text('Marcar como En Proceso (Fumigando)'),
                    ),
                    const PopupMenuItem(
                      value: 'COMPLETADO',
                      child: Text('Marcar como Completado'),
                    ),
                    const PopupMenuItem(
                      value: 'CANCELADO',
                      child: Text('Marcar como Cancelado'),
                    ),
                  ],
                ),

                // Eliminar servicio
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmarEliminarServicio(servicio),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  void _actualizarEstadoServicio(ServicioModel servicio, String nuevoEstado) async {
    if (servicio.id == null) return;

    await FirebaseFirestore.instance.collection('servicios').doc(servicio.id).update({
      'estado': nuevoEstado,
    });

    if (nuevoEstado == 'COMPLETADO') {
      _ofrecerRegistrarEnContabilidad(servicio);
    } else if (nuevoEstado == 'CANCELADO') {
      // Revertir contabilidad si estaba pagado o registrado
      await FirebaseFirestore.instance.collection('servicios').doc(servicio.id).update({
        'pagado': false,
      });

      final transSnap = await FirebaseFirestore.instance
          .collection('transacciones')
          .where('servicioId', isEqualTo: servicio.id)
          .get();
      for (var doc in transSnap.docs) {
        await doc.reference.delete();
      }

      await NotificationService.instance.cancelarRecordatorio(servicio.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada. Se actualizaron los registros contables.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _ofrecerRegistrarEnContabilidad(ServicioModel servicio) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Registrar ingreso en contabilidad?'),
        content: Text(
          'El servicio de ${servicio.clienteNombre} por ${_currencyFormat.format(servicio.precioTotal)} se ha completado. ¿Deseas agregarlo a los ingresos de la empresa?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                _ofrecerRegistroBitacora(servicio);
              }
            },
            child: const Text('No por ahora'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              await FirebaseFirestore.instance.collection('transacciones').add({
                'tipo': 'INGRESO',
                'categoria': 'SERVICIO',
                'monto': servicio.precioTotal,
                'descripcion': 'Fumigación ${servicio.cultivo} (${servicio.hectareas} Ha) - ${servicio.clienteNombre}',
                'fecha': DateTime.now().toIso8601String(),
                'servicioId': servicio.id,
              });

              if (servicio.id != null) {
                await FirebaseFirestore.instance.collection('servicios').doc(servicio.id).update({
                  'pagado': true,
                });
              }

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('¡Ingreso registrado en Contabilidad con éxito!')),
              );

              if (mounted) {
                _ofrecerRegistroBitacora(servicio);
              }
            },
            child: const Text('Registrar Ingreso', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _ofrecerRegistroBitacora(ServicioModel servicio) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_edu_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Bitácora de Vuelo'),
          ],
        ),
        content: Text(
          '¿Deseas registrar la Bitácora de vuelo de ${servicio.cultivo} para ${servicio.clienteNombre} ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Omitir / No por ahora', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(ctx);
              RegistroBitacoraDialog.mostrar(context, servicio);
            },
            child: const Text('Registrar Bitácora', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarServicio(ServicioModel servicio) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: Text('¿Estás seguro de eliminar el servicio de ${servicio.clienteNombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (servicio.id != null) {
                await FirebaseFirestore.instance.collection('servicios').doc(servicio.id).delete();
                await FirebaseFirestore.instance.collection('bitacoras_vuelo').doc(servicio.id).delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirBuscadorClientes({
    required BuildContext context,
    required Function(ClienteModel cliente) onSeleccionado,
  }) async {
    String query = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Buscar y Seleccionar Cliente',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Escribe nombre, finca o teléfono...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setSheetState(() => query = val.toLowerCase().trim());
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snap.data!.docs;
                          final clientes = docs.map((d) => ClienteModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
                          final filtrados = clientes.where((c) {
                            if (query.isEmpty) return true;
                            return c.nombre.toLowerCase().contains(query) ||
                                c.ubicacion.toLowerCase().contains(query) ||
                                c.telefono.toLowerCase().contains(query);
                          }).toList();

                          if (filtrados.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isEmpty ? 'No hay clientes registrados.' : 'No se encontraron clientes con "$query"',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = filtrados[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                                  child: Text(
                                    c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('📍 ${c.ubicacion}  •  📞 ${c.telefono}'),
                                onTap: () {
                                  onSeleccionado(c);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoAgendarServicio(BuildContext context, {ServicioModel? servicioAEditar}) {
    final formKey = GlobalKey<FormState>();

    String clienteId = servicioAEditar?.clienteId ?? '';
    String clienteNombre = servicioAEditar?.clienteNombre ?? '';
    String clienteTelefono = servicioAEditar?.clienteTelefono ?? '';
    String fincaUbicacion = servicioAEditar?.fincaUbicacion ?? '';
    DateTime fechaSeleccionada = servicioAEditar?.fecha ?? _selectedDay;
    TimeOfDay horaSeleccionada = servicioAEditar != null
        ? TimeOfDay(hour: servicioAEditar.fecha.hour, minute: servicioAEditar.fecha.minute)
        : TimeOfDay.now();
    double hectareas = servicioAEditar?.hectareas ?? 1.0;
    String cultivo = servicioAEditar?.cultivo ?? 'Arroz';
    String tipoAplicacion = servicioAEditar?.tipoAplicacion ?? 'Fungicida';
    String productoQuimico = servicioAEditar?.productoQuimico ?? '';
    double precioPorHectarea = servicioAEditar?.precioPorHectarea ?? 50000;
    String notas = servicioAEditar?.notas ?? '';
    String metodoPago = servicioAEditar?.metodoPago ?? 'EFECTIVO';
    String estado = servicioAEditar?.estado ?? 'PROGRAMADO';
    bool pagado = servicioAEditar?.pagado ?? false;
    String piloto = servicioAEditar?.piloto ?? '';
    String? pilotoColorHex = servicioAEditar?.pilotoColorHex;
    String dron = servicioAEditar?.dron ?? 'DJI Agras T40';

    final dronesDisponibles = [
      'DJI Agras T50',
      'DJI Agras T40',
      'DJI Agras T30',
      'DJI Agras T25',
      'DJI Agras T20P',
      'DJI Agras T10',
      'XAG P100 Pro',
      'XAG V40',
      'Otro Dron',
    ];

    final tiposAplicacion = [
      'Fungicida',
      'Herbicida',
      'Insecticida',
      'Fertilizante Foliar',
      'Coadyuvante',
      'Madurante',
      'Siembra de semillas',
      'Otro',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double precioTotal = hectareas * precioPorHectarea;

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(CropHelper.getEmoji(cultivo), style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Text(
                                servicioAEditar == null ? 'Agendar Vuelo de Fumigación' : 'Editar Vuelo Programado',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selector y Buscador de Cliente
                      if (servicioAEditar != null) ...[
                        TextFormField(
                          initialValue: clienteNombre,
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (val) => clienteNombre = val ?? '',
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: fincaUbicacion,
                          decoration: const InputDecoration(
                            labelText: 'Finca / Ubicación',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (val) => fincaUbicacion = val ?? '',
                        ),
                      ] else ...[
                        if (clienteNombre.isEmpty) ...[
                          InkWell(
                            onTap: () => _abrirBuscadorClientes(
                              context: context,
                              onSeleccionado: (c) {
                                setModalState(() {
                                  clienteId = c.id ?? '';
                                  clienteNombre = c.nombre;
                                  clienteTelefono = c.telefono;
                                  fincaUbicacion = c.ubicacion;
                                });
                              },
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green.shade400, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.green.shade50.withValues(alpha: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_search, color: Colors.green.shade800, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Seleccionar o Buscar Cliente',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade900),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Toca para buscar por nombre, finca o teléfono',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.green.shade700),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2E7D32),
                                  child: Text(
                                    clienteNombre.isNotEmpty ? clienteNombre[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('📍 $fincaUbicacion', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                                      if (clienteTelefono.isNotEmpty)
                                        Text('📞 $clienteTelefono', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text('Cambiar'),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                                  onPressed: () => _abrirBuscadorClientes(
                                    context: context,
                                    onSeleccionado: (c) {
                                      setModalState(() {
                                        clienteId = c.id ?? '';
                                        clienteNombre = c.nombre;
                                        clienteTelefono = c.telefono;
                                        fincaUbicacion = c.ubicacion;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 12),

                      // Selector de Fecha y Hora
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: fechaSeleccionada,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setModalState(() {
                                    fechaSeleccionada = d;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(horaSeleccionada.format(context)),
                              onPressed: () async {
                                final t = await TimePickerHelper.seleccionarHora(
                                  context,
                                  horaInicial: horaSeleccionada,
                                );
                                if (t != null) {
                                  setModalState(() {
                                    horaSeleccionada = t;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Hectáreas y Cultivo (25+ Cultivos con Emojis)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: hectareas.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Hectáreas (Ha)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Inválido' : null,
                              onChanged: (val) {
                                final v = double.tryParse(val);
                                if (v != null) {
                                  setModalState(() => hectareas = v);
                                }
                              },
                              onSaved: (val) => hectareas = double.parse(val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: CropHelper.nombresCultivos.contains(cultivo) ? cultivo : 'Otro (Personalizado)',
                              decoration: const InputDecoration(
                                labelText: 'Cultivo',
                                border: OutlineInputBorder(),
                              ),
                              items: CropHelper.listaCultivos.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['nombre'],
                                  child: Row(
                                    children: [
                                      Text(c['emoji']!, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(c['nombre']!, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setModalState(() => cultivo = val!),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Tipo de Aplicación y Producto Químico
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: tipoAplicacion,
                              decoration: const InputDecoration(
                                labelText: 'Aplicación',
                                border: OutlineInputBorder(),
                              ),
                              items: tiposAplicacion
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (val) => setModalState(() => tipoAplicacion = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: productoQuimico,
                              decoration: const InputDecoration(
                                labelText: 'Producto/Químico',
                                hintText: 'Ej. Fungicida X',
                                border: OutlineInputBorder(),
                              ),
                              onSaved: (val) => productoQuimico = val ?? '',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Piloto Obligatorio Registrado y Dron Asignado
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('pilotos')
                            .where('activo', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapPilotos) {
                          if (!snapPilotos.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: LinearProgressIndicator(),
                            );
                          }
                          final docs = snapPilotos.data!.docs;
                          final pilotos = docs
                              .map((d) => PilotoModel.fromMap(d.id, d.data() as Map<String, dynamic>))
                              .toList();

                          if (pilotos.isEmpty) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No hay pilotos registrados',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Para agendar un vuelo, primero debes registrar al piloto a cargo.',
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade800,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.person_add, size: 16),
                                      label: const Text('Registrar Piloto'),
                                      onPressed: () => GestionPilotosDialog.mostrar(context),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final bool pilotoExiste = pilotos.any((p) => p.nombre == piloto);
                          final String? valorPiloto = pilotoExiste ? piloto : null;

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: valorPiloto,
                                  decoration: const InputDecoration(
                                    labelText: 'Piloto Asignado *',
                                    prefixIcon: Icon(Icons.person_pin),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: pilotos.map((p) {
                                    return DropdownMenuItem<String>(
                                      value: p.nombre,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: p.color,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.black26, width: 0.5),
                                            ),
                                          ),
                                          Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final p = pilotos.firstWhere((item) => item.nombre == val);
                                      setModalState(() {
                                        piloto = p.nombre;
                                        pilotoColorHex = p.colorHex;
                                      });
                                    }
                                  },
                                  validator: (val) {
                                    if (piloto.isEmpty) {
                                      return 'Selecciona un piloto';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Gestionar Pilotos',
                                icon: const Icon(Icons.person_add_outlined, color: Color(0xFF2E7D32)),
                                onPressed: () => GestionPilotosDialog.mostrar(context),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Dron a Usar
                      DropdownButtonFormField<String>(
                        initialValue: dronesDisponibles.contains(dron) ? dron : 'DJI Agras T40',
                        decoration: const InputDecoration(
                          labelText: 'Dron a Usar',
                          prefixIcon: Icon(Icons.flight),
                          border: OutlineInputBorder(),
                        ),
                        items: dronesDisponibles
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) => setModalState(() => dron = val ?? 'DJI Agras T40'),
                        onSaved: (val) => dron = val ?? 'DJI Agras T40',
                      ),

                      const SizedBox(height: 12),

                      // Método de Pago
                      DropdownButtonFormField<String>(
                        initialValue: metodoPago,
                        decoration: const InputDecoration(
                          labelText: 'Método de Pago',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Pago en Efectivo')),
                          DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 En Línea / Transferencia Bancaria')),
                        ],
                        onChanged: (val) => setModalState(() => metodoPago = val!),
                      ),

                      const SizedBox(height: 12),

                      // Precio por Ha y Cálculo Automático
                      TextFormField(
                        initialValue: precioPorHectarea.toStringAsFixed(0),
                        decoration: const InputDecoration(
                          labelText: 'Precio por Hectárea (\$ COP)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Inválido' : null,
                        onChanged: (val) {
                          final p = double.tryParse(val);
                          if (p != null) {
                            setModalState(() => precioPorHectarea = p);
                          }
                        },
                        onSaved: (val) => precioPorHectarea = double.parse(val!),
                      ),

                      const SizedBox(height: 10),

                      // Total Estimado en vivo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total a Cobrar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              _currencyFormat.format(precioTotal),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (servicioAEditar != null) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('¿Servicio Pagado?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          value: pagado,
                          onChanged: (val) => setModalState(() => pagado = val),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Notas
                      TextFormField(
                        initialValue: notas,
                        decoration: const InputDecoration(
                          labelText: 'Notas / Observaciones de Vuelo',
                          hintText: 'Ej. Cables eléctricos al sur, pista junto a la bodega',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onSaved: (val) => notas = val ?? '',
                      ),

                      const SizedBox(height: 18),

                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text(
                            servicioAEditar == null ? 'Agendar en Calendario' : 'Guardar Cambios del Vuelo',
                            style: const TextStyle(fontSize: 16),
                          ),
                          onPressed: () async {
                            if (clienteNombre.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Por favor busca y selecciona un cliente.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            if (formKey.currentState!.validate()) {
                              if (piloto.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Por favor selecciona un piloto registrado.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              formKey.currentState!.save();

                              final fechaHora = DateTime(
                                fechaSeleccionada.year,
                                fechaSeleccionada.month,
                                fechaSeleccionada.day,
                                horaSeleccionada.hour,
                                horaSeleccionada.minute,
                              );

                              final servicioAGuardar = ServicioModel(
                                id: servicioAEditar?.id,
                                clienteId: clienteId,
                                clienteNombre: clienteNombre,
                                clienteTelefono: clienteTelefono,
                                fincaUbicacion: fincaUbicacion,
                                fecha: fechaHora,
                                hectareas: hectareas,
                                cultivo: cultivo,
                                tipoAplicacion: tipoAplicacion,
                                productoQuimico: productoQuimico,
                                precioPorHectarea: precioPorHectarea,
                                precioTotal: hectareas * precioPorHectarea,
                                estado: estado,
                                pagado: pagado,
                                notas: notas,
                                metodoPago: metodoPago,
                                piloto: piloto,
                                pilotoColorHex: pilotoColorHex,
                                dron: dron,
                              );

                              if (servicioAEditar == null) {
                                final docRef = await FirebaseFirestore.instance
                                    .collection('servicios')
                                    .add(servicioAGuardar.toMap());
                                servicioAGuardar.id = docRef.id;
                                await NotificationService.instance.programarRecordatorioVuelo(servicioAGuardar);
                                await NotificationService.instance.notificarNuevoVuelo(servicioAGuardar);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('servicios')
                                    .doc(servicioAEditar.id)
                                    .update(servicioAGuardar.toMap());
                                await NotificationService.instance.programarRecordatorioVuelo(servicioAGuardar);
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(servicioAEditar == null ? '¡Vuelo agendado con éxito!' : '¡Vuelo programado actualizado con éxito!'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
