import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/servicio_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _puedeAlarmaExacta = true;

  /// Suscripción en tiempo real a los vuelos para mantener los recordatorios
  /// sincronizados en todos los dispositivos que usan la app.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subVuelos;

  /// Firma (estado+fecha+cliente) del último recordatorio programado por vuelo,
  /// para no reprogramar en cada snapshot si nada cambió.
  final Map<String, String> _firmasProgramadas = {};

  static const String canalOperacionesId = 'icaroproagro_operaciones';
  static const String canalVuelosId = 'icaroproagro_vuelos';

  /// Minutos de anticipación del recordatorio principal.
  static const int minutosAnticipacion = 60;

  Future<void> inicializar() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Bogota'));
      } catch (_) {}

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notificación tocada: ${details.payload}');
        },
      );

      // Crear canales con máxima prioridad (los permisos se piden luego,
      // sin bloquear el arranque de la app)
      final androidImplementation = _android;
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            canalOperacionesId,
            'Operaciones Icaro Proagro',
            description: 'Alertas inmediatas, confirmaciones de vuelos y pagos',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            canalVuelosId,
            'Recordatorios de Vuelo Icaro Proagro',
            description: 'Avisos previos a la operación de fumigación agrícola',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error inicializando NotificationService: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Solicita permisos de notificación y de alarmas exactas.
  /// El ajuste de alarmas exactas solo se abre una vez para no molestar al usuario.
  Future<void> solicitarPermisos() async {
    if (!_isInitialized) await inicializar();
    final android = _android;
    if (android == null) return;
    try {
      await android.requestNotificationsPermission();

      _puedeAlarmaExacta = await android.canScheduleExactNotifications() ?? true;
      if (!_puedeAlarmaExacta) {
        final prefs = await SharedPreferences.getInstance();
        final yaSolicitado = prefs.getBool('icaro_permiso_alarma_exacta_solicitado') ?? false;
        if (!yaSolicitado) {
          await prefs.setBool('icaro_permiso_alarma_exacta_solicitado', true);
          await android.requestExactAlarmsPermission();
          _puedeAlarmaExacta = await android.canScheduleExactNotifications() ?? false;
        }
      }
    } catch (e) {
      debugPrint('Error solicitando permisos de notificación: $e');
    }
  }

  /// Escucha en tiempo real los vuelos futuros de Firestore y programa/cancela
  /// los recordatorios en este dispositivo. Así TODOS los usuarios de la app
  /// reciben el aviso, no solo quien agendó el vuelo.
  void iniciarSincronizacionRecordatorios() {
    if (_subVuelos != null) return;
    final desde = DateTime.now().subtract(const Duration(hours: 2));
    _subVuelos = FirebaseFirestore.instance
        .collection('servicios')
        .where('fecha', isGreaterThanOrEqualTo: desde.toIso8601String())
        .snapshots()
        .listen(
      (snap) async {
        for (final change in snap.docChanges) {
          final id = change.doc.id;
          if (change.type == DocumentChangeType.removed) {
            await cancelarRecordatorioVuelo(id);
            continue;
          }
          final data = change.doc.data();
          if (data == null) continue;
          await programarRecordatorioVuelo(ServicioModel.fromMap(id, data));
        }
      },
      onError: (e) => debugPrint('Error sincronizando recordatorios: $e'),
    );
  }

  Future<void> detenerSincronizacionRecordatorios() async {
    await _subVuelos?.cancel();
    _subVuelos = null;
  }

  /// ID estable (FNV-1a de 31 bits) para que todos los dispositivos y
  /// reinicios usen el mismo identificador por vuelo.
  static int _idEstable(String texto) {
    int hash = 0x811c9dc5;
    for (final c in texto.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static int _idPrevio(String servicioId) => _idEstable('previo_$servicioId');
  static int _idDespegue(String servicioId) => _idEstable('despegue_$servicioId');

  /// Muestra una notificación inmediata en el dispositivo con alta prioridad
  Future<void> mostrarNotificacionInmediata({
    required int id,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    if (!_isInitialized) await inicializar();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      canalOperacionesId,
      'Operaciones Icaro Proagro',
      channelDescription: 'Alertas inmediatas y confirmaciones de vuelo',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notificationsPlugin.show(
        id,
        titulo,
        cuerpo,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error al mostrar notificación: $e');
    }
  }

  /// Notifica inmediatamente la creación de un nuevo vuelo agendado
  Future<void> notificarNuevoVuelo(ServicioModel s) async {
    final horaStr = DateFormat('dd/MM/yyyy hh:mm a').format(s.fecha);
    await mostrarNotificacionInmediata(
      id: (s.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 100000,
      titulo: '🚁 Vuelo Agendado en Icaro Proagro',
      cuerpo: '${s.clienteNombre} (${s.fincaUbicacion}) • ${s.hectareas} Ha de ${s.cultivo} para el $horaStr',
      payload: s.id,
    );
  }

  /// Notifica la reprogramación de un vuelo
  Future<void> notificarReprogramacionVuelo(ServicioModel s, String motivo) async {
    final horaStr = DateFormat('dd/MM/yyyy hh:mm a').format(s.fecha);
    await mostrarNotificacionInmediata(
      id: ((s.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch) + 1) % 100000,
      titulo: '📅 Vuelo Reprogramado - Icaro Proagro',
      cuerpo: '${s.clienteNombre} se trasladó al $horaStr ($motivo)',
      payload: s.id,
    );
  }

  /// Notifica el registro de un abono o pago
  Future<void> notificarAbonoRegistrado({
    required String cliente,
    required double monto,
    required double saldo,
  }) async {
    final format = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final saldoStr = saldo <= 0 ? '¡Servicio 100% Pagado!' : 'Saldo restante: ${format.format(saldo)}';
    await mostrarNotificacionInmediata(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      titulo: '💵 Abono Registrado - Icaro Proagro',
      cuerpo: '$cliente abonó ${format.format(monto)}. $saldoStr',
    );
  }

  /// Envía una notificación de prueba para verificar funcionamiento en el dispositivo
  Future<void> enviarNotificacionPrueba() async {
    await mostrarNotificacionInmediata(
      id: 99999,
      titulo: '✅ Notificaciones Icaro Proagro Activas',
      cuerpo: 'El sistema de alertas y recordatorios de vuelos en tiempo real está funcionando correctamente.',
    );
  }

  static const NotificationDetails _detallesVuelo = NotificationDetails(
    android: AndroidNotificationDetails(
      canalVuelosId,
      'Recordatorios de Vuelo Icaro Proagro',
      channelDescription: 'Avisos previos a la operación de fumigación',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> _agendar(int id, String titulo, String cuerpo, DateTime fecha, String? payload) async {
    final scheduledDate = tz.TZDateTime.from(fecha, tz.local);
    Future<void> intentar(AndroidScheduleMode modo) => _notificationsPlugin.zonedSchedule(
          id,
          titulo,
          cuerpo,
          scheduledDate,
          _detallesVuelo,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: modo,
          payload: payload,
        );
    try {
      await intentar(_puedeAlarmaExacta
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (e) {
      // Si el sistema no permite alarmas exactas, usar modo inexacto como respaldo
      debugPrint('Alarma exacta no disponible, usando modo inexacto: $e');
      _puedeAlarmaExacta = false;
      await intentar(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Programa los recordatorios de un vuelo:
  /// 1. Aviso 1 hora antes (o 15 min antes si se agenda con poca anticipación).
  /// 2. Aviso a la hora exacta del despegue.
  /// Si el vuelo ya no está PROGRAMADO, cancela sus recordatorios.
  Future<void> programarRecordatorioVuelo(ServicioModel s) async {
    if (!_isInitialized) await inicializar();
    final servicioId = s.id;
    if (servicioId == null) return;

    final now = DateTime.now();
    final fechaVuelo = s.fecha;

    if (s.estado != 'PROGRAMADO' || !fechaVuelo.isAfter(now)) {
      await cancelarRecordatorioVuelo(servicioId);
      return;
    }

    // Evitar reprogramar si nada relevante cambió
    final firma = '${s.estado}|${fechaVuelo.toIso8601String()}|${s.clienteNombre}|${s.piloto}|${s.hectareas}';
    if (_firmasProgramadas[servicioId] == firma) return;

    await cancelarRecordatorioVuelo(servicioId);

    final horaStr = DateFormat('hh:mm a', 'es_CO').format(fechaVuelo);
    final pilotoInfo = s.piloto.isNotEmpty ? ' • Piloto: ${s.piloto}' : '';
    final dronInfo = s.dron.isNotEmpty ? ' • ${s.dron}' : '';
    final detalle = '${s.clienteNombre} (${s.fincaUbicacion}) • ${s.hectareas} Ha de ${s.cultivo}$pilotoInfo$dronInfo';

    try {
      // 1. Aviso previo
      final restante = fechaVuelo.difference(now);
      DateTime? fechaPrevia;
      String tituloPrevio = '';
      if (restante.inMinutes > minutosAnticipacion) {
        fechaPrevia = fechaVuelo.subtract(const Duration(minutes: minutosAnticipacion));
        tituloPrevio = '🚁 Vuelo en 1 hora ($horaStr)';
      } else if (restante.inMinutes > 20) {
        fechaPrevia = fechaVuelo.subtract(const Duration(minutes: 15));
        tituloPrevio = '🚁 Despegue en 15 minutos ($horaStr)';
      }
      if (fechaPrevia != null && fechaPrevia.isAfter(now)) {
        await _agendar(_idPrevio(servicioId), tituloPrevio, 'Tienes programación: $detalle', fechaPrevia, servicioId);
      }

      // 2. Aviso a la hora del vuelo
      await _agendar(_idDespegue(servicioId), '⏰ Es hora del vuelo ($horaStr)', detalle, fechaVuelo, servicioId);

      _firmasProgramadas[servicioId] = firma;
    } catch (e) {
      debugPrint('Error programando recordatorio de vuelo: $e');
    }
  }

  /// Cancela las notificaciones programadas si se cancela, completa o elimina el servicio
  Future<void> cancelarRecordatorioVuelo(String servicioId) async {
    _firmasProgramadas.remove(servicioId);
    try {
      await _notificationsPlugin.cancel(_idPrevio(servicioId));
      await _notificationsPlugin.cancel(_idDespegue(servicioId));
      // Compatibilidad con recordatorios creados por versiones anteriores
      await _notificationsPlugin.cancel(servicioId.hashCode & 0x7fffffff);
    } catch (e) {
      debugPrint('Error cancelando notificación: $e');
    }
  }

  /// Alias para cancelación de recordatorio
  Future<void> cancelarRecordatorio(String servicioId) => cancelarRecordatorioVuelo(servicioId);

  /// Notifica sobre cartera pendiente o cliente con días sin pagar
  Future<void> notificarCuentaRegresivaMora({
    required String cliente,
    required int diasMora,
    required double saldo,
  }) async {
    final format = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    await mostrarNotificacionInmediata(
      id: ('mora_${cliente}_$diasMora'.hashCode) % 100000,
      titulo: '⚠️ Alerta de Cartera: $cliente ($diasMora días)',
      cuerpo: 'Lleva $diasMora días sin pagar un saldo de ${format.format(saldo)}.',
    );
  }

  /// Revisa servicios completados sin liquidar con mora >= 7 días y dispara alertas locales
  Future<void> verificarYNotificarMorosos(List<ServicioModel> servicios) async {
    final morosos = servicios.where((s) =>
        s.estado == 'COMPLETADO' &&
        s.estadoPago != 'PAGADO' &&
        s.saldoPendiente > 0 &&
        s.diasMora >= 7).toList();

    if (morosos.isEmpty) return;

    final format = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    if (morosos.length == 1) {
      final s = morosos.first;
      await notificarCuentaRegresivaMora(
        cliente: s.clienteNombre,
        diasMora: s.diasMora,
        saldo: s.saldoPendiente,
      );
    } else {
      final totalDeuda = morosos.fold<double>(0.0, (acc, s) => acc + s.saldoPendiente);
      await mostrarNotificacionInmediata(
        id: 77777,
        titulo: '🔔 Recordatorio de Cobros: ${morosos.length} Clientes en Mora',
        cuerpo: 'Hay ${format.format(totalDeuda)} pendientes por cobrar con más de una semana de retraso.',
      );
    }
  }
}

