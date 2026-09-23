import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/agro_theme.dart';
import 'home_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pinIngresado = '';
  String _errorMsg = '';
  bool _recordarCelular = true;

  // PIN Maestro predeterminado: 2026 (o el que defina la familia)
  static const String _pinCorrectoDefault = '2026';

  void _onNumeroPresionado(String digito) {
    if (_pinIngresado.length < 4) {
      setState(() {
        _pinIngresado += digito;
        _errorMsg = '';
      });

      if (_pinIngresado.length == 4) {
        _verificarPin();
      }
    }
  }

  void _onBorrar() {
    if (_pinIngresado.isNotEmpty) {
      setState(() {
        _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
        _errorMsg = '';
      });
    }
  }

  Future<void> _verificarPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pinGuardado = prefs.getString('proicaro_pin_personalizado') ?? _pinCorrectoDefault;

    if (_pinIngresado == pinGuardado || _pinIngresado == _pinCorrectoDefault) {
      if (_recordarCelular) {
        await prefs.setBool('proicaro_dispositivo_autorizado', true);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _errorMsg = 'PIN incorrecto. Intenta nuevamente.';
        _pinIngresado = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgroTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO CON MARCO NEÓN
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AgroTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AgroTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AgroTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 25,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Icaro Proagro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AgroTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Control Agrícola & Fumigación',
                  style: TextStyle(
                    fontSize: 13,
                    color: AgroTheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                // BADGE DE SEGURIDAD
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AgroTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AgroTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, size: 15, color: AgroTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        'Acceso Seguro Familiar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AgroTheme.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Ingresa tu PIN de 4 dígitos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AgroTheme.onSurface),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PIN inicial: 2026',
                  style: TextStyle(fontSize: 11, color: AgroTheme.onSurfaceVariant),
                ),

                const SizedBox(height: 18),

                // PUNTOS INDICADORES DE PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final lleno = index < _pinIngresado.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lleno ? AgroTheme.primary : AgroTheme.surfaceContainerHighest,
                        border: Border.all(
                          color: lleno ? AgroTheme.primary : AgroTheme.outlineVariant,
                          width: 2,
                        ),
                        boxShadow: lleno
                            ? [
                                BoxShadow(
                                  color: AgroTheme.primary.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),

                if (_errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMsg,
                    style: const TextStyle(color: AgroTheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],

                const SizedBox(height: 20),

                // OPCIÓN RECORDAR CELULAR
                InkWell(
                  onTap: () {
                    setState(() {
                      _recordarCelular = !_recordarCelular;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _recordarCelular,
                          activeColor: AgroTheme.primary,
                          checkColor: Colors.black,
                          onChanged: (v) {
                            setState(() {
                              _recordarCelular = v ?? true;
                            });
                          },
                        ),
                        const Text(
                          'Recordar este celular (Solo pedir una vez)',
                          style: TextStyle(fontSize: 12, color: AgroTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // TECLADO NUMÉRICO ESTILO COCKPIT
                _buildTecladoNumerico(),

                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTecladoNumerico() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBotonNumero('1'),
              _buildBotonNumero('2'),
              _buildBotonNumero('3'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBotonNumero('4'),
              _buildBotonNumero('5'),
              _buildBotonNumero('6'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBotonNumero('7'),
              _buildBotonNumero('8'),
              _buildBotonNumero('9'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70, height: 56), // Espacio vacío para balance
              _buildBotonNumero('0'),
              SizedBox(
                width: 70,
                height: 56,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, color: AgroTheme.onSurfaceVariant, size: 24),
                  onPressed: _onBorrar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonNumero(String numero) {
    return SizedBox(
      width: 72,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgroTheme.surfaceContainerHigh,
          foregroundColor: AgroTheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AgroTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _onNumeroPresionado(numero),
        child: Text(
          numero,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
