import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/agro_theme.dart';
import '../models/cliente_model.dart';
import '../models/servicio_model.dart';
import '../utils/crop_helper.dart';
import '../utils/operaciones_helper.dart';
import '../services/pdf_service.dart';
import '../services/notification_service.dart';
import 'servicios_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String _busqueda = '';
  String _filtroRapido = 'Todos';
  String _criterioOrden = 'HECTAREAS'; // HECTAREAS, FRECUENCIA, FACTURACION, DEUDA, NOMBRE
  bool _alertasRevisadas = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cardBg,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agenda y Clientes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            'Directorio Agrícola',
                            style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_active_outlined),
                    tooltip: 'Comprobar Alertas de Cartera',
                    onPressed: () async {
                      final snap = await FirebaseFirestore.instance.collection('servicios').get();
                      final servs = snap.docs.map((d) => ServicioModel.fromMap(d.id, d.data())).toList();
                      await NotificationService.instance.verificarYNotificarMorosos(servs);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comprobando clientes en mora y enviando avisos locales...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // BARRA DE BÚSQUEDA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                ),
                child: TextField(
                  style: TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Buscar clientes, fincas, municipios...',
                    hintStyle: TextStyle(color: onSurfaceVariant, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: onSurfaceVariant, size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _busqueda = val.toLowerCase());
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            // BARRA DE FILTROS Y ORDENAMIENTO COMPACTA Y ELEGANTE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  // Selector Segmentado de Estado
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['Todos', 'Activos', 'Inactivos'].map((filtro) {
                        final seleccionado = _filtroRapido == filtro;
                        return GestureDetector(
                          onTap: () => setState(() => _filtroRapido = filtro),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: seleccionado ? primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              filtro,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                                color: seleccionado ? Colors.white : onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const Spacer(),

                  // Botón Modal de Ordenamiento
                  InkWell(
                    onTap: () => _mostrarModalOrden(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 16, color: primary),
                          const SizedBox(width: 4),
                          Text(
                            _obtenerEtiquetaOrden(_criterioOrden),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // LISTA DE CLIENTES EN TIEMPO REAL CON HISTORIAL DE SERVICIOS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
                builder: (context, snapServicios) {
                  final todosServicios = (snapServicios.data?.docs ?? [])
                      .map((d) => ServicioModel.fromMap(d.id, d.data() as Map<String, dynamic>))
                      .toList();

                  // Comprobación adaptativa de mora y notificaciones
                  if (!_alertasRevisadas && todosServicios.isNotEmpty) {
                    _alertasRevisadas = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      NotificationService.instance.verificarYNotificarMorosos(todosServicios);
                    });
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primary));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 48, color: onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text('No hay clientes registrados aún.', style: TextStyle(color: onSurfaceVariant)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Registrar Primer Cliente'),
                                onPressed: () => _mostrarDialogoNuevoCliente(context),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      final todosClientes = docs.map((doc) {
                        return ClienteModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                      }).toList();

                      final clientesFiltrados = todosClientes.where((c) {
                        if (_filtroRapido == 'Activos' && !c.activo) return false;
                        if (_filtroRapido == 'Inactivos' && c.activo) return false;

                        if (_busqueda.isNotEmpty) {
                          final matchNombre = c.nombre.toLowerCase().contains(_busqueda);
                          final matchUbicacion = c.ubicacion.toLowerCase().contains(_busqueda);
                          final matchTelefono = c.telefono.toLowerCase().contains(_busqueda);
                          return matchNombre || matchUbicacion || matchTelefono;
                        }
                        return true;
                      }).toList();

                      // ORDENAMIENTO MINUCIOSO E INTELIGENTE
                      clientesFiltrados.sort((a, b) {
                        final sA = todosServicios.where((s) => (a.id != null && s.clienteId == a.id) || s.clienteNombre.trim().toLowerCase() == a.nombre.trim().toLowerCase()).toList();
                        final sB = todosServicios.where((s) => (b.id != null && s.clienteId == b.id) || s.clienteNombre.trim().toLowerCase() == b.nombre.trim().toLowerCase()).toList();

                        switch (_criterioOrden) {
                          case 'HECTAREAS':
                            final haA = sA.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.hectareas);
                            final haB = sB.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.hectareas);
                            return haB.compareTo(haA);
                          case 'FRECUENCIA':
                            return sB.length.compareTo(sA.length);
                          case 'FACTURACION':
                            final dinA = sA.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.precioTotal);
                            final dinB = sB.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.precioTotal);
                            return dinB.compareTo(dinA);
                          case 'DEUDA':
                            final deudaA = sA.where((s) => s.estado == 'COMPLETADO' && s.estadoPago != 'PAGADO').fold<double>(0.0, (acc, s) => acc + s.saldoPendiente);
                            final deudaB = sB.where((s) => s.estado == 'COMPLETADO' && s.estadoPago != 'PAGADO').fold<double>(0.0, (acc, s) => acc + s.saldoPendiente);
                            return deudaB.compareTo(deudaA);
                          case 'NOMBRE':
                          default:
                            return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
                        }
                      });

                      if (clientesFiltrados.isEmpty) {
                        return Center(
                          child: Text('No se encontraron clientes con el filtro actual.', style: TextStyle(color: onSurfaceVariant)),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 6.0, bottom: 95.0),
                        itemCount: clientesFiltrados.length,
                        itemBuilder: (context, index) {
                          final cliente = clientesFiltrados[index];
                          final serviciosCliente = todosServicios.where((s) {
                            final matchId = cliente.id != null && s.clienteId == cliente.id;
                            final matchNombre = s.clienteNombre.trim().toLowerCase() == cliente.nombre.trim().toLowerCase();
                            return matchId || matchNombre;
                          }).toList();

                          return _buildClientCard(
                            cliente,
                            serviciosCliente,
                            cardBg,
                            primary,
                            onSurface,
                            onSurfaceVariant,
                            borderColor,
                          );
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        onPressed: () => _mostrarDialogoNuevoCliente(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildClientCard(
    ClienteModel cliente,
    List<ServicioModel> serviciosCliente,
    Color cardBg,
    Color primary,
    Color onSurface,
    Color onSurfaceVariant,
    Color borderColor,
  ) {
    final totalVuelos = serviciosCliente.length;
    final totalHa = serviciosCliente.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.hectareas);
    final totalDinero = serviciosCliente.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.precioTotal);
    final serviciosConDeuda = serviciosCliente.where((s) => s.estado == 'COMPLETADO' && s.estadoPago != 'PAGADO' && s.saldoPendiente > 0).toList();
    final totalDeuda = serviciosConDeuda.fold<double>(0.0, (acc, s) => acc + s.saldoPendiente);
    final maxDiasMora = serviciosConDeuda.fold<int>(0, (acc, s) => s.diasMora > acc ? s.diasMora : acc);
    final cultivos = serviciosCliente.map((s) => s.cultivo).toSet().toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        boxShadow: AgroTheme.getShadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente.ubicacion.isNotEmpty ? cliente.ubicacion : 'Finca / Parcela',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.nombre,
                              style: TextStyle(fontSize: 13, color: onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // MENÚ DE OPCIONES RÁPIDAS (EDITAR / ELIMINAR)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: onSurfaceVariant, size: 20),
                  color: cardBg,
                  onSelected: (val) {
                    if (val == 'editar') {
                      _mostrarDialogoEditarCliente(context, cliente);
                    } else if (val == 'eliminar') {
                      _confirmarEliminarCliente(context, cliente);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: primary),
                          const SizedBox(width: 8),
                          const Text('Editar Cliente'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AgroTheme.error),
                          SizedBox(width: 8),
                          Text('Eliminar Cliente', style: TextStyle(color: AgroTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // TIRA DE MÉTRICAS RÁPIDAS (Módulo 360)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Vuelos', '$totalVuelos', Icons.flight_takeoff, primary),
                  Container(height: 22, width: 1, color: borderColor.withValues(alpha: 0.5)),
                  _buildStatItem('Área Fumigada', '${totalHa.toStringAsFixed(1)} Ha', Icons.landscape, Colors.blue),
                  Container(height: 22, width: 1, color: borderColor.withValues(alpha: 0.5)),
                  _buildStatItem('Facturado', _currencyFormat.format(totalDinero), Icons.attach_money, Colors.green),
                ],
              ),
            ),

            // MINI AVISO / CUENTA REGRESIVA DEUDORES
            if (totalDeuda > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: maxDiasMora >= 15
                      ? AgroTheme.error.withValues(alpha: 0.12)
                      : maxDiasMora >= 7
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: maxDiasMora >= 15
                        ? AgroTheme.error.withValues(alpha: 0.6)
                        : maxDiasMora >= 7
                            ? Colors.amber.withValues(alpha: 0.6)
                            : Colors.blue.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      maxDiasMora >= 15 ? Icons.warning_amber_rounded : Icons.timer_outlined,
                      size: 22,
                      color: maxDiasMora >= 15
                          ? AgroTheme.error
                          : (maxDiasMora >= 7 ? Colors.amber[800] : Colors.blue[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            maxDiasMora == 0
                                ? 'Saldo pendiente por cobrar'
                                : '⏳ Lleva $maxDiasMora ${maxDiasMora == 1 ? "día" : "días"} sin pagar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: maxDiasMora >= 15
                                  ? AgroTheme.error
                                  : (maxDiasMora >= 7 ? Colors.amber[900] : Colors.blue[900]),
                            ),
                          ),
                          Text(
                            'Deuda total: ${_currencyFormat.format(totalDeuda)} (${serviciosConDeuda.length} ${serviciosConDeuda.length == 1 ? "servicio" : "servicios"})',
                            style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('Cobrar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _abrirWhatsAppCobro(cliente.telefono, cliente.nombre, totalDeuda, maxDiasMora),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (totalDeuda > 0)
                  _buildTag(
                    'Deuda: ${_currencyFormat.format(totalDeuda)}',
                    Icons.money_off,
                    (maxDiasMora >= 7 ? AgroTheme.error : Colors.amber[800]!).withValues(alpha: 0.15),
                    maxDiasMora >= 7 ? AgroTheme.error : Colors.amber[800]!,
                  ),
                if (cultivos.isNotEmpty)
                  for (var c in cultivos.take(3))
                    CropBadge(cultivo: c)
                else if (cliente.cultivoPrincipal != null && cliente.cultivoPrincipal!.isNotEmpty)
                  CropBadge(cultivo: cliente.cultivoPrincipal!)
                else
                  _buildTag('🌱 Sin vuelos aún', Icons.grass, primary.withValues(alpha: 0.15), primary),
                _buildTag('Tel: ${cliente.telefono}', Icons.phone, onSurfaceVariant.withValues(alpha: 0.15), onSurfaceVariant),
              ],
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        cliente.ubicacion,
                        style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      if (cliente.id != null) {
                        final nuevo = !cliente.activo;
                        await FirebaseFirestore.instance.collection('clientes').doc(cliente.id).update({'activo': nuevo});
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text(
                              nuevo ? '¡Cliente ${cliente.nombre} reactivado!' : 'Cliente ${cliente.nombre} marcado como inactivo',
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cliente.activo ? primary.withValues(alpha: 0.15) : Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cliente.activo ? primary.withValues(alpha: 0.4) : Colors.orangeAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cliente.activo ? Icons.check_circle : Icons.pause_circle_filled,
                            size: 13,
                            color: cliente.activo ? primary : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cliente.activo ? 'Activo' : 'Inactivo (Tocar)',
                            style: TextStyle(
                              fontSize: 11,
                              color: cliente.activo ? primary : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                IconButton(
                  tooltip: 'Llamar al cliente',
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () => _llamarCliente(cliente.telefono),
                ),
                IconButton(
                  tooltip: 'Chat de WhatsApp',
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  onPressed: () => _abrirWhatsAppCliente(cliente.telefono, cliente.nombre),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: const Text('Detalles 360°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _mostrarDetallesCliente360(context, cliente, serviciosCliente),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('Agendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ServiciosScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Future<void> _llamarCliente(String telefono) async {
    final clean = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _abrirWhatsAppCliente(String telefono, String nombre) async {
    final clean = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent('Hola $nombre, te contactamos de Icaro Proagro para coordinar tus servicios de fumigación.');
    final uri = Uri.parse(clean.isNotEmpty ? 'https://wa.me/$clean?text=$text' : 'https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirWhatsAppCobro(String telefono, String nombre, double saldo, int diasMora) async {
    final clean = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final format = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final String moraTexto = diasMora > 0 ? 'con $diasMora días de retraso' : 'pendiente';
    final text = Uri.encodeComponent(
      'Hola $nombre, te saludamos de Icaro Proagro. Te recordamos cordialmente que registras un saldo pendiente de ${format.format(saldo)} ($moraTexto) por servicios de fumigación completados. ¿Cuándo tendrías programado realizar el pago? Quedamos atentos, ¡muchas gracias!',
    );
    final uri = Uri.parse(clean.isNotEmpty ? 'https://wa.me/$clean?text=$text' : 'https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTag(String text, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  /// Módulo de Clientes 360° con desglose de solicitudes, cultivos fumigados, direcciones y facturación
  void _mostrarDetallesCliente360(BuildContext context, ClienteModel cliente, List<ServicioModel> servicios) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).colorScheme.surface;

    final totalVuelos = servicios.length;
    final completados = servicios.where((s) => s.estado == 'COMPLETADO').length;
    final programados = servicios.where((s) => s.estado == 'PROGRAMADO' || s.estado == 'EN_PROCESO').length;
    final cancelados = servicios.where((s) => s.estado == 'CANCELADO').length;

    final totalHa = servicios.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.hectareas);
    final totalDinero = servicios.where((s) => s.estado != 'CANCELADO').fold<double>(0.0, (acc, s) => acc + s.precioTotal);

    // Conteo por cultivo
    final Map<String, int> conteoCultivos = {};
    final Map<String, double> hectareasCultivos = {};
    for (var s in servicios) {
      conteoCultivos[s.cultivo] = (conteoCultivos[s.cultivo] ?? 0) + 1;
      hectareasCultivos[s.cultivo] = (hectareasCultivos[s.cultivo] ?? 0.0) + (s.estado != 'CANCELADO' ? s.hectareas : 0.0);
    }

    // Insumos / químicos únicos
    final quimicos = servicios
        .map((s) => s.productoQuimico.trim())
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList();

    // Direcciones / Fincas únicas
    final fincas = servicios
        .map((s) => s.fincaUbicacion.trim())
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList();
    if (cliente.ubicacion.isNotEmpty && !fincas.contains(cliente.ubicacion.trim())) {
      fincas.insert(0, cliente.ubicacion.trim());
    }

    // Ordenar servicios por fecha descendente
    final serviciosOrdenados = List<ServicioModel>.from(servicios)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asa superior
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cabecera Cliente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.nombre,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${cliente.ubicacion}',
                              style: TextStyle(fontSize: 14, color: onSurfaceVariant),
                            ),
                            Text(
                              '📞 ${cliente.telefono}',
                              style: TextStyle(fontSize: 13, color: onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Barra de Acciones Directas
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Llamar'),
                          onPressed: () => _llamarCliente(cliente.telefono),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                          onPressed: () => _abrirWhatsAppCliente(cliente.telefono, cliente.nombre),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_task, size: 18),
                          label: const Text('Agendar'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ServiciosScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 28),

                  // MÉTRICAS ACUMULADAS 360°
                  Text(
                    '📊 Resumen Histórico 360°',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Servicios',
                          '$totalVuelos',
                          '$completados compl. | $programados prog. | $cancelados canc.',
                          Icons.flight,
                          primary,
                          cardBg,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          'Área Fumigada',
                          '${totalHa.toStringAsFixed(1)} Ha',
                          'Acumulado total',
                          Icons.landscape,
                          Colors.blue,
                          cardBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    'Inversión Total Facturada',
                    _currencyFormat.format(totalDinero),
                    '$completados vuelos ejecutados con éxito',
                    Icons.monetization_on,
                    Colors.green,
                    cardBg,
                    isWide: true,
                  ),

                  const Divider(height: 28),

                  // CULTIVOS Y PRODUCTOS FUMIGADOS
                  Text(
                    '🌾 Cultivos y Tratamientos Realizados',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                  ),
                  const SizedBox(height: 8),
                  if (conteoCultivos.isEmpty)
                    Text('No registra fumigaciones aún.', style: TextStyle(color: onSurfaceVariant, fontSize: 13))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: conteoCultivos.entries.map((e) {
                        final ha = hectareasCultivos[e.key] ?? 0.0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CropHelper.getEmoji(e.key), style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                '${e.key}: ${e.value} ${e.value == 1 ? "vuelo" : "vuelos"} (${ha.toStringAsFixed(1)} Ha)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 14),

                  // PRODUCTOS / INSUMOS APLICADOS
                  Text(
                    '🧪 Insumos y Químicos Aplicados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: onSurface),
                  ),
                  const SizedBox(height: 6),
                  if (quimicos.isEmpty)
                    Text('No hay insumos específicos registrados.', style: TextStyle(color: onSurfaceVariant, fontSize: 13))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quimicos.map((q) {
                        return Chip(
                          backgroundColor: Colors.purple.shade50,
                          side: BorderSide(color: Colors.purple.shade200),
                          label: Text(q, style: TextStyle(fontSize: 12, color: Colors.purple.shade900)),
                          avatar: const Icon(Icons.science, size: 14, color: Colors.purple),
                        );
                      }).toList(),
                    ),

                  const Divider(height: 28),

                  // DIRECCIONES Y FINCAS REGISTRADAS
                  Text(
                    '📍 Fincas y Direcciones Asociadas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                  ),
                  const SizedBox(height: 8),
                  if (fincas.isEmpty)
                    Text('No hay ubicaciones registradas.', style: TextStyle(color: onSurfaceVariant, fontSize: 13))
                  else
                    Column(
                      children: fincas.map((f) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pin_drop, size: 16, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(f, style: TextStyle(fontSize: 13, color: onSurface)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const Divider(height: 28),

                  // HISTORIAL DE VUELOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✈️ Historial de Vuelos (${serviciosOrdenados.length})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (serviciosOrdenados.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: Text('No hay vuelos registrados para este cliente.', style: TextStyle(color: onSurfaceVariant)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: serviciosOrdenados.length,
                      itemBuilder: (context, i) {
                        final s = serviciosOrdenados[i];
                        Color estColor = Colors.blue;
                        if (s.estado == 'COMPLETADO') estColor = Colors.green;
                        if (s.estado == 'EN_PROCESO') estColor = Colors.orange;
                        if (s.estado == 'CANCELADO') estColor = Colors.red;

                        final fechaFmt = DateFormat('dd/MM/yyyy - hh:mm a', 'es').format(s.fecha);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: estColor.withValues(alpha: 0.3)),
                            color: cardBg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(CropHelper.getEmoji(s.cultivo), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text('${s.cultivo} (${s.hectareas} Ha)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: estColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s.estado,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: estColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('📅 $fechaFmt | 📍 ${s.fincaUbicacion}', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                              if (s.piloto.isNotEmpty || s.dron.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '👨‍✈️ Piloto: ${s.piloto.isEmpty ? "No asignado" : s.piloto} | 🚁 ${s.dron.isEmpty ? "Dron general" : s.dron}',
                                    style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _currencyFormat.format(s.precioTotal),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                                        tooltip: 'Enviar Resumen WhatsApp',
                                        onPressed: () => WhatsAppService.enviarResumenWhatsApp(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.redAccent),
                                        tooltip: 'Recibo PDF',
                                        onPressed: () => PdfService.generarYCompartirOrdenServicio(s),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(
    String titulo,
    String valor,
    String subtitulo,
    IconData icon,
    Color color,
    Color cardBg, {
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(valor, style: TextStyle(fontSize: isWide ? 20 : 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitulo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevoCliente(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String nombre = '';
    String telefono = '';
    String ubicacion = '';
    String cultivoPrincipal = CropHelper.cultivos.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Nuevo Cliente / Finca'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nombre del Agricultor / Empresa'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => nombre = v!,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => telefono = v!,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nombre de la Finca / Municipio'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => ubicacion = v!,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: cultivoPrincipal,
                    decoration: const InputDecoration(labelText: 'Cultivo Principal'),
                    items: CropHelper.cultivos.map((c) {
                      final emoji = CropHelper.getEmoji(c);
                      return DropdownMenuItem(value: c, child: Text('$emoji $c'));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => cultivoPrincipal = val ?? CropHelper.cultivos.first),
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
                  await FirebaseFirestore.instance.collection('clientes').add({
                    'nombre': nombre,
                    'telefono': telefono,
                    'ubicacion': ubicacion,
                    'cultivoPrincipal': cultivoPrincipal,
                    'activo': true,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarCliente(BuildContext context, ClienteModel cliente) {
    final formKey = GlobalKey<FormState>();
    String nombre = cliente.nombre;
    String telefono = cliente.telefono;
    String ubicacion = cliente.ubicacion;
    String cultivoPrincipal = cliente.cultivoPrincipal ?? CropHelper.cultivos.first;
    if (!CropHelper.cultivos.contains(cultivoPrincipal)) {
      cultivoPrincipal = CropHelper.cultivos.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Editar Datos del Cliente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre del Agricultor / Empresa'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => nombre = v!,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: telefono,
                    decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => telefono = v!,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: ubicacion,
                    decoration: const InputDecoration(labelText: 'Nombre de la Finca / Municipio'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => ubicacion = v!,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: cultivoPrincipal,
                    decoration: const InputDecoration(labelText: 'Cultivo Principal'),
                    items: CropHelper.cultivos.map((c) {
                      final emoji = CropHelper.getEmoji(c);
                      return DropdownMenuItem(value: c, child: Text('$emoji $c'));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => cultivoPrincipal = val ?? CropHelper.cultivos.first),
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
                  if (cliente.id != null) {
                    await FirebaseFirestore.instance.collection('clientes').doc(cliente.id).update({
                      'nombre': nombre,
                      'telefono': telefono,
                      'ubicacion': ubicacion,
                      'cultivoPrincipal': cultivoPrincipal,
                    });
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Datos del cliente actualizados con éxito!')),
                    );
                  }
                }
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminarCliente(BuildContext context, ClienteModel cliente) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AgroTheme.error),
            SizedBox(width: 8),
            Text('¿Eliminar Cliente?'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente a "${cliente.nombre}" (${cliente.ubicacion})? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              if (cliente.id != null) {
                await FirebaseFirestore.instance.collection('clientes').doc(cliente.id).delete();
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cliente ${cliente.nombre} eliminado.')),
                );
              }
            },
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );
  }

  String _obtenerEtiquetaOrden(String id) {
    switch (id) {
      case 'HECTAREAS':
        return '🌾 Hectáreas';
      case 'FRECUENCIA':
        return '🚁 Frecuencia';
      case 'FACTURACION':
        return '💰 Facturación';
      case 'DEUDA':
        return '⚠️ Deuda';
      case 'NOMBRE':
        return '🔤 A - Z';
      default:
        return 'Ordenar';
    }
  }

  void _mostrarModalOrden(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardBg = Theme.of(context).colorScheme.surface;

    final opciones = [
      {'id': 'HECTAREAS', 'label': 'Más Hectáreas Fumigadas', 'emoji': '🌾', 'sub': 'Clientes con mayor área acumulada'},
      {'id': 'FRECUENCIA', 'label': 'Más Frecuente', 'emoji': '🚁', 'sub': 'Mayor cantidad de servicios realizados'},
      {'id': 'FACTURACION', 'label': 'Mayor Facturación Total', 'emoji': '💰', 'sub': 'Mayor volumen de dinero generado'},
      {'id': 'DEUDA', 'label': 'Mayor Saldo Pendiente', 'emoji': '⚠️', 'sub': 'Priorizar cobranza de cartera'},
      {'id': 'NOMBRE', 'label': 'Orden Alfabético', 'emoji': '🔤', 'sub': 'De la A a la Z por nombre'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sort_rounded, color: primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Ordenar Clientes',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                ...opciones.map((op) {
                  final seleccionada = _criterioOrden == op['id'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: seleccionada ? primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(op['emoji']!, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(
                      op['label']!,
                      style: TextStyle(
                        fontWeight: seleccionada ? FontWeight.bold : FontWeight.w500,
                        color: seleccionada ? primary : onSurface,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      op['sub']!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    trailing: seleccionada
                        ? Icon(Icons.check_circle_rounded, color: primary, size: 22)
                        : null,
                    onTap: () {
                      setState(() => _criterioOrden = op['id']!);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
