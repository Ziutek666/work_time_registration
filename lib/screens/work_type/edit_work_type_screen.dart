import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/work_type.dart';
import '../../models/information.dart';
import '../../models/information_category.dart';
import '../../services/work_type_service.dart';
import '../../services/information_service.dart';
import '../../services/information_category_service.dart';
import '../../repositories/work_type_repository.dart';
import '../../widgets/dialogs.dart';

class EditWorkTypeScreen extends StatefulWidget {
  final WorkType workType;

  const EditWorkTypeScreen({
    super.key,
    required this.workType,
  });

  @override
  _EditWorkTypeScreenState createState() => _EditWorkTypeScreenState();
}

class _EditWorkTypeScreenState extends State<EditWorkTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationMinutesController;

  late bool _isBreak;
  late bool _isSubTask;
  late bool _isCheckPoint;
  late bool _isRequired;
  late bool _isPaid;
  late bool _requiresQrScan; // NOWOŚĆ: Stan dla nowego przełącznika

  bool _isSaving = false;
  bool _isProcessing = false;

  late List<String> _currentInformationIds;
  List<Information> _linkedInformations = [];
  bool _isLoadingInformations = false;
  bool _expandInformationSection = true;

  late List<String> _currentLinkedActionIds;
  List<WorkType> _linkedActions = [];
  bool _isLoadingLinkedActions = false;
  bool _expandLinkedActionsSection = true;

  Map<String, InformationCategory> _availableCategoriesMap = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workType.name);
    _descriptionController = TextEditingController(text: widget.workType.description);
    _durationMinutesController = TextEditingController(text: widget.workType.defaultDuration?.inMinutes.toString() ?? '');

    _isBreak = widget.workType.isBreak;
    _isSubTask = widget.workType.isSubTask;
    _isCheckPoint = widget.workType.isCheckPoint;
    _isRequired = widget.workType.isRequired;
    _isPaid = widget.workType.isPaid;
    _requiresQrScan = widget.workType.requiresQrScan; // NOWOŚĆ: Inicjalizacja stanu

    _currentInformationIds = List.from(widget.workType.informationIds);
    _currentLinkedActionIds = List.from(widget.workType.subTaskIds);

    _loadInitialData();
  }

  // Metody _loadInitialData, _initializeCategoryData, _loadLinkedInformations, _loadLinkedActions bez zmian...
  Future<void> _loadInitialData() async {
    _initializeCategoryData();
    _loadLinkedInformations();
    _loadLinkedActions();
  }

  Future<void> _initializeCategoryData() async {
    try {
      final categories = await informationCategoryService.getAllCategoriesForProject(widget.workType.projectId);
      if (mounted) setState(() => _availableCategoriesMap = {for (var cat in categories) cat.categoryId: cat});
    } catch(e) {
      print("Błąd ładowania kategorii informacji: $e");
    }
  }

  Future<void> _loadLinkedInformations() async {
    if (_currentInformationIds.isEmpty) return;
    setState(() => _isLoadingInformations = true);
    try {
      _linkedInformations = await informationService.getInformationByIds(_currentInformationIds);
      _linkedInformations.sort((a,b) => a.title.compareTo(b.title));
    } catch (e) {
      print("Błąd ładowania powiązanych informacji: $e");
    } finally {
      if (mounted) setState(() => _isLoadingInformations = false);
    }
  }

  Future<void> _loadLinkedActions() async {
    if (_currentLinkedActionIds.isEmpty) return;
    setState(() => _isLoadingLinkedActions = true);
    try {
      _linkedActions = await WorkTypeService(WorkTypeRepository()).getWorkTypesByIds(_currentLinkedActionIds);
      _linkedActions.sort((a,b) => a.name.compareTo(b.name));
    } catch (e) {
      print("Błąd ładowania powiązanych akcji: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLinkedActions = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  // Metody _selectAndLinkInformation, _removeInformationLink, _selectAndLinkAction, _removeLinkedAction bez zmian...
  Future<void> _selectAndLinkInformation() async {
    if (_isSaving) return;
    final selectedInformation = await context.push<Information?>('/select-information', extra: widget.workType.projectId);
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
        extra: {'projectId': widget.workType.projectId, 'filter_type': 'not_main', 'exclude_ids': _currentLinkedActionIds}
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


  Future<void> _updateWorkType() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSaving = true; });

    Duration? defaultDuration;
    if (_durationMinutesController.text.isNotEmpty) {
      final minutes = int.tryParse(_durationMinutesController.text);
      if (minutes != null && minutes > 0) defaultDuration = Duration(minutes: minutes);
    }

    // MODYFIKACJA: Dodanie `requiresQrScan` do aktualizowanego obiektu
    final updatedWorkType = widget.workType.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      defaultDuration: defaultDuration,
      setNullDefaultDuration: _durationMinutesController.text.isEmpty,
      isPaid: _isPaid,
      isRequired: _isRequired,
      requiresQrScan: _requiresQrScan, // Zapisz nową wartość
      informationIds: _currentInformationIds,
      subTaskIds: _currentLinkedActionIds,
    );

    try {
      await WorkTypeService(WorkTypeRepository()).updateWorkType(updatedWorkType);
      if (mounted) {
        await showSuccessDialog(context,'Zapisano!', 'Zmiany w typie pracy "${updatedWorkType.name}" zostały pomyślnie zapisane.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd Aktualizacji', 'Wystąpił błąd: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final bool showLinkedActionsSection = !_isBreak && !_isSubTask && !_isCheckPoint;
    final bool showIsRequiredSwitch = _isBreak || _isSubTask || _isCheckPoint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text('Edytuj Typ Pracy'),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Zapisz zmiany', onPressed: _updateWorkType),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.grey.shade200],
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Edycja: ${widget.workType.name}', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 28.0),
                          _buildSectionTitle(theme.textTheme, "Informacje Ogólne"),
                          _buildTextFormField(controller: _nameController, labelText: "Nazwa Typu Pracy *", validator: (v) => v==null||v.isEmpty ? 'Nazwa jest wymagana' : null),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(controller: _descriptionController, labelText: "Opis (opcjonalnie)", maxLines: 3),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(theme.textTheme, "Ustawienia Szczegółowe"),

                          if (showIsRequiredSwitch)
                            _buildSwitchTile(
                              title: "Wymagane do zakończenia pracy",
                              subtitle: "Pracownik musi wykonać tę akcję, aby móc zakończyć główne zadanie.",
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
                          ),
                          const SizedBox(height: 24.0),
                          _buildLinkedInformationsSection(theme),
                          if (showLinkedActionsSection) ...[
                            const SizedBox(height: 24.0),
                            _buildLinkedActionsSection(theme),
                          ],
                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                            icon: const Icon(Icons.save),
                            label: const Text('Zapisz Zmiany'),
                            onPressed: _isSaving ? null : _updateWorkType,
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

  Widget _buildSwitchTile({ required String title, String? subtitle, required bool value, required ValueChanged<bool>? onChanged, required IconData icon }) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall) : null,
      value: value,
      onChanged: _isSaving ? null : onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
    );
  }

  // --- Widgety pomocnicze (bez zmian) ---
  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 14.0, top: 10.0),
        child: Text(title,
            style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.9))));
  }

  Widget _buildTextFormField(
      {required TextEditingController controller,
        required String labelText,
        int maxLines = 1,
        TextInputType? keyboardType,
        String? Function(String?)? validator}) {
    return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.7),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        enabled: !_isProcessing);
  }

  // Pozostałe metody budujące UI (_buildLinkedInformationsSection, _buildLinkedActionsSection) pozostają bez zmian.
  // ... (załączone poniżej dla kompletności)

  Widget _buildLinkedInformationsSection(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _buildSectionTitle(theme.textTheme, "Powiązane Informacje"),
        Row(children: [
          IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Powiąż informację',
              color: theme.colorScheme.primary,
              onPressed: _isProcessing ? null : _selectAndLinkInformation),
          IconButton(
              icon: Icon(_expandInformationSection
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
              tooltip: 'Rozwiń/Zwiń',
              color: theme.colorScheme.primary,
              onPressed: () => setState(
                      () => _expandInformationSection = !_expandInformationSection))
        ])
      ]),
      if (_expandInformationSection)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
              children: [
                const SizedBox(height: 8.0),
                Text('Informacje wybrane tutaj będą powiązane z tym typem pracy.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12.0),
                if (_isLoadingInformations)
                  const Center(child: CircularProgressIndicator())
                else if (_linkedInformations.isEmpty)
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text('Brak powiązanych informacji.',
                              style: theme.textTheme.bodyMedium)))
                else
                  ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _linkedInformations.length,
                      itemBuilder: (context, index) {
                        final info = _linkedInformations[index];
                        return Card(
                            elevation: 1.0,
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                                leading: Icon(Icons.info_outline_rounded,
                                    color: theme.colorScheme.secondary),
                                title:
                                Text(info.title, style: theme.textTheme.titleSmall),
                                trailing: IconButton(
                                    icon: Icon(Icons.link_off_rounded,
                                        color: theme.colorScheme.error),
                                    tooltip: 'Usuń powiązanie',
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _removeInformationLink(info))));
                      })
              ]
          ),
        )
    ]);
  }

  Widget _buildLinkedActionsSection(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _buildSectionTitle(theme.textTheme, "Podzadania/Przerwy"),
        Row(children: [
          IconButton(
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              tooltip: 'Powiąż akcję',
              color: theme.colorScheme.primary,
              onPressed: _isProcessing ? null : _selectAndLinkAction),
          IconButton(
              icon: Icon(_expandLinkedActionsSection
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
              tooltip: 'Rozwiń/Zwiń',
              color: theme.colorScheme.primary,
              onPressed: () => setState(() =>
              _expandLinkedActionsSection = !_expandLinkedActionsSection))
        ])
      ]),
      if (_expandLinkedActionsSection)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              const SizedBox(height: 8.0),
              Text(
                  'Wybrane podzadania lub przerwy będą dostępne jako kolejne akcje dla tego zadania.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12.0),
              if (_isLoadingLinkedActions)
                const Center(child: CircularProgressIndicator())
              else if (_linkedActions.isEmpty)
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('Brak powiązanych akcji.',
                            style: theme.textTheme.bodyMedium)))
              else
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _linkedActions.length,
                    itemBuilder: (context, index) {
                      final action = _linkedActions[index];
                      IconData icon;
                      Color color;
                      if (action.isBreak) {
                        icon = Icons.free_breakfast_outlined;
                        color = Colors.orange.shade700;
                      } else if (action.isCheckPoint) {
                        icon = Icons.task_alt_outlined;
                        color = Colors.green.shade600;
                      }
                      else {
                        icon = Icons.low_priority_outlined;
                        color = Colors.teal.shade600;
                      }
                      return Card(
                          elevation: 1.0,
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                              leading: Icon(icon, color: color),
                              title: Text(action.name,
                                  style: theme.textTheme.titleSmall),
                              trailing: IconButton(
                                  icon: Icon(Icons.link_off_rounded,
                                      color: theme.colorScheme.error),
                                  tooltip: 'Usuń powiązanie',
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _removeLinkedAction(action))));
                    })
            ],
          ),
        )
    ]);
  }
}