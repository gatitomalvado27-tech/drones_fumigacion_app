import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dia_no_laborable_model.dart';
import '../models/mantenimiento_equipo_model.dart';

class ResultadoValidacionAgenda {
  final DiaNoLaborableModel? diaNoLaborable;
  final List<MantenimientoEquipoModel> mantenimientosConflicto;

  const ResultadoValidacionAgenda({
    this.diaNoLaborable,
    this.mantenimientosConflicto = const [],
  });

  bool get tieneAdvertencias =>
      diaNoLaborable != null || mantenimientosConflicto.isNotEmpty;
}

class AgendaValidacionService {
  /// Evaluación pura en memoria (útil tanto en UI como en pruebas unitarias).
  static ResultadoValidacionAgenda evaluarConflictos({
    required DateTime fechaHoraVuelo,
    required String dronAsignado,
    required List<DiaNoLaborableModel> diasNoLaborables,
    required List<MantenimientoEquipoModel> mantenimientos,
  }) {
    final idDia = DiaNoLaborableModel.generarIdFecha(fechaHoraVuelo);
    DiaNoLaborableModel? diaBloqueado;
    for (final d in diasNoLaborables) {
      if (d.id == idDia ||
          (d.fecha.year == fechaHoraVuelo.year &&
              d.fecha.month == fechaHoraVuelo.month &&
              d.fecha.day == fechaHoraVuelo.day)) {
        diaBloqueado = d;
        break;
      }
    }

    final conflictos = mantenimientos
        .where((m) => m.entraEnConflictoCon(fechaHoraVuelo, equipoVuelo: dronAsignado))
        .toList();

    return ResultadoValidacionAgenda(
      diaNoLaborable: diaBloqueado,
      mantenimientosConflicto: conflictos,
    );
  }

  /// Consulta Firestore en tiempo real antes de guardar o reprogramar un vuelo.
  static Future<ResultadoValidacionAgenda> validarEnFirestore({
    required DateTime fechaHoraVuelo,
    required String dronAsignado,
  }) async {
    try {
      final idDia = DiaNoLaborableModel.generarIdFecha(fechaHoraVuelo);
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('dias_no_laborables').doc(idDia).get(),
        FirebaseFirestore.instance.collection('mantenimientos_equipos').get(),
      ]);

      final docDia = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
      final snapMant = futures[1] as QuerySnapshot<Map<String, dynamic>>;

      final dias = <DiaNoLaborableModel>[];
      if (docDia.exists && docDia.data() != null) {
        dias.add(DiaNoLaborableModel.fromMap(docDia.id, docDia.data()!));
      }

      final mantenimientos = snapMant.docs
          .map((d) => MantenimientoEquipoModel.fromMap(d.id, d.data()))
          .toList();

      return evaluarConflictos(
        fechaHoraVuelo: fechaHoraVuelo,
        dronAsignado: dronAsignado,
        diasNoLaborables: dias,
        mantenimientos: mantenimientos,
      );
    } catch (_) {
      return const ResultadoValidacionAgenda();
    }
  }
}
