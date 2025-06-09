// edit_work_type_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart'; // For DeepCollectionEquality

// Dostosuj ścieżki do swoich plików
import '../../models/project.dart';
import '../../models/work_type.dart';
import '../../models/information.dart';
import '../../services/work_type_service.dart';
import '../../services/information_service.dart';
import '../../repositories/work_type_repository.dart';
import '../../repositories/information_repository.dart';
import '../../widgets/dialogs.dart';

class EditWorkTypeScreen extends StatefulWidget {
  final WorkType workTypeToEdit;

  const EditWorkTypeScreen({
    super.key,
    required this.workTypeToEdit,
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
  late bool _isPaid;
  bool _isProcessing = false;

  // Informacje
  List<String> _currentInformationIds = [];
  List<Information> _linkedInformations = [];
  bool _isLoadingInformations = false;
  bool _expandInformationSection = false;

  // NOWE: Powiązane Akcje (Podzadania/Przerwy)
  List<String> _currentLinkedActionIds = [];
  List<WorkType> _linkedActions = [];
  bool _isLoadingLinkedActions = false;
  bool _expandLinkedActionsSection = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _durationMinutesController = TextEditingController();
    _loadWorkTypeData();
  }

  Future<void> _loadWorkTypeData() async {
    setState(() { _isProcessing = true; });
    try {
      final wt = widget.workTypeToEdit;
      _nameController.text = wt.name;
      _descriptionController.text = wt.description;
      _durationMinutesController.text = wt.defaultDuration?.inMinutes.toString() ?? '';
      _isBreak = wt.isBreak;
      _isSubTask = wt.isSubTask;
      _isPaid = wt.isPaid;

      _currentInformationIds = List<String>.from(wt.informationIds);
      if (_currentInformationIds.isNotEmpty) {
        await _loadLinkedInformationsByIds();
      }

      // NOWE: Załaduj powiązane akcje (podzadania/przerwy)
      _currentLinkedActionIds = List<String>.from(wt.subTaskIds);
      if (_currentLinkedActionIds.isNotEmpty) {
        await _loadLinkedActionsByIds();
      }

    } catch (e) {
      debugPrint('Błąd podczas ładowania danych WorkType do edycji: $e');
      if (mounted) {
        await showErrorDialog(context, 'Błąd ładowania', 'Nie udało się załadować danych typu pracy: ${e.toString()}');
      }
    } finally {
      if(mounted) setState(() { _isProcessing = false; });
    }
  }

  // --- Metody dla POWIĄZANYCH INFORMACJI (bez zmian) ---
  Future<void> _loadLinkedInformationsByIds() async {
    if (!mounted || _currentInformationIds.isEmpty) {
      if (mounted) setState(() => _linkedInformations = []);
      return;
    }
    if (mounted) setState(() => _isLoadingInformations = true);
    try {
      _linkedInformations = await informationService.getInformationByIds(_currentInformationIds);
      _linkedInformations.sort((a, b) => a.title.compareTo(b.title));
    } catch (e) {
      debugPrint('Błąd ładowania powiązanych informacji: $e');
      if(mounted) _linkedInformations = [];
    } finally {
      if (mounted) setState(() => _isLoadingInformations = false);
    }
  }

  Future<void> _selectAndLinkInformation() async {
    if (_isProcessing) return;
    final selectedInformation = await context.push<Information?>(
      '/select-information',
      extra: widget.workTypeToEdit.projectId,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Powiązano informację: ${selectedInformation.title}'), behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Informacja "${selectedInformation.title}" jest już powiązana.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _removeInformationLink(Information infoToRemove) {
    if (_isProcessing) return;
    setState(() {
      _linkedInformations.remove(infoToRemove);
      _currentInformationIds.remove(infoToRemove.informationId);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usunięto powiązanie z informacją: ${infoToRemove.title}'), behavior: SnackBarBehavior.floating));
  }

  // --- NOWE: Metody dla POWIĄZANYCH AKCJI (Podzadań/Przerw) ---
  Future<void> _loadLinkedActionsByIds() async {
    if (!mounted || _currentLinkedActionIds.isEmpty) {
      if (mounted) setState(() => _linkedActions = []);
      return;
    }
    if (mounted) setState(() => _isLoadingLinkedActions = true);
    try {
      _linkedActions = await workTypeService.getWorkTypesByIds(_currentLinkedActionIds);
      _linkedActions.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('Błąd ładowania powiązanych akcji: $e');
      if(mounted) _linkedActions = [];
    } finally {
      if (mounted) setState(() => _isLoadingLinkedActions = false);
    }
  }

  Future<void> _selectAndLinkAction() async {
    if (_isProcessing) return;

    final List<String> idsToExclude = [
      ..._currentLinkedActionIds,
      widget.workTypeToEdit.workTypeId,
    ];

    final selectedAction = await context.push<WorkType?>(
        '/select_work_type',
        extra: {
          'projectId': widget.workTypeToEdit.projectId,
          'filter_type': 'subtask_or_break',
          'exclude_ids': idsToExclude,
        }
    );

    if (selectedAction != null && mounted) {
      if (!selectedAction.isSubTask && !selectedAction.isBreak) {
        await showInfoDialog(context, "Nieprawidłowy Typ", "Wybrany typ pracy '${selectedAction.name}' nie jest ani podzadaniem, ani przerwą.");
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Powiązano akcję: ${selectedAction.name}'), behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Akcja "${selectedAction.name}" jest już powiązana.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _removeLinkedAction(WorkType actionToRemove) {
    if (_isProcessing) return;
    setState(() {
      _linkedActions.remove(actionToRemove);
      _currentLinkedActionIds.remove(actionToRemove.workTypeId);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usunięto powiązanie z akcją: ${actionToRemove.name}'), behavior: SnackBarBehavior.floating));
  }


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  Future<void> _updateWorkType() async {
    if (_isProcessing || !_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);

    Duration? defaultDuration;
    if (_durationMinutesController.text.isNotEmpty) {
      final minutes = int.tryParse(_durationMinutesController.text);
      if (minutes != null && minutes > 0) defaultDuration = Duration(minutes: minutes);
    }

    bool informationLinksChanged = !const DeepCollectionEquality.unordered().equals(_currentInformationIds, widget.workTypeToEdit.informationIds);
    bool linkedActionsChanged = !const DeepCollectionEquality.unordered().equals(_currentLinkedActionIds, widget.workTypeToEdit.subTaskIds);

    bool basicDataChanged = _nameController.text.trim() != widget.workTypeToEdit.name ||
        _descriptionController.text.trim() != widget.workTypeToEdit.description ||
        (defaultDuration?.inMinutes ?? 0) != (widget.workTypeToEdit.defaultDuration?.inMinutes ?? 0) ||
        _isBreak != widget.workTypeToEdit.isBreak ||
        _isSubTask != widget.workTypeToEdit.isSubTask ||
        _isPaid != widget.workTypeToEdit.isPaid;

    if (!basicDataChanged && !informationLinksChanged && !linkedActionsChanged) {
      if (mounted) {
        await showInfoDialog(context, 'Informacja', 'Nie wprowadzono żadnych zmian.');
        setState(() => _isProcessing = false);
      }
      return;
    }

    final updatedWorkType = widget.workTypeToEdit.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      defaultDuration: defaultDuration,
      setNullDefaultDuration: _durationMinutesController.text.isEmpty && widget.workTypeToEdit.defaultDuration != null,
      isBreak: _isBreak,
      isSubTask: _isSubTask,
      isPaid: _isPaid,
      informationIds: _currentInformationIds,
      subTaskIds: _currentLinkedActionIds,
    );

    try {
      await workTypeService.updateWorkType(updatedWorkType);
      if (mounted) {
        await showSuccessDialog(context,'Zaktualizowano!', 'Typ pracy "${updatedWorkType.name}" został pomyślnie zaktualizowany.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd Aktualizacji', 'Wystąpił błąd: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteWorkType() async {
    if (_isProcessing) return;
    final confirm = await showDeleteConfirmationDialog(context, 'Potwierdź usunięcie', 'Czy na pewno chcesz usunąć typ pracy "${widget.workTypeToEdit.name}"?');
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await workTypeService.deleteWorkType(widget.workTypeToEdit.workTypeId);
      if (mounted) {
        await showSuccessDialog(context, 'Usunięto!', 'Typ pracy "${widget.workTypeToEdit.name}" został usunięty.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd Usuwania', 'Nie udało się usunąć typu pracy: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool showLinkedActionsEditor = !_isBreak && !_isSubTask;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edytuj Typ Pracy'),
        actions: [
          if (_isProcessing) const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))))
          else ...[
            IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Zapisz Zmiany', onPressed: _updateWorkType),
            IconButton(icon: Icon(Icons.delete_outline, color: colorScheme.errorContainer), tooltip: 'Usuń Typ Pracy', onPressed: _deleteWorkType),
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
                      children: [
                        Text('Edycja: ${widget.workTypeToEdit.name}', style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 16.0),
                        _buildReadOnlyInfo(textTheme, "ID Typu Pracy", widget.workTypeToEdit.workTypeId),
                        const SizedBox(height: 24.0),
                        _buildSectionTitle(textTheme, "Informacje Ogólne"),
                        _buildTextFormField(controller: _nameController, labelText: "Nazwa Typu Pracy *", prefixIcon: Icons.label_important_outline, validator: (v) => (v == null || v.trim().length < 2) ? 'Nazwa musi mieć min. 2 znaki.' : null),
                        const SizedBox(height: 16.0),
                        _buildTextFormField(controller: _descriptionController, labelText: "Opis (opcjonalnie)", prefixIcon: Icons.notes_outlined, maxLines: 3),
                        const SizedBox(height: 24.0),
                        _buildSectionTitle(textTheme, "Ustawienia Szczegółowe"),
                        _buildSwitchTile(title: "Jest przerwą", value: _isBreak, icon: Icons.free_breakfast_outlined, onChanged: (val) => setState(() { _isBreak = val; if (val) {_isSubTask = false; _currentLinkedActionIds.clear(); _linkedActions.clear();} })),
                        _buildSwitchTile(title: "Jest pod-zadaniem", value: _isSubTask, icon: Icons.low_priority_outlined, onChanged: (val) => setState(() { _isSubTask = val; if (val) {_isBreak = false; _currentLinkedActionIds.clear(); _linkedActions.clear();} })),
                        _buildSwitchTile(title: "Jest płatne", value: _isPaid, icon: Icons.attach_money_outlined, onChanged: (val) => setState(() => _isPaid = val)),
                        const SizedBox(height: 16.0),
                        _buildTextFormField(controller: _durationMinutesController, labelText: "Domyślny czas trwania (minuty)", prefixIcon: Icons.timer_outlined, keyboardType: TextInputType.number, validator: (v) => (v != null && v.isNotEmpty && (int.tryParse(v) == null || int.parse(v) <= 0)) ? 'Podaj poprawną liczbę.' : null),
                        const SizedBox(height: 24.0),
                        _buildLinkedInformationsSection(theme),
                        if (showLinkedActionsEditor) ...[
                          const SizedBox(height: 24.0),
                          _buildLinkedActionsSection(theme),
                        ],
                        const SizedBox(height: 32.0),
                        ElevatedButton.icon(icon: const Icon(Icons.save_alt_outlined), label: const Text('Zapisz Zmiany'), onPressed: _isProcessing ? null : _updateWorkType),
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

  // --- Widgety pomocnicze (bez zmian, ale załączone dla kompletności) ---
  Widget _buildSectionTitle(TextTheme textTheme, String title) { return Padding(padding: const EdgeInsets.only(bottom: 14.0, top: 10.0), child: Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))); }
  Widget _buildReadOnlyInfo(TextTheme textTheme, String label, String value) { return InputDecorator(decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.fingerprint_outlined), border: const OutlineInputBorder()), child: SelectableText(value, style: textTheme.bodyLarge)); }
  Widget _buildTextFormField({required TextEditingController controller, required String labelText, IconData? prefixIcon, int maxLines = 1, int minLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) { return TextFormField(controller: controller, decoration: InputDecoration(labelText: labelText, prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null), maxLines: maxLines, minLines: minLines, keyboardType: keyboardType, validator: validator, enabled: !_isProcessing); }
  Widget _buildSwitchTile({required String title, required bool value, required ValueChanged<bool> onChanged, required IconData icon}) { return SwitchListTile(title: Text(title, style: Theme.of(context).textTheme.titleSmall), value: value, onChanged: _isProcessing ? null : onChanged, secondary: Icon(icon, color: Theme.of(context).colorScheme.primary), dense: true, activeColor: Theme.of(context).colorScheme.tertiary); }
  Widget _buildLinkedInformationsSection(ThemeData theme)
  {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionTitle(theme.textTheme, "Powiązane Informacje"), Row(children: [IconButton(icon: const Icon(Icons.add_link), tooltip: 'Powiąż informację', color: theme.colorScheme.primary, onPressed: _isProcessing ? null : _selectAndLinkInformation), IconButton(icon: Icon(_expandInformationSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down), tooltip: 'Rozwiń/Zwiń', color: theme.colorScheme.primary,
              onPressed: () => setState(() => _expandInformationSection = !_expandInformationSection))])]), if (_expandInformationSection) ...[ const SizedBox(height: 8.0), Text('Informacje wybrane tutaj będą powiązane z tym typem pracy.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)), const SizedBox(height: 12.0), if (_isLoadingInformations) const Center(child: CircularProgressIndicator()) else if (_linkedInformations.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('Brak powiązanych informacji.', style: theme.textTheme.bodyMedium))) else ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _linkedInformations.length, itemBuilder: (context, index) { final info = _linkedInformations[index]; return Card(elevation: 1.0, margin: const EdgeInsets.only(bottom: 8.0), child: ListTile(leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.secondary), title: Text(info.title, style: theme.textTheme.titleSmall), trailing: IconButton(icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error), tooltip: 'Usuń powiązanie', onPressed: _isProcessing ? null : () => _removeInformationLink(info)))); })]]);
  }
  Widget _buildLinkedActionsSection(ThemeData theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionTitle(theme.textTheme, "Podzadania/Przerwy"),
      Row(children: [IconButton(icon: const Icon(Icons.playlist_add_check_circle_outlined), tooltip: 'Powiąż akcję', color: theme.colorScheme.primary, onPressed: _isProcessing ? null : _selectAndLinkAction), IconButton(icon: Icon(_expandLinkedActionsSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down), tooltip: 'Rozwiń/Zwiń', color: theme.colorScheme.primary, onPressed: () => setState(() => _expandLinkedActionsSection = !_expandLinkedActionsSection))])]), if (_expandLinkedActionsSection) ...[ const SizedBox(height: 8.0), Text('Wybrane podzadania lub przerwy będą dostępne jako kolejne akcje dla tego zadania.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)), const SizedBox(height: 12.0), if (_isLoadingLinkedActions) const Center(child: CircularProgressIndicator()) else if (_linkedActions.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('Brak powiązanych akcji.', style: theme.textTheme.bodyMedium))) else ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _linkedActions.length, itemBuilder: (context, index) { final action = _linkedActions[index]; IconData icon; Color color; if(action.isBreak){icon = Icons.free_breakfast_outlined; color = Colors.orange.shade700;}else{icon = Icons.low_priority_outlined; color = Colors.teal.shade600;} return Card(elevation: 1.0, margin: const EdgeInsets.only(bottom: 8.0), child: ListTile(leading: Icon(icon, color: color), title: Text(action.name, style: theme.textTheme.titleSmall), trailing: IconButton(icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error), tooltip: 'Usuń powiązanie', onPressed: _isProcessing ? null : () => _removeLinkedAction(action)))); })]]); }
}

