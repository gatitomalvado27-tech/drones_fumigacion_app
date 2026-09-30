import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/servicio_model.dart';
import '../models/transaccion_model.dart';
import '../theme/agro_theme.dart';
import '../services/notification_service.dart';
import 'registro_bitacora_dialog.dart';

enum TipoGestionCobro {
  total,
  parcial,
  credito,
}

class RegistroCobroServicioDialog extends StatefulWidget {
  final ServicioModel servicio;
  final bool abrirBitacoraDespues;

  const RegistroCobroServicioDialog({
    super.key,
    required this.servicio,
    this.abrirBitacoraDespues = true,
  });

  static Future<bool?> mostrar(
    BuildContext context,
    ServicioModel servicio, {
    bool abrirBitacoraDespues = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RegistroCobroServicioDialog(
        servicio: servicio,
        abrirBitacoraDespues: abrirBitacoraDespues,
      ),
    );
  }

  @override
  State<RegistroCobroServicioDialog> createState() => _RegistroCobroServicioDialogState();
}

class _RegistroCobroServicioDialogState extends State<RegistroCobroServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  TipoGestionCobro _tipoCobro = TipoGestionCobro.total;
  late String _metodoPago;
  late TextEditingController _montoAbonoController;
  late TextEditingController _notaController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _metodoPago = TransaccionModel.metodosPagoMap.containsKey(widget.servicio.metodoPago)
        ? widget.servicio.metodoPago
        : 'EFECTIVO';

    final saldo = widget.servicio.saldoPendiente > 0
        ? widget.servicio.saldoPendiente
        : widget.servicio.precioTotal;

    _montoAbonoController = TextEditingController(text: saldo.toStringAsFixed(0));
    _notaController = TextEditingController();
  }

  @override
  void dispose() {
    _montoAbonoController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _procesarCobro() async {
    if (_tipoCobro == TipoGestionCobro.parcial && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardando = true);

    try {
      final s = widget.servicio;
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);

      final double saldoActual = s.saldoPendiente > 0 ? s.saldoPendiente : s.precioTotal;
      final String nota = _notaController.text.trim();
      final notaTexto = nota.isNotEmpty ? ' ($nota)' : '';

      if (_tipoCobro == TipoGestionCobro.total) {
        // 1. Cobro Total del Servicio
        final montoCobro = saldoActual;

        await FirebaseFirestore.instance.collection('transacciones').add({
          'tipo': 'INGRESO',
          'categoria': 'SERVICIO',
          'monto': montoCobro,
          'descripcion': 'Fumigación ${s.cultivo} (${s.hectareas} Ha) - ${s.clienteNombre}$notaTexto',
          'fecha': DateTime.now().toIso8601String(),
          'clienteNombre': s.clienteNombre,
          'servicioId': s.id,
          'metodoPago': _metodoPago,
        });

        if (s.id != null) {
          await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
            'estado': 'COMPLETADO',
            'pagado': true,
            'totalAbonado': s.precioTotal,
            'metodoPago': _metodoPago,
          });
          s.estado = 'COMPLETADO';
          s.pagado = true;
          s.totalAbonado = s.precioTotal;
          s.metodoPago = _metodoPago;
        }

        NotificationService.instance.notificarAbonoRegistrado(
          cliente: s.clienteNombre,
          monto: montoCobro,
          saldo: 0.0,
        );

        messenger.showSnackBar(
          SnackBar(
            content: Text('¡Ingreso de ${_currencyFormat.format(montoCobro)} registrado en Contabilidad con éxito!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      } else if (_tipoCobro == TipoGestionCobro.parcial) {
        // 2. Abono Parcial
        final abono = double.tryParse(_montoAbonoController.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0.0;
        final nuevoTotalAbonado = s.totalAbonado + abono;
        final bool quedaPagado = nuevoTotalAbonado >= (s.precioTotal - 1.0);
        final saldoRestante = (s.precioTotal - nuevoTotalAbonado).clamp(0.0, double.infinity);

        await FirebaseFirestore.instance.collection('transacciones').add({
          'tipo': 'INGRESO',
          'categoria': 'SERVICIO',
          'monto': abono,
          'descripcion': 'Abono Fumigación ${s.cultivo} (${s.hectareas} Ha) - ${s.clienteNombre}$notaTexto',
          'fecha': DateTime.now().toIso8601String(),
          'clienteNombre': s.clienteNombre,
          'servicioId': s.id,
          'metodoPago': _metodoPago,
        });

        if (s.id != null) {
          await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
            'estado': 'COMPLETADO',
            'pagado': quedaPagado,
            'totalAbonado': nuevoTotalAbonado,
            'metodoPago': _metodoPago,
          });
          s.estado = 'COMPLETADO';
          s.pagado = quedaPagado;
          s.totalAbonado = nuevoTotalAbonado;
          s.metodoPago = _metodoPago;
        }

        NotificationService.instance.notificarAbonoRegistrado(
          cliente: s.clienteNombre,
          monto: abono,
          saldo: saldoRestante,
        );

        messenger.showSnackBar(
          SnackBar(
            content: Text('¡Abono de ${_currencyFormat.format(abono)} registrado! Resta: ${_currencyFormat.format(saldoRestante)}'),
            backgroundColor: Colors.teal,
          ),
        );
      } else {
        // 3. A Crédito (Sin cobro inmediato)
        if (s.id != null) {
          await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
            'estado': 'COMPLETADO',
            'pagado': false,
          });
          s.estado = 'COMPLETADO';
          s.pagado = false;
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text('Vuelo completado. Quedó registrado en Cuentas por Cobrar de Contabilidad (${_currencyFormat.format(saldoActual)}).'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }

      nav.pop(true);

      // Ofrecer la bitácora si está habilitado y el servicio aún no tiene bitácora registrada
      if (widget.abrirBitacoraDespues && mounted && s.bitacora == null) {
        _ofrecerRegistroBitacora(context, s);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar cobro: $e'),
            backgroundColor: AgroTheme.error,
          ),
        );
      }
    }
  }

  void _ofrecerRegistroBitacora(BuildContext context, ServicioModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.history_edu_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Bitácora de Vuelo'),
          ],
        ),
        content: Text(
          '¿Deseas diligenciar la Bitácora técnica del vuelo de ${s.cultivo} para ${s.clienteNombre} (hectáreas reales, clima, baterías)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Omitir / Más tarde', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Registrar Bitácora', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              RegistroBitacoraDialog.mostrar(context, s);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final primary = AgroTheme.getPrimary(context);
    final cardBg = AgroTheme.getCard(context);

    final s = widget.servicio;
    final saldo = s.saldoPendiente > 0 ? s.saldoPendiente : s.precioTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.paid_rounded, color: Color(0xFF2E7D32), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestión Contable del Vuelo',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
                            ),
                            Text(
                              '${s.clienteNombre} • ${s.cultivo} (${s.hectareas} Ha)',
                              style: TextStyle(fontSize: 12, color: subtext),
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

                  const SizedBox(height: 16),

                  // TARJETA DE RESUMEN FINANCIERO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monto Total del Servicio', style: TextStyle(fontSize: 11, color: subtext)),
                            Text(
                              _currencyFormat.format(s.precioTotal),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text),
                            ),
                          ],
                        ),
                        if (s.totalAbonado > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Abonado: ${_currencyFormat.format(s.totalAbonado)}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                              Text(
                                'Saldo: ${_currencyFormat.format(saldo)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SELECTOR DE TIPO DE PAGO
                  Text(
                    '¿Cómo se gestionó el pago del servicio?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTipoOpcion(
                          tipo: TipoGestionCobro.total,
                          titulo: 'Cobrado Total',
                          icono: Icons.check_circle_outline,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTipoOpcion(
                          tipo: TipoGestionCobro.parcial,
                          titulo: 'Abono Parcial',
                          icono: Icons.pie_chart_outline,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTipoOpcion(
                          tipo: TipoGestionCobro.credito,
                          titulo: 'A Crédito',
                          icono: Icons.schedule,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // CAMPOS DINÁMICOS SEGÚN SELECCIÓN
                  if (_tipoCobro == TipoGestionCobro.parcial) ...[
                    TextFormField(
                      controller: _montoAbonoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monto del Abono Recibido (\$ COP) *',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'El saldo restante quedará en Cuentas por Cobrar',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingresa el monto del abono';
                        final numVal = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                        if (numVal == null || numVal <= 0) return 'Monto inválido';
                        if (numVal > saldo) return 'El abono supera el saldo pendiente (${_currencyFormat.format(saldo)})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_tipoCobro != TipoGestionCobro.credito) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _metodoPago,
                      decoration: InputDecoration(
                        labelText: 'Cuenta / Medio de Ingreso *',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: TransaccionModel.metodosPagoMap.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _metodoPago = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _notaController,
                    decoration: InputDecoration(
                      labelText: 'Nota u observación (Opcional)',
                      hintText: 'Ej: Transferencia Nequi recibida por el piloto, o saldo al finalizar la semana...',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // BOTONERA
                  Row(
                    children: [
                      TextButton(
                        onPressed: _guardando ? null : () => Navigator.pop(context, false),
                        child: Text('Omitir', style: TextStyle(color: subtext)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tipoCobro == TipoGestionCobro.credito
                              ? Colors.orange.shade800
                              : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _guardando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _guardando
                              ? 'Guardando...'
                              : (_tipoCobro == TipoGestionCobro.credito ? 'Registrar a Crédito' : 'Registrar en Caja'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _guardando ? null : _procesarCobro,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipoOpcion({
    required TipoGestionCobro tipo,
    required String titulo,
    required IconData icono,
    required Color color,
  }) {
    final sel = _tipoCobro == tipo;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _tipoCobro = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? color : AgroTheme.getBorder(context).withValues(alpha: 0.5),
            width: sel ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icono, color: sel ? color : AgroTheme.getSubtext(context), size: 22),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? color : AgroTheme.getText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
