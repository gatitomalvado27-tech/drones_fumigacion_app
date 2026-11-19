import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cierre_mensual_model.dart';
import '../models/servicio_model.dart';
import '../models/transaccion_model.dart';

class BalanceMensualAutoService {
  static bool _ejecutando = false;

  static String idMes(int anio, int mes) =>
      '$anio-${mes.toString().padLeft(2, '0')}';

  /// Lógica pura (fácilmente verificable en pruebas unitarias) que determina
  /// qué meses ya finalizados necesitan generar su balance mensual.
  static List<(int anio, int mes)> calcularMesesFinalizadosPendientes({
    required DateTime ahora,
    required Iterable<DateTime> fechasConActividad,
    required Set<String> cierresExistentes,
  }) {
    final candidatos = <String, (int, int)>{};

    // 1. Siempre incluir el mes inmediatamente anterior al actual
    //    para que apenas finalice un mes ya quede su registro oficial.
    final mesAnterior = DateTime(ahora.year, ahora.month - 1, 1);
    final idAnterior = idMes(mesAnterior.year, mesAnterior.month);
    if (!cierresExistentes.contains(idAnterior)) {
      candidatos[idAnterior] = (mesAnterior.year, mesAnterior.month);
    }

    // 2. Incluir cualquier otro mes finalizado que haya tenido movimientos o vuelos
    for (final f in fechasConActividad) {
      final esMesFinalizado =
          f.year < ahora.year || (f.year == ahora.year && f.month < ahora.month);
      if (!esMesFinalizado) continue;
      final id = idMes(f.year, f.month);
      if (!cierresExistentes.contains(id)) {
        candidatos[id] = (f.year, f.month);
      }
    }

    final lista = candidatos.values.toList()
      ..sort((a, b) {
        final cmpAnio = a.$1.compareTo(b.$1);
        return cmpAnio != 0 ? cmpAnio : a.$2.compareTo(b.$2);
      });
    return lista;
  }

  /// Verifica en segundo plano si existen meses finalizados sin cierre
  /// y genera sus balances automáticamente en `cierres_mensuales`.
  /// Retorna la cantidad de balances nuevos generados.
  static Future<int> verificarYGenerarBalancesAutomaticos({
    DateTime? fechaReferencia,
  }) async {
    if (_ejecutando) return 0;
    _ejecutando = true;
    int generados = 0;

    try {
      final ahora = fechaReferencia ?? DateTime.now();
      final db = FirebaseFirestore.instance;

      final resultados = await Future.wait([
        db.collection('cierres_mensuales').get(),
        db.collection('transacciones').get(),
        db.collection('servicios').get(),
      ]);

      final snapCierres = resultados[0];
      final snapTrans = resultados[1];
      final snapServ = resultados[2];

      final cierresExistentes = snapCierres.docs.map((d) => d.id).toSet();
      final todasTrans = snapTrans.docs
          .map((d) => TransaccionModel.fromMap(d.id, d.data()))
          .toList();
      final todosServ = snapServ.docs
          .map((d) => ServicioModel.fromMap(d.id, d.data()))
          .toList();

      final fechas = <DateTime>[
        ...todasTrans.map((t) => t.fecha),
        ...todosServ.map((s) => s.fecha),
      ];

      final pendientes = calcularMesesFinalizadosPendientes(
        ahora: ahora,
        fechasConActividad: fechas,
        cierresExistentes: cierresExistentes,
      );

      for (final (anio, mes) in pendientes) {
        final cierre = construirCierreMensual(
          anio: anio,
          mes: mes,
          todasTrans: todasTrans,
          todosServ: todosServ,
          fechaCierre: ahora,
        );
        await db
            .collection('cierres_mensuales')
            .doc(cierre.id)
            .set(cierre.toMap());
        generados++;
      }
    } catch (e) {
      debugPrint('Error en generación automática de balances mensuales: $e');
    } finally {
      _ejecutando = false;
    }

    return generados;
  }

  /// Construye el modelo consolidado de un mes específico a partir de
  /// transacciones y servicios.
  static CierreMensualModel construirCierreMensual({
    required int anio,
    required int mes,
    required List<TransaccionModel> todasTrans,
    required List<ServicioModel> todosServ,
    DateTime? fechaCierre,
  }) {
    final docId = idMes(anio, mes);
    final transMes = todasTrans
        .where((t) => t.fecha.year == anio && t.fecha.month == mes)
        .toList();
    final servMes = todosServ
        .where((s) => s.fecha.year == anio && s.fecha.month == mes)
        .toList();

    double totalIng = 0;
    double totalEgr = 0;
    final Map<String, double> egresosPorCat = {};
    final Map<String, double> ingresosPorBanco = {};

    for (final t in transMes) {
      if (t.tipo == 'INGRESO') {
        totalIng += t.monto;
        ingresosPorBanco[t.metodoPago] =
            (ingresosPorBanco[t.metodoPago] ?? 0) + t.monto;
      } else if (t.tipo == 'EGRESO') {
        totalEgr += t.monto;
        egresosPorCat[t.categoria] =
            (egresosPorCat[t.categoria] ?? 0) + t.monto;
      }
    }

    double porCobrar = 0;
    double totalHa = 0;
    for (final s in servMes) {
      if (s.estado != 'CANCELADO') {
        totalHa += s.hectareas;
      }
      if (!s.pagado && s.estado != 'CANCELADO') {
        porCobrar += s.saldoPendiente;
      }
    }

    return CierreMensualModel(
      id: docId,
      mes: mes,
      anio: anio,
      fechaCierre: fechaCierre ?? DateTime.now(),
      totalIngresos: totalIng,
      totalEgresos: totalEgr,
      utilidadNeta: totalIng - totalEgr,
      totalHectareas: totalHa,
      totalVuelos: servMes.where((s) => s.estado != 'CANCELADO').length,
      totalPorCobrar: porCobrar,
      desgloseBancos: ingresosPorBanco,
      desgloseCategorias: egresosPorCat,
    );
  }
}
