import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/servicio_model.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../models/app_version_model.dart';
import 'bitacoras_historial_screen.dart';
import 'bitacora_danos_screen.dart';

class HerramientasScreen extends StatefulWidget {
  const HerramientasScreen({super.key});

  @override
  State<HerramientasScreen> createState() => _HerramientasScreenState();
}

class _HerramientasScreenState extends State<HerramientasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramientas de Campo'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Daños en Equipos',
            icon: const Icon(Icons.car_crash_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BitacoraDanosScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Historial de Bitácoras',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BitacorasHistorialScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Probar Notificación Real',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              await NotificationService.instance.enviarNotificacionPrueba();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 Notificación de prueba enviada a tu dispositivo.'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3.5,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'Calculadora'),
            Tab(icon: Icon(Icons.battery_charging_full), text: 'Baterías'),
            Tab(icon: Icon(Icons.share), text: 'Reporte WA'),
            Tab(icon: Icon(Icons.system_update_rounded), text: 'Actualizaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CalculadoraCaldoTab(),
          BateriasTab(),
          ReportesWhatsAppTab(),
          ActualizacionesTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: CALCULADORA DE CALDO Y VUELOS DE FUMIGACIÓN
// ---------------------------------------------------------------------------
class CalculadoraCaldoTab extends StatefulWidget {
  const CalculadoraCaldoTab({super.key});

  @override
  State<CalculadoraCaldoTab> createState() => _CalculadoraCaldoTabState();
}

class _CalculadoraCaldoTabState extends State<CalculadoraCaldoTab> {
  final _formKey = GlobalKey<FormState>();

  double _hectareas = 10.0;
  double _tasaAplicacion = 15.0; // Litros por Ha
  double _capacidadTanque = 40.0; // Litros por tanque de dron
  double _dosisQuimicoPorHa = 1.0; // Litros o Kg por Ha
  String _unidadDosis = 'Litros'; // 'Litros', 'Mililitros', 'Kilos', 'Gramos'

  String _modeloDronSeleccionado = 'DJI Agras T40 (40L)';

  final Map<String, double> _presetsDrones = {
    'DJI Agras T50 (40L)': 40.0,
    'DJI Agras T40 (40L)': 40.0,
    'DJI Agras T30 (30L)': 30.0,
    'DJI Agras T25 (20L)': 20.0,
    'DJI Agras T20P (20L)': 20.0,
    'DJI Agras T10 (10L)': 10.0,
    'Personalizado': 0.0,
  };

  void _recalcular() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Cálculos matemáticos de precisión agrícola
    final volumenTotalCaldo = _hectareas * _tasaAplicacion; // Litros totales de mezcla
    final haPorTanque = _tasaAplicacion > 0 ? _capacidadTanque / _tasaAplicacion : 0.0;
    final totalTanques = _capacidadTanque > 0 ? volumenTotalCaldo / _capacidadTanque : 0.0;
    final vuelosRequeridos = totalTanques.ceil();

    final cantidadTotalQuimico = _hectareas * _dosisQuimicoPorHa;
    final quimicoPorTanque = totalTanques > 0 ? cantidadTotalQuimico / totalTanques : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner informativo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Calcula el volumen de mezcla y tanques necesarios para evitar sobras o faltantes en el lote.',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selector de Dron
          DropdownButtonFormField<String>(
            initialValue: _modeloDronSeleccionado,
            decoration: const InputDecoration(
              labelText: 'Modelo de Dron de Fumigación',
              prefixIcon: Icon(Icons.flight),
              border: OutlineInputBorder(),
            ),
            items: _presetsDrones.keys.map((modelo) {
              return DropdownMenuItem(value: modelo, child: Text(modelo));
            }).toList(),
            onChanged: (modelo) {
              if (modelo != null) {
                setState(() {
                  _modeloDronSeleccionado = modelo;
                  if (modelo != 'Personalizado') {
                    _capacidadTanque = _presetsDrones[modelo]!;
                  }
                });
              }
            },
          ),

          const SizedBox(height: 14),

          // Inputs de hectáreas y tasa de aplicación
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _hectareas.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Hectáreas del lote (Ha)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.crop_square),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final v = double.tryParse(val);
                          if (v != null && v > 0) {
                            _hectareas = v;
                            _recalcular();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _tasaAplicacion.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Tasa (Litros/Ha)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.water_drop),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final v = double.tryParse(val);
                          if (v != null && v > 0) {
                            _tasaAplicacion = v;
                            _recalcular();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    if (_modeloDronSeleccionado == 'Personalizado') ...[
                      Expanded(
                        child: TextFormField(
                          initialValue: _capacidadTanque.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Capacidad Tanque (L)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final v = double.tryParse(val);
                            if (v != null && v > 0) {
                              _capacidadTanque = v;
                              _recalcular();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: _dosisQuimicoPorHa.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Dosis Producto / Ha',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.science),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final v = double.tryParse(val);
                          if (v != null) {
                            _dosisQuimicoPorHa = v;
                            _recalcular();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _unidadDosis,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Litros', 'ml', 'Kg', 'gr']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (u) {
                          if (u != null) {
                            setState(() => _unidadDosis = u);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // RESULTADOS EN TARJETA DESTACADA
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Plan de Vuelo y Mezcla',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$vuelosRequeridos Vuelos',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  _buildResultadoFila(
                    icon: Icons.water_drop,
                    titulo: 'Volumen total de caldo a preparar:',
                    valor: '${volumenTotalCaldo.toStringAsFixed(1)} Litros',
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 10),

                  _buildResultadoFila(
                    icon: Icons.local_gas_station,
                    titulo: 'Tanques completos de dron:',
                    valor: '${totalTanques.toStringAsFixed(1)} tanques (~$vuelosRequeridos vuelos)',
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 10),

                  _buildResultadoFila(
                    icon: Icons.speed,
                    titulo: 'Cobertura por cada tanque:',
                    valor: '${haPorTanque.toStringAsFixed(2)} Ha / tanque',
                    color: Colors.teal.shade800,
                  ),
                  const SizedBox(height: 10),

                  _buildResultadoFila(
                    icon: Icons.science,
                    titulo: 'Producto químico total para el lote:',
                    valor: '${cantidadTotalQuimico.toStringAsFixed(2)} $_unidadDosis',
                    color: Colors.purple.shade700,
                  ),
                  const SizedBox(height: 10),

                  _buildResultadoFila(
                    icon: Icons.opacity,
                    titulo: 'Dosis a verter por tanque de dron:',
                    valor: '${quimicoPorTanque.toStringAsFixed(2)} $_unidadDosis / tanque',
                    color: Colors.green.shade800,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoFila({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 2),
              Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: CONTROL Y VIDA ÚTIL DE BATERÍAS LIPO / LFP
// ---------------------------------------------------------------------------
class BateriasTab extends StatelessWidget {
  const BateriasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('baterias').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.battery_alert, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No hay baterías registradas.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Agrega las baterías de tus drones para vigilar sus ciclos.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final codigo = data['codigo'] ?? 'Batería';
              final modelo = data['modelo'] ?? 'BAX601';
              final ciclos = (data['ciclos'] ?? 0) as int;
              final ciclosMaximos = (data['ciclosMaximos'] ?? 1000) as int;
              final porcentajeVida = ((ciclosMaximos - ciclos) / ciclosMaximos).clamp(0.0, 1.0);

              Color estadoColor = Colors.green;
              if (porcentajeVida < 0.3) {
                estadoColor = Colors.red;
              } else if (porcentajeVida < 0.6) {
                estadoColor = Colors.orange;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: estadoColor.withValues(alpha: 0.15),
                                child: Icon(Icons.battery_charging_full, color: estadoColor),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Modelo: $modelo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Botón sumar 1 ciclo
                              IconButton(
                                tooltip: '+1 Vuelo / Carga',
                                icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32)),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('baterias')
                                      .doc(doc.id)
                                      .update({'ciclos': ciclos + 1});
                                },
                              ),
                              // Eliminar batería
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () {
                                  FirebaseFirestore.instance.collection('baterias').doc(doc.id).delete();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ciclos: $ciclos / $ciclosMaximos', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${(porcentajeVida * 100).toStringAsFixed(0)}% vida útil', style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: porcentajeVida,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(estadoColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        onPressed: () => _mostrarDialogoNuevaBateria(context),
        icon: const Icon(Icons.battery_saver),
        label: const Text('Añadir Batería'),
      ),
    );
  }

  static void _mostrarDialogoNuevaBateria(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String codigo = '';
    String modelo = 'BAX601 (T40/T50)';
    int ciclos = 0;
    int ciclosMaximos = 1000;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Batería'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Identificador / Código (ej. Bat 01)'),
                  validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                  onSaved: (v) => codigo = v!,
                ),
                TextFormField(
                  initialValue: modelo,
                  decoration: const InputDecoration(labelText: 'Modelo de Batería'),
                  onSaved: (v) => modelo = v ?? '',
                ),
                TextFormField(
                  initialValue: '0',
                  decoration: const InputDecoration(labelText: 'Ciclos actuales'),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => ciclos = int.tryParse(v ?? '0') ?? 0,
                ),
                TextFormField(
                  initialValue: '1000',
                  decoration: const InputDecoration(labelText: 'Ciclos máximos recomendados'),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => ciclosMaximos = int.tryParse(v ?? '1000') ?? 1000,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                await FirebaseFirestore.instance.collection('baterias').add({
                  'codigo': codigo,
                  'modelo': modelo,
                  'ciclos': ciclos,
                  'ciclosMaximos': ciclosMaximos,
                  'fechaRegistro': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3: GENERADOR DE REPORTES PARA WHATSAPP
// ---------------------------------------------------------------------------
class ReportesWhatsAppTab extends StatelessWidget {
  const ReportesWhatsAppTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay servicios registrados para generar reporte.'),
            );
          }

          final servicios = snapshot.data!.docs.map((doc) {
            return ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          servicios.sort((a, b) => b.fecha.compareTo(a.fecha));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: servicios.length,
            itemBuilder: (context, index) {
              final servicio = servicios[index];
              final fechaTexto = DateFormat('dd/MM/yyyy - hh:mm a').format(servicio.fecha);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              servicio.clienteNombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Text(
                            currency.format(servicio.precioTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${servicio.fincaUbicacion} • ${servicio.cultivo} (${servicio.hectareas} Ha)',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estado: ${servicio.estado}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366), // Color oficial WhatsApp
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copiar Reporte WhatsApp', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              final mensaje = _generarTextoReporte(servicio, fechaTexto, currency);
                              Clipboard.setData(ClipboardData(text: mensaje));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF2E7D32),
                                  content: Text('¡Reporte copiado! Listo para pegar en el chat de WhatsApp del cliente.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _generarTextoReporte(
    ServicioModel s,
    String fechaTexto,
    NumberFormat currency,
  ) {
    return '''
🚁 *REPORTE DE FUMIGACIÓN CON DRON AGRÍCOLA* 🚁
*ICARO PROAGRO*

Estimado(a) *${s.clienteNombre}*, le compartimos el resumen de la aplicación aérea realizada:

📅 *Fecha:* $fechaTexto
📍 *Finca / Ubicación:* ${s.fincaUbicacion}
🌱 *Cultivo:* ${s.cultivo}
🌾 *Área fumigada:* ${s.hectareas.toStringAsFixed(1)} Hectáreas
🧪 *Tipo de aplicación:* ${s.tipoAplicacion}
${s.productoQuimico.isNotEmpty ? "📦 *Producto aplicado:* ${s.productoQuimico}\n" : ""}💵 *Precio por Ha:* ${currency.format(s.precioPorHectarea)}
💰 *VALOR TOTAL:* ${currency.format(s.precioTotal)}
📌 *Estado del servicio:* ${s.estado}
${s.notas.isNotEmpty ? "\n📝 *Observaciones:* ${s.notas}\n" : ""}
¡Gracias por confiar en nosotros para la protección de sus cultivos! 🌾
''';
  }
}

class ActualizacionesTab extends StatefulWidget {
  const ActualizacionesTab({super.key});

  @override
  State<ActualizacionesTab> createState() => _ActualizacionesTabState();
}

class _ActualizacionesTabState extends State<ActualizacionesTab> {
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    UpdateService.cargarInfoLocal().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _buscarActualizacionesManual() async {
    setState(() => _buscando = true);
    try {
      final nuevaVersion = await UpdateService.verificarSiHayActualizacion();
      if (!mounted) return;
      setState(() => _buscando = false);

      if (nuevaVersion != null) {
        UpdateDialog.mostrar(context, nuevaVersion);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(
              '✅ ¡Tienes la última versión instalada (${UpdateService.versionCompletaLocal})!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _buscando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al buscar actualizaciones: $e'),
          ),
        );
      }
    }
  }

  void _mostrarDialogoConfigurarVersion(BuildContext context, AppVersionModel? actual) {
    final versionCtrl = TextEditingController(text: actual?.version ?? '1.0.1');
    final buildCtrl = TextEditingController(text: (actual != null ? actual.buildNumber + 1 : 2).toString());
    final urlCtrl = TextEditingController(text: actual?.apkUrl ?? '');
    final novedadesCtrl = TextEditingController(
      text: actual?.novedades ?? '• Nueva categoría "Casa" en egresos\n• Mejoras en estabilidad y velocidad\n• Sistema de actualización automática integrado',
    );
    bool obligatoria = actual?.obligatoria ?? false;
    bool habilitada = actual?.habilitada ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Publicar Actualización', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configura la versión remota en la nube. Los dispositivos de los pilotos y usuarios detectarán esta versión automáticamente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: versionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Versión (ej: 1.0.1)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: buildCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Build (ej: 2)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Enlace Directo del APK',
                    hintText: 'https://ejemplo.com/app-release.apk',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: novedadesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Novedades / Notas de versión',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Actualización obligatoria?', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Bloquea el uso de la app hasta que actualicen', style: TextStyle(fontSize: 11)),
                  value: obligatoria,
                  onChanged: (v) => setDlgState(() => obligatoria = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Alerta activa?', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Muestra el diálogo de actualización a los usuarios', style: TextStyle(fontSize: 11)),
                  value: habilitada,
                  onChanged: (v) => setDlgState(() => habilitada = v),
                ),
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
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: const Text('Publicar en la Nube'),
              onPressed: () async {
                final ver = versionCtrl.text.trim();
                final bld = int.tryParse(buildCtrl.text.trim()) ?? 1;
                final url = urlCtrl.text.trim();
                final nov = novedadesCtrl.text.trim();

                final nuevo = AppVersionModel(
                  version: ver.isNotEmpty ? ver : '1.0.0',
                  buildNumber: bld,
                  apkUrl: url,
                  novedades: nov,
                  obligatoria: obligatoria,
                  habilitada: habilitada,
                  fecha: DateTime.now(),
                );

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await UpdateService.guardarNuevaVersionRemota(nuevo);
                if (ctx.mounted) Navigator.pop(ctx);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF2E7D32),
                    content: Text('✅ Información de actualización guardada con éxito en Firebase.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BANNER PRINCIPAL
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    themeColor,
                    themeColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Actualizaciones Icaro Proagro',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistema inteligente de actualización automática directa (In-App OTA)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // TARJETA DE VERSIÓN INSTALADA LOCAL
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.smartphone_rounded, color: themeColor),
                          SizedBox(width: 8),
                          Text('Versión en este Dispositivo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          UpdateService.versionCompletaLocal,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Esta es la versión del software actualmente instalada en tu teléfono. Pulsa el botón de abajo para verificar si hay una versión más reciente con nuevas funciones.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _buscando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _buscando ? 'Buscando actualizaciones...' : 'Buscar Actualizaciones Ahora',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _buscando ? null : _buscarActualizacionesManual,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // STREAM DE LA VERSIÓN EN LA NUBE (FIRESTORE)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('app_config').doc('actualizacion').snapshots(),
            builder: (context, snapshot) {
              AppVersionModel? remota;
              if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
                remota = AppVersionModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
              }

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_done_outlined, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('Última Versión en la Nube', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (remota != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (remota.habilitada ? Colors.blueAccent : Colors.grey).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                remota.habilitada ? 'Activa' : 'Inactiva',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: remota.habilitada ? Colors.blueAccent : Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (remota != null) ...[
                        Row(
                          children: [
                            const Text('Versión disponible: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('v${remota.version}+${remota.buildNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Enlace APK: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                remota.apkUrl.isNotEmpty ? remota.apkUrl : 'No configurado aún',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            remota.novedades.isNotEmpty ? remota.novedades : 'Sin notas registradas.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Aún no hay una versión configurada en Firebase. Toca "Configurar Versión" para inicializarla.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_note, size: 18, color: Colors.blueAccent),
                        label: const Text('Configurar / Publicar Nueva Versión', style: TextStyle(color: Colors.blueAccent)),
                        onPressed: () => _mostrarDialogoConfigurarVersion(context, remota),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

