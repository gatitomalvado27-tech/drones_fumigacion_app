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
        // 2. PAGADO: registrar en caja lo que falte (respetando abonos/anticipos ya aplicados)
        final cubierto = ingresado > s.totalAbonado ? ingresado : s.totalAbonado;
        final faltante = s.precioTotal - cubierto;
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

  /// Incrementa (o ajusta) el Saldo a Favor de un cliente en la colección `clientes`.
  /// Si el cliente aún no existe como documento en `clientes`, lo crea automáticamente.
  static Future<void> sumarSaldoAFavorCliente({
    required String clienteId,
    required String clienteNombre,
    String clienteCedula = '',
    required String clienteTelefono,
    required String fincaUbicacion,
    required String cultivo,
    required double montoExcedente,
  }) async {
    if (montoExcedente <= 0) return;
    final col = _db.collection('clientes');

    if (clienteId.isNotEmpty) {
      final docRef = col.doc(clienteId);
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        final actual = ((snap.data()!['saldoAFavor'] ?? 0) as num).toDouble();
        await docRef.update({
          'saldoAFavor': actual + montoExcedente,
          if (clienteCedula.isNotEmpty) 'cedula': clienteCedula,
        });
        return;
      }
    }

    // Buscar por nombre exacto (case-insensitive)
    final allSnap = await col.get();
    final busq = clienteNombre.trim().toLowerCase();
    for (final d in allSnap.docs) {
      final nom = (d.data()['nombre'] ?? '').toString().trim().toLowerCase();
      if (nom == busq) {
        final actual = ((d.data()['saldoAFavor'] ?? 0) as num).toDouble();
        await d.reference.update({
          'saldoAFavor': actual + montoExcedente,
          if (clienteCedula.isNotEmpty && (d.data()['cedula'] ?? '').toString().isEmpty)
            'cedula': clienteCedula,
        });
        return;
      }
    }

    // Si no existía en `clientes`, crearlo con el saldo a favor
    await col.add({
      'nombre': clienteNombre.trim(),
      'cedula': clienteCedula.trim(),
      'telefono': clienteTelefono.trim(),
      'ubicacion': fincaUbicacion.trim(),
      'cultivoPrincipal': cultivo.trim(),
      'activo': true,
      'saldoAFavor': montoExcedente,
    });
  }

  /// Descuenta saldo a favor del cliente cuando se aplica a una nueva programación o servicio existente.
  static Future<double> descontarSaldoAFavorCliente({
    required String clienteId,
    required String clienteNombre,
    required double montoAAplicar,
  }) async {
    if (montoAAplicar <= 0) return 0.0;
    final col = _db.collection('clientes');

    DocumentSnapshot<Map<String, dynamic>>? targetDoc;
    if (clienteId.isNotEmpty) {
      final snap = await col.doc(clienteId).get();
      if (snap.exists) targetDoc = snap;
    }

    if (targetDoc == null) {
      final allSnap = await col.get();
      final busq = clienteNombre.trim().toLowerCase();
      for (final d in allSnap.docs) {
        final nom = (d.data()['nombre'] ?? '').toString().trim().toLowerCase();
        if (nom == busq) {
          targetDoc = d;
          break;
        }
      }
    }

    if (targetDoc == null || targetDoc.data() == null) return 0.0;
    final disponible = ((targetDoc.data()!['saldoAFavor'] ?? 0) as num).toDouble();
    if (disponible <= 0) return 0.0;

    final aplicado = montoAAplicar > disponible ? disponible : montoAAplicar;
    final restante = (disponible - aplicado).clamp(0.0, double.infinity);
    await targetDoc.reference.update({'saldoAFavor': restante});
    return aplicado;
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
