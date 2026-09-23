import 'package:flutter/material.dart';
import '../theme/agro_theme.dart';

class CropHelper {
  static const List<Map<String, String>> listaCultivos = [
    {'nombre': 'Arroz', 'emoji': '🌾'},
    {'nombre': 'Maíz', 'emoji': '🌽'},
    {'nombre': 'Caña de azúcar', 'emoji': '🎋'},
    {'nombre': 'Café', 'emoji': '☕'},
    {'nombre': 'Plátano / Banano', 'emoji': '🍌'},
    {'nombre': 'Pasto / Ganadería', 'emoji': '🥩'},
    {'nombre': 'Palma de aceite', 'emoji': '🌴'},
    {'nombre': 'Cacao', 'emoji': '🍫'},
    {'nombre': 'Papa', 'emoji': '🥔'},
    {'nombre': 'Papa Criolla', 'emoji': '🥔'},
    {'nombre': 'Aguacate (Hass)', 'emoji': '🥑'},
    {'nombre': 'Cítricos (Limón, Naranja)', 'emoji': '🍊'},
    {'nombre': 'Tomate', 'emoji': '🍅'},
    {'nombre': 'Cebolla', 'emoji': '🧅'},
    {'nombre': 'Flores / Floricultura', 'emoji': '💐'},
    {'nombre': 'Frijol', 'emoji': '🫘'},
    {'nombre': 'Soya', 'emoji': '🌱'},
    {'nombre': 'Algodón', 'emoji': '☁️'},
    {'nombre': 'Sorgo', 'emoji': '🌾'},
    {'nombre': 'Yuca', 'emoji': '🍠'},
    {'nombre': 'Piña', 'emoji': '🍍'},
    {'nombre': 'Mango', 'emoji': '🥭'},
    {'nombre': 'Hortalizas', 'emoji': '🥬'},
    {'nombre': 'Tabaco', 'emoji': '🍂'},
    {'nombre': 'Frutales', 'emoji': '🍎'},
    {'nombre': 'Otro (Personalizado)', 'emoji': '🌱'},
  ];

  static List<String> get nombresCultivos => listaCultivos.map((c) => c['nombre']!).toList();
  static List<String> get cultivos => nombresCultivos;

  static String getEmoji(String cultivo) {
    final normalizado = cultivo.toLowerCase().trim();
    for (var c in listaCultivos) {
      if (normalizado.contains(c['nombre']!.toLowerCase())) {
        return c['emoji']!;
      }
    }
    // Detección por palabras clave
    if (normalizado.contains('arroz')) return '🌾';
    if (normalizado.contains('maiz') || normalizado.contains('maíz')) return '🌽';
    if (normalizado.contains('caña') || normalizado.contains('cana')) return '🎋';
    if (normalizado.contains('cafe') || normalizado.contains('café')) return '☕';
    if (normalizado.contains('platano') || normalizado.contains('plátano') || normalizado.contains('banan')) return '🍌';
    if (normalizado.contains('pasto') || normalizado.contains('ganader')) return '🥩';
    if (normalizado.contains('palma')) return '🌴';
    if (normalizado.contains('cacao')) return '🍫';
    if (normalizado.contains('papa') || normalizado.contains('criolla') || normalizado.contains('crolla')) return '🥔';
    if (normalizado.contains('aguacate') || normalizado.contains('palta')) return '🥑';
    if (normalizado.contains('citrico') || normalizado.contains('cítrico') || normalizado.contains('limon') || normalizado.contains('naranja')) return '🍊';
    if (normalizado.contains('tomate')) return '🍅';
    if (normalizado.contains('cebolla')) return '🧅';
    if (normalizado.contains('flor')) return '💐';
    if (normalizado.contains('frijol') || normalizado.contains('frejol')) return '🫘';
    if (normalizado.contains('soya') || normalizado.contains('soja')) return '🌱';
    if (normalizado.contains('algodon') || normalizado.contains('algodón')) return '☁️';
    if (normalizado.contains('sorgo')) return '🌾';
    if (normalizado.contains('yuca')) return '🍠';
    if (normalizado.contains('piña') || normalizado.contains('pina')) return '🍍';
    if (normalizado.contains('mango')) return '🥭';
    if (normalizado.contains('hortaliza') || normalizado.contains('lechuga')) return '🥬';
    if (normalizado.contains('tabaco')) return '🍂';
    if (normalizado.contains('siembra')) return '🌱';
    if (normalizado.contains('monitoreo') || normalizado.contains('mapeo')) return '🛰️';

    return '🌱';
  }
}

class CropBadge extends StatelessWidget {
  final String cultivo;
  final bool showLabel;
  final double fontSize;
  final Color? customColor;

  const CropBadge({
    super.key,
    required this.cultivo,
    this.showLabel = true,
    this.fontSize = 11,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = CropHelper.getEmoji(cultivo);
    final primary = customColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: fontSize + 2)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              cultivo,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AgroTheme.getText(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
