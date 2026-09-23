import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/cierre_mensual_model.dart';
import '../models/transaccion_model.dart';
import '../models/servicio_model.dart';
import '../services/pdf_service.dart';
import '../theme/agro_theme.dart';

class HistorialBalancesScreen extends StatefulWidget {
  const HistorialBalancesScreen({super.key});

  @override
  State<HistorialBalancesScreen> createState() => _HistorialBalancesScreenState();
}

class _HistorialBalancesScreenState extends State<HistorialBalancesScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static const List<String> mesesNombres = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context) {
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final primary = AgroTheme.getPrimary(context);
    final border = AgroTheme.getBorder(context);

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      appBar: AppBar(
        title: const Text('Historial de Balances Mensuales'),
        backgroundColor: AgroTheme.getBg(context),
        foregroundColor: text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Archivar / Cerrar un Mes',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () => _mostrarDialogoCerrarMes(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cierres_mensuales')
              .orderBy('anio', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final cierres = docs.map((d) {
              return CierreMensualModel.fromMap(d.id, d.data() as Map<String, dynamic>);
            }).toList();

            // Ordenar por anio desc, mes desc
            cierres.sort((a, b) {
              final cmpAnio = b.anio.compareTo(a.anio);
              if (cmpAnio != 0) return cmpAnio;
              return b.mes.compareTo(a.mes);
            });

            if (cierres.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu_outlined, size: 54, color: subtext.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Aún no hay balances mensuales archivados.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Al terminar cada mes puedes congelar el balance oficial para consultarlo o re-descargarlo cuando quieras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: subtext),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.archive, size: 16),
                        label: const Text('Cerrar y Archivar un Mes'),
                        onPressed: () => _mostrarDialogoCerrarMes(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: cierres.length,
              itemBuilder: (context, index) {
                final c = cierres[index];
                final nombreMes = (c.mes >= 1 && c.mes <= 12) ? mesesNombres[c.mes] : 'Mes ${c.mes}';
                final tituloMes = '$nombreMes ${c.anio}'.toUpperCase();

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.picture_as_pdf, color: primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tituloMes,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: text,
                                      ),
                                    ),
                                    Text(
                                      'Cerrado el ${DateFormat('dd/MM/yyyy').format(c.fechaCierre)}',
                                      style: TextStyle(fontSize: 11, color: subtext),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.utilidadNeta >= 0
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c.utilidadNeta >= 0 ? 'Rentable' : 'Déficit',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: c.utilidadNeta >= 0 ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // MÉTRICAS CLAVE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol('Ingresos', _currencyFormat.format(c.totalIngresos), Colors.green),
                            _buildInfoCol('Egresos', _currencyFormat.format(c.totalEgresos), Colors.redAccent),
                            _buildInfoCol('Utilidad Neta', _currencyFormat.format(c.utilidadNeta), primary),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol('Hectáreas', '${c.totalHectareas.toStringAsFixed(1)} Ha', text),
                            _buildInfoCol('Vuelos', '${c.totalVuelos}', text),
                            _buildInfoCol('Por Cobrar', _currencyFormat.format(c.totalPorCobrar), Colors.amber),
                          ],
                        ),

                        // DESGLOSE BANCOS SI EXISTE
                        if (c.desgloseBancos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: c.desgloseBancos.entries.map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${TransaccionModel.nombreMetodo(e.key)}: ${_currencyFormat.format(e.value)}',
                                  style: TextStyle(fontSize: 10, color: subtext),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary.withValues(alpha: 0.15),
                              foregroundColor: primary,
                              elevation: 0,
                              side: BorderSide(color: primary.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text(
                              'Generar y Compartir PDF Oficial',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Generando documento oficial PDF...')),
                              );
                              await PdfService.generarYCompartirBalance(
                                periodoTitulo: tituloMes,
                                totalIngresos: c.totalIngresos,
                                totalEgresos: c.totalEgresos,
                                utilidadNeta: c.utilidadNeta,
                                totalPorCobrar: c.totalPorCobrar,
                                totalHectareas: c.totalHectareas,
                                totalVuelos: c.totalVuelos,
                                egresosPorCategoria: c.desgloseCategorias,
                                ingresosPorCuenta: c.desgloseBancos,
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
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AgroTheme.getSubtext(context))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _mostrarDialogoCerrarMes(BuildContext context) {
    final now = DateTime.now();
    int mesSel = now.month == 1 ? 12 : now.month - 1;
    int anioSel = now.month == 1 ? now.year - 1 : now.year;
    bool procesando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final primary = AgroTheme.getPrimary(context);

          return AlertDialog(
            title: const Text('Archivar Cierre de Mes'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona el mes que deseas consolidar y archivar en el historial de la app:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: mesSel,
                        decoration: const InputDecoration(labelText: 'Mes', border: OutlineInputBorder()),
                        items: List.generate(12, (i) {
                          final m = i + 1;
                          return DropdownMenuItem(value: m, child: Text(mesesNombres[m], style: const TextStyle(fontSize: 12)));
                        }),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => mesSel = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        initialValue: anioSel,
                        decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
                        items: [now.year - 1, now.year, now.year + 1]
                            .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => anioSel = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: procesando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.black),
                onPressed: procesando
                    ? null
                    : () async {
                        setDlgState(() => procesando = true);
                        try {
                          await consolidarYArchivarMes(mesSel, anioSel);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('El mes de ${mesesNombres[mesSel]} $anioSel ha sido archivado.'),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDlgState(() => procesando = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al archivar mes: $e')),
                            );
                          }
                        }
                      },
                child: Text(procesando ? 'Archivando...' : 'Archivar Balance'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> consolidarYArchivarMes(int mes, int anio) async {
    final docId = '$anio-${mes.toString().padLeft(2, '0')}';

    final snapTrans = await FirebaseFirestore.instance.collection('transacciones').get();
    final snapServ = await FirebaseFirestore.instance.collection('servicios').get();

    final todasTrans = snapTrans.docs.map((d) => TransaccionModel.fromMap(d.id, d.data())).toList();
    final todosServ = snapServ.docs.map((d) => ServicioModel.fromMap(d.id, d.data())).toList();

    final transMes = todasTrans.where((t) => t.fecha.year == anio && t.fecha.month == mes).toList();
    final servMes = todosServ.where((s) => s.fecha.year == anio && s.fecha.month == mes).toList();

    double totalIng = 0;
    double totalEgr = 0;
    final Map<String, double> egresosPorCat = {};
    final Map<String, double> ingresosPorBanco = {};

    for (var t in transMes) {
      if (t.tipo == 'INGRESO') {
        totalIng += t.monto;
        final metodo = t.metodoPago;
        ingresosPorBanco[metodo] = (ingresosPorBanco[metodo] ?? 0) + t.monto;
      } else if (t.tipo == 'EGRESO') {
        totalEgr += t.monto;
        egresosPorCat[t.categoria] = (egresosPorCat[t.categoria] ?? 0) + t.monto;
      }
    }

    double porCobrar = 0;
    double totalHa = 0;
    for (var s in servMes) {
      totalHa += s.hectareas;
      if (!s.pagado && s.estado != 'CANCELADO') {
        porCobrar += s.saldoPendiente;
      }
    }

    final cierre = CierreMensualModel(
      id: docId,
      mes: mes,
      anio: anio,
      fechaCierre: DateTime.now(),
      totalIngresos: totalIng,
      totalEgresos: totalEgr,
      utilidadNeta: totalIng - totalEgr,
      totalHectareas: totalHa,
      totalVuelos: servMes.length,
      totalPorCobrar: porCobrar,
      desgloseBancos: ingresosPorBanco,
      desgloseCategorias: egresosPorCat,
    );

    await FirebaseFirestore.instance.collection('cierres_mensuales').doc(docId).set(cierre.toMap());
  }
}
