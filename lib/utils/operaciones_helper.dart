import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../models/servicio_model.dart';
import '../services/pdf_service.dart';
import '../theme/agro_theme.dart';

class CalculoInsumosBaterias {
  final double hectareas;
  final String dronModelo;
  final double litrosPorHectarea;
  final double dosisQuimicoPorHectarea;

  CalculoInsumosBaterias({
    required this.hectareas,
    this.dronModelo = 'DJI Agras T40',
    this.litrosPorHectarea = 15.0, // Promedio agrícola estándar con drones
    this.dosisQuimicoPorHectarea = 1.0,
  });

  /// Capacidad en litros del tanque del dron
  int get capacidadTanqueLitros {
    final d = dronModelo.toUpperCase();
    if (d.contains('T50')) return 50;
    if (d.contains('T40')) return 40;
    if (d.contains('T30')) return 30;
    if (d.contains('T25') || d.contains('T20')) return 20;
    if (d.contains('T10')) return 10;
    if (d.contains('P100')) return 40;
    return 40; // Default estándar
  }

  /// Total de litros de mezcla de caldo a preparar
  double get totalLitrosCaldo => hectareas * litrosPorHectarea;

  /// Número de tanques / despegues de fumigación
  int get tanquesEstimados {
    if (capacidadTanqueLitros <= 0) return 1;
    return (totalLitrosCaldo / capacidadTanqueLitros).ceil();
  }

  /// Total producto químico comercial concentrado (L o Kg)
  double get totalProductoQuimico => hectareas * dosisQuimicoPorHectarea;

  /// Estimado de ciclos de batería (promedio 1.8 Ha por batería con pulverización)
  int get ciclosBateriaEstimados {
    if (hectareas <= 0) return 0;
    final c = (hectareas / 1.8).ceil();
    return c < 1 ? 1 : c;
  }

  /// Recomendación de baterías físicas a llevar a campo
  String get recomendacionLogistica {
    final c = ciclosBateriaEstimados;
    if (c <= 2) {
      return 'Llevar mínimo 2 baterías cargadas al 100%.';
    } else if (c <= 5) {
      return 'Llevar 3 baterías y planta eléctrica/cargador rápido para rotación continua.';
    } else {
      return 'Operación grande ($c vuelos de batería). Se requiere generador de carga rápida en campo.';
    }
  }

  /// Muestra el modal interactivo de cálculo de insumos y baterías
  static void mostrarDialogoCalculadora(BuildContext context, ServicioModel servicio) {
    showDialog(
      context: context,
      builder: (ctx) => CalculadoraInsumosModal(servicio: servicio),
    );
  }
}

class CalculadoraInsumosModal extends StatefulWidget {
  final ServicioModel servicio;

  const CalculadoraInsumosModal({super.key, required this.servicio});

  @override
  State<CalculadoraInsumosModal> createState() => _CalculadoraInsumosModalState();
}

class _CalculadoraInsumosModalState extends State<CalculadoraInsumosModal> {
  late String _dronSeleccionado;
  double _litrosPorHa = 15.0;
  double _dosisQuimicoPorHa = 1.0;

  final List<String> _dronesDisponibles = [
    'DJI Agras T50',
    'DJI Agras T40',
    'DJI Agras T30',
    'DJI Agras T25',
    'DJI Agras T10',
    'XAG P100 Pro',
  ];

  @override
  void initState() {
    super.initState();
    _dronSeleccionado = widget.servicio.dron.isNotEmpty ? widget.servicio.dron : 'DJI Agras T40';
    if (!_dronesDisponibles.contains(_dronSeleccionado)) {
      _dronesDisponibles.insert(0, _dronSeleccionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AgroTheme.getPrimary(context);
    final cardBg = AgroTheme.getCard(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final border = AgroTheme.getBorder(context);

    final calc = CalculoInsumosBaterias(
      hectareas: widget.servicio.hectareas,
      dronModelo: _dronSeleccionado,
      litrosPorHectarea: _litrosPorHa,
      dosisQuimicoPorHectarea: _dosisQuimicoPorHa,
    );

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calculate, color: primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculadora de Vuelo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
                ),
                Text(
                  '${widget.servicio.clienteNombre} • ${widget.servicio.hectareas} Ha',
                  style: TextStyle(fontSize: 11, color: subtext),
                ),
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
            // Selección de aeronave
            Text('Aeronave / Dron:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _dronSeleccionado,
                  dropdownColor: cardBg,
                  items: _dronesDisponibles.map((d) {
                    return DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: text, fontSize: 13)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _dronSeleccionado = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Parámetros de aplicación
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tasa Caldo (L/Ha):', style: TextStyle(fontSize: 11, color: subtext)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: _litrosPorHa.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 13, color: text),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() => _litrosPorHa = parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dosis Químico (L/Ha):', style: TextStyle(fontSize: 11, color: subtext)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: _dosisQuimicoPorHa.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 13, color: text),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() => _dosisQuimicoPorHa = parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Tarjetas de Resultados Clave
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Tanques Vuelo',
                    value: '${calc.tanquesEstimados}',
                    subtitle: 'Tanque de ${calc.capacidadTanqueLitros} L',
                    icon: Icons.local_gas_station,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Mezcla Total',
                    value: '${calc.totalLitrosCaldo.toStringAsFixed(1)} L',
                    subtitle: 'Agua + Producto',
                    icon: Icons.water_drop,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Insumo Puro',
                    value: '${calc.totalProductoQuimico.toStringAsFixed(1)} L',
                    subtitle: widget.servicio.productoQuimico.isNotEmpty
                        ? widget.servicio.productoQuimico
                        : 'Producto concentrado',
                    icon: Icons.science,
                    color: Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Baterías (Ciclos)',
                    value: '${calc.ciclosBateriaEstimados}',
                    subtitle: '~1.8 Ha por vuelo',
                    icon: Icons.battery_charging_full,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Logística Recomendada
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logística de Baterías:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          calc.recomendacionLogistica,
                          style: TextStyle(fontSize: 11, color: text),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Enviar por WhatsApp'),
          onPressed: () {
            Navigator.pop(context);
            WhatsAppService.compartirPlanLogisticoWhatsApp(
              context: context,
              servicio: widget.servicio,
              calculo: calc,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final border = AgroTheme.getBorder(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtext),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: subtext),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class WhatsAppService {
  static final _currencyFormat =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  /// Abre WhatsApp con el resumen formateado del servicio
  static Future<bool> enviarResumenWhatsApp(ServicioModel servicio, [BuildContext? context]) {
    return _compartirWhatsApp(servicio: servicio, context: context);
  }

  static Future<bool> compartirResumenWhatsApp({
    BuildContext? context,
    required ServicioModel servicio,
  }) {
    return _compartirWhatsApp(servicio: servicio, context: context);
  }

  static Future<bool> _compartirWhatsApp({
    required ServicioModel servicio,
    BuildContext? context,
  }) async {
    final fechaStr = DateFormat('dd/MM/yyyy • hh:mm a', 'es').format(servicio.fecha);
    final String estadoPago =
        servicio.pagado ? '✅ PAGADO (${servicio.metodoPago})' : '⏳ PENDIENTE DE PAGO';

    String telefonoLimpio = servicio.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (telefonoLimpio.startsWith('57') && telefonoLimpio.length > 10) {
      // Ya tiene código de país
    } else if (telefonoLimpio.length == 10 && telefonoLimpio.startsWith('3')) {
      telefonoLimpio = '57$telefonoLimpio';
    }

    final buffer = StringBuffer();
    buffer.writeln('🚁 *ICARO PROAGRO - REPORTE DE SERVICIO AGRÍCOLA*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Cliente:* ${servicio.clienteNombre}');
    buffer.writeln('📍 *Ubicación / Finca:* ${servicio.fincaUbicacion}');
    buffer.writeln('📅 *Fecha:* $fechaStr');
    buffer.writeln('🌱 *Cultivo:* ${servicio.cultivo}');
    buffer.writeln('💧 *Labor:* ${servicio.tipoAplicacion}');
    if (servicio.productoQuimico.isNotEmpty) {
      buffer.writeln('🧪 *Insumo / Producto:* ${servicio.productoQuimico}');
    }
    buffer.writeln('📐 *Área Fumigada:* ${servicio.hectareas} Ha');
    if (servicio.piloto.isNotEmpty) {
      buffer.writeln('👨‍✈️ *Piloto a Cargo:* ${servicio.piloto}');
    }
    if (servicio.dron.isNotEmpty) {
      buffer.writeln('🛸 *Aeronave:* ${servicio.dron}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *Valor Total:* ${_currencyFormat.format(servicio.precioTotal)}');
    buffer.writeln('📋 *Estado:* $estadoPago');
    if (servicio.notas.isNotEmpty) {
      buffer.writeln('📝 *Observaciones:* ${servicio.notas}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_Generado con Icaro Proagro - Tecnología Aérea Agrícola_');

    final String encodedText = Uri.encodeComponent(buffer.toString());
    final Uri url = Uri.parse(
      telefonoLimpio.isNotEmpty
          ? 'https://wa.me/$telefonoLimpio?text=$encodedText'
          : 'https://wa.me/?text=$encodedText',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error lanzando WhatsApp: $e');
      return false;
    }
  }

  /// Comparte el plan logístico de insumos y baterías por WhatsApp
  static Future<bool> compartirPlanLogisticoWhatsApp({
    required BuildContext context,
    required ServicioModel servicio,
    required CalculoInsumosBaterias calculo,
  }) async {
    final fechaStr = DateFormat('dd/MM/yyyy • hh:mm a', 'es').format(servicio.fecha);

    String telefonoLimpio = servicio.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (telefonoLimpio.startsWith('57') && telefonoLimpio.length > 10) {
      // Ya tiene código
    } else if (telefonoLimpio.length == 10 && telefonoLimpio.startsWith('3')) {
      telefonoLimpio = '57$telefonoLimpio';
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 *ICARO PROAGRO - PLAN LOGÍSTICO Y MEZCLA DE VUELO*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Cliente:* ${servicio.clienteNombre}');
    buffer.writeln('📍 *Finca:* ${servicio.fincaUbicacion}');
    buffer.writeln('📅 *Fecha:* $fechaStr');
    buffer.writeln('🛸 *Dron:* ${calculo.dronModelo}');
    buffer.writeln('📐 *Área:* ${calculo.hectareas} Ha');
    buffer.writeln('🌱 *Cultivo:* ${servicio.cultivo}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🛢️ *Tanques a Preparar:* ${calculo.tanquesEstimados} despegues (${calculo.capacidadTanqueLitros}L/tanque)');
    buffer.writeln('💧 *Caldo Total Mezcla:* ${calculo.totalLitrosCaldo.toStringAsFixed(1)} Litros');
    buffer.writeln('🧪 *Insumo Concentrado:* ${calculo.totalProductoQuimico.toStringAsFixed(1)} L/Kg (${servicio.productoQuimico})');
    buffer.writeln('🔋 *Vuelos Batería:* ~${calculo.ciclosBateriaEstimados} ciclos');
    buffer.writeln('⚡ *Recomendación:* ${calculo.recomendacionLogistica}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_Plan de vuelo optimizado por Icaro Proagro_');

    final String encodedText = Uri.encodeComponent(buffer.toString());
    final Uri url = Uri.parse(
      telefonoLimpio.isNotEmpty
          ? 'https://wa.me/$telefonoLimpio?text=$encodedText'
          : 'https://wa.me/?text=$encodedText',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error lanzando WhatsApp: $e');
      return false;
    }
  }

  /// Comparte el archivo PDF formal mediante WhatsApp u otras apps instaladas
  static Future<void> compartirPdf(ServicioModel servicio) async {
    final pdfBytes = await PdfService.generarOrdenServicio(servicio);
    final nombreArchivo =
        'Reporte_Icaro_Proagro_${servicio.clienteNombre.replaceAll(" ", "_")}_${DateFormat("ddMMyyyy").format(servicio.fecha)}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: nombreArchivo);
  }
}

/// Widget discreto para mostrar si la app está en modo online u offline
class IndicadorModoOffline extends StatelessWidget {
  const IndicadorModoOffline({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isDark ? Colors.green.shade900 : Colors.green.shade100).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Modo Campo Offline 📡',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
