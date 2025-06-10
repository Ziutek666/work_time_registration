import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Dostosuj ścieżki do swoich modeli i serwisów
import '../../models/work_entry.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/user_app.dart';
import '../../models/information.dart';
import '../../services/work_entry_service.dart';
import '../../services/project_service.dart';
import '../../services/area_service.dart';
import '../../services/user_service.dart';

/// Reprezentuje pojedynczą sesję pracy, od startu do stopu,
/// wraz ze wszystkimi zdarzeniami, które wystąpiły w jej trakcie.
class WorkSession {
  final WorkEntry startEntry;
  final WorkEntry? endEntry; // Może być null, jeśli sesja jest w toku
  final List<WorkEntry> allEventsInSession; // Wszystkie zdarzenia, w tym start/stop

  WorkSession({
    required this.startEntry,
    this.endEntry,
    required this.allEventsInSession,
  });

  bool get isFinished => endEntry != null;

  Duration get duration {
    if (!isFinished) {
      return DateTime.now().difference(startEntry.eventActionTimestamp.toDate());
    }
    return endEntry!.eventActionTimestamp
        .toDate()
        .difference(startEntry.eventActionTimestamp.toDate());
  }

  String get workTypeName => startEntry.workTypeName;
}

class UserInfoHistoryScreen extends StatefulWidget {
  const UserInfoHistoryScreen({super.key});

  @override
  State<UserInfoHistoryScreen> createState() => _UserInfoHistoryScreenState();
}

class _UserInfoHistoryScreenState extends State<UserInfoHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFilterPanelExpanded = true;
  UserApp? _currentUser;

  // UPROSZCZONA STRUKTURA DANYCH: Przechowujemy sesje tylko dla bieżącego użytkownika
  Map<String, Map<String, List<WorkSession>>> _groupedSessionsForCurrentUser = {};
  List<WorkEntry> _allWorkEntries = [];

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;

  // Stan dla podsumowania czasów
  Duration _totalMainWorkDuration = Duration.zero;
  Duration _totalBreakDuration = Duration.zero;
  Duration _totalSubtaskDuration = Duration.zero;

  // Mapy nazw i dostępne obiekty do filtrów
  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];
  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'pl_PL');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) {
        throw Exception("Brak zalogowanego użytkownika.");
      }

      final now = DateTime.now();
      _selectedDateRange =
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      await _fetchAndProcessEntries();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndProcessEntries() async {
    if (_selectedDateRange == null || _currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _allWorkEntries = await workEntryService.getWorkEntriesForUserBetweenDates(
        _currentUser!.uid!,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month,
            _selectedDateRange!.end.day + 1),
      );
      await _ensureProjectAndAreaNamesAvailable(_allWorkEntries);
      _applyFiltersAndGroup();
    } catch (e) {
      if (mounted) {
        setState(
                () => _errorMessage = "Błąd przetwarzania historii: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndGroup() {
    List<WorkEntry> tempFiltered = List.from(_allWorkEntries);

    if (_selectedFilterProject != null) {
      tempFiltered = tempFiltered
          .where((e) => e.projectId == _selectedFilterProject!.projectId)
          .toList();
    }
    if (_selectedFilterArea != null) {
      tempFiltered = tempFiltered
          .where((e) => e.areaId == _selectedFilterArea!.areaId)
          .toList();
    }

    _calculateSummaryDurations(tempFiltered);

    tempFiltered.sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

    _groupedSessionsForCurrentUser.clear();
    final groupedByProject = groupBy(tempFiltered, (entry) => entry.projectId);

    groupedByProject.forEach((projectId, entriesInProject) {
      final groupedByArea = groupBy(entriesInProject, (entry) => entry.areaId);
      final areaMap = <String, List<WorkSession>>{};

      groupedByArea.forEach((areaId, entriesInArea) {
        areaMap[areaId] = _pairEntriesIntoSessions(entriesInArea);
      });
      _groupedSessionsForCurrentUser[projectId] = areaMap;
    });

    final projectIdsInView = _groupedSessionsForCurrentUser.keys.toSet();
    if (projectIdsInView.isNotEmpty) {
      _loadProjectsForFilter(projectIdsInView.toList());
    }

    if (mounted) setState(() {});
  }

  List<WorkSession> _pairEntriesIntoSessions(List<WorkEntry> entries) {
    final List<WorkSession> sessions = [];
    WorkEntry? activeMainTaskStart;
    List<WorkEntry> eventsForCurrentSession = [];

    for (final entry in entries) {
      final isMainTask = !entry.workTypeIsBreak && !entry.workTypeIsSubTask;

      if (activeMainTaskStart == null) {
        if (entry.isStart && isMainTask) {
          activeMainTaskStart = entry;
          eventsForCurrentSession.add(entry);
        }
      } else {
        eventsForCurrentSession.add(entry);
        if (!entry.isStart && isMainTask && entry.workTypeId == activeMainTaskStart.workTypeId) {
          sessions.add(WorkSession(
            startEntry: activeMainTaskStart,
            endEntry: entry,
            allEventsInSession: List.from(eventsForCurrentSession),
          ));
          activeMainTaskStart = null;
          eventsForCurrentSession.clear();
        }
      }
    }

    if (activeMainTaskStart != null) {
      sessions.add(WorkSession(
        startEntry: activeMainTaskStart,
        allEventsInSession: List.from(eventsForCurrentSession),
      ));
    }

    sessions.sort((a, b) => b.startEntry.eventActionTimestamp.compareTo(a.startEntry.eventActionTimestamp));
    return sessions;
  }

  void _calculateSummaryDurations(List<WorkEntry> entries) {
    Map<String, WorkEntry> openSessions = {};
    List<MapEntry<WorkEntry, WorkEntry>> pairedSessions = [];

    final sortedEntries = List<WorkEntry>.from(entries);
    sortedEntries
        .sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

    for (var entry in sortedEntries) {
      String sessionKey =
          '${entry.userId}_${entry.projectId}_${entry.areaId}_${entry.workTypeId}';
      if (entry.isStart) {
        openSessions[sessionKey] = entry;
      } else {
        if (openSessions.containsKey(sessionKey)) {
          pairedSessions.add(MapEntry(openSessions.remove(sessionKey)!, entry));
        }
      }
    }

    Duration mainWork = Duration.zero;
    Duration breakTime = Duration.zero;
    Duration subtaskTime = Duration.zero;

    for (var session in pairedSessions) {
      final duration = session.value.eventActionTimestamp
          .toDate()
          .difference(session.key.eventActionTimestamp.toDate());
      if (session.key.workTypeIsBreak) {
        breakTime += duration;
      } else if (session.key.workTypeIsSubTask) {
        subtaskTime += duration;
      } else {
        mainWork += duration;
      }
    }

    if (mounted) {
      setState(() {
        _totalMainWorkDuration = mainWork;
        _totalBreakDuration = breakTime;
        _totalSubtaskDuration = subtaskTime;
      });
    }
  }

  String _formatDurationHHMMSS(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _ensureProjectAndAreaNamesAvailable(
      List<WorkEntry> entries) async {
    final Set<String> projectIds =
    entries.map((e) => e.projectId).where((id) => id.isNotEmpty).toSet();
    final Set<String> areaIds =
    entries.map((e) => e.areaId).where((id) => id.isNotEmpty).toSet();
    final List<String> missingProjectIds =
    projectIds.where((id) => !_projectNamesMap.containsKey(id)).toList();
    final List<String> missingAreaIds =
    areaIds.where((id) => !_areaNamesMap.containsKey(id)).toList();
    if (missingProjectIds.isNotEmpty) {
      final newProjects =
      await projectService.fetchProjectsByIds(missingProjectIds);
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

  Future<void> _loadProjectsForFilter(List<String> projectIds) async {
    try {
      _availableProjectsForFilter = await projectService.fetchProjectsByIds(projectIds);
      _availableProjectsForFilter = _availableProjectsForFilter.toSet().toList();
      _availableProjectsForFilter
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint("Błąd ładowania projektów do filtra: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      final allAreas = await areaService.getAreasByProject(projectId);
      if (mounted) {
        setState(() {
          _availableAreasForFilter = allAreas.toSet().toList();
          _availableAreasForFilter.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      }
    } catch (e) {
      debugPrint("Błąd ładowania obszarów do filtra: $e");
      if (mounted) setState(() => _availableAreasForFilter = []);
    }
  }

  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });

    if (project != null) {
      _loadAreasForFilter(project.projectId);
    }

    _applyFiltersAndGroup();
  }

  void _onAreaFilterChanged(Area? area) {
    setState(() {
      _selectedFilterArea = area;
    });
    _applyFiltersAndGroup();
  }

  void _setDateRangeAndFetch(DateTimeRange newRange) {
    setState(() => _selectedDateRange = newRange);
    _fetchAndProcessEntries();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('pl', 'PL'));
    if (picked != null && picked != _selectedDateRange) {
      _setDateRangeAndFetch(picked);
    }
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange =
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    _fetchAndProcessEntries();
  }

  DateTimeRange _getTodayRange() {
    final now = DateTime.now();
    return DateTimeRange(
        start: DateTime(now.year, now.month, now.day), end: now);
  }

  DateTimeRange _getThisWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
        start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        end: now);
  }

  DateTimeRange _getThisMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja Historia Akcji'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generuj Raport PDF',
            onPressed: _isLoading || _groupedSessionsForCurrentUser.isEmpty
                ? null
                : _generatePdf,
          )
        ],
      ),
      body: Column(
        children: [
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error))))
                : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilterPanel(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('filter_panel_user_history'),
        initiallyExpanded: _isFilterPanelExpanded,
        onExpansionChanged: (isExpanded) =>
            setState(() => _isFilterPanelExpanded = isExpanded),
        title: Text("Filtry i Podsumowanie",
            style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        leading:
        Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary),
        trailing:
        Icon(_isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more),
        children: [
          Padding(
              padding:
              const EdgeInsets.only(bottom: 16.0, left: 16, right: 16, top: 8),
              child: Column(
                children: [
                  _buildSummaryCard(theme),
                  _buildFilterSection(theme),
                ],
              ))
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Twoje Podsumowanie Czasu',
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 12),
      _buildSummaryRow(theme, Icons.work_outline, 'Praca:',
          _formatDurationHHMMSS(_totalMainWorkDuration)),
      _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Przerwy:',
          _formatDurationHHMMSS(_totalBreakDuration),
          color: Colors.orange.shade700),
      _buildSummaryRow(theme, Icons.low_priority_rounded, 'Podzadania:',
          _formatDurationHHMMSS(_totalSubtaskDuration),
          color: Colors.teal.shade600),
      const Divider(height: 24),
    ]);
  }

  Widget _buildSummaryRow(
      ThemeData theme, IconData icon, String label, String value,
      {Color? color}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Icon(icon,
              size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label ', style: theme.textTheme.bodyLarge),
          const Spacer(),
          Text(value,
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color ?? theme.colorScheme.primary)),
        ]));
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDatePresetButtons(theme),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_selectedDateRange != null
              ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
              : 'Wybierz zakres dat'),
          onPressed: () => _selectDateRange(context),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Project>(
          decoration: const InputDecoration(
              labelText: 'Projekt',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10)),
          value: _selectedFilterProject,
          hint: const Text('Wszystkie'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<Project>(
                value: null, child: Text('Wszystkie projekty')),
            ..._availableProjectsForFilter.map((p) =>
                DropdownMenuItem<Project>(
                    value: p,
                    child: Text(p.name, overflow: TextOverflow.ellipsis)))
          ],
          onChanged: _onProjectFilterChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Area>(
          decoration: InputDecoration(
            labelText: 'Obszar',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            filled: _selectedFilterProject == null,
            fillColor:
            _selectedFilterProject == null ? Colors.grey.shade200 : null,
          ),
          value: _selectedFilterArea,
          hint: const Text('Wszystkie'),
          isExpanded: true,
          onChanged:
          _selectedFilterProject == null ? null : _onAreaFilterChanged,
          items: [
            const DropdownMenuItem<Area>(
                value: null, child: Text('Wszystkie obszary')),
            ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(
                value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.clear_all_rounded),
          label: const Text('Wyczyść Filtry'),
          onPressed: _clearFilters,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 40),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePresetButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: [
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getTodayRange()),
              child: const Text('Dzisiaj')),
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getThisWeekRange()),
              child: const Text('Ten tydzień')),
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getThisMonthRange()),
              child: const Text('Ten miesiąc')),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    if (_groupedSessionsForCurrentUser.isEmpty && !_isLoading) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Brak sesji pracy do wyświetlenia w wybranym zakresie.',
                textAlign: TextAlign.center),
          ));
    }

    final projectIds = _groupedSessionsForCurrentUser.keys.toList();
    projectIds.sort((a, b) => (_projectNamesMap[a] ?? a)
        .toLowerCase()
        .compareTo((_projectNamesMap[b] ?? b).toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: projectIds.length,
      itemBuilder: (context, projectIndex) {
        final projectId = projectIds[projectIndex];
        final projectName = _projectNamesMap[projectId] ?? 'Projekt bez nazwy';
        final areasInProject = _groupedSessionsForCurrentUser[projectId]!;
        final areaIds = areasInProject.keys.toList();
        areaIds.sort((a, b) => (_areaNamesMap[a] ?? a)
            .toLowerCase()
            .compareTo((_areaNamesMap[b] ?? b).toLowerCase()));

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            key: PageStorageKey<String>(projectId),
            leading: Icon(Icons.folder_copy_outlined, color: theme.colorScheme.primary),
            title: Text(projectName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            children: areaIds.map((areaId) {
              final areaName = _areaNamesMap[areaId] ?? 'Obszar bez nazwy';
              final sessionsInArea = areasInProject[areaId]!;
              return _buildAreaSessionsList(areaName, sessionsInArea, theme);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAreaSessionsList(String areaName, List<WorkSession> sessions, ThemeData theme) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 16, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text("Obszar: $areaName", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...sessions.map((session) => _buildSessionCard(session, theme)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(WorkSession session, ThemeData theme) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.workTypeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  _formatDurationHHMMSS(session.duration),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (!session.isFinished)
                  const Chip(
                    label: Text('W TOKU'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Początek: ${_dateFormat.format(session.startEntry.eventActionTimestamp.toDate())} ${_timeFormat.format(session.startEntry.eventActionTimestamp.toDate())}'
                '${session.isFinished ? "\nKoniec:    ${_dateFormat.format(session.endEntry!.eventActionTimestamp.toDate())} ${_timeFormat.format(session.endEntry!.eventActionTimestamp.toDate())}" : ""}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ...session.allEventsInSession.map((event) => _buildWorkEntryRowWithInfo(event, theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkEntryRowWithInfo(WorkEntry entry, ThemeData theme) {
    final infos = entry.relatedInformations ?? [];

    IconData icon;
    Color color;
    String actionText = entry.isStart ? "Rozpoczęcie" : "Zakończenie";

    if (entry.workTypeIsBreak) {
      icon = entry.isStart
          ? Icons.free_breakfast_outlined
          : Icons.check_circle_outline;
      color = Colors.orange.shade700;
    } else if (entry.workTypeIsSubTask) {
      icon =
      entry.isStart ? Icons.low_priority_rounded : Icons.check_circle_outline;
      color = Colors.teal.shade600;
    } else {
      icon =
      entry.isStart ? Icons.play_circle_outline : Icons.stop_circle_outlined;
      color = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$actionText: ${entry.workTypeName}',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_dateFormat.format(entry.eventActionTimestamp.toDate())}  ${_timeFormat.format(entry.eventActionTimestamp.toDate())}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (infos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0, right: 4.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(color: theme.dividerColor, width: 2.0)),
                ),
                child: _buildInfoList(infos, theme),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoList(List<Information> infos, ThemeData theme) {
    if (infos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infos.map((info) {
        return Padding(
          padding: const EdgeInsets.only(left: 10.0, bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.content,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              if (info.decision != null)
                info.decision!
                    ? Text(
                  "Odpowiedź: TAK",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                )
                    : Text("Odpowiedź: NIE",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              if (info.textResponse != null)
                Text(
                  'Opis: ${info.textResponse!}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              Text(
                _formatUpdateTime(info.updatedAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatUpdateTime(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Brak daty aktualizacji';
    }
    return 'Aktualizacja: ${_dateFormat.format(timestamp.toDate())} ${_timeFormat.format(timestamp.toDate())}';
  }

  // --- Logika generowania PDF ---

  Future<void> _generatePdf() async {
    // Zmieniamy ścieżki na nowe pliki czcionek Roboto
    final regularFontData =
    await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData =
    await rootBundle.load("assets/fonts/Roboto-Bold.ttf");

    final ttfRegular = pw.Font.ttf(regularFontData.buffer.asByteData());
    final ttfBold = pw.Font.ttf(boldFontData.buffer.asByteData());

    final pdfTheme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);
    final pdf = pw.Document(theme: pdfTheme);

    final reportName = _currentUser?.displayName ?? 'Mój Raport';
    final dateRange = _selectedDateRange != null
        ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
        : 'Nie wybrano zakresu';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildPdfHeader(reportName, dateRange),
        footer: (context) => _buildPdfFooter(context),
        build: (context) {
          final List<pw.Widget> content = [];

          content.add(pw.Header(level: 1, text: 'Podsumowanie Czasu'));
          content.add(_buildPdfSummaryTable());
          content.add(pw.SizedBox(height: 20));

          content.add(pw.Header(level: 1, text: 'Szczegółowy Rejestr Sesji Pracy'));
          content.add(pw.Divider());

          final sortedProjectIds = _groupedSessionsForCurrentUser.keys.toList()
            ..sort((a, b) => (_projectNamesMap[a] ?? a)
                .toLowerCase()
                .compareTo((_projectNamesMap[b] ?? b).toLowerCase()));

          for (var projectId in sortedProjectIds) {
            final areas = _groupedSessionsForCurrentUser[projectId]!;
            final projectName = _projectNamesMap[projectId] ?? 'ID: $projectId';
            content.add(pw.Header(
              level: 2,
              text: 'Projekt: $projectName',
              textStyle: const pw.TextStyle(color: PdfColors.blueGrey800),
            ));

            final sortedAreaIds = areas.keys.toList()
              ..sort((a, b) => (_areaNamesMap[a] ?? a)
                  .toLowerCase()
                  .compareTo((_areaNamesMap[b] ?? b).toLowerCase()));

            for (var areaId in sortedAreaIds) {
              final sessions = areas[areaId]!;
              if (sessions.isEmpty) continue;

              final areaName = _areaNamesMap[areaId] ?? 'ID: $areaId';
              content.add(pw.Header(
                level: 3,
                text: 'Obszar: $areaName',
                textStyle: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ));

              content.add(pw.Column(
                  children: sessions
                      .map((session) => _buildPdfSessionBlock(session))
                      .toList()));
              content.add(pw.SizedBox(height: 10));
            }
            content.add(pw.Divider(height: 20));
          }

          return content;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'moj_raport_akcji_${reportName.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildPdfHeader(String reportName, String dateRange) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 1.5))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Raport Akcji i Informacji',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
        pw.SizedBox(height: 5),
        pw.Text('Dla: $reportName'),
        pw.Text('Okres: $dateRange'),
      ]),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Strona ${context.pageNumber} z ${context.pagesCount}',
          style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)),
    );
  }

  pw.Widget _buildPdfSummaryTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1)
      },
      children: [
        pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Typ Czasu',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('Suma',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
        pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Praca główna')),
          pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_formatDurationHHMMSS(_totalMainWorkDuration))),
        ]),
        pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Podzadania')),
          pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_formatDurationHHMMSS(_totalSubtaskDuration))),
        ]),
        pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(5), child: pw.Text('Przerwy')),
          pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_formatDurationHHMMSS(_totalBreakDuration))),
        ]),
      ],
    );
  }

  pw.Widget _buildPdfSessionBlock(WorkSession session) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(session.workTypeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 5),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Czas trwania: ${_formatDurationHHMMSS(session.duration)}'),
                    pw.Text(session.isFinished ? 'Zakończona' : 'W toku', style: pw.TextStyle(color: session.isFinished ? PdfColors.green700 : PdfColors.orange700)),
                  ]
              ),
              pw.SizedBox(height: 5),
              pw.Text('Początek: ${_dateFormat.format(session.startEntry.eventActionTimestamp.toDate())} ${_timeFormat.format(session.startEntry.eventActionTimestamp.toDate())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              if (session.isFinished)
                pw.Text('Koniec:    ${_dateFormat.format(session.endEntry!.eventActionTimestamp.toDate())} ${_timeFormat.format(session.endEntry!.eventActionTimestamp.toDate())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Divider(height: 10, color: PdfColors.grey400),
              pw.SizedBox(height: 5),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: session.allEventsInSession.map((entry) => _buildPdfWorkEntryRow(entry)).toList(),
              ),
            ]
        )
    );
  }

  pw.Widget _buildPdfWorkEntryRow(WorkEntry entry) {
    String actionText = entry.isStart ? "START" : "STOP";
    if (entry.workTypeIsBreak) actionText += " Przerwa";
    if (entry.workTypeIsSubTask) actionText += " Podzadanie";

    final infos = entry.relatedInformations ?? [];

    return pw.Container(
        padding: const pw.EdgeInsets.only(left: 10, bottom: 5, top: 5),
        decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.grey200, width: 2))
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('$actionText: ${entry.workTypeName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Text('${_timeFormat.format(entry.eventActionTimestamp.toDate())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ]
              ),
              if (infos.isNotEmpty)
                ...infos.map((info) {
                  final List<pw.Widget> infoWidgets = [
                    pw.Text(info.content, style: const pw.TextStyle(fontSize: 8)),
                  ];
                  if (info.decision != null) {
                    infoWidgets.add(pw.Text(info.decision! ? "Odp: TAK" : "Odp: NIE", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: info.decision! ? PdfColors.green700 : PdfColors.red700)));
                  }
                  if (info.textResponse != null) {
                    infoWidgets.add(pw.Text('Opis: ${info.textResponse}', style: const pw.TextStyle(fontSize: 8)));
                  }
                  return pw.Container(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: infoWidgets)
                  );
                }).toList()
            ]
        )
    );
  }
}