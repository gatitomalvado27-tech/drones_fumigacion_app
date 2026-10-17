import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/agro_theme.dart';

class FirmaDigitalDialog extends StatefulWidget {
  final String? firmaActualBase64;
  final String nombrePiloto;

  const FirmaDigitalDialog({
    super.key,
    this.firmaActualBase64,
    required this.nombrePiloto,
  });

  @override
  State<FirmaDigitalDialog> createState() => _FirmaDigitalDialogState();
}

class _FirmaDigitalDialogState extends State<FirmaDigitalDialog> {
  final List<List<Offset>> _trazos = [];
  List<Offset> _trazoActual = [];
  String? _firmaSubidaBase64;
  bool _procesando = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _firmaSubidaBase64 = widget.firmaActualBase64;
  }

  void _limpiar() {
    setState(() {
      _trazos.clear();
      _trazoActual = [];
      _firmaSubidaBase64 = null;
    });
  }

  Future<void> _subirImagenFirma() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 300,
        imageQuality: 85,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      setState(() {
        _trazos.clear();
        _trazoActual = [];
        _firmaSubidaBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar imagen: $e')),
        );
      }
    }
  }

  Future<String?> _renderizarTramoABase64(Size canvasSize) async {
    if (_trazos.isEmpty) return _firmaSubidaBase64;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );

    final paint = Paint()
      ..color = const Color(0xFF0A2463) // Azul tinta oscura profesional para PDF
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    for (final trazo in _trazos) {
      if (trazo.length < 2) {
        if (trazo.isNotEmpty) {
          canvas.drawCircle(
            trazo.first,
            1.8,
            Paint()..color = const Color(0xFF0A2463),
          );
        }
        continue;
      }
      final path = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (int i = 1; i < trazo.length; i++) {
        path.lineTo(trazo[i].dx, trazo[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasSize.width.toInt().clamp(100, 800),
      canvasSize.height.toInt().clamp(60, 400),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return base64Encode(pngBytes);
  }

  @override
  Widget build(BuildContext context) {
    const canvasSize = Size(340, 170);

    return AlertDialog(
      backgroundColor: AgroTheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AgroTheme.lightPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.draw_rounded,
              color: AgroTheme.lightPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firma Digital de Operario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.nombrePiloto.isEmpty
                      ? 'Aparecerá en los PDFs oficiales'
                      : widget.nombrePiloto,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dibuja la firma con el dedo sobre el recuadro blanco o sube una imagen de la firma:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              width: canvasSize.width,
              height: canvasSize.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AgroTheme.lightPrimary.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Línea guía de firma
                    Positioned(
                      bottom: 34,
                      left: 24,
                      right: 24,
                      child: Column(
                        children: [
                          Container(
                            height: 1,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'FIRMA AUTORIZADA',
                            style: TextStyle(
                              color: Colors.black38,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_trazos.isEmpty && _firmaSubidaBase64 != null)
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Image.memory(
                          base64Decode(_firmaSubidaBase64!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _firmaSubidaBase64 = null;
                          _trazoActual = [details.localPosition];
                          _trazos.add(_trazoActual);
                        });
                      },
                      onPanUpdate: (details) {
                        final pos = details.localPosition;
                        if (pos.dx >= 0 &&
                            pos.dx <= canvasSize.width &&
                            pos.dy >= 0 &&
                            pos.dy <= canvasSize.height) {
                          setState(() {
                            _trazoActual.add(pos);
                          });
                        }
                      },
                      onPanEnd: (_) {
                        setState(() {
                          _trazoActual = [];
                        });
                      },
                      child: CustomPaint(
                        size: canvasSize,
                        painter: _SignaturePainter(trazos: _trazos),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _limpiar,
                  icon: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  label: const Text(
                    'Limpiar',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _subirImagenFirma,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                  ),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.amberAccent,
                    size: 16,
                  ),
                  label: const Text(
                    'Galería',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AgroTheme.lightPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _procesando
              ? null
              : () async {
                  setState(() => _procesando = true);
                  final base64Str = await _renderizarTramoABase64(canvasSize);
                  if (context.mounted) {
                    Navigator.pop(context, base64Str ?? '');
                  }
                },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Guardar Firma'),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> trazos;

  _SignaturePainter({required this.trazos});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A2463)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length < 2) {
        if (trazo.isNotEmpty) {
          canvas.drawCircle(
            trazo.first,
            1.8,
            Paint()..color = const Color(0xFF0A2463),
          );
        }
        continue;
      }
      final path = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (int i = 1; i < trazo.length; i++) {
        path.lineTo(trazo[i].dx, trazo[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
