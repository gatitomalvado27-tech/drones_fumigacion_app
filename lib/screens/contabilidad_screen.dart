import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/agro_theme.dart';
import '../models/transaccion_model.dart';
import '../models/servicio_model.dart';
import '../models/deuda_model.dart';
import '../models/cliente_model.dart';
import '../services/pdf_service.dart';
import '../services/notification_service.dart';
import '../utils/crop_helper.dart';
import 'historial_balances_screen.dart';
import '../widgets/registro_cobro_servicio_dialog.dart';

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filtroTipo = 'TODOS'; // 'TODOS', 'INGRESO', 'EGRESO', 'DEUDA'
  String _filtroPeriodo = 'ESTE_MES'; // 'HOY', 'ESTA_SEMANA', 'ESTE_MES', 'MES_PASADO', 'ESTE_ANO', 'TODO', 'PERSONALIZADO'
  String _filtroJornada = 'TODO'; // 'TODO', 'MANANA', 'TARDE'
  String _filtroCuenta = 'TODAS'; // 'TODAS', 'EFECTIVO', 'BANCOLOMBIA', 'NEQUI', etc.
  String _filtroCategoriaEgreso = 'TODAS'; // 'TODAS', 'COMBUSTIBLE', 'MANTENIMIENTO', etc.
  String _busqueda = '';
  DateTimeRange? _rangoPersonalizado;
  int _semanaOffset = 0; // 0 = actual, -1 = semana anterior, -2 = hace 2 semanas, etc.

  int get _filtrosActivosCount {
    int count = 0;
    if (_filtroJornada != 'TODO') count++;
    if (_filtroTipo != 'TODOS') count++;
    if (_filtroCuenta != 'TODAS') count++;
    if (_filtroCategoriaEgreso != 'TODAS') count++;
    return count;
  }

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sincronizarSemanaSegunPeriodo() {
    final now = DateTime.now();
    if (_filtroPeriodo == 'HOY' || _filtroPeriodo == 'ESTA_SEMANA' || _filtroPeriodo == 'ESTE_MES' || _filtroPeriodo == 'ESTE_ANO' || _filtroPeriodo == 'TODO') {
      _semanaOffset = 0;
    } else if (_filtroPeriodo == 'MES_PASADO') {
      final mesPasado = DateTime(now.year, now.month - 1, 15);
      final diffDias = mesPasado.difference(now).inDays;
      _semanaOffset = (diffDias / 7).round();
    } else if (_filtroPeriodo == 'PERSONALIZADO' && _rangoPersonalizado != null) {
      final diffDias = _rangoPersonalizado!.start.difference(now).inDays;
      _semanaOffset = (diffDias / 7).floor();
    }
  }

  DateTime _obtenerLunesSemana(int offset) {
    final now = DateTime.now();
    final fechaRef = now.add(Duration(days: offset * 7));
    final inicioSemana = fechaRef.subtract(Duration(days: fechaRef.weekday - 1));
    return DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
  }

  bool _estaEnPeriodo(DateTime fecha) {
    final now = DateTime.now();

    // Filtro horario / jornada (Mañana vs Tarde)
    if (_filtroJornada == 'MANANA') {
      if (fecha.hour < 5 || fecha.hour >= 12) return false;
    } else if (_filtroJornada == 'TARDE') {
      if (fecha.hour < 12 || fecha.hour >= 19) return false;
    }

    // Filtro temporal
    if (_filtroPeriodo == 'HOY') {
      return fecha.year == now.year && fecha.month == now.month && fecha.day == now.day;
    } else if (_filtroPeriodo == 'ESTA_SEMANA') {
      final lunes = _obtenerLunesSemana(_semanaOffset);
      final domingo = lunes.add(const Duration(days: 7));
      return fecha.isAfter(lunes.subtract(const Duration(seconds: 1))) && fecha.isBefore(domingo);
    } else if (_filtroPeriodo == 'ESTE_MES') {
      return fecha.year == now.year && fecha.month == now.month;
    } else if (_filtroPeriodo == 'MES_PASADO') {
      final prev = DateTime(now.year, now.month - 1, 1);
      return fecha.year == prev.year && fecha.month == prev.month;
    } else if (_filtroPeriodo == 'ESTE_ANO') {
      return fecha.year == now.year;
    } else if (_filtroPeriodo == 'PERSONALIZADO' && _rangoPersonalizado != null) {
      final start = DateTime(_rangoPersonalizado!.start.year, _rangoPersonalizado!.start.month, _rangoPersonalizado!.start.day);
      final end = DateTime(_rangoPersonalizado!.end.year, _rangoPersonalizado!.end.month, _rangoPersonalizado!.end.day, 23, 59, 59);
      return fecha.isAfter(start.subtract(const Duration(seconds: 1))) && fecha.isBefore(end.add(const Duration(seconds: 1)));
    }
    return true; // 'TODO'
  }

  String _getTituloPeriodo() {
    if (_filtroPeriodo == 'HOY') return 'Rendimiento de Hoy';
    if (_filtroPeriodo == 'ESTA_SEMANA') {
      if (_semanaOffset == 0) return 'Rendimiento de Esta Semana';
      if (_semanaOffset == -1) return 'Rendimiento de la Semana Pasada';
      return 'Rendimiento de hace ${-_semanaOffset} semanas';
    }
    if (_filtroPeriodo == 'ESTE_MES') return 'Rendimiento de Este Mes';
    if (_filtroPeriodo == 'MES_PASADO') return 'Rendimiento del Mes Pasado';
    if (_filtroPeriodo == 'ESTE_ANO') return 'Rendimiento de Este Año (${DateTime.now().year})';
    if (_filtroPeriodo == 'PERSONALIZADO' && _rangoPersonalizado != null) {
      return 'Rango: ${DateFormat('dd/MM').format(_rangoPersonalizado!.start)} - ${DateFormat('dd/MM').format(_rangoPersonalizado!.end)}';
    }
    return 'Rendimiento Histórico Total';
  }

  String _getNombreCortoPeriodo() {
    if (_filtroPeriodo == 'HOY') return 'Hoy';
    if (_filtroPeriodo == 'ESTA_SEMANA') {
      if (_semanaOffset == 0) return 'Esta Semana';
      if (_semanaOffset == -1) return 'Semana Pasada';
      return 'Sem. ${-_semanaOffset}';
    }
    if (_filtroPeriodo == 'ESTE_MES') return 'Este Mes';
    if (_filtroPeriodo == 'MES_PASADO') return 'Mes Pasado';
    if (_filtroPeriodo == 'ESTE_ANO') return 'Este Año';
    if (_filtroPeriodo == 'PERSONALIZADO' && _rangoPersonalizado != null) {
      return '${DateFormat('dd/MM').format(_rangoPersonalizado!.start)}-${DateFormat('dd/MM').format(_rangoPersonalizado!.end)}';
    }
    return 'Histórico';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Contabilidad',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Patrimonio y Finanzas',
                          style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary.withValues(alpha: 0.8)),
                      backgroundColor: primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.picture_as_pdf, size: 14, color: primary),
                    label: Text(
                      'PDF',
                      style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _generarBalanceMensual(context),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    tooltip: 'Historial de Balances',
                    icon: Icon(Icons.history_edu, color: primary, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistorialBalancesScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    tooltip: 'Exportar a Excel / Sheets',
                    icon: Icon(Icons.table_chart, color: primary, size: 20),
                    onPressed: () => _mostrarDialogoExportarExcel(context),
                  ),
                ],
              ),
            ),

            // BARRA UNIFICADA DE CONTROL Y FILTROS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                children: [
                  // Selector de Período Rápido
                  InkWell(
                    onTap: () => _mostrarSelectorPeriodo(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 15, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            _getNombreCortoPeriodo(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Buscador Rápido
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Buscar movimiento...',
                          hintStyle: TextStyle(fontSize: 11.5, color: onSurfaceVariant),
                          prefixIcon: Icon(Icons.search, size: 16, color: onSurfaceVariant),
                          suffixIcon: _busqueda.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 15),
                                  onPressed: () => setState(() => _busqueda = ''),
                                )
                              : null,
                          filled: true,
                          fillColor: cardBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor.withValues(alpha: 0.4)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor.withValues(alpha: 0.3)),
                          ),
                        ),
                        style: TextStyle(color: onSurface, fontSize: 12),
                        onChanged: (val) => setState(() => _busqueda = val),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botón de Filtros Avanzados con Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: _filtrosActivosCount > 0
                              ? primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          minimumSize: const Size(38, 38),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _filtrosActivosCount > 0 ? primary : onSurfaceVariant,
                        ),
                        tooltip: 'Filtros avanzados',
                        onPressed: () => _mostrarModalFiltrosAvanzados(context),
                      ),
                      if (_filtrosActivosCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AgroTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_filtrosActivosCount',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // TIRA DE FILTROS ACTIVOS (SOLO VISIBLE SI HAY FILTROS APLICADOS)
            if (_filtrosActivosCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 4.0, bottom: 4.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_filtroJornada != 'TODO')
                        _buildActiveChip(
                          label: _filtroJornada == 'MANANA' ? '☀️ Mañana' : '⛅ Tarde',
                          onDeleted: () => setState(() => _filtroJornada = 'TODO'),
                        ),
                      if (_filtroTipo != 'TODOS')
                        _buildActiveChip(
                          label: _filtroTipo == 'INGRESO' ? '🟢 Ingresos' : '🔴 Egresos',
                          onDeleted: () => setState(() => _filtroTipo = 'TODOS'),
                        ),
                      if (_filtroCuenta != 'TODAS')
                        _buildActiveChip(
                          label: TransaccionModel.nombreMetodo(_filtroCuenta),
                          onDeleted: () => setState(() => _filtroCuenta = 'TODAS'),
                        ),
                      if (_filtroCategoriaEgreso != 'TODAS')
                        _buildActiveChip(
                          label: 'Gasto: $_filtroCategoriaEgreso',
                          onDeleted: () => setState(() => _filtroCategoriaEgreso = 'TODAS'),
                        ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setState(() {
                            _filtroJornada = 'TODO';
                            _filtroTipo = 'TODOS';
                            _filtroCuenta = 'TODAS';
                            _filtroCategoriaEgreso = 'TODAS';
                          });
                        },
                        child: const Text('Limpiar filtros', style: TextStyle(fontSize: 11, color: AgroTheme.error)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 6),

            // TAB BAR ESTILO STITCH
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: onSurfaceVariant,
                indicator: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Balance y Patrimonio'),
                  Tab(text: 'Cuentas por Cobrar'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // CONTENIDO DE PESTAÑAS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMovimientosTab(cardBg, primary, onSurface, onSurfaceVariant, borderColor),
                  _buildCuentasPorCobrarTab(cardBg, primary, onSurface, onSurfaceVariant, borderColor),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        onPressed: () => _mostrarDialogoEditarTransaccion(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Movimiento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActiveChip({required String label, required VoidCallback onDeleted}) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Chip(
        label: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primary)),
        deleteIcon: Icon(Icons.close_rounded, size: 13, color: primary),
        onDeleted: onDeleted,
        backgroundColor: primary.withValues(alpha: 0.12),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSegmentButton(String tipo, String label, Color primary, Color onSurface, Color onSurfaceVariant) {
    final sel = _filtroTipo == tipo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filtroTipo = tipo),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: sel ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: sel ? FontWeight.bold : FontWeight.w500,
              color: sel ? Colors.black : onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarSelectorPeriodo(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).colorScheme.surface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleccionar Período Contable',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'HOY',
                  title: 'Hoy',
                  subtitle: 'Movimientos registrados el día de hoy',
                  icon: Icons.today_rounded,
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'ESTA_SEMANA',
                  title: 'Esta Semana (Lun - Dom)',
                  subtitle: _semanaOffset == 0 ? 'Semana en curso' : 'Semana seleccionada (offset $_semanaOffset)',
                  icon: Icons.view_week_rounded,
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'ESTE_MES',
                  title: 'Este Mes',
                  subtitle: 'Consolidado del mes en curso',
                  icon: Icons.calendar_month_rounded,
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'MES_PASADO',
                  title: 'Mes Pasado',
                  subtitle: 'Consolidado del mes inmediatamente anterior',
                  icon: Icons.history_rounded,
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'ESTE_ANO',
                  title: 'Este Año (${DateTime.now().year})',
                  subtitle: 'Todos los movimientos acumulados de este año',
                  icon: Icons.calendar_today_rounded,
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'PERSONALIZADO',
                  title: 'Rango Personalizado...',
                  subtitle: _rangoPersonalizado != null
                      ? '${DateFormat('dd/MM/yyyy').format(_rangoPersonalizado!.start)} - ${DateFormat('dd/MM/yyyy').format(_rangoPersonalizado!.end)}'
                      : 'Elige una fecha inicial y final con calendario',
                  icon: Icons.date_range_rounded,
                  onCustomTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      initialDateRange: _rangoPersonalizado ?? DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _rangoPersonalizado = picked;
                        _filtroPeriodo = 'PERSONALIZADO';
                        _sincronizarSemanaSegunPeriodo();
                      });
                    }
                  },
                ),
                _buildPeriodoModalOption(
                  ctx: ctx,
                  key: 'TODO',
                  title: 'Histórico Completo',
                  subtitle: 'Todas las transacciones registradas desde el inicio',
                  icon: Icons.all_inclusive_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodoModalOption({
    required BuildContext ctx,
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onCustomTap,
  }) {
    final sel = _filtroPeriodo == key;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: sel ? primary.withValues(alpha: 0.1) : null,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: sel ? primary.withValues(alpha: 0.2) : onSurfaceVariant.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: sel ? primary : onSurfaceVariant),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: sel ? FontWeight.bold : FontWeight.w600,
          color: sel ? primary : onSurface,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
      trailing: sel ? Icon(Icons.check_circle_rounded, color: primary, size: 20) : null,
      onTap: () {
        if (onCustomTap != null) {
          onCustomTap();
        } else {
          setState(() {
            _filtroPeriodo = key;
            _sincronizarSemanaSegunPeriodo();
          });
          Navigator.pop(ctx);
        }
      },
    );
  }

  void _mostrarModalFiltrosAvanzados(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filtros Avanzados',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
                        ),
                        if (_filtrosActivosCount > 0)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _filtroJornada = 'TODO';
                                _filtroTipo = 'TODOS';
                                _filtroCuenta = 'TODAS';
                                _filtroCategoriaEgreso = 'TODAS';
                              });
                              setState(() {});
                            },
                            child: const Text('Limpiar todo', style: TextStyle(color: AgroTheme.error, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // SECCIÓN 1: JORNADA DEL DÍA
                    Text('Jornada del Día', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'key': 'TODO', 'label': 'Todo el Día', 'icon': Icons.all_inclusive},
                        {'key': 'MANANA', 'label': '☀️ Mañana (5am-12m)', 'icon': Icons.wb_sunny_outlined},
                        {'key': 'TARDE', 'label': '⛅ Tarde (12m-7pm)', 'icon': Icons.wb_cloudy_outlined},
                      ].map((item) {
                        final sel = _filtroJornada == item['key'];
                        return ChoiceChip(
                          label: Text(item['label'] as String),
                          selected: sel,
                          selectedColor: primary.withValues(alpha: 0.2),
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? primary : onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: sel ? primary : borderColor.withValues(alpha: 0.3)),
                          ),
                          onSelected: (val) {
                            setModalState(() => _filtroJornada = val ? (item['key'] as String) : 'TODO');
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // SECCIÓN 2: TIPO DE MOVIMIENTO
                    Text('Tipo de Movimiento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'key': 'TODOS', 'label': 'Todos'},
                        {'key': 'INGRESO', 'label': '🟢 Solo Ingresos'},
                        {'key': 'EGRESO', 'label': '🔴 Solo Egresos'},
                      ].map((item) {
                        final sel = _filtroTipo == item['key'];
                        return ChoiceChip(
                          label: Text(item['label'] as String),
                          selected: sel,
                          selectedColor: primary.withValues(alpha: 0.2),
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? primary : onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: sel ? primary : borderColor.withValues(alpha: 0.3)),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _filtroTipo = item['key'] as String);
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // SECCIÓN 3: CUENTA / BANCO EN COLOMBIA
                    Text('Cuenta / Método de Pago (Colombia)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        'TODAS', 'EFECTIVO', 'BANCOLOMBIA', 'NEQUI', 'DAVIPLATA', 'DAVIVIENDA', 'BANCO_BOGOTA', 'BBVA', 'PSE'
                      ].map((cuentaKey) {
                        final sel = _filtroCuenta == cuentaKey;
                        final label = cuentaKey == 'TODAS' ? 'Todas las Cuentas' : TransaccionModel.nombreMetodo(cuentaKey);
                        return ChoiceChip(
                          label: Text(label),
                          selected: sel,
                          selectedColor: primary.withValues(alpha: 0.2),
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? primary : onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: sel ? primary : borderColor.withValues(alpha: 0.3)),
                          ),
                          onSelected: (val) {
                            setModalState(() => _filtroCuenta = val ? cuentaKey : 'TODAS');
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // SECCIÓN 4: CATEGORÍA DE GASTOS / EGRESOS
                    Text('Categoría de Gastos / Egresos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        'TODAS', 'COMBUSTIBLE', 'MANTENIMIENTO', 'PILOTO', 'INSUMOS', 'BATERIAS', 'VIATICOS', 'REPUESTOS', 'CASA', 'OTROS'
                      ].map((catKey) {
                        final sel = _filtroCategoriaEgreso == catKey;
                        return ChoiceChip(
                          label: Text(catKey == 'TODAS' ? 'Todas las Categorías' : catKey),
                          selected: sel,
                          selectedColor: AgroTheme.error.withValues(alpha: 0.2),
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? AgroTheme.error : onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: sel ? AgroTheme.error : borderColor.withValues(alpha: 0.3)),
                          ),
                          onSelected: (val) {
                            setModalState(() => _filtroCategoriaEgreso = val ? catKey : 'TODAS');
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Aplicar Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: MOVIMIENTOS, PATRIMONIO Y BALANCE VISUAL EN GRANDE
  // ---------------------------------------------------------------------------
  Widget _buildMovimientosTab(Color cardBg, Color primary, Color onSurface, Color onSurfaceVariant, Color borderColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
      builder: (context, snapServicios) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('transacciones').snapshots(),
          builder: (context, snapTransacciones) {
            if (snapTransacciones.connectionState == ConnectionState.waiting ||
                snapServicios.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primary));
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            // Datos de Transacciones filtradas por período
            final docsTrans = snapTransacciones.data?.docs ?? [];
            final todasTrans = docsTrans.map((doc) {
              return TransaccionModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();
            todasTrans.sort((a, b) => b.fecha.compareTo(a.fecha));

            final transaccionesEnPeriodo = todasTrans.where((t) => _estaEnPeriodo(t.fecha)).toList();

            double totalIngresos = 0;
            double totalIngresosEfectivo = 0;
            double totalIngresosLinea = 0;
            int transaccionesIngresoCount = 0;
            double totalEgresos = 0;
            int transaccionesEgresoCount = 0;
            final Map<String, double> egresosPorCat = {};
            final Map<String, int> egresosConteoPorCat = {};

            for (var t in transaccionesEnPeriodo) {
              if (t.tipo == 'INGRESO') {
                totalIngresos += t.monto;
                transaccionesIngresoCount++;
                if (t.metodoPago == 'EN_LINEA') {
                  totalIngresosLinea += t.monto;
                } else {
                  totalIngresosEfectivo += t.monto;
                }
              }
              if (t.tipo == 'EGRESO') {
                totalEgresos += t.monto;
                transaccionesEgresoCount++;
                egresosPorCat[t.categoria] = (egresosPorCat[t.categoria] ?? 0) + t.monto;
                egresosConteoPorCat[t.categoria] = (egresosConteoPorCat[t.categoria] ?? 0) + 1;
              }
            }

            // Datos de Servicios (Hectáreas y Cuentas por Cobrar) filtradas por período
            final docsServ = snapServicios.data?.docs ?? [];
            final todosServ = docsServ.map((doc) {
              return ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();

            final Set<String> servicioIdsConTransaccion = todasTrans
                .where((t) => t.servicioId != null && t.servicioId!.isNotEmpty)
                .map((t) => t.servicioId!)
                .toSet();

            final List<ServicioModel> vuelosCompletadosSinMovimiento = todosServ.where((s) {
              if (s.id == null) return false;
              return s.estado == 'COMPLETADO' && !servicioIdsConTransaccion.contains(s.id);
            }).toList();

            final serviciosEnPeriodo = todosServ.where((s) => _estaEnPeriodo(s.fecha)).toList();

            double totalHa = 0;
            double totalPorCobrar = 0;
            int serviciosPendientes = 0;
            int serviciosPagados = 0;

            for (var s in serviciosEnPeriodo) {
              if (s.estado != 'CANCELADO') {
                totalHa += s.hectareas;
                if (!s.pagado) {
                  totalPorCobrar += s.saldoPendiente;
                  serviciosPendientes++;
                } else {
                  serviciosPagados++;
                }
              }
            }

            final double cajaLiquidaReal = totalIngresos - totalEgresos;
            final double patrimonioReal = cajaLiquidaReal + totalPorCobrar;
            final double totalCartera = totalIngresos + totalPorCobrar;
            final double porcentajeCobrado = totalCartera > 0
                ? (totalIngresos / totalCartera).clamp(0.0, 1.0)
                : 1.0;

            // Métricas de Rentabilidad Neta
            final double margenNeto = cajaLiquidaReal;
            final double margenPorcentaje = totalIngresos > 0 ? ((margenNeto / totalIngresos) * 100) : 0.0;
            final double rentabilidadPorHa = totalHa > 0 ? (margenNeto / totalHa) : 0.0;
            final double costoPorHa = totalHa > 0 ? (totalEgresos / totalHa) : 0.0;

            final transaccionesFiltradas = transaccionesEnPeriodo.where((t) {
              if (_filtroTipo != 'TODOS' && t.tipo != _filtroTipo) return false;
              if (_filtroCuenta != 'TODAS') {
                if (_filtroCuenta == 'EFECTIVO' && !t.esEfectivo) return false;
                if (_filtroCuenta != 'EFECTIVO' && t.metodoPago != _filtroCuenta) return false;
              }
              if (_filtroCategoriaEgreso != 'TODAS') {
                if (t.tipo != 'EGRESO' || !t.categoria.toUpperCase().contains(_filtroCategoriaEgreso.toUpperCase())) {
                  return false;
                }
              }
              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                final matchDesc = t.descripcion.toLowerCase().contains(q);
                final matchCat = t.categoria.toLowerCase().contains(q);
                final matchCliente = (t.clienteNombre ?? '').toLowerCase().contains(q);
                final matchBanco = TransaccionModel.nombreMetodo(t.metodoPago).toLowerCase().contains(q);
                return matchDesc || matchCat || matchCliente || matchBanco;
              }
              return true;
            }).toList();

            // Flujo Semanal Dinámico basado en _semanaOffset (Permite ver semanas pasadas)
            final lunes = _obtenerLunesSemana(_semanaOffset);
            final domingo = lunes.add(const Duration(days: 7));
            final esSemanaActual = _semanaOffset == 0;
            final now = DateTime.now();
            final hoyDiaSemana = now.weekday; // 1 = Lunes, ..., 7 = Domingo

            final List<String> titulosDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
            final List<double> flujoNetoPorDia = List.filled(7, 0.0);
            final List<double> ingresosPorDia = List.filled(7, 0.0);
            final List<double> egresosPorDia = List.filled(7, 0.0);

            for (var t in todasTrans) {
              if (t.fecha.isAfter(lunes.subtract(const Duration(seconds: 1))) && t.fecha.isBefore(domingo)) {
                final diaIdx = t.fecha.weekday - 1; // 0..6
                if (diaIdx >= 0 && diaIdx < 7) {
                  if (t.tipo == 'INGRESO') {
                    ingresosPorDia[diaIdx] += t.monto;
                    flujoNetoPorDia[diaIdx] += t.monto;
                  } else if (t.tipo == 'EGRESO') {
                    egresosPorDia[diaIdx] += t.monto;
                    flujoNetoPorDia[diaIdx] -= t.monto;
                  }
                }
              }
            }

            final totalNetoSemana = flujoNetoPorDia.fold<double>(0.0, (acum, val) => acum + val);
            final maxFlujo = flujoNetoPorDia.map((e) => e.abs()).fold<double>(1.0, (p, e) => e > p ? e : p);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 8.0, bottom: 95.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TÍTULO DE PERÍODO ACTIVO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getTituloPeriodo(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
                      ),
                      Text(
                        '${serviciosEnPeriodo.length} vuelos en período',
                        style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ALERTA DE CONCILIACIÓN DE VUELOS COMPLETADOS SIN REGISTRO EN CAJA
                  if (vuelosCompletadosSinMovimiento.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade700, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${vuelosCompletadosSinMovimiento.length} Vuelo(s) Finalizado(s) sin Reflejar en Caja',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                      ),
                                    ),
                                    Text(
                                      'Vuelos completados que aún no tienen movimiento registrado. Toca para registrar su cobro o crédito:',
                                      style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...vuelosCompletadosSinMovimiento.map((v) {
                            return Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${v.clienteNombre} (${v.cultivo} - ${v.hectareas} Ha)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: onSurface),
                                        ),
                                        Text(
                                          'Valor: ${_currencyFormat.format(v.precioTotal)} • Fecha: ${DateFormat("dd/MM/yyyy").format(v.fecha)}',
                                          style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.paid_outlined, size: 14),
                                    label: const Text('Registrar Cobro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      RegistroCobroServicioDialog.mostrar(context, v, abrirBitacoraDespues: false);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // HERO CARD 1: PATRIMONIO REAL DE LA EMPRESA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance, color: primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'PATRIMONIO REAL',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: primary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Caja + Por Cobrar',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currencyFormat.format(patrimonioReal),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Valor neto operacional • ${totalHa.toStringAsFixed(1)} Ha voladas acumuladas',
                          style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Caja Disponible', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currencyFormat.format(cajaLiquidaReal),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: cajaLiquidaReal >= 0 ? primary : AgroTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: borderColor),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('Por Cobrar', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currencyFormat.format(totalPorCobrar),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // HERO CARD: MÉTRICAS DE RENTABILIDAD NETA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: (margenNeto >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.trending_up, color: margenNeto >= 0 ? Colors.green : Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'RENTABILIDAD NETA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: margenNeto >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (margenNeto >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${margenPorcentaje.toStringAsFixed(1)}% Margen Neto',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: margenNeto >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currencyFormat.format(margenNeto),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: margenNeto >= 0
                                ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.greenAccent
                                    : const Color(0xFF1B5E20))
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ganancia real en caja (Ingresos cobrados - Gastos operativos)',
                          style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Utilidad / Ha', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(rentabilidadPorHa),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: rentabilidadPorHa >= 0 ? primary : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: borderColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Costo Op. / Ha', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(costoPorHa),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: borderColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Margen Operativo', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${margenPorcentaje.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: margenPorcentaje >= 30 ? Colors.green : Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // HERO CARD 2: INGRESO COBRADO VS CUÁNTO SE DEBE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cobrado vs Cuánto se Debe',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${(porcentajeCobrado * 100).toStringAsFixed(0)}% Efectivo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: primary, size: 16),
                                        const SizedBox(width: 4),
                                        Text('Ingresos Cobrados', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currencyFormat.format(totalIngresos),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$serviciosPagados vuelos pagados',
                                      style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.hourglass_top, color: Colors.orangeAccent, size: 16),
                                        SizedBox(width: 4),
                                        Text('Cuánto se Debe', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currencyFormat.format(totalPorCobrar),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$serviciosPendientes por cobrar',
                                      style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: (porcentajeCobrado * 100).toInt().clamp(1, 100),
                                  child: Container(color: primary),
                                ),
                                Expanded(
                                  flex: ((1.0 - porcentajeCobrado) * 100).toInt().clamp(0, 100),
                                  child: Container(color: Colors.orangeAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cobrado: ${(porcentajeCobrado * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                            ),
                            Text(
                              'Pendiente: ${((1.0 - porcentajeCobrado) * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // RESUMEN Y TOTALES DE INGRESOS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.35)),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.trending_up, color: primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Ingresos Recaudados', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),
                                    Text(
                                      _currencyFormat.format(totalIngresos),
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$transaccionesIngresoCount cobros',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('💵', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text('Efectivo', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(totalIngresosEfectivo),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface),
                                  ),
                                  if (totalIngresos > 0)
                                    Text(
                                      '${(totalIngresosEfectivo / totalIngresos * 100).toStringAsFixed(0)}% del total',
                                      style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: borderColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('💳', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text('Transferencia / Línea', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(totalIngresosLinea),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface),
                                  ),
                                  if (totalIngresos > 0)
                                    Text(
                                      '${(totalIngresosLinea / totalIngresos * 100).toStringAsFixed(0)}% del total',
                                      style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // RESUMEN Y DESGLOSE DE EGRESOS POR CATEGORÍA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AgroTheme.error.withValues(alpha: 0.35)),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AgroTheme.error.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.trending_down, color: AgroTheme.error, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Gastos / Egresos', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),
                                    Text(
                                      _currencyFormat.format(totalEgresos),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AgroTheme.error),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AgroTheme.error.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add, size: 14, color: AgroTheme.error),
                              label: const Text('Gasto', style: TextStyle(color: AgroTheme.error, fontSize: 12)),
                              onPressed: () => _mostrarDialogoGastoRapido(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Desglose por Categorías de Egreso',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface),
                            ),
                            Text(
                              '$transaccionesEgresoCount gastos',
                              style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (egresosPorCat.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No se registran egresos en el período seleccionado.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: onSurfaceVariant),
                            ),
                          )
                        else
                          Column(
                            children: egresosPorCat.entries.map((entry) {
                              final cat = entry.key;
                              final monto = entry.value;
                              final pct = totalEgresos > 0 ? (monto / totalEgresos) : 0.0;
                              final conteo = egresosConteoPorCat[cat] ?? 1;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(_getIconoCategoria(cat), size: 15, color: onSurfaceVariant),
                                            const SizedBox(width: 6),
                                            Text(
                                              cat,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '($conteo)',
                                              style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              _currencyFormat.format(monto),
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: onSurface),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AgroTheme.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${(pct * 100).toStringAsFixed(1)}%',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AgroTheme.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 4,
                                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AgroTheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // GRÁFICA DE RENDIMIENTO DINÁMICA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Flujo de Caja Semanal',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (totalNetoSemana >= 0 ? primary : AgroTheme.error).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _currencyFormat.format(totalNetoSemana),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: totalNetoSemana >= 0 ? primary : AgroTheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('d MMM').format(lunes)} - ${DateFormat('d MMM').format(domingo.subtract(const Duration(days: 1)))}'
                                    '${esSemanaActual ? " • Semana Actual" : " • Hace ${-_semanaOffset} sem"}',
                                    style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            // CONTROLES DE NAVEGACIÓN SEMANAL (< Hoy >)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  tooltip: 'Semana anterior',
                                  onPressed: () {
                                    setState(() {
                                      _semanaOffset--;
                                    });
                                  },
                                ),
                                if (!esSemanaActual)
                                  InkWell(
                                    onTap: () => setState(() => _semanaOffset = 0),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Hoy',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: primary),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  tooltip: 'Semana siguiente',
                                  onPressed: esSemanaActual
                                      ? null
                                      : () {
                                          setState(() {
                                            _semanaOffset++;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 130,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 10,
                              minY: 0,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (group) => cardBg,
                                  tooltipBorder: BorderSide(color: borderColor),
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final dia = titulosDias[group.x];
                                    final neto = flujoNetoPorDia[group.x];
                                    final ing = ingresosPorDia[group.x];
                                    final egr = egresosPorDia[group.x];
                                    return BarTooltipItem(
                                      '$dia\nNeto: ${_currencyFormat.format(neto)}\n(+${_currencyFormat.format(ing)} / -${_currencyFormat.format(egr)})',
                                      TextStyle(
                                        color: neto >= 0 ? primary : AgroTheme.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < titulosDias.length) {
                                        final esHoy = esSemanaActual && (hoyDiaSemana - 1) == index;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            titulosDias[index],
                                            style: TextStyle(
                                              color: esHoy ? primary : onSurfaceVariant,
                                              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(7, (i) {
                                final neto = flujoNetoPorDia[i];
                                final esHoy = esSemanaActual && (hoyDiaSemana - 1) == i;
                                final esPositivo = neto >= 0;
                                final double toY = neto == 0
                                    ? 0.5
                                    : ((neto.abs() / maxFlujo) * 9.0 + 1.0).clamp(0.5, 10.0);
                                return _buildBarGroup(i, toY, esHoy, esPositivo, primary);
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // MOVIMIENTOS RECIENTES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial (${transaccionesFiltradas.length})',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                      ),
                      Text(
                        _getTituloPeriodo(),
                        style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // SELECTOR COMPACTO DE TIPO (TODOS, INGRESOS, EGRESOS)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        _buildSegmentButton('TODOS', 'Todos (${transaccionesFiltradas.length})', primary, onSurface, onSurfaceVariant),
                        _buildSegmentButton('INGRESO', '🟢 Ingresos', primary, onSurface, onSurfaceVariant),
                        _buildSegmentButton('EGRESO', '🔴 Egresos', primary, onSurface, onSurfaceVariant),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (transaccionesFiltradas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Text('No hay movimientos en este período.', style: TextStyle(color: onSurfaceVariant)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transaccionesFiltradas.length,
                      itemBuilder: (context, index) {
                        final t = transaccionesFiltradas[index];
                        return _buildRecentJobCard(t, cardBg, primary, onSurface, onSurfaceVariant, borderColor);
                      },
                    ),

                  const SizedBox(height: 95),
                ],
              ),
            );
          },
        );
      },
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, bool destacado, bool esPositivo, Color primary) {
    final barColor = esPositivo ? primary : AgroTheme.error;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: destacado ? barColor : barColor.withValues(alpha: 0.35),
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          borderSide: destacado ? BorderSide(color: barColor, width: 2) : BorderSide.none,
        ),
      ],
    );
  }

  Widget _buildRecentJobCard(
    TransaccionModel trans,
    Color cardBg,
    Color primary,
    Color onSurface,
    Color onSurfaceVariant,
    Color borderColor,
  ) {
    final esIngreso = trans.tipo == 'INGRESO';
    final colorMonto = esIngreso ? primary : (trans.tipo == 'EGRESO' ? AgroTheme.error : Colors.orangeAccent);
    final signo = esIngreso ? '+' : (trans.tipo == 'EGRESO' ? '-' : '');
    final fechaStr = DateFormat('MMM dd, yyyy', 'es').format(trans.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        boxShadow: AgroTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trans.descripcion,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$signo${_currencyFormat.format(trans.monto)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorMonto),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: onSurfaceVariant),
              const SizedBox(width: 4),
              Text(fechaStr, style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                    ),
                    Text('Cat: ${trans.categoria}', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                    Text('•', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                    Text('Tipo: ${trans.tipo}', style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trans.esEfectivo
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        TransaccionModel.nombreMetodo(trans.metodoPago),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: trans.esEfectivo
                              ? (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : const Color(0xFF1B5E20))
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: primary),
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _mostrarDialogoEditarTransaccion(context, trans),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AgroTheme.error),
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmarEliminarTransaccion(trans),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CUENTAS POR COBRAR (SERVICIOS PENDIENTES DE PAGO CON ABONOS)
  // ---------------------------------------------------------------------------
  Widget _buildCuentasPorCobrarTab(Color cardBg, Color primary, Color onSurface, Color onSurfaceVariant, Color borderColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('servicios').snapshots(),
      builder: (context, snapshotServicios) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('deudas').snapshots(),
          builder: (context, snapshotDeudas) {
            if (snapshotServicios.connectionState == ConnectionState.waiting ||
                snapshotDeudas.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primary));
            }

            final docsServ = snapshotServicios.data?.docs ?? [];
            final todosServicios = docsServ.map((doc) => ServicioModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
            final pendientesServ = todosServicios.where((s) => !s.pagado && s.estado != 'CANCELADO').toList();
            final totalDeudaServicios = pendientesServ.fold<double>(0, (prev, s) => prev + s.saldoPendiente);

            final docsDeudas = snapshotDeudas.data?.docs ?? [];
            final todasDeudas = docsDeudas.map((doc) => DeudaModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
            final deudasActivas = todasDeudas.where((d) => !d.pagada).toList();
            // Ordenar: primero las vencidas con mayor mora
            deudasActivas.sort((a, b) {
              if (a.estaVencida && !b.estaVencida) return -1;
              if (!a.estaVencida && b.estaVencida) return 1;
              return b.diasDeuda.compareTo(a.diasDeuda);
            });
            final totalDeudaIndependientes = deudasActivas.fold<double>(0, (prev, d) => prev + d.saldoPendiente);

            final totalCarteraGlobal = totalDeudaServicios + totalDeudaIndependientes;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 95.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TARJETA DE RESUMEN DE CARTERA GLOBAL
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6)),
                      boxShadow: AgroTheme.getShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pending_actions, size: 38, color: Colors.orangeAccent),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Cartera Pendiente por Cobrar', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),
                                  Text(
                                    _currencyFormat.format(totalCarteraGlobal),
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
                                  ),
                                  Text(
                                    '${pendientesServ.length} vuelos (${_currencyFormat.format(totalDeudaServicios)}) • ${deudasActivas.length} deudas directas (${_currencyFormat.format(totalDeudaIndependientes)})',
                                    style: TextStyle(fontSize: 10.5, color: onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_circle_outline, size: 16),
                              label: const Text('Registrar Nueva Deuda', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              onPressed: () => _mostrarDialogoRegistrarDeuda(context),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orangeAccent),
                                foregroundColor: Colors.orangeAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('Informe Cartera (PDF)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                PdfService.generarYCompartirCarteraGeneral(serviciosPendientes: pendientesServ);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ==========================================================
                  // SECCIÓN 1: DEUDAS Y CUENTAS DIRECTAS REGISTRADAS
                  // ==========================================================
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_late_outlined, size: 18, color: deudasActivas.isNotEmpty ? Colors.redAccent : onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text('Deudas y Préstamos Directos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (deudasActivas.isNotEmpty ? Colors.redAccent : onSurfaceVariant).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${deudasActivas.length} activas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: deudasActivas.isNotEmpty ? Colors.redAccent : onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (deudasActivas.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 28, color: primary.withValues(alpha: 0.6)),
                          const SizedBox(height: 6),
                          Text(
                            'No hay deudas directas pendientes.',
                            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _mostrarDialogoRegistrarDeuda(context),
                            child: const Text('+ Agregar cuenta por cobrar a cliente', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: deudasActivas.length,
                      itemBuilder: (context, index) {
                        final d = deudasActivas[index];
                        final double pctAbonado = d.montoTotal > 0
                            ? (d.abonos / d.montoTotal).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: d.estaVencida ? Colors.redAccent.withValues(alpha: 0.7) : borderColor.withValues(alpha: 0.5),
                              width: d.estaVencida ? 1.5 : 1.0,
                            ),
                            boxShadow: AgroTheme.getShadow(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      d.clienteNombre,
                                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: onSurface),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Resta: ${_currencyFormat.format(d.saldoPendiente)}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: d.estaVencida ? Colors.redAccent : Colors.orangeAccent,
                                        ),
                                      ),
                                      if (d.abonos > 0)
                                        Text(
                                          'Total: ${_currencyFormat.format(d.montoTotal)}',
                                          style: TextStyle(fontSize: 10, color: onSurfaceVariant, decoration: TextDecoration.lineThrough),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('📝 ${d.concepto}', style: TextStyle(fontSize: 12.5, color: onSurface)),
                              const SizedBox(height: 8),

                              // AVISO / CUENTA REGRESIVA DE DÍAS SIN PAGAR O VENCIMIENTO
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (d.estaVencida)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            '⚠️ Vencida hace ${-(d.diasRestantesVencimiento ?? 0)} días (${d.diasDeuda} días sin pagar)',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 14, color: Colors.orangeAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            '⏳ Vence en ${d.diasRestantesVencimiento ?? 0} días (${d.diasDeuda} días de antigüedad)',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (d.clienteTelefono.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '📞 ${d.clienteTelefono}',
                                        style: TextStyle(fontSize: 10.5, color: onSurfaceVariant),
                                      ),
                                    ),
                                ],
                              ),

                              // BARRA DE PROGRESO DE ABONO
                              if (d.abonos > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pctAbonado,
                                    minHeight: 5,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Abonado: ${_currencyFormat.format(d.abonos)}', style: const TextStyle(fontSize: 10, color: Colors.green)),
                                    Text('${(pctAbonado * 100).toStringAsFixed(0)}% liquidado', style: TextStyle(fontSize: 10, color: onSurfaceVariant)),
                                  ],
                                ),
                              ],

                              const Divider(height: 16),

                              // ACCIONES DE LA DEUDA
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Eliminar deuda',
                                    icon: const Icon(Icons.delete_outline, size: 17, color: AgroTheme.error),
                                    onPressed: () => _confirmarEliminarDeuda(d),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(color: Colors.green),
                                      foregroundColor: Colors.green,
                                    ),
                                    icon: const Icon(Icons.chat, size: 14, color: Colors.green),
                                    label: const Text('Recordar (WhatsApp)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _enviarRecordatorioDeudaWhatsApp(d),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.payments_outlined, size: 14),
                                    label: const Text('Abonar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _mostrarDialogoAbonarDeuda(d),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.check, size: 15),
                                    label: const Text('Cobrar Todo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _liquidarDeudaCompleta(d),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // ==========================================================
                  // SECCIÓN 2: VUELOS / SERVICIOS CON PAGOS PENDIENTES
                  // ==========================================================
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flight_takeoff, size: 18, color: primary),
                          const SizedBox(width: 6),
                          Text('Vuelos con Pagos Pendientes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface)),
                        ],
                      ),
                      Text('${pendientesServ.length} activos', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (pendientesServ.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
                      ),
                      child: Text('¡Excelente! No hay servicios de vuelo pendientes por cobrar.', style: TextStyle(color: onSurfaceVariant, fontSize: 12)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendientesServ.length,
                      itemBuilder: (context, index) {
                        final s = pendientesServ[index];
                        final double pctAbonado = s.precioTotal > 0
                            ? (s.totalAbonado / s.precioTotal).clamp(0.0, 1.0)
                            : 0.0;
                        final int diasSinPagar = DateTime.now().difference(s.fecha).inDays;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                            boxShadow: AgroTheme.getShadow(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.clienteNombre,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Resta: ${_currencyFormat.format(s.saldoPendiente)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
                                      ),
                                      if (s.totalAbonado > 0)
                                        Text(
                                          'Total: ${_currencyFormat.format(s.precioTotal)}',
                                          style: TextStyle(fontSize: 10, color: onSurfaceVariant, decoration: TextDecoration.lineThrough),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CropBadge(cultivo: s.cultivo),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: s.metodoPago == 'EN_LINEA'
                                          ? Colors.blueAccent.withValues(alpha: 0.15)
                                          : Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      s.metodoPago == 'EN_LINEA' ? '💳 Transferencia' : '💵 Efectivo',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: s.metodoPago == 'EN_LINEA' ? Colors.blueAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : const Color(0xFF1B5E20)),
                                      ),
                                    ),
                                  ),
                                  // Mini aviso de días sin pagar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (diasSinPagar >= 7 ? Colors.redAccent : Colors.orangeAccent).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      diasSinPagar > 0 ? '⚠️ Hace $diasSinPagar días sin pagar' : '📅 Vuelo Hoy',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: diasSinPagar >= 7 ? Colors.redAccent : Colors.orangeAccent,
                                      ),
                                    ),
                                  ),
                                  if (s.totalAbonado > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Abonado: ${_currencyFormat.format(s.totalAbonado)}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('📍 ${s.fincaUbicacion} • ${s.hectareas} Ha', style: TextStyle(fontSize: 12, color: onSurfaceVariant)),

                              // BARRA DE PROGRESO DE ABONO
                              if (s.totalAbonado > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pctAbonado,
                                    minHeight: 6,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${(pctAbonado * 100).toStringAsFixed(0)}% pagado',
                                    style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                  ),
                                ),
                              ],

                              const Divider(height: 18),

                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AgroTheme.error,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.cancel_outlined, size: 15),
                                    label: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _cancelarServicioPorCobrar(s),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar Monto Total',
                                    icon: Icon(Icons.edit_outlined, size: 17, color: primary),
                                    onPressed: () => _mostrarDialogoEditarMontoServicio(s),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(color: primary.withValues(alpha: 0.6)),
                                    ),
                                    icon: Icon(Icons.receipt_long, size: 15, color: primary),
                                    label: Text('Estado Cuenta', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _mostrarOpcionesEstadoCuentaCliente(s, todosServicios),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.payments_outlined, size: 15),
                                    label: const Text('Abonar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _mostrarDialogoAbonarServicio(s),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Cobrar Todo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _registrarCobroServicio(s),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 95),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MÉTODOS DE GESTIÓN DE DEUDAS INDEPENDIENTES
  // ===========================================================================

  void _mostrarDialogoRegistrarDeuda(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String clienteNombre = '';
    String clienteTelefono = '';
    String concepto = '';
    double montoTotal = 0;
    DateTime? fechaVencimiento = DateTime.now().add(const Duration(days: 15));

    // Obtener lista de clientes registrados para sugerencias
    final snapClientes = await FirebaseFirestore.instance.collection('clientes').get();
    final clientesList = snapClientes.docs.map((d) => ClienteModel.fromMap(d.id, d.data())).toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                const Icon(Icons.note_add_outlined, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                const Expanded(child: Text('Registrar Cuenta por Cobrar')),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (clientesList.isNotEmpty) ...[
                      DropdownButtonFormField<ClienteModel>(
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Cliente Registrado (Opcional)',
                          isDense: true,
                        ),
                        items: clientesList.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (clienteSel) {
                          if (clienteSel != null) {
                            setModalState(() {
                              clienteNombre = clienteSel.nombre;
                              clienteTelefono = clienteSel.telefono;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      initialValue: clienteNombre,
                      key: ValueKey(clienteNombre),
                      decoration: const InputDecoration(labelText: 'Nombre del Deudor / Cliente *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese el nombre' : null,
                      onSaved: (val) => clienteNombre = val!.trim(),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: clienteTelefono,
                      key: ValueKey('tel_$clienteTelefono'),
                      decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp (Opcional)'),
                      keyboardType: TextInputType.phone,
                      onSaved: (val) => clienteTelefono = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Monto Total de la Deuda (\$) *', prefixText: '\$ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingrese el monto';
                        final n = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                        if (n == null || n <= 0) return 'Monto inválido';
                        return null;
                      },
                      onSaved: (val) => montoTotal = double.parse(val!.replaceAll('.', '').replaceAll(',', '').trim()),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Concepto / Motivo de la Deuda *',
                        hintText: 'Ej. Préstamo de insumos, saldo atrasado...',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese el concepto' : null,
                      onSaved: (val) => concepto = val!.trim(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fecha Límite:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(
                              fechaVencimiento != null ? DateFormat('dd/MM/yyyy').format(fechaVencimiento!) : 'Sin límite',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: const Text('Elegir Fecha'),
                          onPressed: () async {
                            final pick = await showDatePicker(
                              context: context,
                              initialDate: fechaVencimiento ?? DateTime.now().add(const Duration(days: 15)),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (pick != null) {
                              setModalState(() => fechaVencimiento = pick);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    final nuevaDeuda = DeudaModel(
                      clienteNombre: clienteNombre,
                      clienteTelefono: clienteTelefono,
                      concepto: concepto,
                      montoTotal: montoTotal,
                      fechaEmision: DateTime.now(),
                      fechaVencimiento: fechaVencimiento,
                    );

                    await FirebaseFirestore.instance.collection('deudas').add(nuevaDeuda.toMap());

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('¡Deuda de $clienteNombre registrada exitosamente!')),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoAbonarDeuda(DeudaModel deuda) {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    String metodoPago = 'EFECTIVO';
    String notaAbono = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                const Icon(Icons.payments_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(child: Text('Registrar Abono a Deuda')),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deuda.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(deuda.concepto, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo Pendiente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            _currencyFormat.format(deuda.saldoPendiente),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Monto a Abonar (\$)', prefixText: '\$ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingrese el monto';
                        final numVal = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                        if (numVal == null || numVal <= 0) return 'Monto inválido';
                        if (numVal > deuda.saldoPendiente + 1.0) return 'Supera el saldo (${_currencyFormat.format(deuda.saldoPendiente)})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: metodoPago,
                      decoration: const InputDecoration(labelText: 'Método / Banco Recibido'),
                      items: const [
                        DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo (Caja General)')),
                        DropdownMenuItem(value: 'BANCOLOMBIA', child: Text('🟡 Bancolombia')),
                        DropdownMenuItem(value: 'NEQUI', child: Text('🟣 Nequi')),
                        DropdownMenuItem(value: 'DAVIPLATA', child: Text('🔴 Daviplata')),
                        DropdownMenuItem(value: 'DAVIVIENDA', child: Text('🔴 Davivienda')),
                        DropdownMenuItem(value: 'BANCO_BOGOTA', child: Text('🔵 Banco de Bogotá')),
                        DropdownMenuItem(value: 'BBVA', child: Text('🔵 BBVA')),
                        DropdownMenuItem(value: 'PSE', child: Text('🌐 PSE / En Línea')),
                      ],
                      onChanged: (val) => setModalState(() => metodoPago = val ?? 'EFECTIVO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Nota / Referencia (Opcional)'),
                      onSaved: (val) => notaAbono = val ?? '',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    final montoAbono = double.parse(controller.text.replaceAll('.', '').replaceAll(',', '').trim());

                    final nuevoTotalAbonado = deuda.abonos + montoAbono;
                    final bool pagada = nuevoTotalAbonado >= (deuda.montoTotal - 1.0);
                    final saldoRestante = (deuda.montoTotal - nuevoTotalAbonado).clamp(0.0, double.infinity);

                    // Actualizar documento de deuda
                    if (deuda.id != null) {
                      await FirebaseFirestore.instance.collection('deudas').doc(deuda.id).update({
                        'abonos': nuevoTotalAbonado,
                        'pagada': pagada,
                      });
                    }

                    // REGISTRAR INGRESO AUTOMÁTICO EN CONTABILIDAD
                    final descNota = notaAbono.isNotEmpty ? ' ($notaAbono)' : '';
                    await FirebaseFirestore.instance.collection('transacciones').add({
                      'tipo': 'INGRESO',
                      'categoria': 'ABONO_DEUDA',
                      'monto': montoAbono,
                      'descripcion': 'Abono Deuda [${deuda.concepto}] - ${deuda.clienteNombre}$descNota',
                      'fecha': DateTime.now().toIso8601String(),
                      'clienteNombre': deuda.clienteNombre,
                      'metodoPago': metodoPago,
                    });

                    NotificationService.instance.notificarAbonoRegistrado(
                      cliente: deuda.clienteNombre,
                      monto: montoAbono,
                      saldo: saldoRestante,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('¡Abono de ${_currencyFormat.format(montoAbono)} registrado y contabilizado como Ingreso!')),
                      );
                    }
                  }
                },
                child: const Text('Confirmar Abono'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _liquidarDeudaCompleta(DeudaModel deuda) {
    String metodoPago = 'EFECTIVO';
    final montoRestante = deuda.saldoPendiente;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('¿Confirmar Pago Total de Deuda?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se marcará como totalmente pagada la deuda de "${deuda.clienteNombre}" por un valor de ${_currencyFormat.format(montoRestante)}.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metodoPago,
                decoration: const InputDecoration(labelText: 'Medio de Pago'),
                items: const [
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo (Caja General)')),
                  DropdownMenuItem(value: 'BANCOLOMBIA', child: Text('🟡 Bancolombia')),
                  DropdownMenuItem(value: 'NEQUI', child: Text('🟣 Nequi')),
                  DropdownMenuItem(value: 'DAVIPLATA', child: Text('🔴 Daviplata')),
                  DropdownMenuItem(value: 'PSE', child: Text('🌐 Transferencia / PSE')),
                ],
                onChanged: (val) => setModalState(() => metodoPago = val ?? 'EFECTIVO'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
              onPressed: () async {
                if (deuda.id != null) {
                  await FirebaseFirestore.instance.collection('deudas').doc(deuda.id).update({
                    'abonos': deuda.montoTotal,
                    'pagada': true,
                  });
                }

                // REGISTRAR INGRESO EN CONTABILIDAD
                await FirebaseFirestore.instance.collection('transacciones').add({
                  'tipo': 'INGRESO',
                  'categoria': 'ABONO_DEUDA',
                  'monto': montoRestante,
                  'descripcion': 'Cobro Total Deuda [${deuda.concepto}] - ${deuda.clienteNombre}',
                  'fecha': DateTime.now().toIso8601String(),
                  'clienteNombre': deuda.clienteNombre,
                  'metodoPago': metodoPago,
                });

                NotificationService.instance.notificarAbonoRegistrado(
                  cliente: deuda.clienteNombre,
                  monto: montoRestante,
                  saldo: 0.0,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('¡Deuda de ${deuda.clienteNombre} cancelada y registrada en Ingresos!')),
                );
              },
              child: const Text('Confirmar Cobro'),
            ),
          ],
        ),
      ),
    );
  }

  void _enviarRecordatorioDeudaWhatsApp(DeudaModel deuda) async {
    final buffer = StringBuffer();
    buffer.writeln('🚁 *ICARO PROAGRO - RECORDATORIO DE PAGO* 🌾');
    buffer.writeln('Estimado/a *${deuda.clienteNombre}*, un cordial saludo.');
    buffer.writeln('Le recordamos que a la fecha presenta un saldo pendiente con nosotros:');
    buffer.writeln('');
    buffer.writeln('📌 *Concepto:* ${deuda.concepto}');
    buffer.writeln('💰 *Saldo Pendiente:* ${_currencyFormat.format(deuda.saldoPendiente)}');
    if (deuda.abonos > 0) {
      buffer.writeln('💵 *Ya abonado previamente:* ${_currencyFormat.format(deuda.abonos)}');
      buffer.writeln('📊 *Monto Total:* ${_currencyFormat.format(deuda.montoTotal)}');
    }
    buffer.writeln('📅 *Fecha de Registro:* ${DateFormat("dd/MM/yyyy").format(deuda.fechaEmision)} (${deuda.diasDeuda} días transcurridos)');
    if (deuda.fechaVencimiento != null) {
      if (deuda.estaVencida) {
        buffer.writeln('⚠️ *Estado:* Vencido hace ${-(deuda.diasRestantesVencimiento ?? 0)} días (Límite: ${DateFormat("dd/MM/yyyy").format(deuda.fechaVencimiento!)})');
      } else {
        buffer.writeln('⏳ *Fecha Límite:* ${DateFormat("dd/MM/yyyy").format(deuda.fechaVencimiento!)} (Restan ${deuda.diasRestantesVencimiento ?? 0} días)');
      }
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('📲 _Agradecemos comunicarse con nosotros para acordar el pago o reportar su comprobante de transferencia._');
    buffer.writeln('¡Muchas gracias por su atención!');

    final texto = Uri.encodeComponent(buffer.toString());
    final telLimpio = deuda.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = telLimpio.isNotEmpty
        ? Uri.parse('https://wa.me/57$telLimpio?text=$texto')
        : Uri.parse('https://wa.me/?text=$texto');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: buffer.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje copiado al portapapeles para WhatsApp')),
        );
      }
    }
  }

  void _confirmarEliminarDeuda(DeudaModel deuda) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar Registro de Deuda'),
        content: Text('¿Deseas eliminar la deuda de "${deuda.clienteNombre}" (${deuda.concepto}) por ${_currencyFormat.format(deuda.saldoPendiente)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              if (deuda.id != null) {
                await FirebaseFirestore.instance.collection('deudas').doc(deuda.id).delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deuda eliminada del registro')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GENERADOR DE BALANCE MENSUAL FORMAL
  // ===========================================================================
  void _generarBalanceMensual(BuildContext context) async {
    final now = DateTime.now();
    final mesNombre = DateFormat('MMMM yyyy', 'es').format(now);

    final snapTrans = await FirebaseFirestore.instance.collection('transacciones').get();
    final snapServ = await FirebaseFirestore.instance.collection('servicios').get();

    final todasTrans = snapTrans.docs.map((d) => TransaccionModel.fromMap(d.id, d.data())).toList();
    final todosServ = snapServ.docs.map((d) => ServicioModel.fromMap(d.id, d.data())).toList();

    // Filtrar para el mes actual
    final transMes = todasTrans.where((t) => t.fecha.year == now.year && t.fecha.month == now.month).toList();
    final servMes = todosServ.where((s) => s.fecha.year == now.year && s.fecha.month == now.month).toList();

    double ingMes = 0;
    double ingEfectivoMes = 0;
    double ingLineaMes = 0;
    double egrMes = 0;
    final Map<String, double> egresosPorCat = {};
    final Map<String, int> egresosConteoPorCat = {};

    for (var t in transMes) {
      if (t.tipo == 'INGRESO') {
        ingMes += t.monto;
        if (t.metodoPago == 'EN_LINEA') {
          ingLineaMes += t.monto;
        } else {
          ingEfectivoMes += t.monto;
        }
      }
      if (t.tipo == 'EGRESO') {
        egrMes += t.monto;
        egresosPorCat[t.categoria] = (egresosPorCat[t.categoria] ?? 0) + t.monto;
        egresosConteoPorCat[t.categoria] = (egresosConteoPorCat[t.categoria] ?? 0) + 1;
      }
    }

    double porCobrarMes = 0;
    double haMes = 0;
    for (var s in servMes) {
      haMes += s.hectareas;
      if (!s.pagado && s.estado != 'CANCELADO') {
        porCobrarMes += s.saldoPendiente;
      }
    }

    final utilidadNeta = ingMes - egrMes;

    // Generar formato de reporte
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('🚁 ICARO PROAGRO - BALANCE CONTABLE MENSUAL 🌾');
    buffer.writeln('Mes: ${mesNombre.toUpperCase()}');
    buffer.writeln('Fecha de emisión: ${DateFormat("dd/MM/yyyy HH:mm").format(now)}');
    buffer.writeln('========================================\n');
    buffer.writeln('1. TOTALES Y RECAUDOS DE INGRESOS:');
    buffer.writeln('• En Efectivo:               ${_currencyFormat.format(ingEfectivoMes)}');
    buffer.writeln('• En Línea / Transferencias: ${_currencyFormat.format(ingLineaMes)}');
    buffer.writeln('• TOTAL INGRESOS:            ${_currencyFormat.format(ingMes)}\n');
    buffer.writeln('2. TOTALES Y DESGLOSE DE EGRESOS:');
    if (egresosPorCat.isEmpty) {
      buffer.writeln('  (Sin gastos registrados en el mes)');
    } else {
      egresosPorCat.forEach((cat, valor) {
        final pct = egrMes > 0 ? (valor / egrMes * 100).toStringAsFixed(1) : '0';
        final conteo = egresosConteoPorCat[cat] ?? 1;
        buffer.writeln('• $cat ($conteo reg.): ${_currencyFormat.format(valor)} ($pct%)');
      });
      buffer.writeln('• TOTAL EGRESOS:             ${_currencyFormat.format(egrMes)} (100%)\n');
    }
    buffer.writeln('3. RESULTADOS OPERACIONALES:');
    buffer.writeln('• UTILIDAD OPERATIVA NETA:   ${_currencyFormat.format(utilidadNeta)}');
    buffer.writeln('• Cuentas Pendientes Cobro:  ${_currencyFormat.format(porCobrarMes)}');
    buffer.writeln('• Total Hectáreas Fumigadas: ${haMes.toStringAsFixed(1)} Ha');
    buffer.writeln('• Total Vuelos Registrados:  ${servMes.length}');
    buffer.writeln('\n========================================');
    buffer.writeln('Icaro Proagro - Tecnología Aérea');

    final textoBalance = buffer.toString();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.description, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Balance Mensual - $mesNombre',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  textoBalance,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text(
                  'Generar e Imprimir Balance Oficial PDF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generando documento PDF oficial de Icaro Proagro...')),
                  );
                  await PdfService.generarYCompartirBalance(
                    periodoTitulo: mesNombre.toUpperCase(),
                    transacciones: transMes,
                    servicios: servMes,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar Texto para WhatsApp'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: textoBalance));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Balance copiado al portapapeles!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoGastoRapido(BuildContext context) {
    double monto = 0;
    String categoria = 'COMBUSTIBLE';
    String descripcion = '';
    String metodoPago = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Registrar Gasto Rápido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: categoria,
                items: ['COMBUSTIBLE', 'MANTENIMIENTO', 'PILOTO', 'INSUMOS', 'BATERIAS', 'VIATICOS', 'CASA', 'OTROS']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setMState(() => categoria = val!),
                decoration: const InputDecoration(labelText: 'Categoría de Gasto'),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'Monto del Gasto (\$)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => monto = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'Concepto (ej: Gasolina generador)'),
                onChanged: (v) => descripcion = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: metodoPago,
                items: const [
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo')),
                  DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 Transferencia / En Línea')),
                ],
                onChanged: (val) => setMState(() => metodoPago = val ?? 'EFECTIVO'),
                decoration: const InputDecoration(labelText: 'Método de Pago'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
              onPressed: () async {
                if (monto > 0) {
                  await FirebaseFirestore.instance.collection('transacciones').add({
                    'tipo': 'EGRESO',
                    'categoria': categoria,
                    'monto': monto,
                    'descripcion': descripcion.isNotEmpty ? descripcion : 'Gasto de $categoria',
                    'fecha': DateTime.now().toIso8601String(),
                    'metodoPago': metodoPago,
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar Gasto'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarMontoServicio(ServicioModel s) {
    double nuevoMonto = s.precioTotal;
    final controller = TextEditingController(text: s.precioTotal.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Editar Cobro - ${s.clienteNombre}'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Monto Total a Cobrar (\$)'),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final v = double.tryParse(val);
            if (v != null) nuevoMonto = v;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (s.id != null) {
                await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                  'precioTotal': nuevoMonto,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _registrarCobroServicio(ServicioModel s) async {
    String metodoCobro = s.metodoPago;
    final montoRestante = s.saldoPendiente;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('¿Confirmar Cobro Total?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se cancelará el saldo pendiente de ${s.clienteNombre} por ${_currencyFormat.format(montoRestante)} y el servicio quedará 100% pagado.',
              ),
              if (s.totalAbonado > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '(Ya abonó previamente ${_currencyFormat.format(s.totalAbonado)} de un total de ${_currencyFormat.format(s.precioTotal)})',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: metodoCobro,
                items: const [
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo en Mano')),
                  DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 Transferencia / En Línea')),
                ],
                onChanged: (val) => setDialogState(() => metodoCobro = val ?? 'EFECTIVO'),
                decoration: const InputDecoration(labelText: 'Medio de Pago Recibido'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);

                if (s.id != null) {
                  await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                    'pagado': true,
                    'totalAbonado': s.precioTotal,
                    'estado': 'COMPLETADO',
                    'metodoPago': metodoCobro,
                  });
                }

                await FirebaseFirestore.instance.collection('transacciones').add({
                  'tipo': 'INGRESO',
                  'categoria': 'SERVICIO',
                  'monto': montoRestante,
                  'descripcion': 'Cobro Total Fumigación ${s.cultivo} (${s.hectareas} Ha) - ${s.clienteNombre}',
                  'fecha': DateTime.now().toIso8601String(),
                  'clienteNombre': s.clienteNombre,
                  'servicioId': s.id,
                  'metodoPago': metodoCobro,
                });

                NotificationService.instance.notificarAbonoRegistrado(
                  cliente: s.clienteNombre,
                  monto: montoRestante,
                  saldo: 0.0,
                );

                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('¡Cobro de ${_currencyFormat.format(montoRestante)} registrado con éxito!')),
                );
              },
              child: const Text('Confirmar Cobro'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAbonarServicio(ServicioModel s) {
    final formKey = GlobalKey<FormState>();
    final saldoActual = s.saldoPendiente;
    final controller = TextEditingController();
    String metodoPago = s.metodoPago;
    String notaAbono = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                const Icon(Icons.payments_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(child: Text('Registrar Abono')),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.clienteNombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${s.cultivo} • ${s.hectareas} Ha • ${s.fincaUbicacion}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Servicio:', style: TextStyle(fontSize: 12)),
                              Text(_currencyFormat.format(s.precioTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ya Abonado:', style: TextStyle(fontSize: 12, color: Colors.green)),
                              Text(_currencyFormat.format(s.totalAbonado), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saldo Pendiente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(
                                _currencyFormat.format(saldoActual),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.orangeAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Monto del Abono (\$)',
                        prefixText: '\$ ',
                        hintText: 'Ej. 250000',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ingrese un monto';
                        final numVal = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                        if (numVal == null || numVal <= 0) return 'Monto inválido';
                        if (numVal > saldoActual + 1.0) return 'Supera el saldo (${_currencyFormat.format(saldoActual)})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Quick chips para agilizar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: const Text('Todo el Saldo', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              controller.text = saldoActual.toStringAsFixed(0);
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('50%', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              controller.text = (saldoActual * 0.5).round().toString();
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('30%', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              controller.text = (saldoActual * 0.3).round().toString();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: metodoPago,
                      decoration: const InputDecoration(labelText: 'Método de Pago'),
                      items: const [
                        DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo')),
                        DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 Transferencia / En Línea')),
                      ],
                      onChanged: (val) => setModalState(() => metodoPago = val ?? 'EFECTIVO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Nota / Referencia (Opcional)'),
                      onSaved: (val) => notaAbono = val ?? '',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();

                    final montoAbono = double.parse(controller.text.replaceAll('.', '').replaceAll(',', '').trim());
                    final nuevoTotalAbonado = s.totalAbonado + montoAbono;
                    final bool quedaPagado = nuevoTotalAbonado >= (s.precioTotal - 1.0);
                    final saldoRestante = (s.precioTotal - nuevoTotalAbonado).clamp(0.0, double.infinity);

                    if (s.id != null) {
                      await FirebaseFirestore.instance.collection('servicios').doc(s.id).update({
                        'totalAbonado': nuevoTotalAbonado,
                        'pagado': quedaPagado,
                        if (quedaPagado) 'estado': 'COMPLETADO',
                        'metodoPago': metodoPago,
                      });
                    }

                    final descNota = notaAbono.isNotEmpty ? ' ($notaAbono)' : '';
                    await FirebaseFirestore.instance.collection('transacciones').add({
                      'tipo': 'INGRESO',
                      'categoria': 'SERVICIO',
                      'monto': montoAbono,
                      'descripcion': 'Abono Fumigación ${s.cultivo} (${s.hectareas} Ha) - ${s.clienteNombre}$descNota',
                      'fecha': DateTime.now().toIso8601String(),
                      'clienteNombre': s.clienteNombre,
                      'servicioId': s.id,
                      'metodoPago': metodoPago,
                    });

                    NotificationService.instance.notificarAbonoRegistrado(
                      cliente: s.clienteNombre,
                      monto: montoAbono,
                      saldo: saldoRestante,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Abono de ${_currencyFormat.format(montoAbono)} registrado!'),
                        duration: const Duration(seconds: 7),
                        action: SnackBarAction(
                          label: 'Recibo WhatsApp',
                          textColor: Colors.greenAccent,
                          onPressed: () => _compartirReciboAbonoWhatsApp(
                            s,
                            montoAbono,
                            nuevoTotalAbonado,
                            saldoRestante,
                            metodoPago,
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Confirmar Abono'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarOpcionesEstadoCuentaCliente(ServicioModel s, List<ServicioModel> todosServicios) {
    final serviciosCliente = todosServicios
        .where((srv) => srv.clienteNombre.trim().toLowerCase() == s.clienteNombre.trim().toLowerCase() && srv.estado != 'CANCELADO')
        .toList();

    double totalFacturado = 0;
    double totalAbonado = 0;
    for (var srv in serviciosCliente) {
      totalFacturado += srv.precioTotal;
      totalAbonado += srv.totalAbonado;
    }
    final double saldoTotalDebe = (totalFacturado - totalAbonado).clamp(0.0, double.infinity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estado de Cuenta: ${s.clienteNombre}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Servicios acumulados: ${serviciosCliente.length}', style: const TextStyle(fontSize: 12)),
                      Text('Total Abonado: ${_currencyFormat.format(totalAbonado)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo Total Deudor', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                      Text(
                        _currencyFormat.format(saldoTotalDebe),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
              ),
              title: const Text('Descargar / Compartir Estado de Cuenta (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Documento formal con membrete Icaro Proagro para imprimir o enviar', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.generarYCompartirEstadoCuentaCliente(
                  clienteNombre: s.clienteNombre,
                  clienteTelefono: s.clienteTelefono,
                  fincaUbicacion: s.fincaUbicacion,
                  serviciosCliente: serviciosCliente,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.chat, color: Colors.white, size: 20),
              ),
              title: const Text('Enviar Resumen por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Envía al cliente el detalle claro y cortés de cuánto debe', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _enviarEstadoCuentaWhatsApp(s, serviciosCliente, totalFacturado, totalAbonado, saldoTotalDebe);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _enviarEstadoCuentaWhatsApp(
    ServicioModel s,
    List<ServicioModel> servicios,
    double totalFacturado,
    double totalAbonado,
    double saldoTotalDebe,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('🚁 *ICARO PROAGRO - ESTADO DE CUENTA Y CARTERA* 🌾');
    buffer.writeln('Estimado/a *${s.clienteNombre}*, le compartimos el resumen consolidado de sus servicios de fumigación aérea:');
    buffer.writeln('');
    buffer.writeln('📍 *Finca / Ubicación:* ${s.fincaUbicacion}');
    buffer.writeln('📅 *Fecha de Corte:* ${DateFormat("dd/MM/yyyy").format(DateTime.now())}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('*DETALLE DE SERVICIOS:*');

    for (var srv in servicios) {
      final fStr = DateFormat("dd/MM/yyyy").format(srv.fecha);
      final estadoStr = srv.pagado
          ? '✅ PAGADO'
          : (srv.totalAbonado > 0
              ? '⏳ ABONADO ${_currencyFormat.format(srv.totalAbonado)} (Resta ${_currencyFormat.format(srv.saldoPendiente)})'
              : '⚠️ PENDIENTE ${_currencyFormat.format(srv.precioTotal)}');
      buffer.writeln('• $fStr | ${srv.cultivo} (${srv.hectareas} Ha): $estadoStr');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('📊 *Total Facturado:* ${_currencyFormat.format(totalFacturado)}');
    buffer.writeln('💵 *Total Abonado:* ${_currencyFormat.format(totalAbonado)}');
    buffer.writeln('⚠️ *SALDO TOTAL PENDIENTE:* ${_currencyFormat.format(saldoTotalDebe)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('📲 _Para coordinar su pago o cualquier inquietud, comuníquese con el equipo de Icaro Proagro._');

    final texto = Uri.encodeComponent(buffer.toString());
    final telLimpio = s.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = telLimpio.isNotEmpty
        ? Uri.parse('https://wa.me/57$telLimpio?text=$texto')
        : Uri.parse('https://wa.me/?text=$texto');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: buffer.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje copiado al portapapeles para enviar por WhatsApp')),
        );
      }
    }
  }

  void _compartirReciboAbonoWhatsApp(
    ServicioModel s,
    double montoAbono,
    double nuevoTotalAbonado,
    double saldoRestante,
    String metodoPago,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('🚁 *ICARO PROAGRO - COMPROBANTE DE ABONO* 🌾');
    buffer.writeln('Cliente: *${s.clienteNombre}*');
    buffer.writeln('Finca: ${s.fincaUbicacion}');
    buffer.writeln('Servicio: Fumigación ${s.cultivo} (${s.hectareas} Ha)');
    buffer.writeln('📅 Fecha: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('💵 *Monto Abonado:* ${_currencyFormat.format(montoAbono)}');
    buffer.writeln('💳 *Método:* ${metodoPago == "EN_LINEA" ? "Transferencia / En Línea" : "Efectivo"}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('📊 *Total Servicio:* ${_currencyFormat.format(s.precioTotal)}');
    buffer.writeln('💰 *Total Abonado:* ${_currencyFormat.format(nuevoTotalAbonado)}');
    buffer.writeln('📌 *Saldo Restante:* ${_currencyFormat.format(saldoRestante)}');
    if (saldoRestante <= 0) {
      buffer.writeln('\n✅ *¡Servicio totalmente cancelado y al día!*');
    }
    buffer.writeln('\n_Gracias por preferir la tecnología aérea de Icaro Proagro._');

    final texto = Uri.encodeComponent(buffer.toString());
    final telLimpio = s.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = telLimpio.isNotEmpty
        ? Uri.parse('https://wa.me/57$telLimpio?text=$texto')
        : Uri.parse('https://wa.me/?text=$texto');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: buffer.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprobante copiado al portapapeles')),
        );
      }
    }
  }

  void _mostrarDialogoEditarTransaccion(BuildContext context, TransaccionModel? transExistente) {
    final formKey = GlobalKey<FormState>();

    String tipo = transExistente?.tipo ?? 'INGRESO';
    String categoria = transExistente?.categoria ?? 'SERVICIO';
    double monto = transExistente?.monto ?? 0;
    String descripcion = transExistente?.descripcion ?? '';
    DateTime fecha = transExistente?.fecha ?? DateTime.now();
    String metodoPago = transExistente?.metodoPago ?? 'EFECTIVO';

    final categorias = [
      'SERVICIO',
      'COMBUSTIBLE',
      'MANTENIMIENTO',
      'PILOTO',
      'INSUMOS',
      'BATERIAS',
      'VIATICOS',
      'CASA',
      'OTROS',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(transExistente == null ? 'Nuevo Movimiento' : 'Editar Movimiento'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tipo,
                        items: ['INGRESO', 'EGRESO', 'DEUDA']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setModalState(() => tipo = val!),
                        decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: categoria,
                        items: categorias
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setModalState(() => categoria = val!),
                        decoration: const InputDecoration(labelText: 'Categoría'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: TransaccionModel.metodosPagoMap.containsKey(metodoPago) ? metodoPago : 'EFECTIVO',
                        items: const [
                          DropdownMenuItem(value: 'EFECTIVO', child: Text('💵 Efectivo (Caja General)')),
                          DropdownMenuItem(value: 'BANCOLOMBIA', child: Text('🟡 Bancolombia')),
                          DropdownMenuItem(value: 'NEQUI', child: Text('🟣 Nequi')),
                          DropdownMenuItem(value: 'DAVIPLATA', child: Text('🔴 Daviplata')),
                          DropdownMenuItem(value: 'DAVIVIENDA', child: Text('🔴 Davivienda')),
                          DropdownMenuItem(value: 'BANCO_BOGOTA', child: Text('🔵 Banco de Bogotá')),
                          DropdownMenuItem(value: 'BBVA', child: Text('🔵 BBVA')),
                          DropdownMenuItem(value: 'PSE', child: Text('🌐 PSE / Transferencia')),
                          DropdownMenuItem(value: 'EN_LINEA', child: Text('💳 En Línea (General)')),
                          DropdownMenuItem(value: 'OTROS', child: Text('🏦 Otra Cuenta')),
                        ],
                        onChanged: (val) => setModalState(() => metodoPago = val ?? 'EFECTIVO'),
                        decoration: const InputDecoration(labelText: 'Cuenta / Método de Pago'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: monto > 0 ? monto.toStringAsFixed(0) : '',
                        decoration: const InputDecoration(
                          labelText: 'Monto (\$) - Totalmente editable',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Ingrese un monto válido' : null,
                        onSaved: (val) => monto = double.parse(val!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: descripcion,
                        decoration: const InputDecoration(labelText: 'Descripción / Concepto'),
                        validator: (val) => val == null || val.isEmpty ? 'Ingrese una descripción' : null,
                        onSaved: (val) => descripcion = val!,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          TextButton.icon(
                            icon: Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                            label: Text('Cambiar', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: fecha,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setModalState(() => fecha = d);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);

                      if (transExistente == null) {
                        await FirebaseFirestore.instance.collection('transacciones').add({
                          'tipo': tipo,
                          'categoria': categoria,
                          'monto': monto,
                          'descripcion': descripcion,
                          'fecha': fecha.toIso8601String(),
                          'metodoPago': metodoPago,
                        });
                      } else {
                        await FirebaseFirestore.instance.collection('transacciones').doc(transExistente.id).update({
                          'tipo': tipo,
                          'categoria': categoria,
                          'monto': monto,
                          'descripcion': descripcion,
                          'fecha': fecha.toIso8601String(),
                          'metodoPago': metodoPago,
                        });
                      }

                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text(transExistente == null ? '¡Movimiento guardado!' : '¡Monto actualizado con éxito!')),
                      );
                    }
                  },
                  child: Text(transExistente == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarEliminarTransaccion(TransaccionModel trans) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar Movimiento'),
        content: Text(
          '¿Deseas eliminar el registro "${trans.descripcion}" por ${_currencyFormat.format(trans.monto)}?'
          '${trans.servicioId != null ? '\n\nNota: Este movimiento corresponde a un cobro de vuelo. Al eliminarlo, dicho servicio volverá a figurar en cuentas por cobrar pendientes.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              if (trans.id != null) {
                await FirebaseFirestore.instance.collection('transacciones').doc(trans.id).delete();
                if (trans.servicioId != null) {
                  await FirebaseFirestore.instance.collection('servicios').doc(trans.servicioId).update({'pagado': false});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Movimiento eliminado del registro contable')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _cancelarServicioPorCobrar(ServicioModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Cancelar Operación de Vuelo'),
        content: Text(
          '¿Deseas marcar la operación de "${s.clienteNombre}" (${s.cultivo} • ${s.hectareas} Ha) como CANCELADA?\n\n'
          'Esta acción descartará el cobro de la cartera y sincronizará la contabilidad para que no figure deuda activa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgroTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              if (s.id != null && s.id!.isNotEmpty) {
                await FirebaseFirestore.instance.collection('servicios').doc(s.id!).update({
                  'estado': 'CANCELADO',
                  'pagado': false,
                });
                final transSnap = await FirebaseFirestore.instance
                    .collection('transacciones')
                    .where('servicioId', isEqualTo: s.id!)
                    .get();
                for (var doc in transSnap.docs) {
                  await doc.reference.delete();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Operación cancelada y sincronizada en contabilidad')),
                  );
                }
              }
            },
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoExportarExcel(BuildContext context) async {
    final snap = await FirebaseFirestore.instance.collection('transacciones').get();
    final docs = snap.docs;

    final transacciones = docs.map((d) => TransaccionModel.fromMap(d.id, d.data())).toList();
    transacciones.sort((a, b) => a.fecha.compareTo(b.fecha));

    double sumIngresos = 0;
    double sumEgresos = 0;
    double sumDeudas = 0;

    final buffer = StringBuffer();
    buffer.writeln('FECHA\tTIPO\tCATEGORIA\tDESCRIPCION\tINGRESO\tEGRESO\tDEUDA\tSALDO');

    double saldoAcumulado = 0;
    for (var t in transacciones) {
      final fecha = DateFormat('yyyy-MM-dd').format(t.fecha);
      double ingreso = t.tipo == 'INGRESO' ? t.monto : 0;
      double egreso = t.tipo == 'EGRESO' ? t.monto : 0;
      double deuda = t.tipo == 'DEUDA' ? t.monto : 0;

      saldoAcumulado += (ingreso - egreso);
      sumIngresos += ingreso;
      sumEgresos += egreso;
      sumDeudas += deuda;

      buffer.writeln(
        '$fecha\t${t.tipo}\t${t.categoria}\t${t.descripcion}\t${ingreso.toStringAsFixed(0)}\t${egreso.toStringAsFixed(0)}\t${deuda.toStringAsFixed(0)}\t${saldoAcumulado.toStringAsFixed(0)}',
      );
    }

    buffer.writeln('');
    buffer.writeln('TOTALES:\t\t\t\t${sumIngresos.toStringAsFixed(0)}\t${sumEgresos.toStringAsFixed(0)}\t${sumDeudas.toStringAsFixed(0)}\t${(sumIngresos - sumEgresos).toStringAsFixed(0)}');

    final contenidoParaExcel = buffer.toString();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.table_chart, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Exportar a Excel / Sheets'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consolidado de ${transacciones.length} transacciones contables.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• Ingresos: ${_currencyFormat.format(sumIngresos)}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            Text('• Egresos: ${_currencyFormat.format(sumEgresos)}', style: const TextStyle(color: AgroTheme.error)),
            Text('• Utilidad Neta: ${_currencyFormat.format(sumIngresos - sumEgresos)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('• Pendiente por Cobrar: ${_currencyFormat.format(sumDeudas)}', style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Al tocar "Copiar para Excel / Google Sheets", los datos se copian en formato de celdas. Solo abre un archivo nuevo de Excel o Sheets y presiona Ctrl + V.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar para Excel / Sheets'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contenidoParaExcel));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Datos copiados! Pégalos (Ctrl+V) en cualquier hoja de Excel o Google Sheets.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconoCategoria(String cat) {
    final c = cat.toUpperCase();
    if (c.contains('CASA') || c.contains('HOGAR')) return Icons.home_outlined;
    if (c.contains('COMBUSTIBLE')) return Icons.local_gas_station;
    if (c.contains('MANTENIMIENTO')) return Icons.build_outlined;
    if (c.contains('PILOTO') || c.contains('NOMINA') || c.contains('NÓMINA')) return Icons.badge_outlined;
    if (c.contains('INSUMO') || c.contains('QUIMICO')) return Icons.science_outlined;
    if (c.contains('BATERIA') || c.contains('BATERÍA')) return Icons.battery_charging_full;
    if (c.contains('VIATICO') || c.contains('VIÁTICO') || c.contains('TRANSPORTE')) return Icons.directions_car_outlined;
    if (c.contains('REPUESTO')) return Icons.precision_manufacturing_outlined;
    if (c.contains('SEGURO')) return Icons.security_outlined;
    return Icons.receipt_outlined;
  }
}