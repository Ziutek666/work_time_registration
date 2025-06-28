import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/project.dart';
import '../../models/work_type.dart';
import '../../models/information.dart';
import '../../models/information_category.dart';
import '../../services/work_type_service.dart';
import '../../services/information_service.dart';
import '../../services/information_category_service.dart';
import '../../repositories/work_type_repository.dart';
import '../../widgets/dialogs.dart';

class CreateWorkTypeScreen extends StatefulWidget {
  final Project project;
  final String? workTypeCategory;

  const CreateWorkTypeScreen({
    super.key,
    required this.project,
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

  // Pola stanu dla flag
  bool _isBreak = false;
  bool _isSubTask = false;
  bool _isCheckPoint = false;
  bool _isMain = false;
  bool _isRequired = false;
  bool _isPaid = true;
  bool _requiresQrScan = false; // NOWOŚĆ: Stan dla nowego przełącznika
  bool _isSaving = false;

  // Pola stanu dla powiązanych elementów
  List<String> _currentInformationIds = [];
  List<Information> _linkedInformations = [];
  bool _isLoadingInformations = false;
  bool _expandInformationSection = false;

  List<String> _currentLinkedActionIds = [];
  List<WorkType> _linkedActions = [];
  bool _isLoadingLinkedActions = false;
  bool _expandLinkedActionsSection = false;

  Map<String, InformationCategory> _availableCategoriesMap = {};
  String _screenTitle = 'Nowy Typ Pracy';

  @override
  void initState() {
    super.initState();
    _initializeCategoryData();

    if (widget.workTypeCategory == "break") {
      _isBreak = true;
      _screenTitle = 'Nowa Przerwa';
    } else if (widget.workTypeCategory == "subtask") {
      _isSubTask = true;
      _screenTitle = 'Nowe Podzadanie';
    } else if (widget.workTypeCategory == "checkpoint") {
      _isCheckPoint = true;
      _screenTitle = 'Nowy Punkt Kontrolny';
    } else if (widget.workTypeCategory == "main") {
      _isMain = true;
      _screenTitle = 'Nowe Zadanie Główne';
    }
  }

  Future<void> _initializeCategoryData() async {
    // ... bez zmian
    try {
      final categories = await informationCategoryService.getAllCategoriesForProject(widget.project.projectId);
      if (mounted) {
        setState(() => _availableCategoriesMap = {for (var cat in categories) cat.categoryId: cat});
      }
    } catch(e) {
      debugPrint("Błąd ładowania kategorii informacji: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  Future<void> _createWorkType() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    Duration? defaultDuration;
    if (_durationMinutesController.text.isNotEmpty) {
      final minutes = int.tryParse(_durationMinutesController.text);
      if (minutes != null && minutes > 0) defaultDuration = Duration(minutes: minutes);
    }

    // MODYFIKACJA: Dodanie `requiresQrScan` do tworzonego obiektu
    final newWorkType = WorkType(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      defaultDuration: defaultDuration,
      isBreak: _isBreak,
      isSubTask: _isSubTask,
      isCheckPoint: _isCheckPoint,
      isRequired: _isRequired,
      isPaid: _isPaid,
      isMain: _isMain,
      requiresQrScan: _requiresQrScan, // Przekazanie wartości z nowego przełącznika
      projectId: widget.project.projectId,
      ownerId: widget.project.ownerId,
      informationIds: _currentInformationIds,
      subTaskIds: _currentLinkedActionIds,
    );

    try {
      final createdWorkType = await WorkTypeService(WorkTypeRepository()).createWorkType(newWorkType);
      if (mounted) {
        await showSuccessDialog(context,'Utworzono!', 'Nowy typ pracy "${createdWorkType.name}" został pomyślnie utworzony.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd Tworzenia', 'Wystąpił błąd: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showLinkedActionsSection = !_isBreak && !_isSubTask && !_isCheckPoint;
    final bool showIsRequiredSwitch = _isBreak || _isSubTask || _isCheckPoint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: Text(_screenTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _isSaving ? null : () => context.pop(false)),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Zapisz', onPressed: _createWorkType),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primaryContainer.withOpacity(0.6), theme.colorScheme.secondaryContainer.withOpacity(0.4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_screenTitle, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 28.0),
                          _buildSectionTitle(theme.textTheme, "Informacje Ogólne"),
                          _buildTextFormField(
                            controller: _nameController,
                            labelText: "Nazwa *",
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Nazwa jest wymagana.' : null,
                          ),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(controller: _descriptionController, labelText: "Opis (opcjonalnie)", maxLines: 3),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(theme.textTheme, "Ustawienia Szczegółowe"),

                          if (showIsRequiredSwitch)
                            _buildSwitchTile(
                              title: "Wymagane do zakończenia pracy",
                              subtitle: "Pracownik musi wykonać tę akcję, aby móc zakończyć zadanie główne.",
                              value: _isRequired,
                              onChanged: (val) => setState(() => _isRequired = val),
                              icon: Icons.rule_folder_outlined,
                            ),

                          // NOWOŚĆ: Dodany przełącznik do obsługi `requiresQrScan`
                          _buildSwitchTile(
                            title: "Wymagaj skanowania kodu QR",
                            subtitle: "Rozpoczęcie tej akcji będzie wymagało zeskanowania kodu QR.",
                            value: _requiresQrScan,
                            onChanged: (val) => setState(() => _requiresQrScan = val),
                            icon: Icons.qr_code_scanner_outlined,
                          ),

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
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty && (int.tryParse(value) == null || int.parse(value) <= 0)) {
                                return 'Wprowadź poprawną liczbę minut (>0).';
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
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
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

  // --- Widgety pomocnicze (bez zmian) ---

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0, top: 10.0),
      child: Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildTextFormField({ required TextEditingController controller, required String labelText, String? hintText, int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_isSaving,
    );
  }

  Widget _buildSwitchTile({ required String title, String? subtitle, required bool value, required ValueChanged<bool>? onChanged, required IconData icon }) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)) : null,
      value: value,
      onChanged: _isSaving ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
    );
  }

  // Pozostałe metody (_buildLinkedInformationsSection, _buildLinkedActionsSection, _selectAndLinkInformation, etc.) pozostają bez zmian
  // ...
  Future<void> _selectAndLinkInformation() async {
    if (_isSaving) return;
    final selectedInformation = await context.push<Information?>('/select-information', extra: widget.project.projectId);
    if (selectedInformation != null && mounted && !_currentInformationIds.contains(selectedInformation.informationId)) {
      setState(() {
        _currentInformationIds.add(selectedInformation.informationId);
        _linkedInformations.add(selectedInformation);
        _linkedInformations.sort((a, b) => a.title.compareTo(b.title));
        if (!_expandInformationSection) _expandInformationSection = true;
      });
    }
  }

  void _removeInformationLink(Information infoToRemove) {
    if (_isSaving || !_linkedInformations.contains(infoToRemove)) return;
    setState(() {
      _linkedInformations.remove(infoToRemove);
      _currentInformationIds.remove(infoToRemove.informationId);
    });
  }

  Future<void> _selectAndLinkAction() async {
    if (_isSaving) return;
    final selectedAction = await context.push<WorkType?>(
        '/select_work_type',
        extra: {'projectId': widget.project.projectId, 'filter_type': 'not_main', 'exclude_ids': _currentLinkedActionIds}
    );
    if (selectedAction != null && mounted && !_currentLinkedActionIds.contains(selectedAction.workTypeId)) {
      setState(() {
        _currentLinkedActionIds.add(selectedAction.workTypeId);
        _linkedActions.add(selectedAction);
        _linkedActions.sort((a, b) => a.name.compareTo(b.name));
        if (!_expandLinkedActionsSection) _expandLinkedActionsSection = true;
      });
    }
  }

  void _removeLinkedAction(WorkType actionToRemove) {
    if (_isSaving || !_linkedActions.contains(actionToRemove)) return;
    setState(() {
      _linkedActions.remove(actionToRemove);
      _currentLinkedActionIds.remove(actionToRemove.workTypeId);
    });
  }

  Widget _buildLinkedInformationsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme.textTheme, "Powiązane Informacje"),
            IconButton(icon: const Icon(Icons.add_link), onPressed: _isSaving ? null : _selectAndLinkInformation),
          ],
        ),
        if (_linkedInformations.isEmpty) const Text('Brak powiązanych informacji.')
        else ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _linkedInformations.length,
          itemBuilder: (context, index) {
            final info = _linkedInformations[index];
            final category = _availableCategoriesMap[info.categoryId];
            return Card(
              child: ListTile(
                leading: Icon(category?.iconData ?? Icons.help_outline, color: category?.color ?? Colors.grey),
                title: Text(info.title),
                trailing: IconButton(icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error), onPressed: _isSaving ? null : () => _removeInformationLink(info)),
              ),
            );
          },
        ),
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
            _buildSectionTitle(theme.textTheme, "Podzadania/Przerwy"),
            IconButton(icon: const Icon(Icons.playlist_add_check_circle_outlined), onPressed: _isSaving ? null : _selectAndLinkAction),
          ],
        ),
        if (_linkedActions.isEmpty) const Text('Brak powiązanych akcji.')
        else ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _linkedActions.length,
          itemBuilder: (context, index) {
            final action = _linkedActions[index];
            return Card(
              child: ListTile(
                title: Text(action.name),
                trailing: IconButton(icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error), onPressed: _isSaving ? null : () => _removeLinkedAction(action)),
              ),
            );
          },
        ),
      ],
    );
  }
}