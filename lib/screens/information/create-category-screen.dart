// lib/widgets/icon_picker_grid.dart
import 'package:flutter/material.dart';

import '../../models/app_data.dart';
import '../../models/information_category.dart';
import '../../services/information_category_service.dart';
import '../../widgets/color-picker.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/icon-picker.dart';// Upewnij się, że ścieżka jest poprawna


class CreateCategoryDialog extends StatefulWidget {
  final String projectId;
  const CreateCategoryDialog({Key? key, required this.projectId}) : super(key: key);

  @override
  State<CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<CreateCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  IconData? _selectedIcon;
  Color? _selectedColor;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAndPop() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIcon == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać ikonę.'), backgroundColor: Colors.orange)); return; }
    if (_selectedColor == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać kolor.'), backgroundColor: Colors.orange)); return; }

    setState(() => _isSaving = true);

    try {
      final newCategory = InformationCategory(
        categoryId: '',
        projectId: widget.projectId,
        name: _nameController.text.trim(),
        iconCodePoint: _selectedIcon!.codePoint,
        iconFontFamily: _selectedIcon!.fontFamily ?? 'MaterialIcons',
        color: _selectedColor!,
      );
      final createdCategoryId = await informationCategoryService.createCategory(newCategory);
      final createdCategory = newCategory.copyWith(categoryId: createdCategoryId);
      if (mounted) Navigator.of(context).pop(createdCategory);
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd', 'Nie udało się utworzyć kategorii: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nowa Kategoria Informacji'),
      // ZMIANA: Zamiast SingleChildScrollView jako content, używamy SizedBox
      // i SingleChildScrollView wewnątrz, aby uniknąć błędów RenderBox.
      content: SizedBox(
        width: double.maxFinite, // Dopasuj do szerokości dialogu
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nazwa kategorii *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nazwa jest wymagana.' : null,
                ),
                const SizedBox(height: 16),
                Text('Wybierz ikonę:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                // Usunięto zbędny SizedBox i SingleChildScrollView
                IconPickerGrid(
                  onIconSelected: (icon) => setState(() => _selectedIcon = icon),
                  initialSelectedIcon: _selectedIcon,
                ),
                const SizedBox(height: 16),
                Text('Wybierz kolor:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                // Usunięto zbędny SizedBox i SingleChildScrollView
                ColorPickerGrid(
                  onColorSelected: (color) => setState(() => _selectedColor = color),
                  initialSelectedColor: _selectedColor,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if(_isSaving) const Center(child: CircularProgressIndicator()),
        if(!_isSaving) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        if(!_isSaving) ElevatedButton(onPressed: _createAndPop, child: const Text('Utwórz')),
      ],
    );
  }
}