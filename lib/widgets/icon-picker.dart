import 'package:flutter/material.dart';
import 'package:work_time_registration/models/app_data.dart'; // Załóżmy, że appData jest tutaj

/// Widget wyświetlający siatkę ikon do wyboru.
class IconPickerGrid extends StatefulWidget {
  /// Callback wywoływany, gdy użytkownik wybierze ikonę.
  final ValueChanged<IconData> onIconSelected;

  /// Opcjonalnie: ikona, która ma być początkowo zaznaczona.
  final IconData? initialSelectedIcon;

  const IconPickerGrid({
    Key? key,
    required this.onIconSelected,
    this.initialSelectedIcon,
  }) : super(key: key);

  @override
  State<IconPickerGrid> createState() => _IconPickerGridState();
}

class _IconPickerGridState extends State<IconPickerGrid> {
  // Przechowuje aktualnie wybraną ikonę, aby ją podświetlić.
  IconData? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialSelectedIcon;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableIcons = appData.iconsList; // Użycie globalnej instancji appData

    if (availableIcons.isEmpty) {
      return const Center(child: Text("Brak dostępnych ikon."));
    }

    return GridView.builder(
      shrinkWrap: true, // Aby siatka zajęła tylko potrzebne miejsce
      physics: const NeverScrollableScrollPhysics(), // Jeśli siatka jest wewnątrz SingleChildScrollView
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6, // Liczba ikon w rzędzie
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: availableIcons.length,
      itemBuilder: (context, index) {
        final icon = availableIcons[index];
        final isSelected = _selectedIcon == icon;

        return InkWell(
          onTap: () {
            // Zaktualizuj stan, aby podświetlić wybraną ikonę
            setState(() {
              _selectedIcon = icon;
            });
            // Wywołaj callback, aby przekazać wybraną ikonę do rodzica
            widget.onIconSelected(icon);
          },
          borderRadius: BorderRadius.circular(8.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}