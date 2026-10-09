import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/servicio_model.dart';
import 'notification_service.dart';

/// Motor de contabilidad automática para los vuelos (servicios).
///
/// Mantiene `transacciones` y `servicios` sincronizados sin intervención manual:
/// - Vuelo programado sin pago  -> queda automáticamente en Cuentas por Cobrar.
/// - Vuelo marcado como pagado  -> genera el INGRESO faltante en caja (origen AUTO).
/// - Vuelo desmarcado de pagado -> revierte solo los ingresos automáticos.
/// - Vuelo cancelado            -> anula todos sus ingresos y su recordatorio.
/// - Vuelo eliminado            -> borra servicio, ingresos, bitácora y recordatorio.
class ContabilidadAutoService {
  ContabilidadAutoService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String origenAuto = 'AUTO';

  /// Sincroniza la contabilidad de un servicio según su estado y bandera de pago.
  /// Es idempotente: puede llamarse varias veces sin duplicar movimientos.
  static Future<void> sincronizarServicio(ServicioModel s) async {
    final id = s.id;
    if (id == null) return;

    try {
      final servicioRef = _db.collection('servicios').doc(id);
      final snapTrans = await _db
          .collection('transacciones')
          .where('servicioId', isEqualTo: id)
          .get();

      // 1. CANCELADO: anular todo
      if (s.estado == 'CANCELADO') {
        final batch = _db.batch();
        for (final doc in snapTrans.docs) {
          batch.delete(doc.reference);
        }
        batch.update(servicioRef, {'pagado': false, 'totalAbonado': 0.0});
        await batch.commit();
        s.pagado = false;
        s.totalAbonado = 0.0;
        await NotificationService.instance.cancelarRecordatorioVuelo(id);
        return;
      }

      double ingresado = 0;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> automaticas = [];
      for (final doc in snapTrans.docs) {
        final data = doc.data();
        if (data['tipo'] != 'INGRESO') continue;
        ingresado += ((data['monto'] ?? 0) as num).toDouble();
        if (data['origen'] == origenAuto) automaticas.add(doc);
      }

      if (s.pagado) {
        // 2. PAGADO: registrar en caja lo que falte
        final faltante = s.precioTotal - ingresado;
        if (faltante > 1.0) {
          await _db.collection('transacciones').add({
            'tipo': 'INGRESO',
            'categoria': 'SERVICIO',
            'monto': faltante,
            'descripcion': 'Fumigación ${s.cultivo} (${s.hectareas} Ha) - ${s.clienteNombre}',
            'fecha': DateTime.now().toIso8601String(),
            'clienteNombre': s.clienteNombre,
            'servicioId': id,
            'metodoPago': s.metodoPago,
            'origen': origenAuto,
          });
        }
        if ((s.totalAbonado - s.precioTotal).abs() > 0.5) {
          await servicioRef.update({'totalAbonado': s.precioTotal});
          s.totalAbonado = s.precioTotal;
        }
      } else if (automaticas.isNotEmpty) {
        // 3. DESMARCADO como pagado: revertir solo ingresos automáticos
        final batch = _db.batch();
        double revertido = 0;
        for (final doc in automaticas) {
          revertido += ((doc.data()['monto'] ?? 0) as num).toDouble();
          batch.delete(doc.reference);
        }
        final nuevoAbonado = (ingresado - revertido).clamp(0.0, double.infinity);
        batch.update(servicioRef, {'totalAbonado': nuevoAbonado});
        await batch.commit();
        s.totalAbonado = nuevoAbonado;
      }
    } catch (e) {
      debugPrint('Error sincronizando contabilidad del servicio $id: $e');
    }
  }

  /// Cambia el estado de un vuelo y aplica automáticamente sus efectos contables
  /// y de recordatorios.
  static Future<void> cambiarEstado(ServicioModel s, String nuevoEstado) async {
    final id = s.id;
    if (id == null) return;

    await _db.collection('servicios').doc(id).update({'estado': nuevoEstado});
    s.estado = nuevoEstado;

    if (nuevoEstado == 'PROGRAMADO') {
      await NotificationService.instance.programarRecordatorioVuelo(s);
    } else {
      await NotificationService.instance.cancelarRecordatorioVuelo(id);
    }

    await sincronizarServicio(s);
  }

  /// Elimina por completo un vuelo y todos sus registros asociados.
  static Future<void> eliminarServicio(String id) async {
    final snapTrans = await _db
        .collection('transacciones')
        .where('servicioId', isEqualTo: id)
        .get();

    final batch = _db.batch();
    for (final doc in snapTrans.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('bitacoras_vuelo').doc(id));
    batch.delete(_db.collection('servicios').doc(id));
    await batch.commit();

    await NotificationService.instance.cancelarRecordatorioVuelo(id);
  }
}
