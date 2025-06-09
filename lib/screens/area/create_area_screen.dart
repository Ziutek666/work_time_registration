import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/work_type.dart'; // Dodano import dla WorkType
import '../../services/area_service.dart';
import '../../services/work_type_service.dart'; // Dodano import dla WorkTypeService
import '../../widgets/dialogs.dart';

// Założenie: areaService i workTypeService są dostępne globalnie lub przez DI
// final AreaService areaService = AreaService();
// final WorkTypeService workTypeService = WorkTypeService(WorkTypeRepository());


class CreateAreaScreen extends StatefulWidget {
  final Project project;

  const CreateAreaScreen({super.key, required this.project});

  @override
  _CreateAreaScreenState createState() => _CreateAreaScreenState();
}

class _CreateAreaScreenState extends State<CreateAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;
  bool _active = false; // Domyślny stan dla nowego obszaru

  // Zmienne stanu dla powiązanych TYPÓW PRACY
  List<String> _currentWorkTypesIds = [];
  List<WorkType> _linkedWorkTypes = [];
  bool _isLoadingWorkTypes = false;
  bool _expandWorkTypesSection = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Metody dla POWIĄZANYCH TYPÓW PRACY ---
  Future<void> _selectAndLinkWorkType() async {
    if (_isSaving) return;
    // Założenie: '/select_work_type' to trasa do ekranu wyboru typu pracy,
    // który zwraca wybrany obiekt WorkType lub null.
    // Przekazujemy projectId, aby filtrować typy pracy dla danego projektu.
    final selectedWorkType = await context.push<WorkType?>(
      '/select_work_type', // Upewnij się, że ta trasa istnieje
      extra: widget.project.projectId,
    );

    if (selectedWorkType != null && mounted) {
      final selectedId = selectedWorkType.workTypeId;
      if (!_currentWorkTypesIds.contains(selectedId)) {
        setState(() {
          _currentWorkTypesIds.add(selectedId);
          _linkedWorkTypes.add(selectedWorkType);
          _linkedWorkTypes.sort((a, b) => a.name.compareTo(b.name)); // Sortuj dla spójności
          if (!_expandWorkTypesSection) _expandWorkTypesSection = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Powiązano typ pracy: ${selectedWorkType.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Typ pracy "${selectedWorkType.name}" jest już powiązany.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeWorkTypeLink(WorkType workTypeToRemove) {
    if (_isSaving) return;
    if (!_linkedWorkTypes.contains(workTypeToRemove)) return;

    setState(() {
      _linkedWorkTypes.remove(workTypeToRemove);
      _currentWorkTypesIds.remove(workTypeToRemove.workTypeId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Usunięto powiązanie z typem pracy: ${workTypeToRemove.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // --- Koniec metod dla typów pracy ---


  Future<void> _performActualAreaCreation(String areaName, String areaDescription) async {
    if (!mounted) return;
    // Upewnij się, że _isSaving jest true na początku tej operacji, jeśli nie zostało ustawione wcześniej
    if (!_isSaving) {
      setState(() {
        _isSaving = true;
      });
    }

    try {
      // Tworzenie obiektu Area z uwzględnieniem workTypesIds
      await areaService.createArea(
        projectId: widget.project.projectId,
        ownerId: widget.project.ownerId,
        name: areaName,
        description: areaDescription,
        active: _active, // Dodano przekazanie stanu aktywności
        users: [], // Domyślnie pusta lista użytkowników przy tworzeniu
        workTypesIds: _currentWorkTypesIds, // Przekazanie powiązanych typów pracy
      );
      if (!mounted) return;
      await showSuccessDialog(context,'Utworzono!', 'Nowy obszar "$areaName" został pomyślnie utworzony.');
      if (!mounted) return;
      context.pop(true);
    } catch (e, stackTrace) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd Tworzenia Obszaru', 'Wystąpił błąd: ${e.toString()}');
      debugPrint('Błąd podczas tworzenia obszaru: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _createArea() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    final areaName = _nameController.text.trim();
    final areaDescription = _descriptionController.text.trim();

    try {
      bool nameExists = await areaService.checkIfAreaNameExists(
        projectId: widget.project.projectId,
        name: areaName,
      );

      if (!mounted) return;

      if (nameExists) {
        bool? shouldContinue = await showQuestionDialog(
          context,
          'Uwaga: Nazwa Obszaru Istnieje',
          'Obszar o nazwie "$areaName" już istnieje w tym projekcie. Czy na pewno chcesz utworzyć kolejny obszar o tej samej nazwie?',
        );

        if (shouldContinue == true) {
          await _performActualAreaCreation(areaName, areaDescription);
        } else {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
        }
      } else {
        await _performActualAreaCreation(areaName, areaDescription);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd', 'Wystąpił nieoczekiwany błąd: ${e.toString()}');
      debugPrint('Błąd w _createArea przed próbą tworzenia: $e');
      debugPrintStack(stackTrace: stackTrace);
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
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj",
          onPressed: _isSaving ? null : () => context.pop(false),
        ),
        title: Text(
          'Nowy Obszar',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
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
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Obszar',
              onPressed: _createArea,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.7),
              theme.colorScheme.secondary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Definiowanie Nowego Obszaru',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Informacje Ogólne"),
                          _buildTextFormField(
                            controller: _nameController,
                            labelText: "Nazwa Obszaru *",
                            hintText: "Np. Hala Produkcyjna, Biuro XYZ",
                            prefixIcon: Icons.map_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nazwa obszaru jest wymagana.';
                              }
                              if (value.trim().length < 3) {
                                return 'Nazwa musi mieć co najmniej 3 znaki.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(
                            controller: _descriptionController,
                            labelText: "Opis (opcjonalnie)",
                            hintText: "Dodatkowy opis obszaru",
                            prefixIcon: Icons.notes_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16.0),
                          _buildSwitchTile(
                            title: "Obszar aktywny",
                            value: _active,
                            onChanged: (val) => setState(() => _active = val),
                            icon: Icons.toggle_on_outlined,
                          ),
                          const SizedBox(height: 24.0),
                          // Sekcja powiązanych typów pracy
                          _buildLinkedWorkTypesSection(theme),
                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Utwórz Obszar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              elevation: 4.0,
                            ),
                            onPressed: _isSaving ? null : _createArea,
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
      ),
    );
  }

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      dense: true,
      activeColor: Theme.of(context).colorScheme.tertiary,
    );
  }

  // Widget do wyświetlania sekcji powiązanych typów pracy
  Widget _buildLinkedWorkTypesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme.textTheme, "Powiązane Typy Pracy"),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_link),
                  tooltip: 'Powiąż typ pracy',
                  color: theme.colorScheme.primary,
                  onPressed: _isSaving ? null : _selectAndLinkWorkType,
                ),
                IconButton(
                  icon: Icon(_expandWorkTypesSection ? Icons.keyboard_arrow_up_outlined : Icons.keyboard_arrow_down_outlined),
                  tooltip: _expandWorkTypesSection ? 'Zwiń listę typów pracy' : 'Rozwiń listę typów pracy',
                  color: theme.colorScheme.primary,
                  onPressed: () => setState(() => _expandWorkTypesSection = !_expandWorkTypesSection),
                ),
              ],
            ),
          ],
        ),
        if (_expandWorkTypesSection) ...[
          const SizedBox(height: 8.0),
          Text(
            'Typy pracy wybrane tutaj będą domyślnie dostępne lub sugerowane dla tego obszaru.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12.0),
          if (_isLoadingWorkTypes) // Chociaż przy tworzeniu to rzadkość
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (_linkedWorkTypes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(child: Text('Brak powiązanych typów pracy.', style: theme.textTheme.bodyMedium)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _linkedWorkTypes.length,
              itemBuilder: (context, index) {
                final workType = _linkedWorkTypes[index];
                IconData leadingIconData;
                if (workType.isBreak) leadingIconData = Icons.free_breakfast_outlined;
                else if (workType.isSubTask) leadingIconData = Icons.assignment_turned_in_outlined;
                else leadingIconData = Icons.work_history_outlined;

                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  child: ListTile(
                    leading: Icon(leadingIconData, color: theme.colorScheme.secondary),
                    title: Text(workType.name, style: theme.textTheme.titleSmall),
                    subtitle: Text(workType.description.isNotEmpty ? workType.description : 'Brak opisu', style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(Icons.link_off, color: theme.colorScheme.error),
                      tooltip: 'Usuń powiązanie',
                      onPressed: _isSaving ? null : () => _removeWorkTypeLink(workType),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  ),
                );
              },
            ),
          const SizedBox(height: 8.0),
        ],
      ],
    );
  }
}
