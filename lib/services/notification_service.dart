import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/servicio_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String canalOperacionesId = 'icaroproagro_operaciones';
  static const String canalVuelosId = 'icaroproagro_vuelos';

  Future<void> inicializar() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

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

      // Crear canales con máxima prioridad y solicitar permisos en Android
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();

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

  /// Programa una notificación para recordar un vuelo programado antes del despegue
  Future<void> programarRecordatorioVuelo(ServicioModel s) async {
    if (!_isInitialized) await inicializar();
    if (s.id == null) return;

    final id = s.id.hashCode;
    final now = DateTime.now();
    final fechaVuelo = s.fecha;

    if (fechaVuelo.isBefore(now)) return; // Vuelo ya pasado

    // Lógica adaptativa de recordatorio:
    // 1. Si faltan más de 2 horas: avisar 2 horas antes
    // 2. Si faltan entre 20 min y 2 horas: avisar 15 minutos antes
    // 3. Si falta menos: no programar alarma previa
    DateTime fechaAlerta;
    String tituloAlerta;

    final diferencia = fechaVuelo.difference(now);
    if (diferencia.inHours >= 2) {
      fechaAlerta = fechaVuelo.subtract(const Duration(hours: 2));
      tituloAlerta = '🚁 Vuelo Próximo en 2 Horas';
    } else if (diferencia.inMinutes >= 20) {
      fechaAlerta = fechaVuelo.subtract(const Duration(minutes: 15));
      tituloAlerta = '🚁 Despegue en 15 Minutos';
    } else {
      return;
    }

    if (fechaAlerta.isBefore(now)) return;

    try {
      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(fechaAlerta, tz.local);

      final String pilotoInfo = s.piloto.isNotEmpty ? ' • Piloto: ${s.piloto}' : '';
      final String dronInfo = s.dron.isNotEmpty ? ' • Dron: ${s.dron}' : '';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        canalVuelosId,
        'Recordatorios de Vuelo Icaro Proagro',
        channelDescription: 'Avisos previos a la operación de fumigación',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        tituloAlerta,
        '${s.clienteNombre} (${s.fincaUbicacion}) - ${s.hectareas} Ha de ${s.cultivo}$pilotoInfo$dronInfo',
        scheduledDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: s.id,
      );
    } catch (e) {
      debugPrint('Error programando recordatorio de vuelo: $e');
    }
  }

  /// Cancela la notificación programada si se cancela o elimina el servicio
  Future<void> cancelarRecordatorioVuelo(String servicioId) async {
    try {
      await _notificationsPlugin.cancel(servicioId.hashCode);
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

