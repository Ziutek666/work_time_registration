import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/area.dart';
import '../../models/project.dart'; // Potrzebne, jeśli ekran wyboru WorkType go wymaga
import '../../models/work_type.dart'; // Dodano import dla WorkType
import '../../services/area_service.dart';
import '../../services/work_type_service.dart'; // Dodano import dla WorkTypeService
import '../../widgets/dialogs.dart';

// Założenie: areaService i workTypeService są dostępne globalnie lub przez DI
// final AreaService areaService = AreaService();
// final WorkTypeService workTypeService = WorkTypeService();

class EditAreaScreen extends StatefulWidget {
  final Area area;
  // final Project project; // Może być potrzebne, jeśli ekran wyboru WorkType wymaga projectId

  const EditAreaScreen({
    super.key,
    required this.area,
    // required this.project // Odkomentuj, jeśli potrzebne
  });

  @override
  _EditAreaScreenState createState() => _EditAreaScreenState();
}

class _EditAreaScreenState extends State<EditAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _active;
  bool _isProcessing = false; // Zmieniono z _isSaving

  // Zmienne stanu dla powiązanych TYPÓW PRACY
  List<String> _currentWorkTypesIds = [];
  List<WorkType> _linkedWorkTypes = [];
  bool _isLoadingWorkTypes = false;
  bool _expandWorkTypesSection = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadAreaData();
  }

  Future<void> _loadAreaData() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });
    try {
      _nameController.text = widget.area.name;
      _descriptionController.text = widget.area.description;
      _active = widget.area.active;
      _currentWorkTypesIds = List<String>.from(widget.area.workTypesIds);

      if (_currentWorkTypesIds.isNotEmpty) {
        await _loadLinkedWorkTypesByIds();
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd podczas ładowania danych obszaru: $e\n$stackTrace');
      if (mounted) {
        await showErrorDialog(context, 'Błąd Ładowania', 'Nie udało się załadować danych obszaru: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Metody dla POWIĄZANYCH TYPÓW PRACY ---
  Future<void> _loadLinkedWorkTypesByIds() async {
    if (!mounted || _currentWorkTypesIds.isEmpty) {
      if (mounted) setState(() => _linkedWorkTypes = []);
      return;
    }
    if (mounted) setState(() => _isLoadingWorkTypes = true);
    try {
      _linkedWorkTypes = await workTypeService.getWorkTypesByIds(_currentWorkTypesIds);
      _linkedWorkTypes.sort((a, b) => a.name.compareTo(b.name));
    } catch (e, stackTrace) {
      debugPrint('Błąd podczas pobierania powiązanych typów pracy po ID: $e\n$stackTrace');
      if (mounted) {
        await showErrorDialog(context, 'Błąd ładowania typów pracy', 'Nie udało się załadować powiązanych typów pracy: ${e.toString()}');
        _linkedWorkTypes = [];
      }
    } finally {
      if (mounted) setState(() => _isLoadingWorkTypes = false);
    }
  }

  Future<void> _selectAndLinkWorkType() async {
    if (_isProcessing) return;
    final selectedWorkType = await context.push<WorkType?>(
        '/select_work_type',
        extra: {
          'projectId': widget.area.projectId,
          'filter_type': 'main', // Przekazanie informacji o typie filtrowania
          // Ekran '/select_work_type_for_linking' musi obsłużyć ten filtr
        }
    );

    if (selectedWorkType != null && mounted) {
      final selectedId = selectedWorkType.workTypeId;
      if (!_currentWorkTypesIds.contains(selectedId)) {
        setState(() {
          _currentWorkTypesIds.add(selectedId);
          _linkedWorkTypes.add(selectedWorkType);
          _linkedWorkTypes.sort((a, b) => a.name.compareTo(b.name));
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
    if (_isProcessing) return;
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

  Future<void> _updateArea() async {
    if (_isProcessing) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() { _isProcessing = true; });

    final areaName = _nameController.text.trim();
    final areaDescription = _descriptionController.text.trim();

    bool basicDataChanged = areaName != widget.area.name ||
        areaDescription != widget.area.description ||
        _active != widget.area.active;

    bool workTypesChanged = !listEquals(_currentWorkTypesIds, widget.area.workTypesIds);

    if (!basicDataChanged && !workTypesChanged) {
      if (mounted) {
        await showInfoDialog(context, 'Informacja', 'Nie wprowadzono żadnych zmian.');
        setState(() { _isProcessing = false; });
      }
      return;
    }

    try {
      await areaService.updateArea(
        areaId: widget.area.areaId,
        name: areaName,
        description: areaDescription,
        active: _active,
        // users: widget.area.users, // Zakładamy, że edycja użytkowników odbywa się gdzie indziej
        workTypesIds: _currentWorkTypesIds,
      );
      if (!mounted) return;
      await showSuccessDialog(context,'Zaktualizowano!', 'Obszar "$areaName" został pomyślnie zaktualizowany.');
      if (!mounted) return;
      context.pop(true);
    } catch (e, stackTrace) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd Aktualizacji Obszaru', 'Wystąpił błąd: ${e.toString()}');
      debugPrint('Błąd podczas aktualizacji obszaru: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteArea() async {
    if (_isProcessing || !mounted) return;
    final result = await showDeleteConfirmationDialog(
      context,
      'Potwierdź usunięcie',
      'Czy na pewno chcesz usunąć obszar "${widget.area.name}"? Tej operacji nie można cofnąć.',
    );
    if (result != true) return;

    setState(() { _isProcessing = true; });
    try {
      await areaService.deleteArea(widget.area.areaId);
      if (!mounted) return;
      await showSuccessDialog(context,'Usunięto!', 'Obszar "${widget.area.name}" został pomyślnie usunięty.');
      if (!mounted) return;
      context.pop(true); // Wróć i odśwież listę
    } catch (e, stackTrace) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd Usuwania Obszaru', 'Wystąpił błąd: ${e.toString()}');
      debugPrint('Błąd podczas usuwania obszaru: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  // Pomocnicza funkcja do porównywania list
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    List<T> sortedA = List<T>.from(a)..sort();
    List<T> sortedB = List<T>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
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
          tooltip: "Anuluj zmiany",
          onPressed: _isProcessing ? null : () => context.pop(false),
        ),
        title: Text(
          'Edytuj Obszar',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
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
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Zmiany',
              onPressed: _updateArea,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
              tooltip: 'Usuń Obszar',
              onPressed: _deleteArea,
            ),
          ]
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
          absorbing: _isProcessing,
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
                            'Edycja Obszaru',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16.0),
                          _buildReadOnlyInfo(textTheme, "ID Obszaru", widget.area.areaId, Icons.fingerprint_outlined),
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
                            icon: const Icon(Icons.save_alt_outlined),
                            label: const Text('Zapisz Zmiany'),
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
                            onPressed: _isProcessing ? null : _updateArea,
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

  Widget _buildReadOnlyInfo(TextTheme textTheme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                SelectableText(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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
      enabled: !_isProcessing,
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
      onChanged: _isProcessing ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      dense: true,
      activeColor: Theme.of(context).colorScheme.tertiary,
    );
  }

  // Widget do wyświetlania sekcji powiązanych typów pracy (analogiczny do CreateAreaScreen)
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
                  onPressed: _isProcessing ? null : _selectAndLinkWorkType,
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
          if (_isLoadingWorkTypes)
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
                      onPressed: _isProcessing ? null : () => _removeWorkTypeLink(workType),
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
