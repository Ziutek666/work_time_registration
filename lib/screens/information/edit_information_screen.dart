// lib/features/information/presentation/screens/edit_information_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/information.dart';
import '../../models/user_app.dart'; // Założenie: ten model istnieje i jest używany
import '../../services/information_service.dart';
import '../../services/user_service.dart'; // Założenie: userService jest dostępne
import '../../../widgets/dialogs.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/models/information_category.dart';

import '../../models/information.dart';
import '../../services/information_category_service.dart';
import '../../services/information_service.dart';
import '../../widgets/dialogs.dart';
import '../../repositories/information_category_repository.dart';
import '../../repositories/information_repository.dart';

class EditInformationScreen extends StatefulWidget {
  final Information information;

  const EditInformationScreen({super.key, required this.information});

  @override
  _EditInformationScreenState createState() => _EditInformationScreenState();
}

class _EditInformationScreenState extends State<EditInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // State for editable fields
  late String _selectedCategoryId;
  late bool _requiresDecision;
  late bool _textResponseRequiredOnDecision;
  late bool _showOnStart;
  late bool _showOnStop;

  bool _isProcessing = false;

  // State for category dropdown
  List<InformationCategory> _availableCategories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.information.title);
    _contentController = TextEditingController(text: widget.information.content);
    _selectedCategoryId = widget.information.categoryId;
    _requiresDecision = widget.information.requiresDecision;
    _textResponseRequiredOnDecision =
        widget.information.textResponseRequiredOnDecision;
    _showOnStart = widget.information.showOnStart;
    _showOnStop = widget.information.showOnStop;

    _loadAvailableCategories();
  }

  Future<void> _loadAvailableCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await informationCategoryService
          .getAllCategoriesForProject(widget.information.projectId);
      if (mounted) {
        setState(() {
          _availableCategories = categories
            ..sort((a, b) => a.name.compareTo(b.name));
        });
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd ładowania',
            'Nie udało się załadować dostępnych kategorii: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updateInformation() async {
    if (_isProcessing) return;

    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isProcessing = true);
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      bool changed = title != widget.information.title ||
          content != widget.information.content ||
          _selectedCategoryId != widget.information.categoryId ||
          _requiresDecision != widget.information.requiresDecision ||
          _textResponseRequiredOnDecision !=
              widget.information.textResponseRequiredOnDecision ||
          _showOnStart != widget.information.showOnStart ||
          _showOnStop != widget.information.showOnStop;

      if (!changed) {
        if (mounted) {
          await showInfoDialog(
              context, 'Informacja', 'Nie wprowadzono żadnych zmian.');
          setState(() => _isProcessing = false);
        }
        return;
      }

      final updatedInfo = widget.information.copyWith(
        title: title,
        content: content,
        categoryId: _selectedCategoryId,
        requiresDecision: _requiresDecision,
        textResponseRequiredOnDecision: _textResponseRequiredOnDecision,
        showOnStart: _showOnStart,
        showOnStop: _showOnStop,
      );

      try {
        await informationService.updateInformation(updatedInfo);
        if (mounted) {
          await showSuccessDialog(
              context, 'Zaktualizowano!', 'Informacja została pomyślnie zaktualizowana.');
          context.pop(true);
        }
      } catch (e, stackTrace) {
        debugPrint('Błąd podczas aktualizacji informacji: $e\n$stackTrace');
        if (mounted) {
          await showErrorDialog(context, 'Błąd Aktualizacji',
              'Wystąpił nieoczekiwany błąd: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _deleteInformation() async {
    if (_isProcessing) return;
    final bool? confirmed = await showDeleteConfirmationDialog(
      context,
      'Potwierdź usunięcie',
      'Czy na pewno chcesz usunąć informację "${widget.information.title}"?',
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await informationService.removeInformation(widget.information.informationId);
        if (mounted) {
          await showSuccessDialog(context, 'Usunięto!',
              'Informacja "${widget.information.title}" została pomyślnie usunięta.');
          context.pop(true);
        }
      } catch (e, stackTrace) {
        debugPrint('Błąd podczas usuwania informacji: $e\n$stackTrace');
        if (mounted) {
          await showErrorDialog(
              context, 'Błąd Usuwania', 'Wystąpił nieoczekiwany błąd: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edytuj Informację'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj zmiany",
          onPressed: _isProcessing ? null : () => context.pop(false),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Zmiany',
              onPressed: _updateInformation,
            ),
            IconButton(
              icon:
              Icon(Icons.delete_outline, color: colorScheme.errorContainer),
              tooltip: 'Usuń Informację',
              onPressed: _deleteInformation,
            ),
          ]
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isProcessing,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Edycja Informacji',
                          style: textTheme.headlineSmall
                              ?.copyWith(color: colorScheme.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16.0),
                        _buildReadOnlyInfo(textTheme, "ID Informacji",
                            widget.information.informationId),
                        const SizedBox(height: 24.0),
                        _buildSectionTitle(textTheme, "Treść Informacji"),
                        _buildTextFormField(
                          controller: _titleController,
                          labelText: 'Tytuł informacji *',
                          prefixIcon: Icons.title_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Tytuł informacji jest wymagany.';
                            if (value.trim().length < 3)
                              return 'Tytuł musi mieć co najmniej 3 znaki.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        _buildTextFormField(
                          controller: _contentController,
                          labelText: 'Treść informacji *',
                          prefixIcon: Icons.article_outlined,
                          maxLines: 5,
                          minLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Treść informacji jest wymagana.';
                            if (value.trim().length < 10)
                              return 'Treść musi mieć co najmniej 10 znaków.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),
                        _buildSectionTitle(textTheme, "Ustawienia Informacji"),
                        _buildCategoryDropdown(textTheme),
                        const SizedBox(height: 8.0),
                        _buildSwitchTile(
                          title: "Wymaga decyzji (Tak/Nie)",
                          value: _requiresDecision,
                          onChanged: (bool value) {
                            setState(() {
                              _requiresDecision = value;
                            });
                          },
                          icon: Icons.checklist_rtl_outlined,
                        ),
                          _buildSwitchTile(
                            title: "Wymagana odpowiedź tekstowa",
                            value: _textResponseRequiredOnDecision,
                            onChanged: (bool value) =>
                                setState(() => _textResponseRequiredOnDecision = value),
                            icon: Icons.edit_note_outlined,
                          ),
                        _buildSwitchTile(
                          title: "Pokaż przy rozpoczęciu pracy",
                          value: _showOnStart,
                          onChanged: (val) => setState(() => _showOnStart = val),
                          icon: Icons.play_circle_outline_outlined,
                        ),
                        _buildSwitchTile(
                          title: "Pokaż przy zakończeniu pracy",
                          value: _showOnStop,
                          onChanged: (val) => setState(() => _showOnStop = val),
                          icon: Icons.stop_circle_outlined,
                        ),
                        const SizedBox(height: 32.0),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Zapisz Zmiany'),
                          onPressed: _isProcessing ? null : _updateInformation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0, top: 10.0),
      child: Text(title,
          style: textTheme.titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildReadOnlyInfo(TextTheme textTheme, String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.fingerprint_outlined),
        border: const OutlineInputBorder(),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      ),
      child: SelectableText(value, style: textTheme.bodyLarge),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    int maxLines = 1,
    int minLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      enabled: !_isProcessing,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      value: value,
      onChanged: _isProcessing ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      dense: true,
      activeColor: Theme.of(context).colorScheme.tertiary,
    );
  }

  Widget _buildCategoryDropdown(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Kategoria informacji *',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        value: _selectedCategoryId,
        items: _availableCategories.map((category) {
          return DropdownMenuItem<String>(
            value: category.categoryId,
            child: Row(
              children: [
                Icon(category.iconData, color: category.color, size: 20),
                const SizedBox(width: 10),
                Text(category.name),
              ],
            ),
          );
        }).toList(),
        onChanged: _isProcessing || _isLoadingCategories
            ? null
            : (value) {
          if (value != null) {
            setState(() => _selectedCategoryId = value);
          }
        },
        validator: (value) =>
        (value == null || value.isEmpty) ? 'Proszę wybrać kategorię.' : null,
        disabledHint: _isLoadingCategories
            ? const Row(children: [
          SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator()),
          SizedBox(width: 10),
          Text("Ładowanie kategorii...")
        ])
            : null,
      ),
    );
  }
}