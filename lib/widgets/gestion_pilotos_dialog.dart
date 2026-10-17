import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/piloto_model.dart';
import '../theme/agro_theme.dart';
import 'firma_digital_dialog.dart';

class GestionPilotosDialog extends StatefulWidget {
  const GestionPilotosDialog({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const GestionPilotosDialog(),
    );
  }

  @override
  State<GestionPilotosDialog> createState() => _GestionPilotosDialogState();
}

class _GestionPilotosDialogState extends State<GestionPilotosDialog> {
  static const List<String> coloresDisponibles = [
    '#1E88E5', // Azul
    '#7E57C2', // Violeta
    '#00897B', // Verde Azulado
    '#FB8C00', // Naranja
    '#E91E63', // Magenta
    '#00ACC1', // Cian
    '#3949AB', // Índigo
    '#43A047', // Verde
    '#8D6E63', // Café
    '#F4511E', // Rojo Intenso
  ];

  @override
  Widget build(BuildContext context) {
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final primary = AgroTheme.getPrimary(context);
    final border = AgroTheme.getBorder(context);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 610),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.badge_outlined, color: primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilotos y Operadores',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                          Text(
                            'Personal, colores y firma digital para PDFs',
                            style: TextStyle(fontSize: 11, color: subtext),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // LISTA DE PILOTOS EN FIRESTORE
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('pilotos').snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final pilotos = docs.map((d) {
                      return PilotoModel.fromMap(d.id, d.data() as Map<String, dynamic>);
                    }).toList();

                    if (pilotos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined, size: 40, color: subtext.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'No hay pilotos registrados aún.\nAgrega uno para asignarle color y firma digital.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subtext, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: pilotos.length,
                      itemBuilder: (context, index) {
                        final p = pilotos[index];
                        final tieneFirma = p.firmaBase64 != null && p.firmaBase64!.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: p.color,
                                child: Text(
                                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.nombre,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: text,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tieneFirma
                                                ? Colors.green.withValues(alpha: 0.18)
                                                : Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tieneFirma ? '✓ Firmado' : 'Sin firma',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: tieneFirma ? Colors.greenAccent : Colors.amberAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.cedula.isNotEmpty || p.telefono.isNotEmpty)
                                      Text(
                                        [
                                          if (p.cedula.isNotEmpty) 'C.C. ${p.cedula}',
                                          if (p.telefono.isNotEmpty) p.telefono,
                                        ].join(' • '),
                                        style: TextStyle(fontSize: 11, color: subtext),
                                      ),
                                  ],
                                ),
                              ),
                              Tooltip(
                                message: 'Configurar Firma Digital PDF',
                                child: IconButton(
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.draw_rounded,
                                    size: 18,
                                    color: tieneFirma ? Colors.greenAccent : Colors.amberAccent,
                                  ),
                                  onPressed: () async {
                                    final nuevaFirma = await showDialog<String>(
                                      context: context,
                                      builder: (_) => FirmaDigitalDialog(
                                        firmaActualBase64: p.firmaBase64,
                                        nombrePiloto: p.nombre,
                                      ),
                                    );
                                    if (nuevaFirma != null && p.id != null) {
                                      await FirebaseFirestore.instance
                                          .collection('pilotos')
                                          .doc(p.id)
                                          .update({
                                        'firmaBase64': nuevaFirma.isEmpty ? null : nuevaFirma,
                                      });
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.edit_outlined, size: 18, color: subtext),
                                onPressed: () => _mostrarFormularioPiloto(context, p),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('pilotos').doc(p.id).delete();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text(
                    'Registrar Nuevo Piloto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _mostrarFormularioPiloto(context, null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarFormularioPiloto(BuildContext context, PilotoModel? pilotoExistente) {
    final nombreCtrl = TextEditingController(text: pilotoExistente?.nombre ?? '');
    final cedulaCtrl = TextEditingController(text: pilotoExistente?.cedula ?? '');
    final telCtrl = TextEditingController(text: pilotoExistente?.telefono ?? '');
    final licCtrl = TextEditingController(text: pilotoExistente?.licencia ?? '');
    String colorSeleccionado = pilotoExistente?.colorHex ?? coloresDisponibles[0];
    String? firmaBase64 = pilotoExistente?.firmaBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final text = AgroTheme.getText(context);
          final primary = AgroTheme.getPrimary(context);

          return AlertDialog(
            title: Text(pilotoExistente == null ? 'Nuevo Piloto / Operador' : 'Editar Piloto / Operador'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cedulaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cédula / Documento (Para firma PDF)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono / WhatsApp',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Licencia / Certificado (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Color de identificación en cronograma:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coloresDisponibles.map((cHex) {
                      final hex = cHex.replaceAll('#', '');
                      final color = Color(int.parse('FF$hex', radix: 16));
                      final esSel = colorSeleccionado == cHex;

                      return GestureDetector(
                        onTap: () {
                          setDlgState(() => colorSeleccionado = cHex);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: esSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: esSel
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: esSel
                              ? const Icon(Icons.check, size: 18, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Firma Digital (Aparece en PDFs de cobro y balances):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                  ),
                  const SizedBox(height: 8),
                  if (firmaBase64 != null && firmaBase64!.isNotEmpty) ...[
                    Container(
                      height: 80,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary),
                      ),
                      child: Image.memory(
                        base64Decode(firmaBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final res = await showDialog<String>(
                          context: ctx,
                          builder: (_) => FirmaDigitalDialog(
                            firmaActualBase64: firmaBase64,
                            nombrePiloto: nombreCtrl.text.trim(),
                          ),
                        );
                        if (res != null) {
                          setDlgState(() {
                            firmaBase64 = res.isEmpty ? null : res;
                          });
                        }
                      },
                      icon: const Icon(Icons.draw_rounded, size: 18),
                      label: Text(
                        firmaBase64 != null && firmaBase64!.isNotEmpty
                            ? 'Cambiar / Borrar Firma Digital'
                            : 'Dibujar o Subir Firma Digital',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final nom = nombreCtrl.text.trim();
                  if (nom.isEmpty) return;

                  final model = PilotoModel(
                    id: pilotoExistente?.id,
                    nombre: nom,
                    cedula: cedulaCtrl.text.trim(),
                    telefono: telCtrl.text.trim(),
                    licencia: licCtrl.text.trim(),
                    colorHex: colorSeleccionado,
                    activo: true,
                    firmaBase64: firmaBase64,
                  );

                  if (pilotoExistente == null) {
                    await FirebaseFirestore.instance.collection('pilotos').add(model.toMap());
                  } else {
                    await FirebaseFirestore.instance.collection('pilotos').doc(model.id).update(model.toMap());
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

