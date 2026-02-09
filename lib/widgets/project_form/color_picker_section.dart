import 'package:flutter/material.dart';

class ColorPickerSection extends StatelessWidget {
  final String selectedColor;
  final Function(String) onColorChanged;

  const ColorPickerSection({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  static const List<Color> _availableColors = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFF44336),
    Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFE91E63),
    Color(0xFF795548), Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            "Цвет проекта",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              // Используем toARGB32 для получения hex
              final colorString = '0x${color.toARGB32().toRadixString(16).toUpperCase()}';
              final isSelected = selectedColor == colorString;

              return GestureDetector(
                onTap: () => onColorChanged(colorString),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 40 : 32,
                    height: isSelected ? 40 : 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: colorScheme.onSurface, width: 2) : null,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2)
                        )
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}