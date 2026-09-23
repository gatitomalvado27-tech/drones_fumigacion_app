import 'dart:async';
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

  // Estado para creación de PIN en primer uso
  bool _cargando = true;
  bool _esPrimerUso = false;
  int _pasoCreacion = 0; // 0: primer ingreso, 1: confirmar
  String _primerPinTemporal = '';

  // Protección contra fuerza bruta
  int _intentosFallidos = 0;
  bool _bloqueado = false;
  int _segundosBloqueo = 0;
  Timer? _timerBloqueo;

  @override
  void initState() {
    super.initState();
    _verificarSiExistePin();
  }

  @override
  void dispose() {
    _timerBloqueo?.cancel();
    super.dispose();
  }

  Future<void> _verificarSiExistePin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('proicaro_pin_personalizado');
    setState(() {
      _cargando = false;
      _esPrimerUso = (pin == null || pin.isEmpty);
    });
  }

  void _onNumeroPresionado(String digito) {
    if (_bloqueado || _cargando) return;

    if (_pinIngresado.length < 4) {
      setState(() {
        _pinIngresado += digito;
        _errorMsg = '';
      });

      if (_pinIngresado.length == 4) {
        if (_esPrimerUso) {
          _procesarCreacionPin();
        } else {
          _verificarPin();
        }
      }
    }
  }

  void _onBorrar() {
    if (_bloqueado || _cargando) return;

    if (_pinIngresado.isNotEmpty) {
      setState(() {
        _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
        _errorMsg = '';
      });
    }
  }

  Future<void> _procesarCreacionPin() async {
    if (_pasoCreacion == 0) {
      setState(() {
        _primerPinTemporal = _pinIngresado;
        _pinIngresado = '';
        _pasoCreacion = 1;
        _errorMsg = '';
      });
    } else {
      if (_pinIngresado == _primerPinTemporal) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('proicaro_pin_personalizado', _pinIngresado);
        if (_recordarCelular) {
          await prefs.setBool('proicaro_dispositivo_autorizado', true);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡PIN de seguridad configurado exitosamente!'),
            backgroundColor: AgroTheme.primary,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMsg = 'Los PIN no coinciden. Intenta de nuevo.';
          _pinIngresado = '';
          _pasoCreacion = 0;
          _primerPinTemporal = '';
        });
      }
    }
  }

  Future<void> _verificarPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pinGuardado = prefs.getString('proicaro_pin_personalizado') ?? '2026';

    if (_pinIngresado == pinGuardado) {
      _intentosFallidos = 0;
      if (_recordarCelular) {
        await prefs.setBool('proicaro_dispositivo_autorizado', true);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _intentosFallidos++;
      setState(() {
        _pinIngresado = '';
        if (_intentosFallidos >= 5) {
          _iniciarBloqueo(30);
        } else {
          final restantes = 5 - _intentosFallidos;
          _errorMsg = 'PIN incorrecto. Te quedan $restantes intentos.';
        }
      });
    }
  }

  void _iniciarBloqueo(int segundos) {
    setState(() {
      _bloqueado = true;
      _segundosBloqueo = segundos;
      _errorMsg = 'Demasiados intentos. Teclado bloqueado por $segundos segundos.';
    });

    _timerBloqueo?.cancel();
    _timerBloqueo = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_segundosBloqueo > 1) {
          _segundosBloqueo--;
          _errorMsg = 'Demasiados intentos. Teclado bloqueado por $_segundosBloqueo s.';
        } else {
          _bloqueado = false;
          _segundosBloqueo = 0;
          _intentosFallidos = 0;
          _errorMsg = '';
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AgroTheme.background,
        body: Center(child: CircularProgressIndicator(color: AgroTheme.primary)),
      );
    }

    String titulo;
    String subtitulo;

    if (_esPrimerUso) {
      if (_pasoCreacion == 0) {
        titulo = 'Configura tu PIN de Seguridad';
        subtitulo = 'Crea una clave de 4 dígitos para este dispositivo';
      } else {
        titulo = 'Confirma tu nuevo PIN';
        subtitulo = 'Vuelve a escribir los 4 dígitos para confirmar';
      }
    } else {
      titulo = 'Ingresa tu PIN de 4 dígitos';
      subtitulo = 'Control de Acceso Seguro Icaro Proagro';
    }

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
                    width: 86,
                    height: 86,
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

                const SizedBox(height: 16),

                const Text(
                  'Icaro Proagro',
                  style: TextStyle(
                    fontSize: 26,
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

                const SizedBox(height: 20),

                // BADGE DE SEGURIDAD
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AgroTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AgroTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _esPrimerUso ? Icons.lock_reset_rounded : Icons.shield_rounded,
                        size: 15,
                        color: AgroTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _esPrimerUso ? 'Primer Inicio - Seguridad' : 'Acceso Protegido',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AgroTheme.primary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AgroTheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AgroTheme.onSurfaceVariant),
                ),

                const SizedBox(height: 20),

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
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AgroTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AgroTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AgroTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // OPCIÓN RECORDAR CELULAR
                if (!_bloqueado)
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
                            'Mantener este celular autorizado',
                            style: TextStyle(fontSize: 12, color: AgroTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // TECLADO NUMÉRICO ESTILO COCKPIT
                _buildTecladoNumerico(),

                const SizedBox(height: 10),
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
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: _bloqueado ? AgroTheme.outlineVariant : AgroTheme.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: _bloqueado ? null : _onBorrar,
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
          backgroundColor: _bloqueado ? AgroTheme.surfaceContainerLowest : AgroTheme.surfaceContainerHigh,
          foregroundColor: _bloqueado ? AgroTheme.outlineVariant : AgroTheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AgroTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: _bloqueado ? null : () => _onNumeroPresionado(numero),
        child: Text(
          numero,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
