import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/agro_theme.dart';
import '../theme/theme_controller.dart';
import 'pin_login_screen.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  static const List<Color> _coloresPrincipales = [
    Color(0xFF10B981), // Esmeralda
    Color(0xFF22C55E), // Verde vivo
    Color(0xFF8FE2B8), // Menta agrícola
    Color(0xFF0EA5E9), // Azul cielo
    Color(0xFF3B82F6), // Azul técnico
    Color(0xFF6366F1), // Índigo
    Color(0xFF8B5CF6), // Violeta
    Color(0xFFF59E0B), // Ámbar
    Color(0xFFEF4444), // Rojo
    Color(0xFF14B8A6), // Turquesa
  ];

  static const List<Color> _coloresSecundarios = [
    Color(0xFF38BDF8),
    Color(0xFF4ADE80),
    Color(0xFFA7F3D0),
    Color(0xFFFBBF24),
    Color(0xFF818CF8),
    Color(0xFFFB7185),
    Color(0xFF2DD4BF),
    Color(0xFF94A3B8),
  ];

  late Color _customPrimary;
  late Color _customSecondary;
  late bool _customDark;

  @override
  void initState() {
    super.initState();
    _customPrimary = ThemeController.instance.customPrimary;
    _customSecondary = ThemeController.instance.customSecondary;
    _customDark = ThemeController.instance.customDark;
  }

  List<Color> _previewColors(PaletaApp p) {
    switch (p) {
      case PaletaApp.verdeAgricola:
        return const [Color(0xFF041710), Color(0xFF10231C), Color(0xFF8FE2B8)];
      case PaletaApp.oscuroProfesional:
        return const [Color(0xFF111315), Color(0xFF1A1D21), Color(0xFF22C55E)];
      case PaletaApp.modoClaro:
        return const [Color(0xFFF3F6F4), Color(0xFFFFFFFF), Color(0xFF059669)];
      case PaletaApp.azulTecnologico:
        return const [Color(0xFF081220), Color(0xFF101E33), Color(0xFF38BDF8)];
      case PaletaApp.personalizado:
        return [
          _customDark ? const Color(0xFF12161B) : const Color(0xFFF6F8FA),
          _customPrimary,
          _customSecondary,
        ];
    }
  }

  Future<void> _mostrarDialogoCambiarPin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final pinActualConfigurado = prefs.getString('proicaro_pin_personalizado') ?? '2026';

    String pinActualIngresado = '';
    String nuevoPin = '';
    String confirmarPin = '';
    String? errorLocal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final primary = AgroTheme.getPrimary(context);
          final errorColor = AgroTheme.getError(context);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shield_outlined, size: 22, color: primary),
                const SizedBox(width: 8),
                const Text('Cambiar PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN actual',
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_clock, size: 18),
                    ),
                    onChanged: (val) {
                      pinActualIngresado = val;
                      if (errorLocal != null) setModalState(() => errorLocal = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo PIN (4 dígitos)',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin, size: 18),
                    ),
                    onChanged: (val) {
                      nuevoPin = val;
                      if (errorLocal != null) setModalState(() => errorLocal = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nuevo PIN',
                      counterText: '',
                      prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                    ),
                    onChanged: (val) {
                      confirmarPin = val;
                      if (errorLocal != null) setModalState(() => errorLocal = null);
                    },
                  ),
                  if (errorLocal != null) ...[
                    const SizedBox(height: 10),
                    Text(errorLocal!, style: TextStyle(color: errorColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (pinActualIngresado != pinActualConfigurado) {
                    setModalState(() => errorLocal = 'El PIN actual no es correcto.');
                    return;
                  }
                  if (nuevoPin.length != 4) {
                    setModalState(() => errorLocal = 'El nuevo PIN debe tener 4 dígitos.');
                    return;
                  }
                  if (nuevoPin != confirmarPin) {
                    setModalState(() => errorLocal = 'La confirmación del PIN no coincide.');
                    return;
                  }
                  await prefs.setString('proicaro_pin_personalizado', nuevoPin);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('PIN de acceso actualizado correctamente.')),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final primary = AgroTheme.getPrimary(context);
        final text = AgroTheme.getText(context);
        final subtext = AgroTheme.getSubtext(context);
        final cardBg = AgroTheme.getCard(context);
        final border = AgroTheme.getBorder(context);
        final errorColor = AgroTheme.getError(context);
        final paletaActual = ThemeController.instance.paleta;

        return Scaffold(
          backgroundColor: AgroTheme.getBg(context),
          appBar: AppBar(
            title: const Text('Configuración'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                // SECCIÓN 1: PALETAS DE COLORES
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Apariencia y Paleta de Colores',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'El tema seleccionado se aplica globalmente en toda la aplicación y se guarda automáticamente.',
                  style: TextStyle(fontSize: 12.5, color: subtext),
                ),
                const SizedBox(height: 14),

                for (final p in PaletaApp.values) ...[
                  _buildPaletaCard(
                    paleta: p,
                    seleccionada: paletaActual == p,
                    colores: _previewColors(p),
                    cardBg: cardBg,
                    border: border,
                    primary: primary,
                    text: text,
                    subtext: subtext,
                  ),
                  const SizedBox(height: 10),
                ],

                // EDITOR DE PALETA PERSONALIZADA
                if (paletaActual == PaletaApp.personalizado) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personaliza tus colores',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: text),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _customDark,
                          title: Text('Fondo oscuro', style: TextStyle(fontSize: 13.5, color: text, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            _customDark ? 'Superficies oscuras elegantes' : 'Superficies claras de alta visibilidad',
                            style: TextStyle(fontSize: 11.5, color: subtext),
                          ),
                          onChanged: (v) {
                            setState(() => _customDark = v);
                            ThemeController.instance.configurarPersonalizado(
                              primary: _customPrimary,
                              secondary: _customSecondary,
                              esOscuro: _customDark,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text('Color principal', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: subtext)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _coloresPrincipales.map((c) {
                            final sel = _customPrimary.toARGB32() == c.toARGB32();
                            return GestureDetector(
                              onTap: () {
                                setState(() => _customPrimary = c);
                                ThemeController.instance.configurarPersonalizado(
                                  primary: _customPrimary,
                                  secondary: _customSecondary,
                                  esOscuro: _customDark,
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel ? text : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: sel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Text('Color secundario', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: subtext)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _coloresSecundarios.map((c) {
                            final sel = _customSecondary.toARGB32() == c.toARGB32();
                            return GestureDetector(
                              onTap: () {
                                setState(() => _customSecondary = c);
                                ThemeController.instance.configurarPersonalizado(
                                  primary: _customPrimary,
                                  secondary: _customSecondary,
                                  esOscuro: _customDark,
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel ? text : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: sel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 12),

                // SECCIÓN 2: SEGURIDAD Y ACCESO
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Seguridad y Acceso',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primary.withValues(alpha: 0.14),
                          child: Icon(Icons.key, color: primary, size: 19),
                        ),
                        title: Text('Cambiar PIN de acceso', style: TextStyle(fontWeight: FontWeight.bold, color: text)),
                        subtitle: Text('Requiere el PIN actual por seguridad', style: TextStyle(fontSize: 12, color: subtext)),
                        trailing: Icon(Icons.chevron_right, color: subtext),
                        onTap: _mostrarDialogoCambiarPin,
                      ),
                      Divider(height: 1, color: border.withValues(alpha: 0.5)),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: errorColor.withValues(alpha: 0.14),
                          child: Icon(Icons.lock_outline, color: errorColor, size: 19),
                        ),
                        title: Text('Bloquear este dispositivo', style: TextStyle(fontWeight: FontWeight.bold, color: errorColor)),
                        subtitle: Text('Solicitará el PIN al volver a entrar', style: TextStyle(fontSize: 12, color: subtext)),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('proicaro_dispositivo_autorizado', false);
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const PinLoginScreen()),
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaletaCard({
    required PaletaApp paleta,
    required bool seleccionada,
    required List<Color> colores,
    required Color cardBg,
    required Color border,
    required Color primary,
    required Color text,
    required Color subtext,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (paleta == PaletaApp.personalizado) {
          ThemeController.instance.configurarPersonalizado(
            primary: _customPrimary,
            secondary: _customSecondary,
            esOscuro: _customDark,
          );
        } else {
          ThemeController.instance.seleccionarPaleta(paleta);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada ? primary : border.withValues(alpha: 0.6),
            width: seleccionada ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Row(
              children: colores.map((c) {
                return Container(
                  width: 18,
                  height: 32,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border.withValues(alpha: 0.5)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ThemeController.nombrePaleta(paleta),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ThemeController.descripcionPaleta(paleta),
                    style: TextStyle(fontSize: 11.5, color: subtext),
                  ),
                ],
              ),
            ),
            Icon(
              seleccionada ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: seleccionada ? primary : subtext.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
