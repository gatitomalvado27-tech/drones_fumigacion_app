import 'package:flutter/material.dart';
import '../theme/agro_theme.dart';

class TimePickerHelper {
  /// Abre el diálogo simplificado de selección de hora con soporte para AM/PM y Hora Militar
  static Future<TimeOfDay?> seleccionarHora(
    BuildContext context, {
    required TimeOfDay horaInicial,
    bool formatoMilitarPredeterminado = false,
  }) async {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) => _AgroTimePickerDialog(
        horaInicial: horaInicial,
        formatoMilitarInicial: formatoMilitarPredeterminado,
      ),
    );
  }

  /// Formatea la hora en texto claro según el formato seleccionado
  static String formatearHora(TimeOfDay hora, {bool esMilitar = false}) {
    if (esMilitar) {
      final h = hora.hour.toString().padLeft(2, '0');
      final m = hora.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else {
      final periodo = hora.period == DayPeriod.am ? 'AM' : 'PM';
      final h = hora.hourOfPeriod == 0 ? 12 : hora.hourOfPeriod;
      final m = hora.minute.toString().padLeft(2, '0');
      return '$h:$m $periodo';
    }
  }
}

class _AgroTimePickerDialog extends StatefulWidget {
  final TimeOfDay horaInicial;
  final bool formatoMilitarInicial;

  const _AgroTimePickerDialog({
    required this.horaInicial,
    required this.formatoMilitarInicial,
  });

  @override
  State<_AgroTimePickerDialog> createState() => _AgroTimePickerDialogState();
}

class _AgroTimePickerDialogState extends State<_AgroTimePickerDialog> {
  late bool _esMilitar;
  late int _horaSeleccionada; // 0 a 23
  late int _minutoSeleccionado; // 0 a 59

  @override
  void initState() {
    super.initState();
    _esMilitar = widget.formatoMilitarInicial;
    _horaSeleccionada = widget.horaInicial.hour;
    _minutoSeleccionado = widget.horaInicial.minute;
  }

  void _cambiarModo(bool militar) {
    setState(() {
      _esMilitar = militar;
    });
  }

  void _abrirRelojNativo() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _horaSeleccionada, minute: _minutoSeleccionado),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: _esMilitar),
          child: child!,
        );
      },
    );
    if (t != null) {
      setState(() {
        _horaSeleccionada = t.hour;
        _minutoSeleccionado = t.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final cardBg = Theme.of(context).colorScheme.surface;
    final border = AgroTheme.getBorder(context);

    // Calcular hora de 12 horas y AM/PM
    final esPm = _horaSeleccionada >= 12;
    final hora12 = _horaSeleccionada == 0
        ? 12
        : (_horaSeleccionada > 12 ? _horaSeleccionada - 12 : _horaSeleccionada);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ENCABEZADO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Seleccionar Hora',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Reloj Tradicional',
                    icon: Icon(Icons.touch_app_outlined, size: 18, color: primary),
                    onPressed: _abrirRelojNativo,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // SELECTOR DE MODO: 12 HORAS (AM/PM) vs HORA MILITAR (24H)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _cambiarModo(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_esMilitar ? primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '☀️ 12 Horas (AM / PM)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_esMilitar ? Colors.white : text.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _cambiarModo(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _esMilitar ? primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🎖️ Hora Militar (24H)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _esMilitar ? Colors.white : text.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PANTALLA VISUAL DE HORA SELECCIONADA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _esMilitar
                          ? _horaSeleccionada.toString().padLeft(2, '0')
                          : hora12.toString().padLeft(2, '0'),
                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: primary),
                    ),
                    Text(
                      ' : ',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primary),
                    ),
                    Text(
                      _minutoSeleccionado.toString().padLeft(2, '0'),
                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: primary),
                    ),
                    if (!_esMilitar) ...[
                      const SizedBox(width: 10),
                      Text(
                        esPm ? 'PM' : 'AM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: esPm ? Colors.orangeAccent : Colors.tealAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // TOGGLE AM / PM (SI ESTÁ EN MODO 12 HORAS)
              if (!_esMilitar) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('☀️ Mañana (AM)'),
                      selected: !esPm,
                      selectedColor: primary.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !esPm ? primary : text,
                      ),
                      onSelected: (val) {
                        if (val && esPm) {
                          setState(() => _horaSeleccionada = (_horaSeleccionada - 12).clamp(0, 23));
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('🌙 Tarde / Noche (PM)'),
                      selected: esPm,
                      selectedColor: Colors.orangeAccent.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: esPm ? Colors.orangeAccent : text,
                      ),
                      onSelected: (val) {
                        if (val && !esPm) {
                          setState(() => _horaSeleccionada = (_horaSeleccionada + 12).clamp(0, 23));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // SELECCIÓN DE HORAS
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Hora:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
              ),
              const SizedBox(height: 6),

              if (!_esMilitar) ...[
                // Horas 1 a 12
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(12, (i) {
                    final h = i + 1;
                    final seleccionada = hora12 == h;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (esPm) {
                            _horaSeleccionada = (h == 12 ? 12 : h + 12);
                          } else {
                            _horaSeleccionada = (h == 12 ? 0 : h);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: seleccionada ? primary : cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: seleccionada ? primary : border.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          h.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                            color: seleccionada ? Colors.white : text,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ] else ...[
                // Horas Militares (00 a 23)
                SizedBox(
                  height: 95,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: List.generate(24, (h) {
                        final seleccionada = _horaSeleccionada == h;
                        return InkWell(
                          onTap: () => setState(() => _horaSeleccionada = h),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 42,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: seleccionada ? primary : cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: seleccionada ? primary : border.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              h.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                                color: seleccionada ? Colors.white : text,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // SELECCIÓN DE MINUTOS
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Minutos:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text)),
              ),
              const SizedBox(height: 6),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55].map((m) {
                  final seleccionada = _minutoSeleccionado == m;
                  return InkWell(
                    onTap: () => setState(() => _minutoSeleccionado = m),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: seleccionada ? primary : cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: seleccionada ? primary : border.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        ':${m.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                          color: seleccionada ? Colors.white : text,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ACCIONES
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        TimeOfDay(hour: _horaSeleccionada, minute: _minutoSeleccionado),
                      );
                    },
                    child: const Text('Aceptar Hora', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
