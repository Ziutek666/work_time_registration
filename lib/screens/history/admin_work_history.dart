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
import '../../widgets/dialogs.dart';


class AdminWorkHistoryScreen extends StatefulWidget {
  const AdminWorkHistoryScreen({super.key});

  @override
  State<AdminWorkHistoryScreen> createState() => _AdminWorkHistoryScreenState();
}

class _AdminWorkHistoryScreenState extends State<AdminWorkHistoryScreen> {

  // Stan UI
  bool _isLoading = true;
  bool _isCalculating = false;
  String? _errorMessage;
  UserApp? _currentUser;
  bool _isFilterPanelExpanded = true;

  // Dane
  List<WorkEntry> _allAdminWorkEntries = [];
  Map<String, Map<String, Map<String, List<WorkEntry>>>> _groupedFilteredEntries = {};

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;
  UserApp? _selectedFilterUser;

  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];
  List<UserApp> _availableUsersForFilter = [];

  // Mapy do przechowywania nazw dla ID
  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};
  Map<String, String> _userNamesMap = {};

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
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) throw Exception("Nie można zidentyfikować administratora.");

      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

      await _loadProjectsForFilter();
      await _loadAllUsersForFilter();
      await _fetchProcessAndSummarizeWorkEntries();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProjectsForFilter() async {
    if (_currentUser?.uid == null) return;
    try {
      _availableProjectsForFilter = await projectService.getProjectsByOwner(_currentUser!.uid!);
      _availableProjectsForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var p in _availableProjectsForFilter) {
        _projectNamesMap[p.projectId] = p.name;
      }
    } catch (e) {
      debugPrint("Błąd ładowania projektów administratora: $e");
    }
    if (mounted) setState(() {});
  }

  /// Pobiera wszystkich użytkowników ze wszystkich projektów administratora.
  Future<void> _loadAllUsersForFilter() async {
    if (_availableProjectsForFilter.isEmpty) {
      if (mounted) setState(() => _availableUsersForFilter = []);
      return;
    }
    try {
      final projectIds = _availableProjectsForFilter.map((p) => p.projectId).toList();
      final allMembers = await projectMemberService.getMembersForAllProjects(projectIds);
      final userIds = allMembers.map((m) => m.userId).toSet();
      if (userIds.isEmpty) {
        if (mounted) setState(() => _availableUsersForFilter = []);
        return;
      }
      final users = await userService.getUsersByIds(userIds.toList());
      users.sort((a, b) => (a.displayName ?? a.email ?? a.uid!).toLowerCase().compareTo((b.displayName ?? b.email ?? b.uid!).toLowerCase()));

      _userNamesMap = { for (var u in users) u.uid! : (u.displayName ?? u.email ?? u.uid!) };
      if (mounted) setState(() => _availableUsersForFilter = users);
    } catch (e) {
      debugPrint("Błąd ładowania wszystkich użytkowników do filtra: $e");
    }
  }

  /// Pobiera użytkowników tylko dla wybranego projektu.
  Future<void> _loadUsersForSingleProjectFilter(String projectId) async {
    try {
      final members = await projectMemberService.getMembersByProjectId(projectId);
      final userIds = members.map((m) => m.userId).toSet();
      if (userIds.isEmpty) {
        if (mounted) setState(() => _availableUsersForFilter = []);
        return;
      }
      final users = await userService.getUsersByIds(userIds.toList());
      users.sort((a, b) => (a.displayName ?? a.email ?? a.uid!).toLowerCase().compareTo((b.displayName ?? b.email ?? b.uid!).toLowerCase()));

      // Aktualizujemy tylko listę dostępnych, nie mapę globalną, która powinna zawierać wszystkich
      if (mounted) setState(() => _availableUsersForFilter = users);
    } catch (e) {
      debugPrint("Błąd ładowania użytkowników dla projektu $projectId: $e");
    }
  }


  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      _availableAreasForFilter = await areaService.getAreasByProject(projectId);
      _availableAreasForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var a in _availableAreasForFilter) { _areaNamesMap[a.areaId] = a.name; }
    } catch (e) {
      if (mounted) setState(() => _availableAreasForFilter = []);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchProcessAndSummarizeWorkEntries() async {
    if (_selectedDateRange == null || _availableProjectsForFilter.isEmpty) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() { _isLoading = true; _isCalculating = true; _errorMessage = null; });

    try {
      final projectIds = _availableProjectsForFilter.map((p) => p.projectId).toList();
      _allAdminWorkEntries = await workEntryService.getWorkEntriesForProjectsBetweenDates(
        projectIds,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day + 1),
      );

      await _ensureProjectAndAreaNamesAvailable(_allAdminWorkEntries);
      await _ensureUserNamesAvailable(_allAdminWorkEntries);
      _calculateIndividualStopDurations();
      _applyFiltersGroupAndSummarize();

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd przetwarzania historii pracy: ${e.toString()}");
    } finally {
      if (mounted) setState(() { _isLoading = false; _isCalculating = false; });
    }
  }

  void _calculateIndividualStopDurations() {
    _entryStopDurations.clear();
    List<WorkEntry> sortedEntries = List.from(_allAdminWorkEntries);
    sortedEntries.sort((a, b) {
      int comp = a.userId.compareTo(b.userId); if (comp != 0) return comp;
      comp = a.projectId.compareTo(b.projectId); if (comp != 0) return comp;
      comp = a.areaId.compareTo(b.areaId); if (comp != 0) return comp;
      comp = a.workTypeId.compareTo(b.workTypeId); if (comp != 0) return comp;
      return a.eventActionTimestamp.compareTo(b.eventActionTimestamp);
    });
    Map<String, WorkEntry> openSessions = {};
    for (var entry in sortedEntries) {
      String sessionKey = '${entry.userId}_${entry.projectId}_${entry.areaId}_${entry.workTypeId}';
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

  void _applyFiltersGroupAndSummarize() {
    List<WorkEntry> tempFiltered = List.from(_allAdminWorkEntries);

    if (_selectedFilterProject != null) tempFiltered.removeWhere((e) => e.projectId != _selectedFilterProject!.projectId);
    if (_selectedFilterArea != null) tempFiltered.removeWhere((e) => e.areaId != _selectedFilterArea!.areaId);
    if (_selectedFilterUser != null) tempFiltered.removeWhere((e) => e.userId != _selectedFilterUser!.uid);

    _totalMainWorkDuration = Duration.zero; _totalBreakDuration = Duration.zero; _totalSubtaskDuration = Duration.zero;
    for (var entry in tempFiltered) {
      if (!entry.isStart && _entryStopDurations.containsKey(entry.entryId)) {
        Duration duration = _entryStopDurations[entry.entryId]!;
        if (entry.workTypeIsBreak) _totalBreakDuration += duration;
        else if (entry.workTypeIsSubTask) _totalSubtaskDuration += duration;
        else _totalMainWorkDuration += duration;
      }
    }

    tempFiltered.sort((a, b) => b.eventActionTimestamp.compareTo(a.eventActionTimestamp));
    final groupedByUser = groupBy(tempFiltered, (WorkEntry entry) => entry.userId);
    _groupedFilteredEntries.clear();
    groupedByUser.forEach((userId, entriesForUser) {
      final groupedByProject = groupBy(entriesForUser, (WorkEntry entry) => entry.projectId);
      _groupedFilteredEntries[userId] = {};
      groupedByProject.forEach((projectId, entriesInProject) {
        final groupedByArea = groupBy(entriesInProject, (WorkEntry entry) => entry.areaId);
        _groupedFilteredEntries[userId]![projectId] = groupedByArea;
      });
    });

    if(mounted) setState(() {});
  }

  Future<void> _ensureProjectAndAreaNamesAvailable(List<WorkEntry> entries) async {
    final Set<String> pIds = entries.map((e) => e.projectId).toSet();
    final Set<String> aIds = entries.map((e) => e.areaId).toSet();
    final List<String> mPIds = pIds.where((id) => id.isNotEmpty && !_projectNamesMap.containsKey(id)).toList();
    final List<String> mAIds = aIds.where((id) => id.isNotEmpty && !_areaNamesMap.containsKey(id)).toList();
    if (mPIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(mPIds);
      for (var p in newProjects) _projectNamesMap[p.projectId] = p.name;
    }
    if (mAIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(mAIds);
      for (var a in newAreas) _areaNamesMap[a.areaId] = a.name;
    }
  }

  Future<void> _ensureUserNamesAvailable(List<WorkEntry> entries) async {
    final Set<String> uIds = entries.map((e) => e.userId).toSet();
    final List<String> mUIds = uIds.where((id) => id.isNotEmpty && !_userNamesMap.containsKey(id)).toList();
    if(mUIds.isNotEmpty) {
      final newUsers = await userService.getUsersByIds(mUIds);
      for(var u in newUsers) {
        _userNamesMap[u.uid!] = u.displayName ?? u.email ?? u.uid!;
      }
    }
  }


  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('pl', 'PL'));
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      await _fetchProcessAndSummarizeWorkEntries();
    }
  }

  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _selectedFilterUser = null;
      _availableAreasForFilter = [];
    });

    if (project != null) {
      Future.wait([
        _loadAreasForFilter(project.projectId),
        _loadUsersForSingleProjectFilter(project.projectId), // ZMIANA: ładuj użytkowników dla wybranego projektu
      ]).then((_) => _applyFiltersGroupAndSummarize());
    } else {
      // Jeśli wybrano "Wszystkie projekty", załaduj wszystkich użytkowników i zastosuj filtry
      _loadAllUsersForFilter().then((_) => _applyFiltersGroupAndSummarize());
    }
  }

  void _onAreaFilterChanged(Area? area) {
    setState(() => _selectedFilterArea = area);
    _applyFiltersGroupAndSummarize();
  }

  void _onUserFilterChanged(UserApp? user) {
    setState(() => _selectedFilterUser = user);
    _applyFiltersGroupAndSummarize();
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _selectedFilterUser = null;
      _availableAreasForFilter = [];
    });
    _fetchProcessAndSummarizeWorkEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historia Pracy (Admin)')),
      body: Column(
        children: [
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isCalculating
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Przeliczanie danych...")]))
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _groupedFilteredEntries.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Brak wpisów spełniających kryteria.', textAlign: TextAlign.center)))
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
        key: const PageStorageKey<String>('filter_panel'),
        initiallyExpanded: _isFilterPanelExpanded,
        onExpansionChanged: (isExpanded) {
          setState(() => _isFilterPanelExpanded = isExpanded);
        },
        title: Text("Filtry i Podsumowanie", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        leading: Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary),
        trailing: Icon(_isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more),
        children: [ Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Column(children: [_buildSummaryCard(theme), _buildFilterSection(theme)])) ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(theme, Icons.work_outline, 'Czas pracy (główne):', _formatDuration(_totalMainWorkDuration)),
          _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Czas przerw:', _formatDuration(_totalBreakDuration), color: Colors.orange.shade700),
          _buildSummaryRow(theme, Icons.low_priority_rounded, 'Czas podzadań:', _formatDuration(_totalSubtaskDuration), color: Colors.teal.shade600),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_selectedDateRange != null ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}' : 'Wybierz zakres dat'),
            onPressed: () => _selectDateRange(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserApp>(
            decoration: const InputDecoration(labelText: 'Pracownik', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
            value: _selectedFilterUser,
            hint: const Text('Wszyscy pracownicy'),
            isExpanded: true,
            items: [
              const DropdownMenuItem<UserApp>(value: null, child: Text('Wszyscy pracownicy')),
              ..._availableUsersForFilter.map((u) => DropdownMenuItem<UserApp>(value: u, child: Text(u.displayName ?? u.email ?? u.uid!, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: _onUserFilterChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: DropdownButtonFormField<Project>(decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder()), value: _selectedFilterProject, hint: const Text('Wszystkie'), isExpanded: true, items: [ const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie')), ..._availableProjectsForFilter.map((p) => DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))], onChanged: _onProjectFilterChanged)),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<Area>(decoration: const InputDecoration(labelText: 'Obszar', border: OutlineInputBorder()), value: _selectedFilterArea, hint: const Text('Wszystkie'), isExpanded: true, disabledHint: _selectedFilterProject == null ? const Text('Wybierz projekt') : null, items: _selectedFilterProject == null ? [] : [ const DropdownMenuItem<Area>(value: null, child: Text('Wszystkie')), ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))], onChanged: _selectedFilterProject != null ? _onAreaFilterChanged : null)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(icon: const Icon(Icons.clear_all_rounded), label: const Text('Wyczyść Filtry'), onPressed: _clearFilters, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), backgroundColor: theme.colorScheme.secondaryContainer, foregroundColor: theme.colorScheme.onSecondaryContainer)),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    final userIds = _groupedFilteredEntries.keys.toList();
    userIds.sort((a,b) => (_userNamesMap[a] ?? a).toLowerCase().compareTo((_userNamesMap[b] ?? b).toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: userIds.length,
      itemBuilder: (context, userIndex) {
        final userId = userIds[userIndex];
        final userName = _userNamesMap[userId] ?? userId;
        final projectsForUser = _groupedFilteredEntries[userId]!;
        final projectIds = projectsForUser.keys.toList()..sort((a,b) => (_projectNamesMap[a] ?? a).toLowerCase().compareTo((_projectNamesMap[b] ?? b).toLowerCase()));

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            key: PageStorageKey<String>(userId),
            leading: Icon(Icons.person_pin_circle_outlined, color: theme.colorScheme.primary, size: 32),
            title: Text(userName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text("ID: $userId", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            children: projectIds.map((projectId) {
              final projectName = _projectNamesMap[projectId] ?? 'Nieznany Projekt';
              final areasInProject = projectsForUser[projectId]!;
              final areaIds = areasInProject.keys.toList()..sort((a,b) => (_areaNamesMap[a] ?? a).toLowerCase().compareTo((_areaNamesMap[b] ?? b).toLowerCase()));

              return ExpansionTile(
                key: PageStorageKey<String>('$userId-$projectId'),
                leading: Padding(padding: const EdgeInsets.only(left: 16.0), child: Icon(Icons.folder_copy_outlined, color: theme.colorScheme.secondary, size: 24)),
                title: Text(projectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                children: areaIds.map((areaId) {
                  final areaName = _areaNamesMap[areaId] ?? 'Nieznany Obszar';
                  final entriesInArea = areasInProject[areaId]!;

                  return ExpansionTile(
                    key: PageStorageKey<String>('$userId-$projectId-$areaId'),
                    leading: Padding(padding: const EdgeInsets.only(left: 32.0), child: Icon(Icons.explore_outlined, size: 20)),
                    title: Text(areaName, style: theme.textTheme.titleSmall),
                    children: entriesInArea.map((entry) => _buildWorkEntryItem(entry, theme)).toList(),
                  );
                }).toList(),
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
      elevation: 1, margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
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

}