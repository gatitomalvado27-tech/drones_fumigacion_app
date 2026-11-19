import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drones_fumigacion_app/models/parametro_vuelo_model.dart';
import 'package:drones_fumigacion_app/models/dia_no_laborable_model.dart';
import 'package:drones_fumigacion_app/models/mantenimiento_equipo_model.dart';
import 'package:drones_fumigacion_app/models/servicio_model.dart';
import 'package:drones_fumigacion_app/models/transaccion_model.dart';
import 'package:drones_fumigacion_app/services/agenda_validacion_service.dart';
import 'package:drones_fumigacion_app/services/balance_mensual_auto_service.dart';
import 'package:drones_fumigacion_app/theme/theme_controller.dart';

void main() {
  group('Parámetros de vuelo por cultivo', () {
    test('Serializa y deserializa con campos opcionales y campos extra', () {
      final modelo = ParametroVueloModel(
        id: 'p1',
        servicioId: 's1',
        clienteNombre: 'Finca El Prado',
        cultivo: 'Arroz',
        fechaAplicacion: DateTime(2026, 11, 18, 7, 30),
        loteUbicacion: 'Lote Norte',
        hectareas: 12.5,
        tipoServicio: 'Fungicida',
        dron: 'DJI Agras T40',
        velocidadVuelo: 6.5,
        unidadVelocidadVuelo: 'm/s',
        alturaVuelo: 3.0,
        anchoFranja: 9.0,
        caudalAplicacion: 12.0,
        volumenPorHectarea: 10.0,
        velocidadAplicacion: 14.0,
        tipoProducto: 'Azoxistrobina',
        dosisProducto: '300 ml/Ha',
        observaciones: 'Viento suave al amanecer',
        camposExtra: {'Tamaño de gota': '180 micras'},
      );

      final map = modelo.toMap();
      final restaurado = ParametroVueloModel.fromMap('p1', map);

      expect(restaurado.cultivo, 'Arroz');
      expect(restaurado.velocidadVuelo, 6.5);
      expect(restaurado.alturaVuelo, 3.0);
      expect(restaurado.anchoFranja, 9.0);
      expect(restaurado.caudalAplicacion, 12.0);
      expect(restaurado.volumenPorHectarea, 10.0);
      expect(restaurado.velocidadAplicacion, 14.0);
      expect(restaurado.camposExtra['Tamaño de gota'], '180 micras');
      expect(restaurado.tieneParametrosTecnicos, isTrue);
    });

    test('Permite guardar registros sin campos numéricos obligatorios', () {
      final minimo = ParametroVueloModel(
        clienteNombre: 'Cliente Demo',
        cultivo: 'Maíz',
        fechaAplicacion: DateTime(2026, 11, 18),
      );
      final restaurado = ParametroVueloModel.fromMap('p2', minimo.toMap());
      expect(restaurado.velocidadVuelo, isNull);
      expect(restaurado.alturaVuelo, isNull);
      expect(restaurado.tieneParametrosTecnicos, isFalse);
    });
  });

  group('Reprogramación de vuelos y retrocompatibilidad', () {
    test('Conserva historial de reprogramaciones y fecha original', () {
      final original = DateTime(2026, 11, 18, 8, 0);
      final nueva = DateTime(2026, 11, 20, 9, 30);

      final servicio = ServicioModel(
        id: 'srv1',
        clienteId: 'cli1',
        clienteNombre: 'Agro Valle',
        clienteTelefono: '3001234567',
        fincaUbicacion: 'La Esperanza',
        fecha: nueva,
        hectareas: 10,
        cultivo: 'Arroz',
        tipoAplicacion: 'Fungicida',
        productoQuimico: 'Producto X',
        precioPorHectarea: 50000,
        precioTotal: 500000,
        reprogramado: true,
        fechaOriginal: original,
        historialReprogramaciones: [
          {
            'fechaAnterior': original.toIso8601String(),
            'fechaNueva': nueva.toIso8601String(),
            'motivo': 'Lluvia',
          }
        ],
      );

      final restaurado = ServicioModel.fromMap('srv1', servicio.toMap());
      expect(restaurado.reprogramado, isTrue);
      expect(restaurado.fechaOriginal, original);
      expect(restaurado.historialReprogramaciones.length, 1);
      expect(restaurado.historialReprogramaciones.first['motivo'], 'Lluvia');
    });

    test('Documentos antiguos sin campos nuevos cargan sin error', () {
      final legacy = ServicioModel.fromMap('old1', {
        'clienteId': 'c1',
        'clienteNombre': 'Juan',
        'clienteTelefono': '3100000000',
        'fincaUbicacion': 'Finca 1',
        'fecha': DateTime(2026, 5, 10).toIso8601String(),
        'hectareas': 5,
        'cultivo': 'Café',
        'tipoAplicacion': 'Foliar',
        'productoQuimico': '',
        'precioPorHectarea': 60000,
        'precioTotal': 300000,
      });

      expect(legacy.reprogramado, isFalse);
      expect(legacy.historialReprogramaciones, isEmpty);
      expect(legacy.parametrosAplicacion, isNull);
    });
  });

  group('Días no laborables y Mantenimiento de equipos', () {
    test('Genera ID determinístico YYYY-MM-DD y detecta conflictos', () {
      final diaNoLab = DiaNoLaborableModel(
        fecha: DateTime(2026, 11, 22),
        motivo: 'Domingo / Descanso',
        descripcion: 'Descanso del equipo',
      );
      expect(diaNoLab.id, '2026-11-22');

      final mantActivo = MantenimientoEquipoModel(
        id: 'm1',
        categoriaEquipo: 'DRON',
        nombreEquipo: 'DJI Agras T40',
        fechaInicio: DateTime(2026, 11, 22, 8, 0),
        fechaFin: DateTime(2026, 11, 24, 17, 0),
        tipoMantenimiento: 'Preventivo',
        estado: 'PENDIENTE',
      );

      final mantCompletado = MantenimientoEquipoModel(
        id: 'm2',
        categoriaEquipo: 'DRON',
        nombreEquipo: 'DJI Agras T30',
        fechaInicio: DateTime(2026, 11, 22, 8, 0),
        fechaFin: DateTime(2026, 11, 22, 18, 0),
        tipoMantenimiento: 'Correctivo',
        estado: 'COMPLETADO',
      );

      expect(mantActivo.esMultidia, isTrue);
      expect(mantActivo.cubreDia(DateTime(2026, 11, 23)), isTrue);

      final resultadoConConflicto = AgendaValidacionService.evaluarConflictos(
        fechaHoraVuelo: DateTime(2026, 11, 22, 10, 0),
        dronAsignado: 'DJI Agras T40',
        diasNoLaborables: [diaNoLab],
        mantenimientos: [mantActivo, mantCompletado],
      );

      expect(resultadoConConflicto.tieneAdvertencias, isTrue);
      expect(resultadoConConflicto.diaNoLaborable, isNotNull);
      expect(resultadoConConflicto.mantenimientosConflicto.length, 1);
      expect(resultadoConConflicto.mantenimientosConflicto.first.id, 'm1');

      final resultadoSinConflictoEquipo = AgendaValidacionService.evaluarConflictos(
        fechaHoraVuelo: DateTime(2026, 11, 25, 10, 0),
        dronAsignado: 'DJI Agras T30',
        diasNoLaborables: [diaNoLab],
        mantenimientos: [mantActivo, mantCompletado],
      );
      expect(resultadoSinConflictoEquipo.tieneAdvertencias, isFalse);
    });
  });

  group('Contabilidad — Categoría INTERESES', () {
    test('INTERESES está disponible como egreso y actualiza balance sin duplicar', () {
      expect(TransaccionModel.categoriasEgreso.contains('INTERESES'), isTrue);

      final movs = [
        TransaccionModel(
          tipo: 'INGRESO',
          categoria: 'SERVICIO',
          monto: 1000000,
          descripcion: 'Vuelo Arroz',
          fecha: DateTime(2026, 11, 18),
        ),
        TransaccionModel(
          tipo: 'EGRESO',
          categoria: 'INTERESES',
          monto: 85000,
          descripcion: 'Intereses crédito bancario',
          observaciones: 'Cuota noviembre',
          fecha: DateTime(2026, 11, 18),
        ),
      ];

      final restaurado = TransaccionModel.fromMap('t2', movs[1].toMap());
      expect(restaurado.categoria, 'INTERESES');
      expect(restaurado.tipo, 'EGRESO');
      expect(restaurado.observaciones, 'Cuota noviembre');

      final ingresos = movs.where((m) => m.tipo == 'INGRESO').fold<double>(0, (a, b) => a + b.monto);
      final egresos = movs.where((m) => m.tipo == 'EGRESO').fold<double>(0, (a, b) => a + b.monto);
      expect(ingresos - egresos, 915000);
    });
  });

  group('Personalización de paletas de colores', () {
    test('Cambia y persiste las 5 paletas en SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeController.instance.inicializar();
      expect(ThemeController.instance.paleta, PaletaApp.verdeAgricola);

      await ThemeController.instance.seleccionarPaleta(PaletaApp.azulTecnologico);
      expect(ThemeController.instance.paleta, PaletaApp.azulTecnologico);
      expect(ThemeController.instance.isDarkMode, isTrue);

      await ThemeController.instance.seleccionarPaleta(PaletaApp.modoClaro);
      expect(ThemeController.instance.isDarkMode, isFalse);

      await ThemeController.instance.configurarPersonalizado(
        primary: const Color(0xFF6366F1),
        secondary: const Color(0xFFFBBF24),
        esOscuro: true,
      );
      expect(ThemeController.instance.paleta, PaletaApp.personalizado);

      // Re-inicializar simulando reinicio de la app
      await ThemeController.instance.inicializar();
      expect(ThemeController.instance.paleta, PaletaApp.personalizado);
      expect(ThemeController.instance.customPrimary.toARGB32(), const Color(0xFF6366F1).toARGB32());
      expect(ThemeController.instance.customSecondary.toARGB32(), const Color(0xFFFBBF24).toARGB32());
      expect(ThemeController.instance.customDark, isTrue);
    });
  });

  group('Balances mensuales automáticos', () {
    test('Detecta el mes recién finalizado y meses anteriores pendientes sin duplicar', () {
      final ahora = DateTime(2026, 11, 1, 0, 5); // Recién inicia noviembre
      final pendientes = BalanceMensualAutoService.calcularMesesFinalizadosPendientes(
        ahora: ahora,
        fechasConActividad: [
          DateTime(2026, 8, 15),
          DateTime(2026, 9, 10),
          DateTime(2026, 11, 1), // Mes en curso: NO debe cerrarse aún
        ],
        cierresExistentes: {'2026-08'},
      );

      // Debe incluir septiembre (con actividad y sin cierre) y octubre (mes recién finalizado)
      expect(pendientes, [(2026, 9), (2026, 10)]);
    });

    test('Consolida ingresos, egresos (incluyendo INTERESES) y utilidad neta del mes', () {
      final cierre = BalanceMensualAutoService.construirCierreMensual(
        anio: 2026,
        mes: 10,
        todasTrans: [
          TransaccionModel(
            tipo: 'INGRESO',
            categoria: 'SERVICIO',
            monto: 800000,
            descripcion: 'Vuelo',
            fecha: DateTime(2026, 10, 12),
            metodoPago: 'BANCOLOMBIA',
          ),
          TransaccionModel(
            tipo: 'EGRESO',
            categoria: 'INTERESES',
            monto: 50000,
            descripcion: 'Intereses',
            fecha: DateTime(2026, 10, 20),
          ),
          // Movimiento de otro mes no debe mezclarse
          TransaccionModel(
            tipo: 'INGRESO',
            categoria: 'SERVICIO',
            monto: 500000,
            descripcion: 'Otro mes',
            fecha: DateTime(2026, 11, 2),
          ),
        ],
        todosServ: [],
      );

      expect(cierre.id, '2026-10');
      expect(cierre.totalIngresos, 800000);
      expect(cierre.totalEgresos, 50000);
      expect(cierre.utilidadNeta, 750000);
      expect(cierre.desgloseCategorias['INTERESES'], 50000);
    });
  });
}
