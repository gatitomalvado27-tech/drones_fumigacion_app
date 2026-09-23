import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../theme/agro_theme.dart';
import '../models/bodega_item_model.dart';

class BodegaScreen extends StatefulWidget {
  const BodegaScreen({super.key});

  @override
  State<BodegaScreen> createState() => _BodegaScreenState();
}

class _BodegaScreenState extends State<BodegaScreen> {
  String _busqueda = '';
  String _filtroCategoria = 'TODOS';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = AgroTheme.isDark(context);
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final subtext = AgroTheme.getSubtext(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    return Scaffold(
      backgroundColor: AgroTheme.getBg(context),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bodega').snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final todosItems = docs.map((d) {
              return BodegaItemModel.fromMap(d.id, d.data() as Map<String, dynamic>);
            }).toList();

            // Calcular totales de métricas
            double valorTotalInventario = 0;
            int totalBajoStock = 0;
            for (var item in todosItems) {
              valorTotalInventario += item.valorTotal;
              if (item.estaBajoStock) totalBajoStock++;
            }

            // Filtrar
            final itemsFiltrados = todosItems.where((item) {
              if (_filtroCategoria == 'EN_ALERTA' && !item.estaBajoStock) {
                return false;
              } else if (_filtroCategoria != 'TODOS' &&
                  _filtroCategoria != 'EN_ALERTA' &&
                  item.categoria != _filtroCategoria) {
                return false;
              }

              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                final matchNombre = item.nombre.toLowerCase().contains(q);
                final matchUbicacion = item.ubicacionBodega.toLowerCase().contains(q);
                final matchDesc = item.descripcion.toLowerCase().contains(q);
                return matchNombre || matchUbicacion || matchDesc;
              }
              return true;
            }).toList();

            return Column(
              children: [
                // HEADER DE BODEGA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.inventory_2, color: Color(0xFF2E7D32), size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bodega & Almacén',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Insumos, Repuestos y Equipos Propios',
                              style: TextStyle(fontSize: 11, color: subtext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Nuevo Ítem',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _mostrarDialogoItem(context, null),
                      ),
                    ],
                  ),
                ),

                // TARJETA DE ESTADÍSTICAS DEL INVENTARIO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Valorización Total',
                          _currencyFormat.format(valorTotalInventario),
                          primary,
                          Icons.monetization_on_outlined,
                        ),
                        Container(height: 35, width: 1, color: border),
                        _buildStatColumn(
                          'Referencias',
                          '${todosItems.length} ítems',
                          text,
                          Icons.category_outlined,
                        ),
                        Container(height: 35, width: 1, color: border),
                        _buildStatColumn(
                          'Stock Crítico',
                          '$totalBajoStock alertas',
                          totalBajoStock > 0 ? Colors.redAccent : Colors.green,
                          Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                // BARRA DE BÚSQUEDA
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar repuesto, insumo, ubicación...',
                      hintStyle: TextStyle(color: subtext, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: subtext, size: 20),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary, width: 1.5),
                      ),
                    ),
                    style: TextStyle(color: text, fontSize: 13),
                    onChanged: (val) => setState(() => _busqueda = val),
                  ),
                ),

                // FILTROS POR CATEGORÍA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('TODOS', 'Todos', Icons.all_inbox),
                        const SizedBox(width: 8),
                        _buildFilterChip('REPUESTO', 'Repuestos', Icons.build_circle_outlined),
                        const SizedBox(width: 8),
                        _buildFilterChip('INSUMO_QUIMICO', 'Insumos / Químicos', Icons.science_outlined),
                        const SizedBox(width: 8),
                        _buildFilterChip('EQUIPO', 'Equipos & Drones', Icons.flight_takeoff),
                        const SizedBox(width: 8),
                        _buildFilterChip('HERRAMIENTA', 'Herramientas', Icons.handyman_outlined),
                        const SizedBox(width: 8),
                        _buildFilterChip('EN_ALERTA', '⚠️ Stock Bajo', Icons.error_outline,
                            isAlert: true, alertCount: totalBajoStock),
                      ],
                    ),
                  ),
                ),

                // LISTA DE ÍTEMS EN BODEGA
                Expanded(
                  child: itemsFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: subtext.withValues(alpha: 0.5)),
                              const SizedBox(height: 10),
                              Text(
                                todosItems.isEmpty
                                    ? 'La bodega está vacía.\nRegistra tu primer insumo o repuesto.'
                                    : 'No hay elementos con el filtro actual.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subtext, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 90),
                          itemCount: itemsFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = itemsFiltrados[index];
                            return _buildItemCard(context, item, cardBg, border, text, subtext, primary);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, {bool isAlert = false, int alertCount = 0}) {
    final sel = _filtroCategoria == key;
    final primary = AgroTheme.getPrimary(context);
    final cardBg = AgroTheme.getCard(context);
    final border = AgroTheme.getBorder(context);

    Color activeColor = primary;
    if (isAlert) activeColor = Colors.redAccent;

    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 14,
        color: sel ? Colors.black : (isAlert && alertCount > 0 ? Colors.redAccent : AgroTheme.getSubtext(context)),
      ),
      label: Text(
        isAlert && alertCount > 0 ? '$label ($alertCount)' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
          color: sel ? Colors.black : AgroTheme.getText(context),
        ),
      ),
      selected: sel,
      selectedColor: activeColor,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: sel ? activeColor : (isAlert && alertCount > 0 ? Colors.redAccent.withValues(alpha: 0.5) : border),
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _filtroCategoria = key);
      },
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    BodegaItemModel item,
    Color cardBg,
    Color border,
    Color text,
    Color subtext,
    Color primary,
  ) {
    final bool bajoStock = item.estaBajoStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bajoStock ? Colors.redAccent.withValues(alpha: 0.7) : border,
          width: bajoStock ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MINIATURA O FOTO DEL OBJETO
                GestureDetector(
                  onTap: () {
                    if (item.imagenBase64 != null) {
                      _mostrarFotoAmpliada(context, item.nombre, item.imagenBase64!);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: primary.withValues(alpha: 0.1),
                      child: item.imagenBase64 != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  base64Decode(item.imagenBase64!),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.fullscreen, size: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            )
                          : Icon(
                              _getIconoCategoria(item.categoria),
                              color: primary,
                              size: 28,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // DETALLES DEL OBJETO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.nombre,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_vert, size: 18, color: subtext),
                            onSelected: (val) {
                              if (val == 'editar') {
                                _mostrarDialogoItem(context, item);
                              } else if (val == 'eliminar') {
                                _confirmarEliminar(context, item);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'editar', child: Text('Editar')),
                              const PopupMenuItem(
                                value: 'eliminar',
                                child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getNombreCategoria(item.categoria),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.location_on_outlined, size: 12, color: subtext),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.ubicacionBodega,
                              style: TextStyle(fontSize: 11, color: subtext),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (item.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.descripcion,
                          style: TextStyle(fontSize: 11, color: subtext),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // FILA DE STOCK Y BOTONES RÁPIDOS (+ / -)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stock: ',
                          style: TextStyle(fontSize: 11, color: subtext),
                        ),
                        Text(
                          '${item.cantidad.toStringAsFixed(item.cantidad % 1 == 0 ? 0 : 1)} ${item.unidad}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: bajoStock ? Colors.redAccent : text,
                          ),
                        ),
                        if (bajoStock) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '⚠️ Bajo',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.costoUnitario > 0)
                      Text(
                        'Total: ${_currencyFormat.format(item.valorTotal)}',
                        style: TextStyle(fontSize: 10, color: subtext),
                      ),
                  ],
                ),

                // BOTONES RÁPIDOS DE MOVIMIENTO (+ Entrada / - Salida)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Descontar / Salida',
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: () => _modificarStockRapido(context, item, false),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Agregar / Entrada',
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => _modificarStockRapido(context, item, true),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconoCategoria(String cat) {
    switch (cat) {
      case 'REPUESTO':
        return Icons.build_circle_outlined;
      case 'INSUMO_QUIMICO':
        return Icons.science_outlined;
      case 'EQUIPO':
        return Icons.flight_takeoff;
      case 'HERRAMIENTA':
        return Icons.handyman_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  String _getNombreCategoria(String cat) {
    switch (cat) {
      case 'REPUESTO':
        return 'Repuesto';
      case 'INSUMO_QUIMICO':
        return 'Insumo / Químico';
      case 'EQUIPO':
        return 'Equipo / Dron';
      case 'HERRAMIENTA':
        return 'Herramienta';
      default:
        return 'General';
    }
  }

  void _mostrarFotoAmpliada(BuildContext context, String nombre, String base64) {
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
                    child: Image.memory(
                      base64Decode(base64),
                      fit: BoxFit.contain,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
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

  void _modificarStockRapido(BuildContext context, BodegaItemModel item, bool esEntrada) {
    final cantidadCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEntrada ? '📥 Entrada a Bodega' : '📤 Salida de Bodega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Stock actual: ${item.cantidad} ${item.unidad}',
              style: TextStyle(fontSize: 12, color: AgroTheme.getSubtext(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: esEntrada ? 'Cantidad a ingresar' : 'Cantidad a retirar',
                suffixText: item.unidad,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;
              if (val <= 0) return;

              final nuevaCantidad = esEntrada ? (item.cantidad + val) : (item.cantidad - val);
              if (nuevaCantidad < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No puedes retirar más de lo que hay en stock.')),
                );
                return;
              }

              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('bodega').doc(item.id).update({
                'cantidad': nuevaCantidad,
                'fechaActualizacion': DateTime.now().toIso8601String(),
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      esEntrada
                          ? 'Se sumaron $val ${item.unidad} a ${item.nombre}.'
                          : 'Se retiraron $val ${item.unidad} de ${item.nombre}.',
                    ),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              }
            },
            child: Text(esEntrada ? 'Ingresar' : 'Retirar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, BodegaItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar de la bodega?'),
        content: Text('¿Seguro que deseas eliminar "${item.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('bodega').doc(item.id).delete();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoItem(BuildContext context, BodegaItemModel? itemExistente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AgroTheme.getCard(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FormularioBodegaSheet(itemExistente: itemExistente),
    );
  }
}

class _FormularioBodegaSheet extends StatefulWidget {
  final BodegaItemModel? itemExistente;
  const _FormularioBodegaSheet({this.itemExistente});

  @override
  State<_FormularioBodegaSheet> createState() => _FormularioBodegaSheetState();
}

class _FormularioBodegaSheetState extends State<_FormularioBodegaSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _cantidadCtrl;
  late TextEditingController _minimoCtrl;
  late TextEditingController _ubicacionCtrl;
  late TextEditingController _costoCtrl;
  late TextEditingController _descripcionCtrl;

  String _categoria = 'REPUESTO';
  String _unidad = 'unidades';
  String? _imagenBase64;
  bool _guardando = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final item = widget.itemExistente;
    _nombreCtrl = TextEditingController(text: item?.nombre ?? '');
    _cantidadCtrl = TextEditingController(text: item != null ? item.cantidad.toString() : '1');
    _minimoCtrl = TextEditingController(text: item != null ? item.cantidadMinimaAlerta.toString() : '2');
    _ubicacionCtrl = TextEditingController(text: item?.ubicacionBodega ?? 'Bodega Principal');
    _costoCtrl = TextEditingController(text: item != null && item.costoUnitario > 0 ? item.costoUnitario.toStringAsFixed(0) : '');
    _descripcionCtrl = TextEditingController(text: item?.descripcion ?? '');
    _categoria = item?.categoria ?? 'REPUESTO';
    _unidad = item?.unidad ?? 'unidades';
    _imagenBase64 = item?.imagenBase64;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _minimoCtrl.dispose();
    _ubicacionCtrl.dispose();
    _costoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarFoto(ImageSource source) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (foto != null) {
        final bytes = await foto.readAsBytes();
        setState(() {
          _imagenBase64 = base64Encode(bytes);
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itemExistente != null;
    final primary = AgroTheme.getPrimary(context);
    final text = AgroTheme.getText(context);
    final border = AgroTheme.getBorder(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Editar Ítem de Bodega' : 'Nuevo Ítem de Bodega',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // SECCIÓN DE FOTO DEL OBJETO
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: _imagenBase64 != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    base64Decode(_imagenBase64!),
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _imagenBase64 = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Icon(Icons.add_a_photo_outlined, size: 36, color: primary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Tomar Foto', style: TextStyle(fontSize: 12)),
                          onPressed: () => _capturarFoto(ImageSource.camera),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Galería', style: TextStyle(fontSize: 12)),
                          onPressed: () => _capturarFoto(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // NOMBRE
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del objeto / repuesto *',
                  hintText: 'Ej. Hélice 5413 CW Agras T40',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 12),

              // CATEGORÍA Y UNIDAD
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'REPUESTO', child: Text('Repuesto')),
                        DropdownMenuItem(value: 'INSUMO_QUIMICO', child: Text('Insumo / Químico')),
                        DropdownMenuItem(value: 'EQUIPO', child: Text('Equipo / Dron')),
                        DropdownMenuItem(value: 'HERRAMIENTA', child: Text('Herramienta')),
                        DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _categoria = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidad,
                      decoration: const InputDecoration(
                        labelText: 'Unidad de medida',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'unidades', child: Text('Unidades')),
                        DropdownMenuItem(value: 'litros', child: Text('Litros (L)')),
                        DropdownMenuItem(value: 'kilos', child: Text('Kilos (Kg)')),
                        DropdownMenuItem(value: 'paquetes', child: Text('Paquetes')),
                        DropdownMenuItem(value: 'metros', child: Text('Metros')),
                        DropdownMenuItem(value: 'kits', child: Text('Kits')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _unidad = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CANTIDAD Y STOCK MÍNIMO
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad actual *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _minimoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Alerta stock mínimo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // COSTO UNITARIO Y UBICACIÓN
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Costo unitario (\$ COP)',
                        hintText: 'Ej. 150000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _ubicacionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación en bodega',
                        hintText: 'Estante 2, Camioneta...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // DESCRIPCIÓN Y ESPECIFICACIONES
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Compatibilidad',
                  hintText: 'Compatible con DJI T40 / T50, Lote #...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _guardando ? 'Guardando...' : (isEdit ? 'Actualizar Objeto' : 'Registrar en Bodega'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _guardando
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _guardando = true);

                          final cant = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          final min = double.tryParse(_minimoCtrl.text.replaceAll(',', '.')) ?? 2.0;
                          final costo = double.tryParse(_costoCtrl.text.replaceAll(',', '.')) ?? 0.0;

                          final model = BodegaItemModel(
                            id: widget.itemExistente?.id,
                            nombre: _nombreCtrl.text.trim(),
                            categoria: _categoria,
                            cantidad: cant,
                            unidad: _unidad,
                            cantidadMinimaAlerta: min,
                            ubicacionBodega: _ubicacionCtrl.text.trim(),
                            costoUnitario: costo,
                            descripcion: _descripcionCtrl.text.trim(),
                            imagenBase64: _imagenBase64,
                            fechaActualizacion: DateTime.now(),
                          );

                          try {
                            if (isEdit) {
                              await FirebaseFirestore.instance
                                  .collection('bodega')
                                  .doc(model.id)
                                  .update(model.toMap());
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('bodega')
                                  .add(model.toMap());
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Ítem actualizado exitosamente.'
                                        : 'Ítem registrado en bodega.',
                                  ),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => _guardando = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
