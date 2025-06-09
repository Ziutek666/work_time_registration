import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Dla funkcji groupBy

// Dostosuj ścieżki do swoich modeli i serwisów
import '../../models/work_entry.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/user_app.dart';
import '../../services/work_entry_service.dart';
import '../../services/project_service.dart';
import '../../services/area_service.dart';
import '../../services/user_service.dart';
import '../../services/project_member_service.dart';
import '../../widgets/dialogs.dart'; // Jeśli potrzebujesz dialogów


class UserWorkHistoryScreen extends StatefulWidget {
  const UserWorkHistoryScreen({super.key});

  @override
  State<UserWorkHistoryScreen> createState() => _UserWorkHistoryScreenState();
}

class _UserWorkHistoryScreenState extends State<UserWorkHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  bool _isCalculating = false;
  String? _errorMessage;
  UserApp? _currentUser;
  bool _isFilterPanelExpanded = true; // NOWA ZMIENNA STANU

  // Dane
  List<WorkEntry> _allUserWorkEntries = [];
  Map<String, Map<String, List<WorkEntry>>> _groupedFilteredEntries = {};

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;

  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];

  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};

  // Podsumowanie czasów
  Duration _totalMainWorkDuration = Duration.zero;
  Duration _totalBreakDuration = Duration.zero;
  Duration _totalSubtaskDuration = Duration.zero;
  Map<String, Duration> _entryStopDurations = {};

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'pl_PL');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss', 'pl_PL');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) {
        throw Exception("Nie można zidentyfikować użytkownika.");
      }

      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

      await _loadProjectsForFilter();
      await _fetchProcessAndSummarizeWorkEntries();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Błąd inicjalizacji: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProjectsForFilter() async {
    if (_currentUser?.uid == null) return;
    try {
      final memberships = await projectMemberService.getProjectsForUser(_currentUser!.uid!);
      final projectIds = memberships.map((m) => m.projectId).toSet().toList();
      if (projectIds.isNotEmpty) {
        _availableProjectsForFilter = await projectService.fetchProjectsByIds(projectIds);
        _availableProjectsForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (var p in _availableProjectsForFilter) {
          _projectNamesMap[p.projectId] = p.name;
        }
      } else {
        _availableProjectsForFilter = [];
      }
    } catch (e) {
      debugPrint("Błąd ładowania projektów do filtra: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    if (_selectedFilterProject == null || _selectedFilterProject!.projectId != projectId) {
      if (mounted) {
        setState(() {
          _selectedFilterArea = null;
          _availableAreasForFilter = [];
        });
      }
    }
    try {
      _availableAreasForFilter = await areaService.getAreasByProject(projectId);
      _availableAreasForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var a in _availableAreasForFilter) {
        _areaNamesMap[a.areaId] = a.name;
      }
    } catch (e) {
      debugPrint("Błąd ładowania obszarów dla projektu $projectId: $e");
      if (mounted) setState(() => _availableAreasForFilter = []);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchProcessAndSummarizeWorkEntries() async {
    if (_currentUser?.uid == null || _selectedDateRange == null) return;

    setState(() { _isLoading = true; _isCalculating = true; _errorMessage = null; });

    try {
      _allUserWorkEntries = await workEntryService.getWorkEntriesForUserBetweenDates(
        _currentUser!.uid!,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day + 1),
      );

      await _ensureProjectAndAreaNamesAvailable(_allUserWorkEntries);
      _calculateIndividualStopDurations();
      _applyFiltersAndGroup();

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Błąd przetwarzania historii pracy: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCalculating = false;
        });
      }
    }
  }

  void _calculateIndividualStopDurations() {
    _entryStopDurations.clear();
    List<WorkEntry> sortedEntries = List.from(_allUserWorkEntries);
    sortedEntries.sort((a, b) {
      int comp = a.projectId.compareTo(b.projectId);
      if (comp != 0) return comp;
      comp = a.areaId.compareTo(b.areaId);
      if (comp != 0) return comp;
      comp = a.workTypeId.compareTo(b.workTypeId);
      if (comp != 0) return comp;
      return a.eventActionTimestamp.compareTo(b.eventActionTimestamp);
    });

    Map<String, WorkEntry> openSessions = {};
    for (var entry in sortedEntries) {
      String sessionKey = '${entry.projectId}_${entry.areaId}_${entry.workTypeId}';
      if (entry.isStart) {
        openSessions[sessionKey] = entry;
      } else {
        if (openSessions.containsKey(sessionKey)) {
          WorkEntry startEvent = openSessions[sessionKey]!;
          Duration duration = entry.eventActionTimestamp.toDate().difference(startEvent.eventActionTimestamp.toDate());
          if (duration.isNegative) duration = Duration.zero;
          _entryStopDurations[entry.entryId] = duration;
          openSessions.remove(sessionKey);
        }
      }
    }
  }

  void _applyFiltersAndGroup() {
    List<WorkEntry> tempFiltered = List.from(_allUserWorkEntries);

    if (_selectedFilterProject != null) {
      tempFiltered = tempFiltered.where((entry) => entry.projectId == _selectedFilterProject!.projectId).toList();
    }
    if (_selectedFilterArea != null) {
      tempFiltered = tempFiltered.where((entry) => entry.areaId == _selectedFilterArea!.areaId).toList();
    }

    _totalMainWorkDuration = Duration.zero;
    _totalBreakDuration = Duration.zero;
    _totalSubtaskDuration = Duration.zero;

    for (var entry in tempFiltered) {
      if (!entry.isStart && _entryStopDurations.containsKey(entry.entryId)) {
        Duration duration = _entryStopDurations[entry.entryId]!;
        if (entry.workTypeIsBreak) {
          _totalBreakDuration += duration;
        } else if (entry.workTypeIsSubTask) {
          _totalSubtaskDuration += duration;
        } else {
          _totalMainWorkDuration += duration;
        }
      }
    }

    tempFiltered.sort((a, b) => b.eventActionTimestamp.compareTo(a.eventActionTimestamp));
    final groupedByProject = groupBy(tempFiltered, (WorkEntry entry) => entry.projectId);
    _groupedFilteredEntries.clear();
    groupedByProject.forEach((projectId, entriesInProject) {
      final groupedByArea = groupBy(entriesInProject, (WorkEntry entry) => entry.areaId);
      _groupedFilteredEntries[projectId] = groupedByArea;
    });

    if(mounted) setState(() {});
  }


  Future<void> _ensureProjectAndAreaNamesAvailable(List<WorkEntry> entries) async {
    final Set<String> projectIdsInEntries = entries.map((e) => e.projectId).where((id) => id.isNotEmpty).toSet();
    final Set<String> areaIdsInEntries = entries.map((e) => e.areaId).where((id) => id.isNotEmpty).toSet();

    final List<String> missingProjectIds = projectIdsInEntries.where((id) => !_projectNamesMap.containsKey(id)).toList();
    final List<String> missingAreaIds = areaIdsInEntries.where((id) => !_areaNamesMap.containsKey(id)).toList();

    if (missingProjectIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(missingProjectIds);
      for (var p in newProjects) {
        _projectNamesMap[p.projectId] = p.name;
      }
    }
    if (missingAreaIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(missingAreaIds);
      for (var a in newAreas) {
        _areaNamesMap[a.areaId] = a.name;
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl', 'PL'),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _fetchProcessAndSummarizeWorkEntries();
    }
  }

  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    if (project != null) {
      _loadAreasForFilter(project.projectId).then((_) {
        _applyFiltersAndGroup();
      });
    } else {
      _applyFiltersAndGroup();
    }
  }

  void _onAreaFilterChanged(Area? area) {
    setState(() {
      _selectedFilterArea = area;
    });
    _applyFiltersAndGroup();
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    _fetchProcessAndSummarizeWorkEntries();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Pracy'),
      ),
      body: Column(
        children: [
          // ZMIANA: Wywołanie nowego, zwijanego panelu
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isCalculating
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Przeliczanie danych...")]))
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _groupedFilteredEntries.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Brak wpisów spełniających kryteria.', textAlign: TextAlign.center)))
                : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  // NOWY WIDGET: Zwijany panel dla filtrów i podsumowania
  Widget _buildCollapsibleFilterPanel(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('filter_panel_user'), // Unikalny klucz
        initiallyExpanded: _isFilterPanelExpanded,
        onExpansionChanged: (isExpanded) {
          setState(() => _isFilterPanelExpanded = isExpanded);
        },
        title: Text(
          "Filtry i Podsumowanie",
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: Icon(
          Icons.filter_list_rounded,
          color: theme.colorScheme.primary,
        ),
        trailing: Icon(
          _isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: [
                _buildSummaryCard(theme),
                _buildFilterSection(theme),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Podsumowanie Twojego Czasu Pracy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          _buildSummaryRow(theme, Icons.work_outline, 'Czas pracy (główne):', _formatDuration(_totalMainWorkDuration)),
          _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Czas przerw:', _formatDuration(_totalBreakDuration), color: Colors.orange.shade700),
          _buildSummaryRow(theme, Icons.low_priority_rounded, 'Czas podzadań:', _formatDuration(_totalSubtaskDuration), color: Colors.teal.shade600),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label ', style: theme.textTheme.titleSmall),
          const Spacer(),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color ?? theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_selectedDateRange != null ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}' : 'Wybierz zakres dat'),
            onPressed: () => _selectDateRange(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: DropdownButtonFormField<Project>(decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder()), value: _selectedFilterProject, hint: const Text('Wszystkie'), isExpanded: true, items: [const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie projekty')), ..._availableProjectsForFilter.map((p) => DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))], onChanged: _onProjectFilterChanged)),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<Area>(decoration: const InputDecoration(labelText: 'Obszar', border: OutlineInputBorder()), value: _selectedFilterArea, hint: const Text('Wszystkie'), isExpanded: true, disabledHint: _selectedFilterProject == null ? const Text('Wybierz projekt') : null, items: _selectedFilterProject == null ? [] : [const DropdownMenuItem<Area>(value: null, child: Text('Wszystkie obszary')), ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))], onChanged: _selectedFilterProject != null ? _onAreaFilterChanged : null)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(icon: const Icon(Icons.clear_all_rounded), label: const Text('Wyczyść Filtry'), onPressed: _clearFilters, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), backgroundColor: theme.colorScheme.secondaryContainer, foregroundColor: theme.colorScheme.onSecondaryContainer)),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    final projectIds = _groupedFilteredEntries.keys.toList();
    projectIds.sort((a, b) => (_projectNamesMap[a] ?? a).toLowerCase().compareTo((_projectNamesMap[b] ?? b).toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: projectIds.length,
      itemBuilder: (context, projectIndex) {
        final projectId = projectIds[projectIndex];
        final projectName = _projectNamesMap[projectId] ?? 'Nieznany Projekt ($projectId)';
        final areasInProject = _groupedFilteredEntries[projectId]!;
        final areaIds = areasInProject.keys.toList();
        areaIds.sort((a,b) => (_areaNamesMap[a] ?? a).toLowerCase().compareTo((_areaNamesMap[b] ?? b).toLowerCase()));

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            key: PageStorageKey<String>(projectId),
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.05),
            collapsedBackgroundColor: theme.cardColor,
            leading: Icon(Icons.folder_copy_outlined, color: theme.colorScheme.primary, size: 28),
            title: Text(projectName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: areaIds.map((areaId) {
              final areaName = _areaNamesMap[areaId] ?? 'Nieznany Obszar ($areaId)';
              final entriesInArea = areasInProject[areaId]!;

              return ExpansionTile(
                key: PageStorageKey<String>('$projectId-$areaId'),
                backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.05),
                collapsedBackgroundColor: theme.cardColor.withAlpha(240),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Icon(Icons.explore_outlined, color: theme.colorScheme.secondary, size: 24),
                ),
                title: Text(areaName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: entriesInArea.map((entry) => _buildWorkEntryItem(entry, theme)).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildWorkEntryItem(WorkEntry entry, ThemeData theme) {
    final isStartEvent = entry.isStart;
    final eventColor = isStartEvent ? Colors.green.shade600 : Colors.red.shade600;
    final eventIcon = isStartEvent ? Icons.play_circle_fill_rounded : Icons.stop_circle_rounded;
    final timestamp = entry.eventActionTimestamp.toDate();
    Duration? durationForStopEvent = !isStartEvent && _entryStopDurations.containsKey(entry.entryId) ? _entryStopDurations[entry.entryId] : null;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(left: 32, right: 16, top: 4, bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        leading: Icon(eventIcon, color: eventColor, size: 24),
        title: Text(entry.workTypeName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_dateFormat.format(timestamp)} ${_timeFormat.format(timestamp)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            if (entry.description != null && entry.description!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3.0), child: Text('Opis: ${entry.description}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (durationForStopEvent != null) Padding(padding: const EdgeInsets.only(top: 3.0), child: Text('Czas trwania: ${_formatDuration(durationForStopEvent)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary))),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(isStartEvent ? 'Start' : 'Stop', style: TextStyle(color: eventColor, fontWeight: FontWeight.bold, fontSize: 11)),
            if(entry.workTypeIsBreak) Tooltip(message: "Przerwa", child: Icon(Icons.free_breakfast_outlined, size: 16, color: Colors.orange.shade700)),
            if(entry.workTypeIsSubTask) Tooltip(message: "Podzadanie", child: Icon(Icons.low_priority_rounded, size: 16, color: Colors.teal.shade600)),
          ],
        ),
        isThreeLine: (entry.description != null && entry.description!.isNotEmpty) || (durationForStopEvent != null),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}