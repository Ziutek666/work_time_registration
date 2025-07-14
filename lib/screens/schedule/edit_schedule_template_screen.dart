import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/area.dart';
import '../../../models/project.dart';
import '../../../services/area_service.dart';
import '../../../widgets/dialogs.dart';
import '../../exceptions/schedule_template_exceptions.dart';
import '../../models/schedule_template.dart';
import '../../services/schedule_template_service.dart';
import '../../widgets/color-picker.dart';

class EditScheduleTemplateScreen extends StatefulWidget {
  final Project project;
  final ScheduleTemplate template;

  const EditScheduleTemplateScreen({
    required this.project,
    required this.template,
    super.key,
  });

  @override
  State<EditScheduleTemplateScreen> createState() =>
      _EditScheduleTemplateScreenState();
}

class _EditScheduleTemplateScreenState extends State<EditScheduleTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final List<ScheduleBlock> _blocks = [];
  bool _isLoading = false;

  late ScheduleTargetType _selectedTargetType;

  // ZMIANA: Stan dla wyboru obszaru na poziomie szablonu
  Area? _selectedArea;
  List<Area> _availableAreas = [];
  bool _isLoadingAreas = true;

  final Map<ScheduleTargetType, String> _targetTypeLabels = {
    ScheduleTargetType.user: 'Pracownik',
    ScheduleTargetType.workType: 'Rodzaj pracy',
    ScheduleTargetType.area: 'Obszar',
    ScheduleTargetType.qrCode: 'Kod QR',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _descriptionController =
        TextEditingController(text: widget.template.description);
    _blocks.addAll(List<ScheduleBlock>.from(widget.template.scheduleBlocks));
    _selectedTargetType = widget.template.targetType;

    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await areaService.getAreasByProject(widget.project.projectId);
      if (mounted) {
        setState(() {
          _availableAreas = areas;
          // Ustaw początkowo wybrany obszar na podstawie danych z szablonu
          _selectedArea = _availableAreas.firstWhereOrNull((a) => a.areaId == widget.template.areaId);
          _isLoadingAreas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, "Błąd", "Nie udało się wczytać obszarów: $e");
        setState(() => _isLoadingAreas = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_blocks.isEmpty) {
      showErrorDialog(context, 'Błąd walidacji',
          'Szablon musi zawierać co najmniej jeden blok czasowy.');
      return;
    }
    // ZMIANA: Walidacja wyboru obszaru dla szablonu
    if (_selectedArea == null) {
      showErrorDialog(context, 'Błąd walidacji', 'Musisz wybrać obszar dla całego szablonu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedTemplate = ScheduleTemplate(
        templateId: widget.template.templateId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        ownerId: widget.template.ownerId,
        projectId: widget.template.projectId,
        scheduleBlocks: _blocks,
        targetType: _selectedTargetType,
        areaId: _selectedArea!.areaId, // ZMIANA: Zapisanie ID obszaru
      );

      await scheduleTemplateService.updateTemplate(updatedTemplate);

      if (mounted) {
        await showSuccessDialog(
            context, 'Sukces', 'Szablon harmonogramu został pomyślnie zaktualizowany.');
        context.pop(true);
      }
    } on ScheduleTemplateException catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd zapisu', e.message);
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd krytyczny',
            'Wystąpił nieoczekiwany błąd: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addBlock() async {
    final newBlock = await showDialog<ScheduleBlock>(
      context: context,
      builder: (context) => _AddOrEditBlockDialog(), // ZMIANA: Nie przekazujemy już projektu
    );
    if (newBlock != null) {
      setState(() {
        _blocks.add(newBlock);
      });
    }
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
    });
  }

  void _editBlock(int index) async {
    final originalBlock = _blocks[index];
    final editedBlock = await showDialog<ScheduleBlock>(
      context: context,
      builder: (context) => _AddOrEditBlockDialog(
        blockToEdit: originalBlock,
      ),
    );

    if (editedBlock != null) {
      setState(() {
        _blocks[index] = editedBlock;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        title: const Text('Edycja szablonu harmonogramu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Zapisz zmiany',
            onPressed: _isLoading ? null : _updateTemplate,
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa szablonu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Nazwa jest wymagana.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opcjonalnie)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // ZMIANA: Pole wyboru obszaru dla całego szablonu
                if (_isLoadingAreas)
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                else
                  DropdownButtonFormField<Area>(
                    value: _selectedArea,
                    hint: const Text('Wybierz obszar dla szablonu...'),
                    isExpanded: true,
                    items: _availableAreas.map((area) => DropdownMenuItem(value: area, child: Text(area.name))).toList(),
                    onChanged: (value) => setState(() => _selectedArea = value),
                    validator: (value) => value == null ? 'Wybór obszaru jest wymagany.' : null,
                    decoration: const InputDecoration(labelText: 'Obszar szablonu *', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ScheduleTargetType>(
                  value: _selectedTargetType,
                  decoration: const InputDecoration(
                    labelText: 'Typ docelowy szablonu',
                    border: OutlineInputBorder(),
                  ),
                  items: ScheduleTargetType.values.map((type) {
                    return DropdownMenuItem<ScheduleTargetType>(
                      value: type,
                      child: Text(_targetTypeLabels[type] ?? type.name),
                    );
                  }).toList(),
                  onChanged: (ScheduleTargetType? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTargetType = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bloki czasowe',
                        style: Theme.of(context).textTheme.titleLarge),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj blok'),
                      onPressed: _addBlock,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBlocksList(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBlocksList() {
    if (_blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text('Dodaj co najmniej jeden blok czasowy.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _blocks.length,
      itemBuilder: (context, index) {
        final block = _blocks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: block.color),
            title: Text(block.name),
            // ZMIANA: Usunięto wyświetlanie obszaru z bloku
            subtitle: Text(
                'Godziny: ${TimeOfDay.fromDateTime(block.startTime).format(context)} - ${TimeOfDay.fromDateTime(block.endTime).format(context)}'),
            isThreeLine: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                  tooltip: 'Edytuj blok',
                  onPressed: () => _editBlock(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Usuń blok',
                  onPressed: () => _removeBlock(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ZMIANA: Dialog został znacznie uproszczony
class _AddOrEditBlockDialog extends StatefulWidget {
  final ScheduleBlock? blockToEdit;

  const _AddOrEditBlockDialog({this.blockToEdit});

  @override
  __AddOrEditBlockDialogState createState() => __AddOrEditBlockDialogState();
}

class __AddOrEditBlockDialogState extends State<_AddOrEditBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Color _selectedColor = Colors.blue;
  final Map<int, bool> _daysOfWeek = {1: false, 2: false, 3: false, 4: false, 5: false, 6: false, 7: false};
  final List<String> _dayLabels = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Ndz'];
  final List<String> _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  int _recurrenceInterval = 1;
  final Map<int, String> _recurrenceOptions = {1: 'Co tydzień', 2: 'Co 2 tygodnie', 4: 'Co 4 tygodnie'};

  bool get isEditing => widget.blockToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: isEditing ? widget.blockToEdit!.name : 'Praca');
    if (isEditing) {
      final block = widget.blockToEdit!;
      _startTime = TimeOfDay.fromDateTime(block.startTime);
      _endTime = TimeOfDay.fromDateTime(block.endTime);
      _selectedColor = block.color;

      final bydayPart = block.recurrenceRule.split(';').firstWhere((p) => p.startsWith('BYDAY='), orElse: () => '');
      if (bydayPart.isNotEmpty) {
        final days = bydayPart.replaceAll('BYDAY=', '').split(',');
        for (final dayCode in days) {
          final index = _dayCodes.indexOf(dayCode);
          if (index != -1) _daysOfWeek[index + 1] = true;
        }
      }
      final intervalPart = block.recurrenceRule.split(';').firstWhere((p) => p.startsWith('INTERVAL='), orElse: () => '');
      if (intervalPart.isNotEmpty) _recurrenceInterval = int.tryParse(intervalPart.replaceAll('INTERVAL=', '')) ?? 1;
    }
  }

  void _saveBlock() {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      showErrorDialog(context, 'Brak danych', 'Musisz wybrać godzinę początkową i końcową.');
      return;
    }
    if (!_daysOfWeek.containsValue(true)) {
      showErrorDialog(context, 'Błąd walidacji', 'Musisz wybrać co najmniej jeden dzień tygodnia.');
      return;
    }

    final byday = _daysOfWeek.entries.where((e) => e.value).map((e) => _dayCodes[e.key - 1]).join(',');
    final recurrenceRule = 'FREQ=WEEKLY;BYDAY=$byday;INTERVAL=$_recurrenceInterval';
    final now = DateTime.now();
    final referenceDate = DateTime(now.year, now.month, now.day);
    DateTime startDateTime = DateTime(referenceDate.year, referenceDate.month, referenceDate.day, _startTime!.hour, _startTime!.minute);
    DateTime endDateTime = DateTime(referenceDate.year, referenceDate.month, referenceDate.day, _endTime!.hour, _endTime!.minute);
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    final newBlock = ScheduleBlock(
      name: _nameController.text,
      startTime: startDateTime,
      endTime: endDateTime,
      colorHex: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      recurrenceRule: recurrenceRule,
    );
    context.pop(newBlock);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edytuj blok czasowy' : 'Dodaj nowy blok czasowy'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nazwa bloku'),
                  validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                          if (time != null) setState(() => _startTime = time);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Godzina od'),
                          child: Text(_startTime?.format(context) ?? 'Wybierz...'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.now());
                          if (time != null) setState(() => _endTime = time);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Godzina do'),
                          child: Text(_endTime?.format(context) ?? 'Wybierz...'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Dni tygodnia:'),
                Wrap(
                  spacing: 4.0,
                  children: List.generate(7, (index) {
                    return ChoiceChip(
                      label: Text(_dayLabels[index]),
                      selected: _daysOfWeek[index + 1]!,
                      onSelected: (selected) => setState(() => _daysOfWeek[index + 1] = selected),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _recurrenceInterval,
                  items: _recurrenceOptions.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _recurrenceInterval = value);
                  },
                  decoration: const InputDecoration(labelText: 'Powtarzalność', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('Wybierz kolor:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
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
        TextButton(onPressed: () => context.pop(), child: const Text('Anuluj')),
        FilledButton(onPressed: _saveBlock, child: Text(isEditing ? 'Zapisz' : 'Dodaj')),
      ],
    );
  }
}