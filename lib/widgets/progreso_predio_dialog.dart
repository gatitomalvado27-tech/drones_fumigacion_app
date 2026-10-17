import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/progreso_predio_model.dart';
import '../services/pdf_service.dart';
import '../theme/agro_theme.dart';

class ProgresoPredioDialog extends StatefulWidget {
  final String clienteId;
  final String clienteNombre;
  final String clienteCedula;
  final String fincaUbicacion;
  final String cultivoInicial;
  final String? servicioId;
  final String pilotoInicial;

  const ProgresoPredioDialog({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteCedula = '',
    required this.fincaUbicacion,
    this.cultivoInicial = '',
    this.servicioId,
    this.pilotoInicial = '',
  });

  static Future<void> mostrar(
    BuildContext context, {
    required String clienteId,
    required String clienteNombre,
    String clienteCedula = '',
    required String fincaUbicacion,
    String cultivoInicial = '',
    String? servicioId,
    String pilotoInicial = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AgroTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (_, scrollCtrl) => ProgresoPredioDialog(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
          clienteCedula: clienteCedula,
          fincaUbicacion: fincaUbicacion,
          cultivoInicial: cultivoInicial,
          servicioId: servicioId,
          pilotoInicial: pilotoInicial,
        ),
      ),
    );
  }

  @override
  State<ProgresoPredioDialog> createState() => _ProgresoPredioDialogState();
}

class _ProgresoPredioDialogState extends State<ProgresoPredioDialog> {
  final ImagePicker _picker = ImagePicker();
  String _filtroEtapa = 'TODAS';

  Color _colorEtapa(String etapa) {
    switch (etapa) {
      case 'PRE_VUELO':
        return Colors.amberAccent;
      case 'DURANTE':
        return Colors.lightBlueAccent;
      case 'POST_APLICACION':
      default:
        return AgroTheme.lightPrimary;
    }
  }

  IconData _iconoEtapa(String etapa) {
    switch (etapa) {
      case 'PRE_VUELO':
        return Icons.search_rounded;
      case 'DURANTE':
        return Icons.airplanemode_active_rounded;
      case 'POST_APLICACION':
      default:
        return Icons.eco_rounded;
    }
  }

  void _verImagenCompleta(BuildContext context, String base64Str, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(14),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.memory(
                base64Decode(base64Str),
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarFormularioNuevoRegistro(BuildContext context) async {
    String etapa = 'POST_APLICACION';
    final fincaCtrl = TextEditingController(text: widget.fincaUbicacion);
    final cultivoCtrl = TextEditingController(text: widget.cultivoInicial);
    final obsCtrl = TextEditingController();
    final List<String> fotosBase64 = [];
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> agregarFoto(ImageSource source) async {
            if (fotosBase64.length >= 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Máximo 4 fotos por registro para mantener fluidez')),
              );
              return;
            }
            try {
              final XFile? picked = await _picker.pickImage(
                source: source,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 72,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              setDlgState(() {
                fotosBase64.add(base64Encode(bytes));
              });
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error al capturar foto: $e')),
                );
              }
            }
          }

          return AlertDialog(
            backgroundColor: AgroTheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.add_a_photo_rounded, color: AgroTheme.lightPrimary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Registrar Progreso del Predio',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Etapa del Seguimiento Agronómico:',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'PRE_VUELO',
                        label: Text('Antes', style: TextStyle(fontSize: 11)),
                        icon: Icon(Icons.search, size: 15),
                      ),
                      ButtonSegment(
                        value: 'DURANTE',
                        label: Text('Durante', style: TextStyle(fontSize: 11)),
                        icon: Icon(Icons.airplanemode_active, size: 15),
                      ),
                      ButtonSegment(
                        value: 'POST_APLICACION',
                        label: Text('Evolución', style: TextStyle(fontSize: 11)),
                        icon: Icon(Icons.eco, size: 15),
                      ),
                    ],
                    selected: {etapa},
                    onSelectionChanged: (val) {
                      setDlgState(() => etapa = val.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fincaCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Predio / Lote / Ubicación',
                      prefixIcon: Icon(Icons.landscape_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cultivoCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Cultivo (Ej. Arroz, Maíz, Caña)',
                      prefixIcon: Icon(Icons.grass_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: obsCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Observaciones de evolución / estado del cultivo',
                      hintText: 'Ej. Excelente control de maleza a los 8 días post-aplicación...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => agregarFoto(ImageSource.camera),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AgroTheme.lightPrimary),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, color: AgroTheme.lightPrimary, size: 18),
                          label: const Text('Cámara', style: TextStyle(color: AgroTheme.lightPrimary, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => agregarFoto(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.lightBlueAccent),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.lightBlueAccent, size: 18),
                          label: const Text('Galería', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (fotosBase64.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 85,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotosBase64.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(fotosBase64[idx]),
                                  width: 85,
                                  height: 85,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setDlgState(() => fotosBase64.removeAt(idx));
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgroTheme.lightPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: guardando
                    ? null
                    : () async {
                        if (fotosBase64.isEmpty && obsCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Agrega al menos una foto o una observación')),
                          );
                          return;
                        }
                        setDlgState(() => guardando = true);
                        final nuevo = ProgresoPredioModel(
                          clienteId: widget.clienteId,
                          clienteNombre: widget.clienteNombre,
                          clienteCedula: widget.clienteCedula,
                          fincaUbicacion: fincaCtrl.text.trim().isEmpty
                              ? widget.fincaUbicacion
                              : fincaCtrl.text.trim(),
                          cultivo: cultivoCtrl.text.trim(),
                          servicioId: widget.servicioId,
                          fecha: DateTime.now(),
                          etapa: etapa,
                          fotosBase64: fotosBase64,
                          observaciones: obsCtrl.text.trim(),
                          piloto: widget.pilotoInicial,
                        );
                        await FirebaseFirestore.instance
                            .collection('progreso_predios')
                            .add(nuevo.toMap());
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar Avance'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busqNombre = widget.clienteNombre.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('progreso_predios')
                .orderBy('fecha', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final allDocs = snapshot.data?.docs ?? [];
              final registrosCliente = allDocs
                  .map((d) => ProgresoPredioModel.fromMap(d.id, d.data() as Map<String, dynamic>))
                  .where((r) =>
                      (widget.clienteId.isNotEmpty && r.clienteId == widget.clienteId) ||
                      r.clienteNombre.trim().toLowerCase() == busqNombre)
                  .toList();

              final filtrados = _filtroEtapa == 'TODAS'
                  ? registrosCliente
                  : registrosCliente.where((r) => r.etapa == _filtroEtapa).toList();

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AgroTheme.lightPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.photo_camera_back_rounded, color: AgroTheme.lightPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progreso del Predio • ${widget.clienteNombre}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '📍 ${widget.fincaUbicacion} • ${registrosCliente.length} registro(s)',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (registrosCliente.isNotEmpty)
                          IconButton(
                            tooltip: 'Exportar Informe PDF Firmado',
                            onPressed: () {
                              PdfService.generarYCompartirProgresoPredioPdf(
                                clienteNombre: widget.clienteNombre,
                                clienteCedula: widget.clienteCedula,
                                fincaUbicacion: widget.fincaUbicacion,
                                registros: registrosCliente,
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.amberAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChipFiltro('TODAS', 'Todas (${registrosCliente.length})'),
                          const SizedBox(width: 6),
                          _buildChipFiltro('PRE_VUELO', '🔍 Antes / Diagnóstico'),
                          const SizedBox(width: 6),
                          _buildChipFiltro('DURANTE', '🚁 Durante Vuelo'),
                          const SizedBox(width: 6),
                          _buildChipFiltro('POST_APLICACION', '🌱 Evolución Post-Vuelo'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.collections_bookmark_outlined,
                                    size: 52,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Aún no hay fotos de progreso para este predio.\nToma fotos antes, durante o después de fumigar\npara documentar la evolución del cultivo.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtrados.length,
                              itemBuilder: (ctx, i) {
                                final r = filtrados[i];
                                final color = _colorEtapa(r.etapa);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AgroTheme.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: color.withValues(alpha: 0.35)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_iconoEtapa(r.etapa), size: 13, color: color),
                                                const SizedBox(width: 4),
                                                Text(
                                                  r.etapaLabel,
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (r.cultivo.isNotEmpty)
                                            Text(
                                              '🌾 ${r.cultivo}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('dd/MM/yyyy hh:mm a').format(r.fecha),
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () async {
                                              if (r.id != null) {
                                                await FirebaseFirestore.instance
                                                    .collection('progreso_predios')
                                                    .doc(r.id)
                                                    .delete();
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (r.fincaUbicacion.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '📍 Lote / Predio: ${r.fincaUbicacion}',
                                          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                        ),
                                      ],
                                      if (r.observaciones.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          r.observaciones,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      ],
                                      if (r.fotosBase64.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 115,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: r.fotosBase64.length,
                                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                                            itemBuilder: (_, fIdx) {
                                              final b64 = r.fotosBase64[fIdx];
                                              return GestureDetector(
                                                onTap: () => _verImagenCompleta(context, b64, r.etapaLabel),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    base64Decode(b64),
                                                    width: 145,
                                                    height: 115,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AgroTheme.lightPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _mostrarFormularioNuevoRegistro(context),
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: const Text(
                          'Tomar / Agregar Fotos de Progreso',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String valor, String label) {
    final sel = _filtroEtapa == valor;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: sel ? Colors.white : Colors.white70)),
      selected: sel,
      selectedColor: AgroTheme.lightPrimary,
      backgroundColor: AgroTheme.background,
      onSelected: (_) => setState(() => _filtroEtapa = valor),
    );
  }
}
