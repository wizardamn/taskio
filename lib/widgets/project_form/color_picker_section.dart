import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ColorPickerSection extends StatelessWidget {
  final String selectedColor;
  final Function(String) onColorChanged;

  const ColorPickerSection({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  static const List<Color> _availableColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'projects.color'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final color = _availableColors[index];

              // ✅ Исправлено: используем toARGB32()
              final colorString =
                  '0x${color.toARGB32().toRadixString(16).toUpperCase()}';

              final isSelected = selectedColor == colorString;

              return GestureDetector(
                onTap: () => onColorChanged(colorString),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 42 : 34,
                  height: isSelected ? 42 : 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                      color: colorScheme.onSurface,
                      width: 2,
                    )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        // ✅ Исправлено: используем withValues()
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                      : null,
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