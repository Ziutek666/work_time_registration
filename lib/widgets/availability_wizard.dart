import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../models/area.dart';
import '../../models/member.dart';
import '../../models/project.dart';
import '../../models/schedule_template.dart';
import '../../models/user_availability.dart';
import '../../services/area_service.dart';
import '../../services/availability_service.dart';
import '../../services/members_service.dart';
import '../../widgets/dialogs.dart';

enum WizardStep { selectProject, declareAvailability }

class AvailabilityWizard extends StatefulWidget {
  final String userId;
  final List<Project> projects;
  final List<ScheduleTemplate> templates;
  final DateTime? initialDate;
  final List<UserAvailability> allAvailabilitiesForProject;

  const AvailabilityWizard({
    super.key,
    required this.userId,
    required this.projects,
    required this.templates,
    this.initialDate,
    required this.allAvailabilitiesForProject,
  });

  @override
  State<AvailabilityWizard> createState() => _AvailabilityWizardState();
}

class _AvailabilityWizardState extends State<AvailabilityWizard> {
  // --- Stan kreatora ---
  WizardStep _currentStep = WizardStep.selectProject;
  Project? _selectedProject;
  ScheduleTemplate? _selectedTemplate;
  List<Area> _projectAreas = [];
  bool _isLoading = false;
  int? _expandedBlockIndex;

  // --- Stan Danych ---
  late DateTime _currentDate;
  bool _isAvailableMode = true;
  Map<int, List<String>> _dailyAvailability = {};
  Map<int, List<String>> _originalDailyAvailability = {};
  bool _isDirty = false;
  bool _wasAnyChangeSaved = false;

  // NOWOŚĆ: Lokalna, bezpieczna kopia danych. Kreator będzie pracował tylko na niej.
  late List<UserAvailability> _localAvailabilities;

  @override
  void initState() {
    super.initState();
    // Tworzymy głęboką kopię listy, aby nie modyfikować oryginalnych danych z ekranu kalendarza.
    _localAvailabilities = widget.allAvailabilitiesForProject.map((a) => a.copyWith()).toList();
    _initializeState();
  }

  void _initializeState() {
    Project? initialProject;

    if (_localAvailabilities.isNotEmpty) {
      final projectId = _localAvailabilities.first.projectId;
      initialProject = widget.projects.firstWhereOrNull((p) => p.projectId == projectId);
    } else if (widget.projects.length == 1) {
      initialProject = widget.projects.first;
    }

    _currentDate = DateUtils.dateOnly(widget.initialDate ?? DateTime.now().add(const Duration(days: 1)));

    if (initialProject != null) {
      _currentStep = WizardStep.declareAvailability;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onProjectSelected(initialProject, preselected: true);
      });
    } else {
      _currentStep = WizardStep.selectProject;
    }
  }

  Future<void> _onProjectSelected(Project? project, {bool preselected = false}) async {
    if (project == null) return;
    setState(() { _isLoading = true; });

    _selectedProject = project;
    _selectedTemplate = widget.templates.firstWhere((t) => t.projectId == project.projectId);

    try {
      final Member? member = await membersService.getMembership(userId: widget.userId, ownerId: project.ownerId);
      final projectAccess = member?.projects.firstWhere((p) => p.projectId == project.projectId);
      _projectAreas = (projectAccess?.areaIds.isNotEmpty ?? false)
          ? await areaService.getAreasByIds(projectAccess!.areaIds.toList())
          : [];

      _loadDataForDay(_currentDate);

      if (!preselected) {
        setState(() => _currentStep = WizardStep.declareAvailability);
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd uprawnień', 'Błąd: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _loadDataForDay(DateTime day) {
    _dailyAvailability.clear();
    _originalDailyAvailability.clear();
    _expandedBlockIndex = null;

    // ZMIANA: Operujemy na lokalnej kopii danych.
    final entriesForDay = _localAvailabilities.where((avail) => DateUtils.isSameDay(avail.date, day));

    if (entriesForDay.isNotEmpty) {
      _isAvailableMode = entriesForDay.first.isAvailable;
    }

    for (final entry in entriesForDay) {
      _dailyAvailability[entry.blockIndex] = List<String>.from(entry.areaIds);
      _originalDailyAvailability[entry.blockIndex] = List<String>.from(entry.areaIds);
    }

    setState(() {
      _currentDate = day;
      _isDirty = false;
    });
  }

  void _checkForChanges() {
    const mapEquality = MapEquality();
    setState(() {
      _isDirty = !mapEquality.equals(_dailyAvailability, _originalDailyAvailability);
    });
  }

  void _onBlockSelectionChanged(bool? isSelected, int blockIndex) {
    setState(() {
      if (isSelected ?? false) {
        _dailyAvailability[blockIndex] = [];
      } else {
        _dailyAvailability.remove(blockIndex);
        if (_expandedBlockIndex == blockIndex) _expandedBlockIndex = null;
      }
    });
    _checkForChanges();
  }

// W klasie _AvailabilityWizardState

// ZASTĄP TĘ FUNKCJĘ
  void _onAreaSelectionChanged(bool? isSelected, int blockIndex, String areaId) {
    setState(() {
      // Pobierz aktualną listę zaznaczonych stref dla danego bloku.
      final currentSelection = _dailyAvailability[blockIndex];
      if (currentSelection == null) return; // Zabezpieczenie, nie powinno się zdarzyć

      // Stwórz modyfikowalną kopię listy.
      // Jeśli lista jest pusta (co oznacza "wszystkie"), "zmaterializuj" ją,
      // czyli wypełnij wszystkimi dostępnymi ID stref.
      List<String> updatedSelection = currentSelection.isEmpty
          ? _projectAreas.map((a) => a.areaId).toList()
          : List.from(currentSelection);

      // Zastosuj zmianę dokonaną przez użytkownika
      if (isSelected == true) {
        if (!updatedSelection.contains(areaId)) {
          updatedSelection.add(areaId);
        }
      } else {
        updatedSelection.remove(areaId);
      }

      // Sprawdzenie dodatkowe: jeśli użytkownik ponownie zaznaczył wszystkie strefy,
      // wróćmy do stanu "wszystkie" (pusta lista) dla czystości danych.
      final allProjectAreaIds = _projectAreas.map((a) => a.areaId).toSet();
      if (const SetEquality().equals(updatedSelection.toSet(), allProjectAreaIds)) {
        _dailyAvailability[blockIndex] = [];
      } else {
        _dailyAvailability[blockIndex] = updatedSelection;
      }
    });
    _checkForChanges();
  }

  Future<bool> _saveCurrentDay() async {
    if (!_isDirty) return true;
    setState(() { _isLoading = true; });
    try {
      // ZMIANA: Znajdujemy i usuwamy stare wpisy z LOKALNEJ kopii i z bazy danych.
      final oldEntriesForDay = _localAvailabilities
          .where((avail) => DateUtils.isSameDay(avail.date, _currentDate))
          .toList();
      for (final oldEntry in oldEntriesForDay) {
        await availabilityService.deleteAvailability(oldEntry.availabilityId);
        _localAvailabilities.remove(oldEntry);
      }

      if (_dailyAvailability.isNotEmpty) {
        final newAvailabilities = _dailyAvailability.entries.map((entry) {
          final safeAreaIds = List<String>.from(entry.value);
          return UserAvailability(
            userId: widget.userId,
            projectId: _selectedProject!.projectId,
            date: _currentDate,
            scheduleTemplateId: _selectedTemplate!.templateId,
            blockIndex: entry.key,
            isAvailable: _isAvailableMode,
            areaIds: safeAreaIds,
          );
        }).toList();
        await availabilityService.saveAvailabilities(newAvailabilities);
        // ZMIANA: Aktualizujemy LOKALNĄ kopię.
        _localAvailabilities.addAll(newAvailabilities);
      }

      _originalDailyAvailability = Map.from(_dailyAvailability.map((key, value) {
        final safeList = List<String>.from(value);
        return MapEntry(key, safeList);
      }));
      setState(() {
        _isDirty = false;
        _wasAnyChangeSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Zmiany zapisane.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ));
      return true;
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd zapisu', 'Nie udało się zapisać danych: $e');
      return false;
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _changeDay(int days) async {
    final success = await _saveCurrentDay();
    if (success && mounted) {
      final newDate = _currentDate.add(Duration(days: days));
      _loadDataForDay(newDate);
    }
  }

  Future<void> _finishAndClose() async {
    final success = await _saveCurrentDay();
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentStep == WizardStep.selectProject
            ? _buildProjectSelection()
            : _buildAvailabilityDeclaration(),
      ),
    );
  }

  Widget _buildProjectSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deklaracja dyspozycyjności', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Wybierz pracodawcę (projekt), dla którego chcesz zadeklarować dyspozycyjność:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<Project>(
            value: _selectedProject,
            items: widget.projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
            onChanged: _onProjectSelected,
            decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityDeclaration() {
    final allTemplateBlocks = _selectedTemplate?.scheduleBlocks ?? [];
    final dailyBlocks = allTemplateBlocks.where((block) {
      final occurrences = SfCalendar.getRecurrenceDateTimeCollection(block.recurrenceRule, block.startTime,
          specificStartDate: _currentDate, specificEndDate: _currentDate);
      return occurrences.isNotEmpty;
    }).toList();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text(_selectedProject?.name ?? 'Deklaracja', style: const TextStyle(fontSize: 16,)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _finishAndClose,
            child: const Text('Zakończ',style: TextStyle(fontSize: 16,color: Colors.white)),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (_isDirty) {
                  showConfirmationDialog(
                    context,
                    'Niezapisane zmiany',
                    'Masz niezapisane zmiany dla tego dnia. Czy na pewno chcesz zamknąć okno bez zapisywania?',
                    onConfirm: () {
                      Navigator.of(context).pop(_wasAnyChangeSaved);
                    },
                  );
                } else {
                  Navigator.of(context).pop(_wasAnyChangeSaved);
                }
              }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Nie mogę'),
                Switch(value: _isAvailableMode, onChanged: (val) {
                  setState(() => _isAvailableMode = val);
                  _isDirty = true;
                }),
                const Text('Mogę'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: dailyBlocks.isEmpty
                ? const Center(child: Text('Brak zaplanowanych bloków pracy w tym dniu.'))
                : ListView.builder(
              itemCount: dailyBlocks.length,
              itemBuilder: (context, index) {
                final block = dailyBlocks[index];
                final originalBlockIndex = allTemplateBlocks.indexOf(block);
                final bool isSelected = _dailyAvailability.containsKey(originalBlockIndex);
                final List<String> selectedAreas = _dailyAvailability[originalBlockIndex] ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    key: PageStorageKey('${_currentDate.toIso8601String()}-$originalBlockIndex'),
                    onExpansionChanged: (isExpanding) {
                      setState(() {
                        _expandedBlockIndex = isExpanding ? originalBlockIndex : null;
                      });
                    },
                    initiallyExpanded: _expandedBlockIndex == originalBlockIndex,
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (val) => _onBlockSelectionChanged(val, originalBlockIndex),
                      activeColor: _isAvailableMode ? Colors.green : Colors.red,
                    ),
                    title: Text(block.name,
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle:
                    Text('${DateFormat('HH:mm').format(block.startTime)} - ${DateFormat('HH:mm').format(block.endTime)}'),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          selectedAreas.isEmpty
                              ? 'Wybrano wszystkie dostępne strefy.'
                              : 'Wybrano niestandardowe strefy:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ..._projectAreas.map((area) {
                        final bool isAreaSelected = selectedAreas.isEmpty || selectedAreas.contains(area.areaId);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(area.name, style: Theme.of(context).textTheme.bodyMedium),
                          value: isAreaSelected,
                          onChanged: (val) => _onAreaSelectionChanged(val, originalBlockIndex, area.areaId),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('EEEE, d MMMM', 'pl_PL').format(_currentDate),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                  icon: const Icon(Icons.arrow_back), label: const Text('Poprzedni'), onPressed: () => _changeDay(-1)),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Zapisz dzień'),
                onPressed: _isDirty ? _saveCurrentDay : null,
              ),
              TextButton.icon(
                  label: const Text('Następny'),
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _changeDay(1)),
            ],
          ),
        ]),
      ),
    );
  }
}