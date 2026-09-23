import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version_model.dart';

class UpdateService {
  static const String _coleccionConfig = 'app_config';
  static const String _docActualizacion = 'actualizacion';

  // Caché de información de versión local
  static String _versionLocal = '1.0.0';
  static int _buildNumberLocal = 1;
  static bool _infoCargada = false;

  /// Obtiene la versión actual instalada en el dispositivo
  static Future<void> cargarInfoLocal() async {
    if (_infoCargada) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _versionLocal = info.version.isNotEmpty ? info.version : '1.0.0';
      _buildNumberLocal = int.tryParse(info.buildNumber) ?? 1;
      _infoCargada = true;
    } catch (e) {
      debugPrint('Error cargando PackageInfo: $e');
      _versionLocal = '1.0.0';
      _buildNumberLocal = 1;
    }
  }

  static String get versionLocal => _versionLocal;
  static int get buildNumberLocal => _buildNumberLocal;
  static String get versionCompletaLocal => 'v$_versionLocal+$_buildNumberLocal';

  /// Consulta en Firestore si existe una nueva versión configurada
  static Future<AppVersionModel?> obtenerInfoRemota() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection(_coleccionConfig)
          .doc(_docActualizacion)
          .get();

      if (!docSnap.exists || docSnap.data() == null) {
        // Inicializar documento por defecto en Firestore para facilitar administración
        final modeloInicial = AppVersionModel(
          version: _versionLocal,
          buildNumber: _buildNumberLocal,
          apkUrl: '',
          novedades: 'Versión inicial de Icaro Proagro.',
          obligatoria: false,
          habilitada: true,
          fecha: DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection(_coleccionConfig)
            .doc(_docActualizacion)
            .set(modeloInicial.toMap());
        return modeloInicial;
      }

      return AppVersionModel.fromMap(docSnap.data()!);
    } catch (e) {
      debugPrint('Error al consultar actualización remota: $e');
      return null;
    }
  }

  /// Determina si la versión remota es superior a la instalada localmente
  static bool esVersionSuperior({
    required String versionRemota,
    required int buildRemoto,
    required String versionLocal,
    required int buildLocal,
  }) {
    if (buildRemoto > buildLocal) return true;
    if (buildRemoto < buildLocal) return false;

    // Comparación semántica (ej. 1.1.0 vs 1.0.0)
    final partesRemotas = versionRemota.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final partesLocales = versionLocal.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    while (partesRemotas.length < 3) {
      partesRemotas.add(0);
    }
    while (partesLocales.length < 3) {
      partesLocales.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (partesRemotas[i] > partesLocales[i]) return true;
      if (partesRemotas[i] < partesLocales[i]) return false;
    }

    return false;
  }

  /// Verifica si hay una actualización pendiente
  static Future<AppVersionModel?> verificarSiHayActualizacion() async {
    await cargarInfoLocal();
    final remota = await obtenerInfoRemota();
    if (remota == null || !remota.habilitada || remota.apkUrl.trim().isEmpty) {
      return null;
    }

    final hayNueva = esVersionSuperior(
      versionRemota: remota.version,
      buildRemoto: remota.buildNumber,
      versionLocal: _versionLocal,
      buildLocal: _buildNumberLocal,
    );

    return hayNueva ? remota : null;
  }

  /// Inicia el flujo de descarga e instalación con ota_update
  static Stream<OtaEvent>? descargarEInstalarOta(String apkUrl) {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return OtaUpdate().execute(
        apkUrl,
        destinationFilename: 'IcaroProagro_update.apk',
        androidProviderAuthority: 'com.example.drones_fumigacion_app.ota_update_provider',
      );
    } catch (e) {
      debugPrint('Error iniciando OtaUpdate: $e');
      return null;
    }
  }

  /// Descarga el APK usando el navegador externo como método de respaldo
  static Future<bool> descargarPorNavegador(String apkUrl) async {
    try {
      final uri = Uri.parse(apkUrl.trim());
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error abriendo enlace en navegador: $e');
    }
    return false;
  }

  /// Guarda una nueva versión en Firestore (Panel Administrador)
  static Future<void> guardarNuevaVersionRemota(AppVersionModel modelo) async {
    await FirebaseFirestore.instance
        .collection(_coleccionConfig)
        .doc(_docActualizacion)
        .set(modelo.toMap(), SetOptions(merge: true));
  }
}
