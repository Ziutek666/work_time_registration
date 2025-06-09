// create_work_type_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Dostosuj ścieżki do swoich plików
import '../../models/project.dart';
import '../../models/work_type.dart';
import '../../models/information.dart';
import '../../models/information_category.dart'; // Import modelu kategorii
import '../../services/work_type_service.dart';
import '../../services/information_service.dart';
import '../../services/information_category_service.dart'; // Import serwisu kategorii
import '../../repositories/work_type_repository.dart';
import '../../repositories/information_repository.dart';
import '../../widgets/dialogs.dart';

class CreateWorkTypeScreen extends StatefulWidget {
  final Project project;
  final bool? initialIsBreak;
  final bool? initialIsSubTask;
  final String? workTypeCategory;

  const CreateWorkTypeScreen({
    super.key,
    required this.project,
    this.initialIsBreak,
    this.initialIsSubTask,
    this.workTypeCategory,
  });

  @override
  _CreateWorkTypeScreenState createState() => _CreateWorkTypeScreenState();
}

class _CreateWorkTypeScreenState extends State<CreateWorkTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationMinutesController = TextEditingController();

  bool _isBreak = false;
  bool _isSubTask = false;
  bool _isPaid = true;
  bool _isSaving = false;

  List<String> _currentInformationIds = [];
  List<Information> _linkedInformations = [];
  bool _isLoadingInformations = false;
  bool _expandInformationSection = false;

  List<String> _currentLinkedActionIds = [];
  List<WorkType> _linkedActions = [];
  bool _isLoadingLinkedActions = false;
  bool _expandLinkedActionsSection = false;

  // Mapa do przechowywania pobranych kategorii dla szybkiego dostępu
  Map<String, InformationCategory> _availableCategoriesMap = {};

  String _screenTitle = 'Nowy Typ Pracy';
  bool _canChangeTypeFlags = true;

  @override
  void initState() {
    super.initState();
    _initializeCategoryData(); // Wywołanie nowej metody inicjalizującej

    // Ustaw wartości początkowe na podstawie przekazanych parametrów
    if (widget.initialIsBreak != null) {
      _isBreak = widget.initialIsBreak!;
    }
    if (widget.initialIsSubTask != null) {
      _isSubTask = widget.initialIsSubTask!;
    }

    // Dostosuj tytuł i możliwość zmiany flag na podstawie kategorii
    if (widget.workTypeCategory == "break") {
      _screenTitle = 'Nowa Przerwa';
      _isBreak = true;
      _isSubTask = false;
      _canChangeTypeFlags = false;
    } else if (widget.workTypeCategory == "subtask") {
      _screenTitle = 'Nowe Podzadanie';
      _isSubTask = true;
      _isBreak = false;
      _canChangeTypeFlags = false;
    } else if (widget.workTypeCategory == "main") {
      _screenTitle = 'Nowe Zadanie Główne';
      _isSubTask = false;
      _isBreak = false;
      _canChangeTypeFlags = false;
    }
  }

  // NOWA METODA: Ładuje kategorie dostępne dla projektu
  Future<void> _initializeCategoryData() async {
    try {
      final categories = await informationCategoryService.getAllCategoriesForProject(widget.project.projectId);
      if (mounted) {
        setState(() {
          _availableCategoriesMap = { for (var cat in categories) cat.categoryId: cat };
        });
      }
    } catch(e) {
      print("Błąd ładowania kategorii informacji: $e");
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  Future<void> _selectAndLinkInformation() async {
    if (_isSaving) return;
    final selectedInformation = await context.push<Information?>(
      '/select-information',
      extra: widget.project.projectId,
    );

    if (selectedInformation != null && mounted) {
      final selectedId = selectedInformation.informationId;
      if (!_currentInformationIds.contains(selectedId)) {
        setState(() {
          _currentInformationIds.add(selectedId);
          _linkedInformations.add(selectedInformation);
          _linkedInformations.sort((a, b) => a.title.compareTo(b.title));
          if (!_expandInformationSection) _expandInformationSection = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Powiązano informację: ${selectedInformation.title}'), behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Informacja "${selectedInformation.title}" jest już powiązana.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _removeInformationLink(Information infoToRemove) {
    if (_isSaving) return;
    if (!_linkedInformations.contains(infoToRemove)) return;
    setState(() {
      _linkedInformations.remove(infoToRemove);
      _currentInformationIds.remove(infoToRemove.informationId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usunięto powiązanie z informacją: ${infoToRemove.title}'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _selectAndLinkAction() async {
    if (_isSaving) return;

    final selectedAction = await context.push<WorkType?>(
        '/select_work_type',
        extra: {
          'projectId': widget.project.projectId,
          'filter_type': 'subtask_or_break',
          'exclude_ids': _currentLinkedActionIds,
        }
    );

    if (selectedAction != null && mounted) {
      if (!selectedAction.isSubTask && !selectedAction.isBreak) {
        await showInfoDialog(context, "Nieprawidłowy Typ", "Wybrany typ pracy '${selectedAction.name}' nie jest ani podzadaniem, ani przerwą. Nie można go powiązać jako akcji dodatkowej.");
        return;
      }

      final selectedId = selectedAction.workTypeId;
      if (!_currentLinkedActionIds.contains(selectedId)) {
        setState(() {
          _currentLinkedActionIds.add(selectedId);
          _linkedActions.add(selectedAction);
          _linkedActions.sort((a, b) => a.name.compareTo(b.name));
          if (!_expandLinkedActionsSection) _expandLinkedActionsSection = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Powiązano akcję: ${selectedAction.name}'), behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akcja "${selectedAction.name}" jest już powiązana.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _removeLinkedAction(WorkType actionToRemove) {
    if (_isSaving) return;
    if (!_linkedActions.contains(actionToRemove)) return;
    setState(() {
      _linkedActions.remove(actionToRemove);
      _currentLinkedActionIds.remove(actionToRemove.workTypeId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usunięto powiązanie z akcją: ${actionToRemove.name}'), behavior: SnackBarBehavior.floating),
    );
  }


  Future<void> _createWorkType() async {
    if (_isSaving) return;

    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      setState(() { _isSaving = true; });

      Duration? defaultDuration;
      if (_durationMinutesController.text.isNotEmpty) {
        final minutes = int.tryParse(_durationMinutesController.text);
        if (minutes != null && minutes > 0) {
          defaultDuration = Duration(minutes: minutes);
        }
      }

      final newWorkType = WorkType(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        defaultDuration: defaultDuration,
        isBreak: _isBreak,
        isSubTask: _isSubTask,
        isPaid: _isPaid,
        projectId: widget.project.projectId,
        ownerId: widget.project.ownerId,
        informationIds: _currentInformationIds,
        subTaskIds: _currentLinkedActionIds,
      );

      try {
        WorkType createdWorkType = await workTypeService.createWorkType(newWorkType);
        if (mounted) {
          await showSuccessDialog(context,'Utworzono!', 'Nowy typ pracy "${createdWorkType.name}" został pomyślnie utworzony.');
          context.pop(true);
        }
      } catch (e, stackTrace) {
        debugPrint('Błąd podczas tworzenia typu pracy: $e');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          await showErrorDialog(context, 'Błąd Tworzenia', 'Wystąpił błąd podczas tworzenia typu pracy: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool showLinkedActionsSection = !_isBreak && !_isSubTask;

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
          _screenTitle,
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Typ Pracy',
              onPressed: _createWorkType,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.6),
              theme.colorScheme.secondaryContainer.withOpacity(0.4),
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
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _screenTitle,
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28.0),
                          _buildSectionTitle(textTheme, "Informacje Ogólne"),
                          _buildTextFormField(
                            controller: _nameController,
                            labelText: "Nazwa Typu Pracy *",
                            hintText: "Np. Praca biurowa, Montaż, Przerwa",
                            prefixIcon: Icons.label_important_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Nazwa jest wymagana.';
                              if (value.trim().length < 2) return 'Nazwa musi mieć min. 2 znaki.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(
                            controller: _descriptionController,
                            labelText: "Opis (opcjonalnie)",
                            hintText: "Dodatkowy opis",
                            prefixIcon: Icons.notes_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Ustawienia Szczegółowe"),
                          if (_canChangeTypeFlags) ...[
                            _buildSwitchTile(
                              title: "Jest przerwą",
                              value: _isBreak,
                              onChanged: (val) {
                                setState(() {
                                  _isBreak = val;
                                  if (val) {
                                    _isSubTask = false;
                                    _currentLinkedActionIds.clear();
                                    _linkedActions.clear();
                                  }
                                });
                              },
                              icon: Icons.free_breakfast_outlined,
                            ),
                            _buildSwitchTile(
                              title: "Jest pod-zadaniem",
                              value: _isSubTask,
                              onChanged: (val) {
                                setState(() {
                                  _isSubTask = val;
                                  if (val) {
                                    _isBreak = false;
                                    _currentLinkedActionIds.clear();
                                    _linkedActions.clear();
                                  }
                                });
                              },
                              icon: Icons.low_priority_outlined,
                            ),
                          ],
                          _buildSwitchTile(
                            title: "Jest płatne",
                            value: _isPaid,
                            onChanged: (val) => setState(() => _isPaid = val),
                            icon: Icons.attach_money_outlined,
                          ),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(
                            controller: _durationMinutesController,
                            labelText: "Domyślny czas trwania (minuty)",
                            hintText: "Np. 15, 30 (opcjonalne)",
                            prefixIcon: Icons.timer_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final int? minutes = int.tryParse(value);
                                if (minutes == null || minutes <= 0) return 'Wprowadź poprawną liczbę minut (>0).';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24.0),
                          _buildLinkedInformationsSection(theme),

                          if (showLinkedActionsSection) ...[
                            const SizedBox(height: 24.0),
                            _buildLinkedActionsSection(theme),
                          ],

                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Utwórz Typ Pracy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isSaving ? null : _createWorkType,
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
      padding: const EdgeInsets.only(bottom: 14.0, top: 10.0),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
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
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
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
    required ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      value: value,
      onChanged: _isSaving ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      dense: true,
      activeColor: Theme.of(context).colorScheme.tertiary,
    );
  }

  Widget _buildLinkedInformationsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme.textTheme, "Powiązane Informacje"),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_link),
                  tooltip: 'Powiąż informację',
                  color: theme.colorScheme.primary,
                  onPressed: _isSaving ? null : _selectAndLinkInformation,
                ),
                IconButton(
                  icon: Icon(_expandInformationSection ? Icons.keyboard_arrow_up_outlined : Icons.keyboard_arrow_down_outlined),
                  tooltip: _expandInformationSection ? 'Zwiń listę informacji' : 'Rozwiń listę informacji',
                  color: theme.colorScheme.primary,
                  onPressed: () => setState(() => _expandInformationSection = !_expandInformationSection),
                ),
              ],
            ),
          ],
        ),
        if (_expandInformationSection) ...[
          const SizedBox(height: 8.0),
          Text(
            'Informacje wybrane tutaj będą powiązane z tym typem pracy.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12.0),
          if (_isLoadingInformations)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (_linkedInformations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3))
              ),
              child: Center(child: Text('Brak powiązanych informacji.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _linkedInformations.length,
              itemBuilder: (context, index) {
                final info = _linkedInformations[index];
                // ZMIANA: Pobierz nazwę kategorii z mapy
                final category = _availableCategoriesMap[info.categoryId];
                final categoryName = category?.name ?? 'Brak kategorii';
                final categoryIcon = category?.iconData ?? Icons.help_outline;
                final categoryColor = category?.color ?? Colors.grey;

                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  child: ListTile(
                    leading: Icon(categoryIcon, color: categoryColor), // Użyj ikony i koloru z kategorii
                    title: Text(info.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text('Kategoria: $categoryName', style: theme.textTheme.bodySmall), // ZMIENIONY TEKST
                    trailing: IconButton(
                      icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error),
                      tooltip: 'Usuń powiązanie',
                      onPressed: _isSaving ? null : () => _removeInformationLink(info),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  ),
                );
              },
            ),
          const SizedBox(height: 8.0),
        ],
      ],
    );
  }

  Widget _buildLinkedActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme.textTheme, "Powiązane Akcje (Podzadania/Przerwy)"),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  tooltip: 'Powiąż akcję (podzadanie/przerwę)',
                  color: theme.colorScheme.primary,
                  onPressed: _isSaving ? null : _selectAndLinkAction,
                ),
                IconButton(
                  icon: Icon(_expandLinkedActionsSection ? Icons.keyboard_arrow_up_outlined : Icons.keyboard_arrow_down_outlined),
                  tooltip: _expandLinkedActionsSection ? 'Zwiń listę akcji' : 'Rozwiń listę akcji',
                  color: theme.colorScheme.primary,
                  onPressed: () => setState(() => _expandLinkedActionsSection = !_expandLinkedActionsSection),
                ),
              ],
            ),
          ],
        ),
        if (_expandLinkedActionsSection) ...[
          const SizedBox(height: 8.0),
          Text(
            'Wybrane podzadania lub przerwy będą dostępne do uruchomienia w ramach tego zadania głównego.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12.0),
          if (_isLoadingLinkedActions)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (_linkedActions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3))
              ),
              child: Center(child: Text('Brak powiązanych akcji.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _linkedActions.length,
              itemBuilder: (context, index) {
                final linkedAction = _linkedActions[index];
                IconData actionIcon;
                Color actionColor;
                String typeLabel;

                if (linkedAction.isBreak) {
                  actionIcon = Icons.free_breakfast_outlined;
                  actionColor = Colors.orange.shade700;
                  typeLabel = "Przerwa";
                } else if (linkedAction.isSubTask) {
                  actionIcon = Icons.low_priority_outlined;
                  actionColor = Colors.teal.shade600;
                  typeLabel = "Podzadanie";
                } else {
                  actionIcon = Icons.help_outline_rounded;
                  actionColor = theme.colorScheme.onSurfaceVariant;
                  typeLabel = "Akcja";
                }

                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  child: ListTile(
                    leading: Icon(actionIcon, color: actionColor),
                    title: Text(linkedAction.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text('$typeLabel${linkedAction.description.isNotEmpty ? ": ${linkedAction.description}" : ""}', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error),
                      tooltip: 'Usuń powiązanie z akcją',
                      onPressed: _isSaving ? null : () => _removeLinkedAction(linkedAction),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
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