import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../models/app_version_model.dart';
import '../services/update_service.dart';
import '../theme/agro_theme.dart';

class UpdateDialog extends StatefulWidget {
  final AppVersionModel versionRemota;

  const UpdateDialog({
    super.key,
    required this.versionRemota,
  });

  static Future<void> mostrar(BuildContext context, AppVersionModel versionRemota) {
    return showDialog(
      context: context,
      barrierDismissible: !versionRemota.obligatoria,
      builder: (ctx) => UpdateDialog(versionRemota: versionRemota),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _descargando = false;
  int _progreso = 0;
  String _estadoTexto = 'Preparando descarga...';
  String? _errorMensaje;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _iniciarActualizacion() {
    setState(() {
      _descargando = true;
      _progreso = 0;
      _errorMensaje = null;
      _estadoTexto = 'Conectando con el servidor...';
    });

    final otaStream = UpdateService.descargarEInstalarOta(widget.versionRemota.apkUrl);

    if (otaStream == null) {
      // Si no es Android o no soporta OTA directo, descargar por navegador
      _abrirEnNavegador();
      return;
    }

    _otaSubscription = otaStream.listen(
      (OtaEvent event) {
        if (!mounted) return;
        setState(() {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final val = int.tryParse(event.value ?? '0') ?? 0;
              _progreso = val.clamp(0, 100);
              _estadoTexto = 'Descargando actualización: $_progreso%';
              break;
            case OtaStatus.INSTALLING:
              _progreso = 100;
              _estadoTexto = 'Abriendo instalador de Icaro Proagro...';
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _errorMensaje = 'Ya hay una descarga en curso.';
              _descargando = false;
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _errorMensaje = 'Permiso no concedido para instalar aplicaciones desconocidas.';
              _descargando = false;
              break;
            case OtaStatus.INTERNAL_ERROR:
              _errorMensaje = 'Error interno al procesar el archivo APK.';
              _descargando = false;
              break;
            default:
              break;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _descargando = false;
          _errorMensaje = 'No se pudo descargar automáticamente: $e';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _descargando = false;
        });
      },
    );
  }

  void _abrirEnNavegador() async {
    final ok = await UpdateService.descargarPorNavegador(widget.versionRemota.apkUrl);
    if (!ok && mounted) {
      setState(() {
        _errorMensaje = 'No se pudo abrir el enlace de descarga.';
        _descargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return PopScope(
      canPop: !widget.versionRemota.obligatoria && !_descargando,
      child: AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.system_update_rounded, color: primary, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              '¡Actualización Disponible!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Versión ${widget.versionRemota.version} (Build ${widget.versionRemota.buildNumber})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Novedades y mejoras:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.versionRemota.novedades.isNotEmpty
                        ? widget.versionRemota.novedades
                        : '• Optimizaciones de rendimiento y estabilidad.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (_descargando) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progreso > 0 ? _progreso / 100 : null,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _estadoTexto,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      '$_progreso%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                    ),
                  ],
                ),
              ],
              if (_errorMensaje != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AgroTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AgroTheme.error, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMensaje!,
                          style: const TextStyle(fontSize: 11, color: AgroTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          if (!_descargando && !widget.versionRemota.obligatoria)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Más tarde'),
            ),
          if (!_descargando)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Actualizar Ahora'),
              onPressed: _iniciarActualizacion,
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Descargar vía Navegador'),
              onPressed: _abrirEnNavegador,
            ),
        ],
      ),
    );
  }
}
