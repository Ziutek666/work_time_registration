import 'package:flutter/material.dart';
import 'package:work_time_registration/models/app_data.dart'; // Assuming appData is here

/// A widget that displays a grid of selectable colors.
class ColorPickerGrid extends StatefulWidget {
  /// Callback function that is triggered when a color is selected.
  final ValueChanged<Color> onColorSelected;

  /// The color that should be initially selected.
  final Color? initialSelectedColor;

  const ColorPickerGrid({
    Key? key,
    required this.onColorSelected,
    this.initialSelectedColor,
  }) : super(key: key);

  @override
  State<ColorPickerGrid> createState() => _ColorPickerGridState();
}

class _ColorPickerGridState extends State<ColorPickerGrid> {
  // Holds the currently selected color to highlight it in the grid.
  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialSelectedColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableColors = appData.colorsList; // Using the global appData instance

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6, // Number of colors per row
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: availableColors.length,
      itemBuilder: (context, index) {
        final color = availableColors[index];
        final isSelected = _selectedColor == color;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
            widget.onColorSelected(color);
          },
          borderRadius: BorderRadius.circular(50.0), // Circular shape for the ripple effect
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                width: 3.0,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
                  : [],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      },
    );
  }
}