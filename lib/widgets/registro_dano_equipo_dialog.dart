import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bitacora_dano_equipo_model.dart';
import '../models/servicio_model.dart';
import '../theme/agro_theme.dart';

class RegistroDanoEquipoDialog extends StatefulWidget {
  final BitacoraDanoEquipoModel? danoExistente;
  final ServicioModel? servicioAsociado;

  const RegistroDanoEquipoDialog({
    super.key,
    this.danoExistente,
    this.servicioAsociado,
  });

  static Future<bool?> mostrar(
    BuildContext context, {
    BitacoraDanoEquipoModel? danoExistente,
    ServicioModel? servicioAsociado,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RegistroDanoEquipoDialog(
        danoExistente: danoExistente,
        servicioAsociado: servicioAsociado,
      ),
    );
  }

  @override
  State<RegistroDanoEquipoDialog> createState() => _RegistroDanoEquipoDialogState();
}

class _RegistroDanoEquipoDialogState extends State<RegistroDanoEquipoDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late String _categoria;
  late String _gravedad;
  late String _estado;
  late TextEditingController _nombreEquipoCtrl;
  late TextEditingController _tipoDanoCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _pilotoCtrl;
  late TextEditingController _costoCtrl;
  late TextEditingController _videoUrlCtrl;
  late TextEditingController _piezasCambiadasCtrl;
  late TextEditingController _notasReparacionCtrl;

  List<String> _fotosBase64 = [];
  bool _crearGastoContable = false;
  bool _guardando = false;

  final Map<String, List<String>> _sugerenciasPorCategoria = {
    'DRON': ['Hélice partida/fisurada', 'Brazo quebrado', 'Motor bloqueado', 'Fuga en manguera de aspersión', 'Falla en radar', 'Golpe en tren de aterrizaje'],
    'CAMIONETA': ['Pinchazo de llanta', 'Rayón/Golpe en carrocería', 'Falla de batería/arranque', 'Amortiguador averiado', 'Luz quemada', 'Daño en carpa/plataforma'],
    'GENERADOR': ['No enciende / Falla de arranque', 'Fuga de aceite/gasolina', 'Cable de carga quemado/sulfatado', 'Apagado por sobrecalentamiento'],
    'BATERIAS': ['Celda desbalanceada', 'Batería hinchada', 'Conector de carga quemado', 'Error de comunicación BMS'],
    'SISTEMA_MEZCLA': ['Manguera rota/fisurada', 'Filtro de bomba obstruido', 'Motobomba no succiona', 'Fuga en tanque'],
    'OTRO': ['Herramienta extraviada/rota', 'Cono de señalización roto', 'Anemómetro dañado'],
  };

  @override
  void initState() {
    super.initState();
    final d = widget.danoExistente;

    _categoria = d?.categoriaEquipo ?? 'DRON';
    _gravedad = d?.gravedad ?? 'LEVE';
    _estado = d?.estado ?? 'REPORTADO';

    String equipoInicial = d?.nombreEquipo ?? '';
    if (equipoInicial.isEmpty && widget.servicioAsociado != null) {
      equipoInicial = widget.servicioAsociado!.dron.isNotEmpty
          ? widget.servicioAsociado!.dron
          : 'DJI Agras T40';
    } else if (equipoInicial.isEmpty) {
      equipoInicial = 'DJI Agras T40 #1';
    }

    _nombreEquipoCtrl = TextEditingController(text: equipoInicial);
    _tipoDanoCtrl = TextEditingController(text: d?.tipoDano ?? '');
    _descripcionCtrl = TextEditingController(text: d?.descripcion ?? '');
    _pilotoCtrl = TextEditingController(
      text: d?.pilotoReporta ?? widget.servicioAsociado?.piloto ?? 'Piloto',
    );
    _costoCtrl = TextEditingController(
      text: d != null && d.costoReparacion > 0 ? d.costoReparacion.toStringAsFixed(0) : '',
    );
    _videoUrlCtrl = TextEditingController(text: d?.videoUrl ?? '');
    _piezasCambiadasCtrl = TextEditingController(text: d?.piezasCambiadas ?? '');
    _notasReparacionCtrl = TextEditingController(text: d?.notasReparacion ?? '');

    _fotosBase64 = d?.fotosBase64 != null ? List<String>.from(d!.fotosBase64) : [];
  }

  @override
  void dispose() {
    _nombreEquipoCtrl.dispose();
    _tipoDanoCtrl.dispose();
    _descripcionCtrl.dispose();
    _pilotoCtrl.dispose();
    _costoCtrl.dispose();
    _videoUrlCtrl.dispose();
    _piezasCambiadasCtrl.dispose();
    _notasReparacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarFoto(ImageSource source) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 75,
      );
      if (foto != null) {
        final bytes = await foto.readAsBytes();
        setState(() {
          _fotosBase64.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar imagen: $e')),
        );
      }
    }
  }

  void _mostrarFotoAmpliada(String base64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.memory(base64Decode(base64), fit: BoxFit.contain),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarDano() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final double costo = double.tryParse(_costoCtrl.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0.0;
      final dExistente = widget.danoExistente;

      final dano = BitacoraDanoEquipoModel(
        id: dExistente?.id,
        categoriaEquipo: _categoria,
        nombreEquipo: _nombreEquipoCtrl.text.trim(),
        fecha: dExistente?.fecha ?? DateTime.now(),
        gravedad: _gravedad,
        tipoDano: _tipoDanoCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        servicioId: widget.servicioAsociado?.id ?? dExistente?.servicioId,
        clienteNombre: widget.servicioAsociado?.clienteNombre ?? dExistente?.clienteNombre,
        pilotoReporta: _pilotoCtrl.text.trim(),
        fotosBase64: _fotosBase64,
        videoUrl: _videoUrlCtrl.text.trim().isNotEmpty ? _videoUrlCtrl.text.trim() : null,
        costoReparacion: costo,
        gastoContableRegistrado: dExistente?.gastoContableRegistrado ?? _crearGastoContable,
        estado: _estado,
        piezasCambiadas: _piezasCambiadasCtrl.text.trim(),
        notasReparacion: _notasReparacionCtrl.text.trim(),
        fechaReparacion: _estado == 'REPARADO' ? (dExistente?.fechaReparacion ?? DateTime.now()) : null,
      );

      final col = FirebaseFirestore.instance.collection('bitacoras_danos');

      if (dExistente?.id == null) {
        final docRef = await col.add(dano.toMap());
        dano.id = docRef.id;
      } else {
        await col.doc(dExistente!.id).update(dano.toMap());
      }

      // Vínculo contable automático si el usuario lo solicitó y hay costo > 0
      if (_crearGastoContable && costo > 0 && !(dExistente?.gastoContableRegistrado ?? false)) {
        await FirebaseFirestore.instance.collection('transacciones').add({
          'tipo': 'EGRESO',
          'categoria': 'MANTENIMIENTO',
          'monto': costo,
          'descripcion': 'Reparación ${_categoria == 'DRON' ? 'Dron' : (_categoria == 'CAMIONETA' ? 'Camioneta' : _categoria)} (${dano.nombreEquipo}): ${dano.tipoDano}',
          'fecha': DateTime.now().toIso8601String(),
          'metodoPago': 'EFECTIVO',
        });
        if (dano.id != null) {
          await col.doc(dano.id).update({'gastoContableRegistrado': true});
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dExistente == null
                        ? 'Novedad de equipo guardada en la Bitácora de Daños.'
                        : 'Registro de daño actualizado con éxito.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar reporte de daño: $e'),
            backgroundColor: AgroTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final primary = AgroTheme.getPrimary(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    final esEdicion = widget.danoExistente != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CABECERA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.car_crash_rounded, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'Actualizar Reporte de Daño' : 'Bitácora de Daños e Incidentes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text),
                        ),
                        Text(
                          'Registro técnico de Dron, Camioneta, Generador o Baterías',
                          style: TextStyle(fontSize: 11.5, color: subtext),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _guardando ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),

            // CUERPO DEL FORMULARIO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SELECCIÓN DE CATEGORÍA DEL EQUIPO
                      Text('Categoría del Equipo Afectado *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BitacoraDanoEquipoModel.categoriasMap.entries.map((e) {
                          final sel = _categoria == e.key;
                          final icono = BitacoraDanoEquipoModel.iconoCategoria(e.key);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _categoria = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel ? primary.withValues(alpha: 0.18) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? primary : border.withValues(alpha: 0.6),
                                  width: sel ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icono, size: 16, color: sel ? primary : subtext),
                                  const SizedBox(width: 6),
                                  Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                      color: sel ? primary : text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // SELECCIÓN DE GRAVEDAD / SEVERIDAD
                      Text('Nivel de Severidad / Gravedad *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGravedadCard('LEVE', '🟢 Leve', 'Operativo', Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGravedadCard('MODERADA', '🟡 Moderada', 'Atención pronta', Colors.orangeAccent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGravedadCard('CRITICA', '🔴 Crítica', 'Inoperativo', Colors.redAccent),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // NOMBRE ESPECÍFICO DEL EQUIPO Y PILOTO REPORTA
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nombreEquipoCtrl,
                              decoration: InputDecoration(
                                labelText: 'Identificador del Equipo *',
                                hintText: _categoria == 'CAMIONETA' ? 'Ej: Hilux Blanca ABC123' : 'Ej: DJI Agras T40 #1',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _pilotoCtrl,
                              decoration: InputDecoration(
                                labelText: 'Piloto / Técnico *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // TIPO DE DAÑO CON ETIQUETAS RÁPIDAS SUGERIDAS
                      Text('Tipo de Daño o Pieza Afectada *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 6),
                      if (_sugerenciasPorCategoria[_categoria] != null) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _sugerenciasPorCategoria[_categoria]!.map((sug) {
                            return ActionChip(
                              label: Text(sug, style: const TextStyle(fontSize: 10.5)),
                              backgroundColor: border.withValues(alpha: isDark ? 0.25 : 0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                _tipoDanoCtrl.text = sug;
                                setState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: _tipoDanoCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ej: Golpe en hélice delantera izquierda, pinchazo en llanta trasera...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el tipo de daño' : null,
                      ),

                      const SizedBox(height: 14),

                      // DESCRIPCIÓN DETALLADA
                      Text('Descripción de lo que Sucedió', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Relata las circunstancias: rama en el lote, bache en carretera, aterrizaje irregular...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // SECCIÓN DE FOTOS Y EVIDENCIA VISUAL
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.photo_camera_back_outlined, size: 18, color: primary),
                              const SizedBox(width: 6),
                              Text('Fotos de Evidencia (${_fotosBase64.length})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Tomar Foto con Cámara',
                                icon: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32), size: 20),
                                onPressed: () => _capturarFoto(ImageSource.camera),
                              ),
                              IconButton(
                                tooltip: 'Seleccionar de Galería',
                                icon: const Icon(Icons.photo_library, color: Colors.blueAccent, size: 20),
                                onPressed: () => _capturarFoto(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_fotosBase64.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: border.withValues(alpha: isDark ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border.withValues(alpha: 0.4), style: BorderStyle.solid),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 22, color: subtext),
                              const SizedBox(width: 8),
                              Text(
                                'Toma fotos claras del daño para el registro técnico',
                                style: TextStyle(fontSize: 11.5, color: subtext),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 85,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _fotosBase64.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => _mostrarFotoAmpliada(_fotosBase64[i]),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode(_fotosBase64[i]),
                                        width: 85,
                                        height: 85,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 3,
                                    right: 3,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _fotosBase64.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 14),

                      // SOPORTE DE VIDEO / ENLACE DE EVIDENCIA
                      TextFormField(
                        controller: _videoUrlCtrl,
                        decoration: InputDecoration(
                          labelText: 'Enlace de Video de Evidencia (Opcional)',
                          hintText: 'Ej: Link de video en Google Drive, WhatsApp o enlace en la nube',
                          prefixIcon: const Icon(Icons.video_camera_back_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ESTIMACIÓN ECONÓMICA Y CONEXIÓN CONTABLE
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: border.withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Impacto Económico / Reparación', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _costoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Costo Estimado o Real de Reparación (\$ COP)',
                                hintText: 'Ej: 180000',
                                prefixIcon: const Icon(Icons.attach_money, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                            ),
                            if (!esEdicion || !(widget.danoExistente?.gastoContableRegistrado ?? false)) ...[
                              const SizedBox(height: 6),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _crearGastoContable,
                                onChanged: (val) => setState(() => _crearGastoContable = val ?? false),
                                title: Text(
                                  'Registrar este valor automáticamente como EGRESO en Contabilidad (Mantenimiento)',
                                  style: TextStyle(fontSize: 11.5, color: text),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ESTADO DE LA REPARACIÓN
                      Text('Estado del Equipo *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'REPORTADO', child: Text('🔴 Reportado (Pendiente)')),
                          DropdownMenuItem(value: 'EN_REPARACION', child: Text('🟡 En Taller / Reparación')),
                          DropdownMenuItem(value: 'REPARADO', child: Text('🟢 Reparado / Operativo')),
                        ],
                        onChanged: (val) => setState(() => _estado = val ?? 'REPORTADO'),
                      ),

                      if (_estado == 'REPARADO') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _piezasCambiadasCtrl,
                          decoration: InputDecoration(
                            labelText: 'Repuestos / Piezas Cambiadas',
                            hintText: 'Ej: Hélice CW T40 nueva de bodega...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // BOTONERA INFERIOR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: border.withValues(alpha: isDark ? 0.15 : 0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context, false),
                    child: Text('Cancelar', style: TextStyle(color: subtext)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _guardando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save, size: 18),
                    label: Text(
                      _guardando ? 'Guardando...' : (esEdicion ? 'Actualizar Novedad' : 'Guardar en Bitácora'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _guardando ? null : _guardarDano,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGravedadCard(String valor, String titulo, String subtitulo, Color color) {
    final sel = _gravedad == valor;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _gravedad = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? color : AgroTheme.getBorder(context).withValues(alpha: 0.5),
            width: sel ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? color : AgroTheme.getText(context))),
            const SizedBox(height: 2),
            Text(subtitulo, style: TextStyle(fontSize: 9.5, color: AgroTheme.getSubtext(context))),
          ],
        ),
      ),
    );
  }
}
