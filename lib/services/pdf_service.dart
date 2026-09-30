import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaccion_model.dart';
import '../models/servicio_model.dart';
import '../models/bitacora_dano_equipo_model.dart';

class PdfService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static Future<void> generarYCompartirBalance({
    required String periodoTitulo,
    List<TransaccionModel> transacciones = const [],
    List<ServicioModel> servicios = const [],
    double? totalIngresos,
    double? totalEgresos,
    double? utilidadNeta,
    double? totalPorCobrar,
    double? totalHectareas,
    int? totalVuelos,
    Map<String, double>? egresosPorCategoria,
    Map<String, double>? ingresosPorCuenta,
  }) async {
    final pdf = pw.Document();

    // Cálculos financieros
    final Map<String, double> ingresosPorCuentaMap = Map.from(ingresosPorCuenta ?? {});
    final Map<String, double> egresosPorCat = Map.from(egresosPorCategoria ?? {});
    final Map<String, int> egresosConteoPorCat = {};

    double calcIngresos = totalIngresos ?? 0;
    double calcIngresosEfectivo = 0;
    double calcIngresosLinea = 0;

    double calcEgresos = totalEgresos ?? 0;
    int countEgresosTotal = 0;

    if (transacciones.isNotEmpty) {
      calcIngresos = 0;
      calcEgresos = 0;
      for (var t in transacciones) {
        if (t.tipo == 'INGRESO') {
          calcIngresos += t.monto;
          ingresosPorCuentaMap[t.metodoPago] = (ingresosPorCuentaMap[t.metodoPago] ?? 0) + t.monto;
          if (t.esEfectivo) {
            calcIngresosEfectivo += t.monto;
          } else {
            calcIngresosLinea += t.monto;
          }
        } else if (t.tipo == 'EGRESO') {
          calcEgresos += t.monto;
          countEgresosTotal++;
          egresosPorCat[t.categoria] = (egresosPorCat[t.categoria] ?? 0) + t.monto;
          egresosConteoPorCat[t.categoria] = (egresosConteoPorCat[t.categoria] ?? 0) + 1;
        }
      }
    } else {
      calcIngresosEfectivo = ingresosPorCuentaMap['EFECTIVO'] ?? 0;
      calcIngresosLinea = calcIngresos - calcIngresosEfectivo;
    }

    double calcPorCobrar = totalPorCobrar ?? 0;
    double calcHectareas = totalHectareas ?? 0;
    final List<ServicioModel> serviciosPendientes = [];

    if (servicios.isNotEmpty) {
      calcPorCobrar = 0;
      calcHectareas = 0;
      for (var s in servicios) {
        calcHectareas += s.hectareas;
        if (!s.pagado && s.estado != 'CANCELADO') {
          calcPorCobrar += s.saldoPendiente;
          serviciosPendientes.add(s);
        }
      }
    }

    final double calcUtilidad = utilidadNeta ?? (calcIngresos - calcEgresos);
    final int calcTotalVuelos = totalVuelos ?? servicios.length;
    final now = DateTime.now();

    // Cargar fuentes
    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();

    // Colores PDF
    const verdePrimario = PdfColor.fromInt(0xFF059669);
    const verdeOscuro = PdfColor.fromInt(0xFF02371E);
    const grisFondo = PdfColor.fromInt(0xFFF1F5F2);
    const grisBorde = PdfColor.fromInt(0xFFCBD5E1);
    const textoOscuro = PdfColor.fromInt(0xFF0F172A);
    const textoSecundario = PdfColor.fromInt(0xFF475569);
    const rojoError = PdfColor.fromInt(0xFFDC2626);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ICARO PROAGRO', style: pw.TextStyle(font: fontBold, fontSize: 24, color: verdePrimario)),
                    pw.Text('Tecnología Aérea y Fumigación con Drones', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: textoSecundario)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: grisFondo,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: grisBorde),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('BALANCE CONTABLE', style: pw.TextStyle(font: fontBold, fontSize: 11, color: verdeOscuro)),
                      pw.Text('Emisión: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: verdePrimario),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // SUBTÍTULO DE PERÍODO
          pw.Text('Período: $periodoTitulo', style: pw.TextStyle(font: fontBold, fontSize: 14, color: textoOscuro)),
          pw.SizedBox(height: 12),

          // TARJETAS DE RESUMEN EJECUTIVO
          pw.Row(
            children: [
              _buildKpiCard('INGRESOS TOTALES', _currencyFormat.format(calcIngresos), verdePrimario, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('GASTOS TOTALES', _currencyFormat.format(calcEgresos), rojoError, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('UTILIDAD NETA', _currencyFormat.format(calcUtilidad), calcUtilidad >= 0 ? verdePrimario : rojoError, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('POR COBRAR', _currencyFormat.format(calcPorCobrar), const PdfColor.fromInt(0xFFD97706), fontBold, fontRegular),
            ],
          ),

          pw.SizedBox(height: 14),

          // MÉTRICAS OPERATIVAS
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: grisFondo,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: grisBorde),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('🌾 Hectáreas: ${calcHectareas.toStringAsFixed(1)} Ha', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: textoOscuro)),
                pw.Text('🚁 Vuelos Totales: $calcTotalVuelos', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: textoOscuro)),
                pw.Text('💵 En Efectivo: ${_currencyFormat.format(calcIngresosEfectivo)}', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: textoOscuro)),
                pw.Text('💳 En Línea: ${_currencyFormat.format(calcIngresosLinea)}', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: textoOscuro)),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // RESUMEN DETALLADO DE INGRESOS
          pw.Text('1. Resumen y Totales de Ingresos', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: grisBorde, width: 0.5),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: verdePrimario),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Tipo / Método de Ingreso', 'Monto Total', '% del Total Ingresos'],
            data: [
              [
                'Ingresos en Efectivo (Caja General)',
                _currencyFormat.format(calcIngresosEfectivo),
                calcIngresos > 0 ? '${(calcIngresosEfectivo / calcIngresos * 100).toStringAsFixed(1)}%' : '0.0%',
              ],
              [
                'Ingresos en Línea / Cuentas Bancarias',
                _currencyFormat.format(calcIngresosLinea),
                calcIngresos > 0 ? '${(calcIngresosLinea / calcIngresos * 100).toStringAsFixed(1)}%' : '0.0%',
              ],
              [
                'TOTAL GENERAL DE INGRESOS',
                _currencyFormat.format(calcIngresos),
                '100.0%',
              ],
            ],
          ),

          if (ingresosPorCuentaMap.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('2. Totales por Cuentas Bancarias y Canales de Recaudo', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: grisBorde, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0284C7)),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Cuenta / Entidad Financiera', 'Monto Recaudado', '% Participación'],
              data: [
                ...ingresosPorCuentaMap.entries.map((e) {
                  final pct = calcIngresos > 0 ? (e.value / calcIngresos * 100).toStringAsFixed(1) : '0.0';
                  return [
                    TransaccionModel.nombreMetodo(e.key),
                    _currencyFormat.format(e.value),
                    '$pct%',
                  ];
                }),
                [
                  'CARTERA POR COBRAR (Clientes Pendientes)',
                  _currencyFormat.format(calcPorCobrar),
                  'Pendiente',
                ],
              ],
            ),
          ],

          pw.SizedBox(height: 16),

          // DESGLOSE DE GASTOS POR CATEGORÍA
          pw.Text('3. Totales y Desglose de Gastos Operativos por Categoría', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
          pw.SizedBox(height: 6),
          if (egresosPorCat.isEmpty)
            pw.Text('No se registraron egresos en el período seleccionado.', style: pw.TextStyle(fontSize: 9, color: textoSecundario))
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: grisBorde, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: rojoError),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Categoría de Gasto / Egreso', 'N° Gastos', 'Monto Total', '% del Total Egresos'],
              data: [
                ...egresosPorCat.entries.map((e) {
                  final pct = calcEgresos > 0 ? (e.value / calcEgresos * 100).toStringAsFixed(1) : '0.0';
                  final cant = egresosConteoPorCat[e.key] ?? 1;
                  return [
                    e.key,
                    '$cant',
                    _currencyFormat.format(e.value),
                    '$pct%',
                  ];
                }),
                [
                  'TOTAL GENERAL DE EGRESOS',
                  '$countEgresosTotal',
                  _currencyFormat.format(calcEgresos),
                  '100.0%',
                ],
              ],
            ),

          pw.SizedBox(height: 16),

          // CARTERA PENDIENTE POR COBRAR
          pw.Text('4. Cartera Pendiente por Cobrar (Deudores)', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
          pw.SizedBox(height: 6),
          if (serviciosPendientes.isEmpty)
            pw.Text('¡Excelente! No hay cobros pendientes registrados.', style: pw.TextStyle(fontSize: 9, color: verdePrimario, font: fontMedium))
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: grisBorde, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headers: ['Cliente', 'Finca / Ubicación', 'Cultivo', 'Ha', 'Total', 'Abonado', 'Saldo'],
              data: serviciosPendientes.map((s) {
                return [
                  s.clienteNombre,
                  s.fincaUbicacion,
                  s.cultivo,
                  '${s.hectareas} Ha',
                  _currencyFormat.format(s.precioTotal),
                  _currencyFormat.format(s.totalAbonado),
                  _currencyFormat.format(s.saldoPendiente),
                ];
              }).toList(),
            ),

          pw.SizedBox(height: 16),

          // HISTORIAL DE MOVIMIENTOS RECIENTES
          pw.Text('5. Registro Detallado de Transacciones Contables', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
          pw.SizedBox(height: 6),
          if (transacciones.isEmpty)
            pw.Text('Sin transacciones en este período.', style: pw.TextStyle(fontSize: 9, color: textoSecundario))
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: grisBorde, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: verdePrimario),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Fecha', 'Tipo', 'Categoría', 'Descripción', 'Método', 'Monto'],
              data: transacciones.take(35).map((t) {
                return [
                  DateFormat('dd/MM/yyyy').format(t.fecha),
                  t.tipo,
                  t.categoria,
                  t.descripcion,
                  t.metodoPago == 'EN_LINEA' ? 'En Línea' : 'Efectivo',
                  _currencyFormat.format(t.monto),
                ];
              }).toList(),
            ),

          pw.SizedBox(height: 25),

          // FIRMAS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 1, color: grisBorde),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma Piloto / Operador', style: pw.TextStyle(fontSize: 8.5, font: fontRegular, color: textoSecundario)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 1, color: grisBorde),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma Administrador / Contabilidad', style: pw.TextStyle(fontSize: 8.5, font: fontRegular, color: textoSecundario)),
                ],
              ),
            ],
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Icaro Proagro - Documento Oficial de Gestión Agrícola y Financiera', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
          ],
        ),
      ),
    );

    // Lanzar vista previa interactiva e impresión/guardado en PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Balance_Icaro_Proagro_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }

  /// Genera y comparte el Estado de Cuenta / Informe de Deuda Individual por Cliente
  static Future<void> generarYCompartirEstadoCuentaCliente({
    required String clienteNombre,
    required String clienteTelefono,
    required String fincaUbicacion,
    required List<ServicioModel> serviciosCliente,
  }) async {
    final pdf = pw.Document();

    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();

    const verdePrimario = PdfColor.fromInt(0xFF059669);
    const verdeOscuro = PdfColor.fromInt(0xFF02371E);
    const grisFondo = PdfColor.fromInt(0xFFF8FAFC);
    const grisBorde = PdfColor.fromInt(0xFFCBD5E1);
    const textoOscuro = PdfColor.fromInt(0xFF0F172A);
    const textoSecundario = PdfColor.fromInt(0xFF475569);
    const naranjaAlerta = PdfColor.fromInt(0xFFD97706);

    final now = DateTime.now();

    double totalFacturado = 0;
    double totalAbonado = 0;
    double totalSaldoPendiente = 0;
    double totalHectareas = 0;

    for (var s in serviciosCliente) {
      if (s.estado != 'CANCELADO') {
        totalFacturado += s.precioTotal;
        totalAbonado += s.totalAbonado;
        totalSaldoPendiente += s.saldoPendiente;
        totalHectareas += s.hectareas;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ICARO PROAGRO', style: pw.TextStyle(font: fontBold, fontSize: 24, color: verdePrimario)),
                    pw.Text('Tecnología Aérea y Fumigación Agrícola con Drones', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: textoSecundario)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: grisFondo,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: grisBorde),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('ESTADO DE CUENTA', style: pw.TextStyle(font: fontBold, fontSize: 11, color: verdeOscuro)),
                      pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}', style: pw.TextStyle(fontSize: 8.5, color: textoSecundario)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: verdePrimario),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // DATOS DEL CLIENTE
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: grisFondo,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: grisBorde),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLIENTE: $clienteNombre', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
                      pw.SizedBox(height: 4),
                      pw.Text('Finca / Predio: $fincaUbicacion', style: pw.TextStyle(fontSize: 9.5, color: textoSecundario)),
                      pw.Text('Teléfono de Contacto: $clienteTelefono', style: pw.TextStyle(fontSize: 9.5, color: textoSecundario)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Servicios Registrados: ${serviciosCliente.length}', style: pw.TextStyle(font: fontMedium, fontSize: 9.5)),
                    pw.Text('Hectáreas Totales: ${totalHectareas.toStringAsFixed(1)} Ha', style: pw.TextStyle(fontSize: 9.5, color: textoSecundario)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // TARJETAS RESUMEN DE SALDO
          pw.Row(
            children: [
              _buildKpiCard('TOTAL SERVICIOS', _currencyFormat.format(totalFacturado), textoOscuro, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('TOTAL ABONADO', _currencyFormat.format(totalAbonado), verdePrimario, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('SALDO PENDIENTE', _currencyFormat.format(totalSaldoPendiente), totalSaldoPendiente > 0 ? naranjaAlerta : verdePrimario, fontBold, fontRegular),
            ],
          ),

          pw.SizedBox(height: 16),

          // TABLA DETALLADA DE SERVICIOS Y DEUDAS
          pw.Text('DETALLE DE SERVICIOS Y CUENTAS POR COBRAR', style: pw.TextStyle(font: fontBold, fontSize: 11, color: textoOscuro)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: grisBorde, width: 0.5),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: verdePrimario),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Fecha', 'Cultivo', 'Ha', 'Total Facturado', 'Abonado', 'Saldo Deudor', 'Estado'],
            data: serviciosCliente.map((s) {
              final fechaFmt = DateFormat('dd/MM/yyyy').format(s.fecha);
              final estadoCobro = s.pagado
                  ? 'PAGADO'
                  : (s.totalAbonado > 0 ? 'CON ABONO' : 'PENDIENTE');

              return [
                fechaFmt,
                s.cultivo,
                '${s.hectareas} Ha',
                _currencyFormat.format(s.precioTotal),
                _currencyFormat.format(s.totalAbonado),
                _currencyFormat.format(s.saldoPendiente),
                estadoCobro,
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 16),

          // TOTAL CONSOLIDADO
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: grisFondo,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: grisBorde),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Facturado:', style: pw.TextStyle(fontSize: 9.5, color: textoSecundario)),
                        pw.Text(_currencyFormat.format(totalFacturado), style: pw.TextStyle(font: fontMedium, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Recibido (Abonos):', style: pw.TextStyle(fontSize: 9.5, color: verdePrimario)),
                        pw.Text('- ${_currencyFormat.format(totalAbonado)}', style: pw.TextStyle(font: fontMedium, fontSize: 10, color: verdePrimario)),
                      ],
                    ),
                    pw.Divider(color: grisBorde, height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('SALDO TOTAL A PAGAR:', style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: textoOscuro)),
                        pw.Text(
                          _currencyFormat.format(totalSaldoPendiente),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 13,
                            color: totalSaldoPendiente > 0 ? naranjaAlerta : verdePrimario,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 25),

          // FIRMAS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 170, height: 1, color: grisBorde),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma Icaro Proagro (Autorizado)', style: pw.TextStyle(fontSize: 8.5, color: textoSecundario)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 170, height: 1, color: grisBorde),
                  pw.SizedBox(height: 4),
                  pw.Text('Aceptación de Saldo (Cliente)', style: pw.TextStyle(fontSize: 8.5, color: textoSecundario)),
                ],
              ),
            ],
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Icaro Proagro • Tecnología y Servicios Aéreos Agrícolas', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'EstadoCuenta_Icaro_Proagro_${clienteNombre.replaceAll(" ", "_")}.pdf',
    );
  }

  /// Genera y comparte el Reporte General de Cartera Pendiente (Todos los deudores)
  static Future<void> generarYCompartirCarteraGeneral({
    required List<ServicioModel> serviciosPendientes,
  }) async {
    final pdf = pw.Document();

    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();

    const verdePrimario = PdfColor.fromInt(0xFF059669);
    const grisFondo = PdfColor.fromInt(0xFFF8FAFC);
    const grisBorde = PdfColor.fromInt(0xFFCBD5E1);
    const textoOscuro = PdfColor.fromInt(0xFF0F172A);
    const textoSecundario = PdfColor.fromInt(0xFF475569);
    const naranjaAlerta = PdfColor.fromInt(0xFFD97706);

    final now = DateTime.now();
    double totalDeudaGlobal = 0;
    double totalFacturadoGlobal = 0;
    double totalHectareas = 0;

    for (var s in serviciosPendientes) {
      totalDeudaGlobal += s.saldoPendiente;
      totalFacturadoGlobal += s.precioTotal;
      totalHectareas += s.hectareas;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ICARO PROAGRO', style: pw.TextStyle(font: fontBold, fontSize: 24, color: verdePrimario)),
                    pw.Text('Tecnología Aérea y Control de Cartera', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: textoSecundario)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: grisFondo,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: grisBorde),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INFORME DE CARTERA', style: pw.TextStyle(font: fontBold, fontSize: 11, color: naranjaAlerta)),
                      pw.Text('Emisión: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}', style: pw.TextStyle(fontSize: 8.5, color: textoSecundario)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: naranjaAlerta),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          // RESUMEN GENERAL DE DEUDORES
          pw.Row(
            children: [
              _buildKpiCard('TOTAL EN MORA', _currencyFormat.format(totalDeudaGlobal), naranjaAlerta, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('CLIENTES CON SALDO', '${serviciosPendientes.length}', verdePrimario, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('HA PENDIENTES', '${totalHectareas.toStringAsFixed(1)} Ha', verdePrimario, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _buildKpiCard('TOTAL FACTURADO', _currencyFormat.format(totalFacturadoGlobal), textoOscuro, fontBold, fontRegular),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('Listado Detallado de Saldos Pendientes', style: pw.TextStyle(font: fontBold, fontSize: 12, color: textoOscuro)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: grisBorde, width: 0.5),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: naranjaAlerta),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: ['Cliente', 'Teléfono', 'Ubicación / Finca', 'Cultivo', 'Facturado', 'Abonado', 'Saldo'],
            data: serviciosPendientes.map((s) {
              return [
                s.clienteNombre,
                s.clienteTelefono,
                s.fincaUbicacion,
                s.cultivo,
                _currencyFormat.format(s.precioTotal),
                _currencyFormat.format(s.totalAbonado),
                _currencyFormat.format(s.saldoPendiente),
              ];
            }).toList(),
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Icaro Proagro • Documento Oficial Interno de Cartera', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cartera_Icaro_Proagro_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }

  static pw.Widget _buildKpiCard(
    String label,
    String valor,
    PdfColor color,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFFFFFF),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 7, color: const PdfColor.fromInt(0xFF475569))),
            pw.SizedBox(height: 3),
            pw.Text(valor, style: pw.TextStyle(font: fontBold, fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  /// Genera bytes en memoria del comprobante / orden de servicio individual
  static Future<Uint8List> generarOrdenServicio(ServicioModel s) async {
    final pdf = pw.Document();

    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();

    const verdePrimario = PdfColor.fromInt(0xFF059669);
    const verdeOscuro = PdfColor.fromInt(0xFF02371E);
    const grisFondo = PdfColor.fromInt(0xFFF8FAFC);
    const grisBorde = PdfColor.fromInt(0xFFCBD5E1);
    const textoOscuro = PdfColor.fromInt(0xFF0F172A);
    const textoSecundario = PdfColor.fromInt(0xFF475569);

    final fechaStr = DateFormat('dd/MM/yyyy - hh:mm a', 'es').format(s.fecha);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ICARO PROAGRO', style: pw.TextStyle(font: fontBold, fontSize: 24, color: verdePrimario)),
                      pw.Text('Tecnología Aérea y Fumigación con Drones', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: textoSecundario)),
                      pw.Text('Operaciones Agrícolas de Precisión', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textoSecundario)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: grisFondo,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: grisBorde),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ORDEN DE SERVICIO Y COBRO', style: pw.TextStyle(font: fontBold, fontSize: 11, color: verdeOscuro)),
                        pw.SizedBox(height: 3),
                        pw.Text('Fecha: $fechaStr', style: pw.TextStyle(fontSize: 8.5, color: textoSecundario)),
                        pw.Text('Estado: ${s.estado}', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: s.estado == 'CANCELADO' ? PdfColors.red : verdePrimario)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // DATOS DEL CLIENTE Y OPERACIÓN
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: grisFondo,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: grisBorde),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('INFORMACIÓN DEL CLIENTE', style: pw.TextStyle(font: fontBold, fontSize: 10, color: verdeOscuro)),
                          pw.SizedBox(height: 6),
                          pw.Text('Cliente: ${s.clienteNombre}', style: pw.TextStyle(font: fontMedium, fontSize: 9.5)),
                          pw.Text('Finca / Ubicación: ${s.fincaUbicacion}', style: pw.TextStyle(fontSize: 9)),
                          pw.Text('Teléfono: ${s.clienteTelefono}', style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EQUIPO Y TRIPULACIÓN', style: pw.TextStyle(font: fontBold, fontSize: 10, color: verdeOscuro)),
                          pw.SizedBox(height: 6),
                          pw.Text('Piloto a Cargo: ${s.piloto.isNotEmpty ? s.piloto : "No especificado"}', style: pw.TextStyle(font: fontMedium, fontSize: 9.5)),
                          pw.Text('Aeronave / Dron: ${s.dron.isNotEmpty ? s.dron : "DJI Agras"}', style: pw.TextStyle(fontSize: 9)),
                          pw.Text('Método de Pago: ${s.metodoPago == "EN_LINEA" ? "Transferencia / En Línea" : "Efectivo"}', style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // TABLA DE DETALLE DE LA APLICACIÓN
              pw.Text('DETALLE DE LA APLICACIÓN AGRÍCOLA', style: pw.TextStyle(font: fontBold, fontSize: 11, color: textoOscuro)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: grisBorde, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: verdePrimario),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: ['Cultivo', 'Labor', 'Insumo', 'Hectáreas', 'Litros Aplicados', 'Precio/Ha', 'Subtotal'],
                data: [
                  [
                    s.cultivo,
                    s.tipoAplicacion,
                    s.productoQuimico.isNotEmpty ? s.productoQuimico : 'Caldo estándar',
                    '${s.hectareas} Ha',
                    s.litrosAplicados != null ? '${s.litrosAplicados!.toStringAsFixed(1)} L' : 'Estándar',
                    _currencyFormat.format(s.precioPorHectarea),
                    _currencyFormat.format(s.precioTotal),
                  ],
                ],
              ),

              pw.SizedBox(height: 14),

              // TOTAL Y CONDICIÓN DE PAGO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 240,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: grisFondo,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: grisBorde),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('VALOR TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: 11, color: textoOscuro)),
                            pw.Text(_currencyFormat.format(s.precioTotal), style: pw.TextStyle(font: fontBold, fontSize: 13, color: verdePrimario)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL ABONADO:', style: pw.TextStyle(fontSize: 9, color: textoSecundario)),
                            pw.Text(_currencyFormat.format(s.totalAbonado), style: pw.TextStyle(font: fontMedium, fontSize: 9.5, color: verdePrimario)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SALDO PENDIENTE:', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textoOscuro)),
                            pw.Text(_currencyFormat.format(s.saldoPendiente), style: pw.TextStyle(font: fontBold, fontSize: 10, color: s.saldoPendiente > 0 ? PdfColors.orange800 : verdePrimario)),
                          ],
                        ),
                        pw.Divider(color: grisBorde, height: 10),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('ESTADO:', style: pw.TextStyle(fontSize: 9, color: textoSecundario)),
                            pw.Text(s.pagado ? 'PAGADO 100%' : 'PENDIENTE', style: pw.TextStyle(font: fontBold, fontSize: 9, color: s.pagado ? verdePrimario : PdfColors.orange800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (s.notas.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: grisFondo,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: grisBorde),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NOTAS Y OBSERVACIONES DE OPERACIÓN:', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: verdeOscuro)),
                      pw.SizedBox(height: 3),
                      pw.Text(s.notas, style: pw.TextStyle(fontSize: 8.5, color: textoOscuro)),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // FIRMAS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 170, height: 1, color: grisBorde),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma Piloto / Operador Certificado', style: pw.TextStyle(fontSize: 8.5, font: fontRegular, color: textoSecundario)),
                      pw.Text(s.piloto.isNotEmpty ? s.piloto : 'Tripulación Icaro Proagro', style: pw.TextStyle(fontSize: 8, font: fontBold, color: textoOscuro)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 170, height: 1, color: grisBorde),
                      pw.SizedBox(height: 4),
                      pw.Text('Recibido a Conformidad por Cliente', style: pw.TextStyle(fontSize: 8.5, font: fontRegular, color: textoSecundario)),
                      pw.Text(s.clienteNombre, style: pw.TextStyle(fontSize: 8, font: fontBold, color: textoOscuro)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Icaro Proagro • Drones de Fumigación y Servicios Agrícolas de Colombia',
              style: pw.TextStyle(fontSize: 7.5, color: textoSecundario),
            ),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// Abre la vista interactiva para imprimir o compartir la orden individual
  static Future<void> generarYCompartirOrdenServicio(ServicioModel s) async {
    final bytes = await generarOrdenServicio(s);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Orden_Icaro_Proagro_${s.clienteNombre.replaceAll(" ", "_")}.pdf',
    );
  }

  /// Genera en bytes la Ficha Técnica de Daños e Inspección de Equipos
  static Future<Uint8List> generarFichaTecnicaDanoPdf(
    BitacoraDanoEquipoModel dano, {
    ServicioModel? servicio,
  }) async {
    final pdf = pw.Document();

    final fontBold = await PdfGoogleFonts.interBold();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();

    const verdePrimario = PdfColor.fromInt(0xFF059669);
    const verdeOscuro = PdfColor.fromInt(0xFF02371E);
    const grisFondo = PdfColor.fromInt(0xFFF1F5F2);
    const grisBorde = PdfColor.fromInt(0xFFCBD5E1);
    const textoOscuro = PdfColor.fromInt(0xFF0F172A);
    const textoSecundario = PdfColor.fromInt(0xFF475569);

    final colorGravedad = dano.gravedad == 'CRITICA'
        ? const PdfColor.fromInt(0xFFDC2626)
        : dano.gravedad == 'MODERADA'
            ? const PdfColor.fromInt(0xFFD97706)
            : const PdfColor.fromInt(0xFF059669);

    final colorEstado = dano.estado == 'REPARADO'
        ? const PdfColor.fromInt(0xFF059669)
        : dano.estado == 'EN_REPARACION'
            ? const PdfColor.fromInt(0xFF2563EB)
            : const PdfColor.fromInt(0xFFD97706);

    final fechaStr = DateFormat("dd/MM/yyyy - hh:mm a").format(dano.fecha);
    final reporteId = dano.id != null && dano.id!.length >= 6
        ? dano.id!.substring(0, 6).toUpperCase()
        : '001';

    // Decodificar imágenes válidas
    final List<Uint8List> fotosBytes = [];
    for (var f in dano.fotosBase64) {
      try {
        final decoded = base64Decode(f);
        if (decoded.isNotEmpty) {
          fotosBytes.add(decoded);
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ENCABEZADO PRINCIPAL
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ICARO PROAGRO',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 22,
                      color: verdeOscuro,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    'SERVICIOS AGRÍCOLAS CON DRONES DE ALTA PRECISIÓN',
                    style: pw.TextStyle(
                      font: fontMedium,
                      fontSize: 8.5,
                      color: verdePrimario,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Ficha Técnica Oficial de Daño e Inspección de Equipos',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: textoSecundario,
                      font: fontRegular,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: grisFondo,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: grisBorde),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'FOLIO #$reporteId',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: verdeOscuro),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Fecha: $fechaStr', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // BADGES DE ESTADO Y GRAVEDAD
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: colorGravedad,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'GRAVEDAD: ${BitacoraDanoEquipoModel.nombreGravedad(dano.gravedad).toUpperCase()}',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: colorEstado,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'ESTADO: ${BitacoraDanoEquipoModel.nombreEstado(dano.estado).toUpperCase()}',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Categoría: ${BitacoraDanoEquipoModel.nombreCategoria(dano.categoriaEquipo)}',
                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textoOscuro),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // SECCIÓN 1: IDENTIFICACIÓN DEL EQUIPO Y RESPONSABLES
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: grisFondo,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: grisBorde),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('1. DATOS DEL EQUIPO Y OPERACIÓN', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: verdeOscuro)),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Equipo / Unidad:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(dano.nombreEquipo, style: pw.TextStyle(font: fontBold, fontSize: 10, color: textoOscuro)),
                          pw.SizedBox(height: 6),
                          pw.Text('Tipo de Equipo:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(BitacoraDanoEquipoModel.nombreCategoria(dano.categoriaEquipo), style: pw.TextStyle(font: fontMedium, fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Piloto / Técnico que Reporta:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(dano.pilotoReporta, style: pw.TextStyle(font: fontBold, fontSize: 10, color: textoOscuro)),
                          pw.SizedBox(height: 6),
                          pw.Text('Operación / Servicio Vinculado:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(
                            servicio != null
                                ? '${servicio.clienteNombre} (${servicio.cultivo} - ${servicio.hectareas} Ha)'
                                : 'No asociado a vuelo específico',
                            style: pw.TextStyle(font: fontMedium, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // SECCIÓN 2: DETALLE TÉCNICO DE LA AVERÍA
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: grisBorde),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('2. DESCRIPCIÓN DEL INCIDENTE Y DAÑO OBSERVADO', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: verdeOscuro)),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text('Tipo de Avería: ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                    pw.Text(dano.tipoDano, style: pw.TextStyle(fontSize: 9, color: textoOscuro)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  dano.descripcion.isNotEmpty ? dano.descripcion : 'Sin descripción adicional.',
                  style: pw.TextStyle(fontSize: 9, color: textoOscuro, font: fontRegular, lineSpacing: 2),
                ),
                if (dano.videoUrl != null && dano.videoUrl!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Enlace de Video Evidencia: ${dano.videoUrl}', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700)),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // SECCIÓN 3: REPUESTOS, COSTOS E IMPACTO FINANCIERO
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: grisFondo,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: grisBorde),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('3. INTERVENCIÓN TÉCNICA, REPUESTOS Y LIQUIDACIÓN', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: verdeOscuro)),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Piezas / Repuestos Reemplazados:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(
                            dano.piezasCambiadas.isNotEmpty ? dano.piezasCambiadas : 'Ninguno registrado aún',
                            style: pw.TextStyle(font: fontMedium, fontSize: 9.5, color: textoOscuro),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Costo de Reparación:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(
                            _currencyFormat.format(dano.costoReparacion),
                            style: pw.TextStyle(font: fontBold, fontSize: 11, color: dano.costoReparacion > 0 ? const PdfColor.fromInt(0xFFDC2626) : verdePrimario),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Estado Contable:', style: pw.TextStyle(fontSize: 8, color: textoSecundario)),
                          pw.Text(
                            dano.gastoContableRegistrado ? 'Asentado en Caja' : 'Pendiente en Caja',
                            style: pw.TextStyle(
                              font: fontMedium,
                              fontSize: 9,
                              color: dano.gastoContableRegistrado ? verdePrimario : const PdfColor.fromInt(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SECCIÓN 4: EVIDENCIA FOTOGRÁFICA
          if (fotosBytes.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('4. REGISTRO FOTOGRÁFICO DE EVIDENCIA (${fotosBytes.length} Foto(s))', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: verdeOscuro)),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: fotosBytes.take(4).map((imgBytes) {
                return pw.Container(
                  width: 230,
                  height: 120,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: grisBorde, width: 1),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      pw.MemoryImage(imgBytes),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          pw.SizedBox(height: 24),

          // SECCIÓN 5: FIRMAS DE RESPONSABILIDAD
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 170, height: 1, color: grisBorde),
                  pw.SizedBox(height: 6),
                  pw.Text('Firma del Piloto / Operador', style: pw.TextStyle(fontSize: 8, font: fontMedium, color: textoSecundario)),
                  pw.Text(dano.pilotoReporta, style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: textoOscuro)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 170, height: 1, color: grisBorde),
                  pw.SizedBox(height: 6),
                  pw.Text('Firma Mantenimiento / Aprobación', style: pw.TextStyle(fontSize: 8, font: fontMedium, color: textoSecundario)),
                  pw.Text('Ícaro Proagro Colombia', style: pw.TextStyle(fontSize: 8.5, font: fontBold, color: textoOscuro)),
                ],
              ),
            ],
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Ícaro Proagro • Registro Oficial de Mantenimiento y Garantías Técnicas',
              style: pw.TextStyle(fontSize: 7.5, color: textoSecundario),
            ),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: textoSecundario)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// Abre la vista interactiva para previsualizar, imprimir o exportar la Ficha Técnica de Daño
  static Future<void> generarYCompartirFichaTecnicaDano(
    BitacoraDanoEquipoModel dano, {
    ServicioModel? servicio,
  }) async {
    final bytes = await generarFichaTecnicaDanoPdf(dano, servicio: servicio);
    final nombreLimpio = dano.nombreEquipo.replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Ficha_Tecnica_Dano_${dano.categoriaEquipo}_$nombreLimpio.pdf',
    );
  }
}
