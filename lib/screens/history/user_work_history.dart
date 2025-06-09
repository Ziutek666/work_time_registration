import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

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

// Helper classes
class _WorkSession {
  final WorkEntry startEntry;
  final WorkEntry endEntry;
  final Duration duration;
  _WorkSession({required this.startEntry, required this.endEntry, required this.duration});
}

class _CompoundWorkSession {
  final _WorkSession mainTask;
  final List<_WorkSession> breaks;
  final List<_WorkSession> subtasks;
  _CompoundWorkSession({
    required this.mainTask,
    this.breaks = const [],
    this.subtasks = const [],
  });
}

class UserWorkHistoryScreen extends StatefulWidget {
  const UserWorkHistoryScreen({super.key});

  @override
  State<UserWorkHistoryScreen> createState() => _UserWorkHistoryScreenState();
}

class _UserWorkHistoryScreenState extends State<UserWorkHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  UserApp? _currentUser;
  bool _isFilterPanelExpanded = true;

  // Dane
  List<WorkEntry> _allUserWorkEntries = [];
  Map<String, Map<String, List<_CompoundWorkSession>>> _groupedSessions = {};

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

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'pl_PL');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // ZMIANA: Dodano nową, zwięzłą funkcję formatującą
  String _formatDurationHHMM(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    return "${duration.inHours}:$twoDigitMinutes";
  }

  String _formatDuration(Duration duration, {bool showSeconds = false}) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String hours = duration.inHours.toString();
    if (showSeconds) {
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "$hours:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$hours godz. $twoDigitMinutes min.";
  }

  Future<void> _initializeScreen() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) throw Exception("Nie można zidentyfikować użytkownika.");
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      await _loadProjectsForFilter();
      await _fetchAndProcessWorkEntries();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProjectsForFilter() async {
    // ... bez zmian
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
    // ... bez zmian
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

  Future<void> _fetchAndProcessWorkEntries() async {
    // ... bez zmian
    if (_currentUser?.uid == null || _selectedDateRange == null) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      _allUserWorkEntries = await workEntryService.getWorkEntriesForUserBetweenDates(
        _currentUser!.uid!,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day + 1),
      );
      await _ensureProjectAndAreaNamesAvailable(_allUserWorkEntries);
      _applyFiltersAndGroup();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd przetwarzania historii pracy: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndGroup() {
    // ... bez zmian
    List<WorkEntry> tempFiltered = List.from(_allUserWorkEntries);
    if (_selectedFilterProject != null) tempFiltered = tempFiltered.where((entry) => entry.projectId == _selectedFilterProject!.projectId).toList();
    if (_selectedFilterArea != null) tempFiltered = tempFiltered.where((entry) => entry.areaId == _selectedFilterArea!.areaId).toList();
    Map<String, WorkEntry> openSessions = {};
    List<_WorkSession> allSessions = [];
    tempFiltered.sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));
    for (var entry in tempFiltered) {
      String sessionKey = '${entry.projectId}_${entry.areaId}_${entry.workTypeId}';
      if (entry.isStart) {
        openSessions[sessionKey] = entry;
      } else {
        if (openSessions.containsKey(sessionKey)) {
          final startEvent = openSessions.remove(sessionKey)!;
          final duration = entry.eventActionTimestamp.toDate().difference(startEvent.eventActionTimestamp.toDate());
          if (!duration.isNegative) {
            allSessions.add(_WorkSession(startEntry: startEvent, endEntry: entry, duration: duration));
          }
        }
      }
    }
    List<_WorkSession> mainTasks = allSessions.where((s) => !s.startEntry.workTypeIsBreak && !s.startEntry.workTypeIsSubTask).toList();
    List<_WorkSession> breaks = allSessions.where((s) => s.startEntry.workTypeIsBreak).toList();
    List<_WorkSession> subtasks = allSessions.where((s) => s.startEntry.workTypeIsSubTask).toList();
    List<_CompoundWorkSession> compoundSessions = [];
    for (var mainTask in mainTasks) {
      final mainTaskStart = mainTask.startEntry.eventActionTimestamp.toDate();
      final mainTaskEnd = mainTask.endEntry.eventActionTimestamp.toDate();
      final associatedBreaks = breaks.where((b) {
        final breakStart = b.startEntry.eventActionTimestamp.toDate();
        return breakStart.isAfter(mainTaskStart) && breakStart.isBefore(mainTaskEnd);
      }).toList();
      final associatedSubtasks = subtasks.where((st) {
        final subtaskStart = st.startEntry.eventActionTimestamp.toDate();
        return subtaskStart.isAfter(mainTaskStart) && subtaskStart.isBefore(mainTaskEnd);
      }).toList();
      compoundSessions.add(_CompoundWorkSession(mainTask: mainTask, breaks: associatedBreaks, subtasks: associatedSubtasks));
    }
    _totalMainWorkDuration = mainTasks.fold(Duration.zero, (prev, s) => prev + s.duration);
    _totalBreakDuration = breaks.fold(Duration.zero, (prev, s) => prev + s.duration);
    _totalSubtaskDuration = subtasks.fold(Duration.zero, (prev, s) => prev + s.duration);
    compoundSessions.sort((a, b) => b.mainTask.startEntry.eventActionTimestamp.compareTo(a.mainTask.startEntry.eventActionTimestamp));
    final groupedByProject = groupBy(compoundSessions, (s) => s.mainTask.startEntry.projectId);
    _groupedSessions.clear();
    groupedByProject.forEach((projectId, sessionsInProject) {
      final groupedByArea = groupBy(sessionsInProject, (s) => s.mainTask.startEntry.areaId);
      _groupedSessions[projectId] = groupedByArea;
    });
    if(mounted) setState(() {});
  }

  Future<void> _ensureProjectAndAreaNamesAvailable(List<WorkEntry> entries) async {
    // ... bez zmian
    final Set<String> projectIdsInEntries = entries.map((e) => e.projectId).where((id) => id.isNotEmpty).toSet();
    final Set<String> areaIdsInEntries = entries.map((e) => e.areaId).where((id) => id.isNotEmpty).toSet();
    final List<String> missingProjectIds = projectIdsInEntries.where((id) => !_projectNamesMap.containsKey(id)).toList();
    final List<String> missingAreaIds = areaIdsInEntries.where((id) => !_areaNamesMap.containsKey(id)).toList();
    if (missingProjectIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(missingProjectIds);
      for (var p in newProjects) { _projectNamesMap[p.projectId] = p.name; }
    }
    if (missingAreaIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(missingAreaIds);
      for (var a in newAreas) { _areaNamesMap[a.areaId] = a.name; }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    // ... bez zmian
    final DateTimeRange? picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('pl', 'PL'));
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      await _fetchAndProcessWorkEntries();
    }
  }

  void _onProjectFilterChanged(Project? project) {
    // ... bez zmian
    setState(() { _selectedFilterProject = project; _selectedFilterArea = null; _availableAreasForFilter = []; });
    if (project != null) {
      _loadAreasForFilter(project.projectId).then((_) => _applyFiltersAndGroup());
    } else {
      _applyFiltersAndGroup();
    }
  }

  void _onAreaFilterChanged(Area? area) {
    // ... bez zmian
    setState(() => _selectedFilterArea = area);
    _applyFiltersAndGroup();
  }

  void _clearFilters() {
    // ... bez zmian
    final now = DateTime.now();
    setState(() { _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now); _selectedFilterProject = null; _selectedFilterArea = null; _availableAreasForFilter = []; });
    _fetchAndProcessWorkEntries();
  }

  @override
  Widget build(BuildContext context) {
    // ... bez zmian
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historia Pracy'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
      body: Column(
        children: [
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _groupedSessions.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Brak zarejestrowanych sesji pracy w wybranym okresie.', textAlign: TextAlign.center)))
                : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilterPanel(ThemeData theme) {
    // ... bez zmian
    return Card(margin: const EdgeInsets.fromLTRB(8, 8, 8, 4), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
        child: ExpansionTile(key: const PageStorageKey<String>('filter_panel_user'), initiallyExpanded: _isFilterPanelExpanded, onExpansionChanged: (isExpanded) => setState(() => _isFilterPanelExpanded = isExpanded), title: Text("Filtry i Podsumowanie", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), leading: Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary), trailing: Icon(_isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more),
            children: [Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16), child: Column(children: [_buildSummaryCard(theme), _buildFilterSection(theme)]))]));
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Podsumowanie Czasu Pracy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 12),
      _buildSummaryRow(theme, Icons.work_outline, 'Praca:', _formatDuration(_totalMainWorkDuration)),
      _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Przerwy:', _formatDuration(_totalBreakDuration), color: Colors.orange.shade700),
      // ZMIANA: Użycie nowej funkcji formatującej
      _buildSummaryRow(theme, Icons.low_priority_rounded, 'Podzadania:', _formatDurationHHMM(_totalSubtaskDuration), color: Colors.teal.shade600),
      const Divider(height: 24),
    ]);
  }

  Widget _buildSummaryRow(ThemeData theme, IconData icon, String label, String value, {Color? color}) {
    // ... bez zmian
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label ', style: theme.textTheme.bodyLarge),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: color ?? theme.colorScheme.primary)),
        ]));
  }

  Widget _buildFilterSection(ThemeData theme) {
    // ... bez zmian
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(icon: const Icon(Icons.date_range), label: Text(_selectedDateRange != null ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}' : 'Wybierz zakres dat'), onPressed: () => _selectDateRange(context), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: DropdownButtonFormField<Project>(decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), value: _selectedFilterProject, hint: const Text('Wszystkie'), isExpanded: true, items: [const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie projekty')), ..._availableProjectsForFilter.map((p) => DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))], onChanged: _onProjectFilterChanged)),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonFormField<Area>(decoration: const InputDecoration(labelText: 'Obszar', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)), value: _selectedFilterArea, hint: const Text('Wszystkie'), isExpanded: true, disabledHint: _selectedFilterProject == null ? const Text('Wybierz projekt') : null, items: _selectedFilterProject == null ? [] : [const DropdownMenuItem<Area>(value: null, child: Text('Wszystkie obszary')), ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))], onChanged: _selectedFilterProject != null ? _onAreaFilterChanged : null)),
      ]),
      const SizedBox(height: 12),
      ElevatedButton.icon(icon: const Icon(Icons.clear_all_rounded), label: const Text('Wyczyść Filtry'), onPressed: _clearFilters, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), backgroundColor: theme.colorScheme.secondaryContainer, foregroundColor: theme.colorScheme.onSecondaryContainer)),
    ]);
  }

  Widget _buildHistoryList(ThemeData theme) {
    // ... bez zmian
    final projectIds = _groupedSessions.keys.toList();
    projectIds.sort((a, b) => (_projectNamesMap[a] ?? a).toLowerCase().compareTo((_projectNamesMap[b] ?? b).toLowerCase()));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: projectIds.length,
      itemBuilder: (context, projectIndex) {
        final projectId = projectIds[projectIndex];
        final projectName = _projectNamesMap[projectId] ?? 'Projekt bez nazwy';
        final areasInProject = _groupedSessions[projectId]!;
        final areaIds = areasInProject.keys.toList();
        areaIds.sort((a,b) => (_areaNamesMap[a] ?? a).toLowerCase().compareTo((_areaNamesMap[b] ?? b).toLowerCase()));
        return Card(margin: const EdgeInsets.symmetric(vertical: 6), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(key: PageStorageKey<String>(projectId), leading: Icon(Icons.folder_copy_outlined, color: theme.colorScheme.primary), title: Text(projectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              children: areaIds.map((areaId) {
                final areaName = _areaNamesMap[areaId] ?? 'Obszar bez nazwy';
                final sessionsInArea = areasInProject[areaId]!;
                return ExpansionTile(key: PageStorageKey<String>('$projectId-$areaId'), leading: Padding(padding: const EdgeInsets.only(left: 16.0), child: Icon(Icons.explore_outlined, color: theme.colorScheme.secondary)), title: Text(areaName, style: theme.textTheme.titleMedium),
                  children: sessionsInArea.map((session) => _buildCompoundSessionCard(session, theme)).toList(),
                );
              }).toList(),
            ));
      },
    );
  }

  Widget _buildCompoundSessionCard(_CompoundWorkSession session, ThemeData theme) {
    // ... bez zmian
    final mainTask = session.mainTask;
    final startTime = mainTask.startEntry.eventActionTimestamp.toDate();
    final endTime = mainTask.endEntry.eventActionTimestamp.toDate();
    final timeFormat = DateFormat('HH:mm');
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(left: 32, right: 16, top: 4, bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.dividerColor, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.work_outline, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(mainTask.startEntry.workTypeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              Text(_formatDuration(mainTask.duration, showSeconds: true), style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ]),
            const Divider(height: 16),
            Padding(padding: const EdgeInsets.only(left: 36.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('d MMM yy', 'pl_PL').format(startTime)}   |   ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              if (mainTask.startEntry.description?.isNotEmpty??false) ...[
                const SizedBox(height: 6),
                Text(mainTask.startEntry.description??'', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ])),
            if (session.subtasks.isNotEmpty || session.breaks.isNotEmpty)
              _buildNestedSessionsSection(theme, subtasks: session.subtasks, breaks: session.breaks),
          ],
        ),
      ),
    );
  }

  Widget _buildNestedSessionsSection(ThemeData theme, {required List<_WorkSession> subtasks, required List<_WorkSession> breaks}) {
    // ... bez zmian
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, left: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          if (subtasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text("Podzadania:", style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
            ),
            ...subtasks.map((subtask) => _buildNestedItem(theme, subtask, isBreak: false)),
          ],
          if (breaks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text("Przerwy:", style: theme.textTheme.labelMedium?.copyWith(color: Colors.orange.shade800)),
            ),
            ...breaks.map((br) => _buildNestedItem(theme, br, isBreak: true)),
          ]
        ],
      ),
    );
  }

  // ZMIANA: Dodano czas rozpoczęcia/zakończenia
  Widget _buildNestedItem(ThemeData theme, _WorkSession session, {required bool isBreak}) {
    final icon = isBreak ? Icons.free_breakfast_outlined : Icons.low_priority_rounded;
    final color = isBreak ? Colors.orange.shade700 : Colors.teal.shade600;
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(session.startEntry.workTypeName, style: theme.textTheme.bodyMedium)),
              Text(
                _formatDuration(session.duration),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26.0, top: 2.0),
            child: Text(
              '${timeFormat.format(session.startEntry.eventActionTimestamp.toDate())} - ${timeFormat.format(session.endEntry.eventActionTimestamp.toDate())}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          )
        ],
      ),
    );
  }
}