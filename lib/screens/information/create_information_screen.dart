// lib/features/information/presentation/screens/create_information_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Dla Timestamp
import '../../models/project.dart';
import '../../models/information.dart';
import '../../services/information_service.dart'; // Używamy globalnej instancji
import '../../../widgets/dialogs.dart';
import 'package:work_time_registration/models/information_category.dart';
import 'package:work_time_registration/services/information_category_service.dart';
import '../../repositories/information_repository.dart';

class CreateInformationScreen extends StatefulWidget {
  final Project project;
  // ZMIANA: Kategoria jest teraz wymagana i przekazywana
  final InformationCategory category;

  const CreateInformationScreen({
    super.key,
    required this.project,
    required this.category,
  });

  @override
  State<CreateInformationScreen> createState() =>
      _CreateInformationScreenState();
}

class _CreateInformationScreenState extends State<CreateInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // Nie ma już potrzeby ładowania ani wyboru kategorii, jest ona przekazywana
  late final InformationCategory _selectedCategory;

  bool _requiresDecision = false;
  bool _textResponseRequiredOnDecision = false;
  bool _showOnStart = false;
  bool _showOnStop = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Ustawienie przekazanej kategorii
    _selectedCategory = widget.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createInformation() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final newInformation = Information(
      informationId: '',
      projectId: widget.project.projectId,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      categoryId:
          _selectedCategory.categoryId, // Użycie ID z przekazanej kategorii
      createdAt: Timestamp.now(),
      requiresDecision: _requiresDecision,
      textResponseRequiredOnDecision: _textResponseRequiredOnDecision,
      showOnStart: _showOnStart,
      showOnStop: _showOnStop,
    );

    try {
      await informationService.createInformation(newInformation);
      if (mounted) {
        await showSuccessDialog(context, 'Utworzono!',
            'Nowa informacja "${newInformation.title}" została pomyślnie utworzona.');
        context.pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd podczas tworzenia informacji: $e\n$stackTrace');
      if (mounted) {
        await showErrorDialog(
            context, 'Błąd Tworzenia', 'Wystąpił błąd: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowa Informacja'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj",
          onPressed: _isSaving ? null : () => context.pop(false),
        ),
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3))))
          else
            IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Zapisz Informację',
                onPressed: _createInformation),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tworzenie Nowej Informacji',
                          style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28.0),
                        // ZMIANA: Wyświetlanie wybranej kategorii jako informacja read-only
                        _buildReadOnlyCategoryInfo(
                            textTheme, "Kategoria", _selectedCategory),
                        const SizedBox(height: 16.0),
                        _buildSectionTitle(textTheme, "Treść Informacji"),
                        _buildTextFormField(
                            controller: _titleController,
                            labelText: "Tytuł informacji *",
                            prefixIcon: Icons.title,
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? 'Tytuł musi mieć min. 3 znaki.'
                                : null),
                        const SizedBox(height: 16.0),
                        _buildTextFormField(
                            controller: _contentController,
                            labelText: "Treść informacji *",
                            prefixIcon: Icons.article_outlined,
                            maxLines: 5,
                            minLines: 3,
                            validator: (v) =>
                                (v == null || v.trim().length < 10)
                                    ? 'Treść musi mieć min. 10 znaków.'
                                    : null),
                        const SizedBox(height: 24.0),
                        _buildSectionTitle(textTheme, "Ustawienia Informacji"),
                        _buildSwitchTile(
                            title: "Wymaga decyzji (Tak/Nie)",
                            value: _requiresDecision,
                            onChanged: (val) => setState(() {
                                  _requiresDecision = val;
                                }),
                            icon: Icons.checklist_rtl_outlined),
                          _buildSwitchTile(
                              title: "Odpowiedź tekstowa wymagana",
                              value: _textResponseRequiredOnDecision,
                              onChanged: (val) => setState(
                                  () => _textResponseRequiredOnDecision = val),
                              icon: Icons.edit_note_outlined),
                        _buildSwitchTile(
                            title: "Pokaż przy rozpoczęciu pracy",
                            value: _showOnStart,
                            onChanged: (val) =>
                                setState(() => _showOnStart = val),
                            icon: Icons.play_circle_outline_outlined),
                        _buildSwitchTile(
                            title: "Pokaż przy zakończeniu pracy",
                            value: _showOnStop,
                            onChanged: (val) =>
                                setState(() => _showOnStop = val),
                            icon: Icons.stop_circle_outlined),
                        const SizedBox(height: 32.0),
                        ElevatedButton.icon(
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Utwórz Informację'),
                            onPressed: _isSaving ? null : _createInformation),
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
          style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  // NOWY WIDGET: do wyświetlania informacji o wybranej kategorii
  Widget _buildReadOnlyCategoryInfo(
      TextTheme textTheme, String label, InformationCategory category) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      ),
      child: Row(
        children: [
          Icon(category.iconData, color: category.color, size: 24),
          const SizedBox(width: 12),
          Text(category.name,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    int maxLines = 1,
    int minLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      enabled: !_isSaving,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      value: value,
      onChanged: _isSaving ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      dense: true,
      activeColor: Theme.of(context).colorScheme.tertiary,
    );
  }
}
