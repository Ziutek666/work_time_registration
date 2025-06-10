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
import '../../services/project_member_service.dart';
import '../../services/work_entry_service.dart';
import '../../services/project_service.dart';
import '../../services/area_service.dart';
import '../../services/user_service.dart';

// Helper classes - bez zmian
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
  _CompoundWorkSession({required this.mainTask, this.breaks = const [], this.subtasks = const []});
}

class AdminWorkHistoryScreen extends StatefulWidget {
  const AdminWorkHistoryScreen({super.key});

  @override
  State<AdminWorkHistoryScreen> createState() => _AdminWorkHistoryScreenState();
}

class _AdminWorkHistoryScreenState extends State<AdminWorkHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFilterPanelExpanded = true;
  UserApp? _currentUser;
  List<Area> _availableAreas = []; // <-- NOWA ZMIENNA

  // ZMIANA: Główna struktura danych. Teraz jest to mapa Pracownik -> Projekt -> Obszar -> Sesje
  Map<String, Map<String, Map<String, List<_CompoundWorkSession>>>> _groupedSessionsByEmployee = {};

  // ZMIANA: Ta lista przechowuje WSZYSTKIE wpisy dla WSZYSTKICH pracowników w zadanym okresie
  List<WorkEntry> _allWorkEntries = [];

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;

  // ZMIANA: _selectedUser służy teraz tylko do filtrowania widoku, a nie do pobierania danych.
  // null oznacza "Wszyscy pracownicy".
  UserApp? _selectedUser;
  List<UserApp> _availableUsers = [];

  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];

  // NOWOŚĆ: Mapy do przechowywania nazw dla szybkiego dostępu
  Map<String, String> _userNamesMap = {};
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

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _loadAllUsers();
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      // Od razu po inicjalizacji ładujemy dane dla wszystkich
      await _fetchAndProcessWorkEntries();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
// Dodaj tę nową metodę w klasie State
  Future<void> _loadAreasForProject(String projectId) async {
    try {
      final areas = await areaService.getAreasByProject(projectId);
      if (mounted) {
        setState(() {
          _availableAreas = areas..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      }
    } catch (e) {
      // Obsługa błędów, np. wyświetlenie SnackBar'a
      debugPrint("Błąd ładowania obszarów: $e");
      if (mounted) {
        setState(() {
          _availableAreas = [];
        });
      }
    }
  }
  Future<void> _loadAllUsers() async {
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) throw Exception("Nie można zidentyfikować administratora.");

      final allProjects = await projectService.getProjectsByOwner(_currentUser?.uid ?? '');
      if (allProjects.isEmpty) {
        setState(() => _availableUsers = []);
        return;
      }
      final allProjectIds = allProjects.map((p) => p.projectId).toList();
      final allMembers = await projectMemberService.getMembersForAllProjects(allProjectIds);
      final uniqueUserIds = allMembers.map((member) => member.userId).toSet().toList();

      if (uniqueUserIds.isEmpty) {
        setState(() => _availableUsers = []);
        return;
      }

      _availableUsers = await userService.getUsersByIds(uniqueUserIds);
      _availableUsers.sort((a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));

      // NOWOŚĆ: Zapełniamy mapę nazw użytkowników
      _userNamesMap = {for (var user in _availableUsers) user.uid!: user.displayName ?? 'Użytkownik bez nazwy'};

    } catch (e) {
      debugPrint("Błąd dynamicznego ładowania użytkowników: $e");
      if (mounted) setState(() => _availableUsers = []);
    }
  }

  // ZMIANA: Ta funkcja jest teraz wywoływana, gdy zmienia się zakres dat.
  // Pobiera wpisy dla WSZYSTKICH użytkowników.
  Future<void> _fetchAndProcessWorkEntries() async {
    if (_selectedDateRange == null || _availableUsers.isEmpty) {
      setState(() {
        _allWorkEntries = [];
        _groupedSessionsByEmployee = {};
      });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Pobieramy wpisy dla wszystkich użytkowników równolegle
      final List<Future<List<WorkEntry>>> futures = _availableUsers.map((user) {
        return workEntryService.getWorkEntriesForUserBetweenDates(
          user.uid!,
          _selectedDateRange!.start,
          DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day + 1),
        );
      }).toList();

      final List<List<WorkEntry>> results = await Future.wait(futures);
      _allWorkEntries = results.expand((list) => list).toList(); // Spłaszczamy listę list

      await _ensureProjectAndAreaNamesAvailable(_allWorkEntries);
      _applyFiltersAndGroup();

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd przetwarzania historii pracy: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ZMIANA: Ta funkcja jest teraz sercem logiki grupowania
  void _applyFiltersAndGroup() {
    List<WorkEntry> tempFiltered = List.from(_allWorkEntries);

    // ZMIANA: Filtr pracownika działa na już pobranych danych
    if (_selectedUser != null) {
      tempFiltered = tempFiltered.where((entry) => entry.userId == _selectedUser!.uid).toList();
    }
    if (_selectedFilterProject != null) {
      tempFiltered = tempFiltered.where((entry) => entry.projectId == _selectedFilterProject!.projectId).toList();
    }
    if (_selectedFilterArea != null) {
      tempFiltered = tempFiltered.where((entry) => entry.areaId == _selectedFilterArea!.areaId).toList();
    }

    // Logika parowania sesji (start-stop) - bez zmian
    Map<String, WorkEntry> openSessions = {};
    List<_WorkSession> allSessions = [];
    tempFiltered.sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));
    for (var entry in tempFiltered) {
      // Klucz sesji musi teraz zawierać ID użytkownika, aby sesje się nie mieszały
      String sessionKey = '${entry.userId}_${entry.projectId}_${entry.areaId}_${entry.workTypeId}';
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

    // Logika tworzenia sesji złożonych (main + przerwy + podzadania) - bez zmian
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

    // Obliczanie podsumowań na podstawie przefiltrowanych danych
    _totalMainWorkDuration = mainTasks.fold(Duration.zero, (prev, s) => prev + s.duration);
    _totalBreakDuration = breaks.fold(Duration.zero, (prev, s) => prev + s.duration);
    _totalSubtaskDuration = subtasks.fold(Duration.zero, (prev, s) => prev + s.duration);

    // NOWOŚĆ: Trójpoziomowe grupowanie
    _groupedSessionsByEmployee.clear();
    final groupedByEmployee = groupBy(compoundSessions, (s) => s.mainTask.startEntry.userId);

    groupedByEmployee.forEach((userId, sessionsForEmployee) {
      final groupedByProject = groupBy(sessionsForEmployee, (s) => s.mainTask.startEntry.projectId);
      final projectMap = <String, Map<String, List<_CompoundWorkSession>>>{};

      groupedByProject.forEach((projectId, sessionsInProject) {
        final groupedByArea = groupBy(sessionsInProject, (s) => s.mainTask.startEntry.areaId);
        projectMap[projectId] = groupedByArea;
      });

      _groupedSessionsByEmployee[userId] = projectMap;
    });

    final projectIdsInView = _groupedSessionsByEmployee.values
        .expand((e) => e.keys)
        .toSet();
    if (projectIdsInView.isNotEmpty) _loadProjectsForFilter();

    if (mounted) setState(() {});
  }

  // ZMIANA: Handler zmiany użytkownika w filtrze.
  // Nie pobiera danych na nowo, tylko filtruje istniejące.
  void _onUserChanged(UserApp? user) {
    setState(() {
      _selectedUser = user;
    });
    // Zastosuj filtry na nowo, aby przeliczyć sumy i widok
    _applyFiltersAndGroup();
  }

  // Funkcje pomocnicze, które nie uległy większym zmianom

  Future<void> _ensureProjectAndAreaNamesAvailable(List<WorkEntry> entries) async {
    final Set<String> projectIds = entries.map((e) => e.projectId).where((id) => id.isNotEmpty).toSet();
    final Set<String> areaIds = entries.map((e) => e.areaId).where((id) => id.isNotEmpty).toSet();
    final List<String> missingProjectIds = projectIds.where((id) => !_projectNamesMap.containsKey(id)).toList();
    final List<String> missingAreaIds = areaIds.where((id) => !_areaNamesMap.containsKey(id)).toList();
    if (missingProjectIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(missingProjectIds);
      for (var p in newProjects) _projectNamesMap[p.projectId] = p.name;
    }
    if (missingAreaIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(missingAreaIds);
      for (var a in newAreas) _areaNamesMap[a.areaId] = a.name;
    }
  }

  Future<void> _loadProjectsForFilter() async {
    // ... bez zmian
    if (_currentUser?.uid == null) return;
    try {
      final memberships =
      await projectMemberService.getProjectsForUser(_currentUser!.uid!);
      final projectIds = memberships.map((m) => m.projectId).toSet().toList();
      if (projectIds.isNotEmpty) {
        _availableProjectsForFilter =
        await projectService.fetchProjectsByIds(projectIds);
        _availableProjectsForFilter.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  String _formatDurationHHMMSS(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _setDateRangeAndFetch(DateTimeRange newRange) {
    setState(() => _selectedDateRange = newRange);
    _fetchAndProcessWorkEntries();
  }

  // ... (reszta funkcji pomocniczych, które nie wymagają zmian: _getTodayRange, _getThisWeekRange, _getThisMonthRange, _selectDateRange)
  DateTimeRange _getTodayRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: startOfDay, end: startOfDay);
  }

  DateTimeRange _getThisWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _getThisMonthRange() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    return DateTimeRange(start: startOfMonth, end: endOfMonth);
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


  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    if (project != null) {
      // Jeśli wybrano nowy projekt, ładujemy jego obszary
      _loadAreasForProject(project.projectId);
    }
    _applyFiltersAndGroup();
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
      _selectedUser = null;
    });
    // Pobieramy dane na nowo dla wyczyszczonego zakresu dat i stosujemy filtry (teraz widok "wszystkich")
    _fetchAndProcessWorkEntries();
  }
// Dodaj też metodę obsługującą zmianę obszaru
  void _onAreaChanged(Area? area) {
    setState(() {
      _selectedFilterArea = area;
    });
    // Po każdej zmianie odświeżamy dane
    _applyFiltersAndGroup();
  }
  // Budowanie UI
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Pracy Pracowników'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generuj Kartę Pracy PDF',
            onPressed: _isLoading || _groupedSessionsByEmployee.isEmpty ? null : _generatePdf,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _groupedSessionsByEmployee.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Brak zarejestrowanych sesji pracy w wybranym okresie.', textAlign: TextAlign.center)))
                : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ZMIANA: Dropdown ma teraz opcję "Wszyscy pracownicy"
      DropdownButtonFormField<UserApp>(
        decoration: const InputDecoration(
            labelText: 'Pracownik',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10)),
        value: _selectedUser,
        hint: const Text('Wszyscy pracownicy'),
        isExpanded: true,
        items: [
          // Dodajemy ręcznie pozycję "Wszyscy"
          const DropdownMenuItem<UserApp>(
            value: null,
            child: Text('Wszyscy pracownicy'),
          ),
          ..._availableUsers.map((u) => DropdownMenuItem<UserApp>(
              value: u,
              child: Text(u.displayName ?? 'Użytkownik bez nazwy',
                  overflow: TextOverflow.ellipsis)))
        ],
        onChanged: _onUserChanged,
      ),
      const SizedBox(height: 12),
      _buildDatePresetButtons(theme),
      OutlinedButton.icon(
        icon: const Icon(Icons.date_range),
        label: Text(_selectedDateRange != null
            ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
            : 'Wybierz zakres dat'),
        onPressed: () => _selectDateRange(context),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<Project>(
                decoration: const InputDecoration(
                    labelText: 'Projekt',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                value: _selectedFilterProject,
                hint: const Text('Wszystkie'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie projekty')),
                  ..._availableProjectsForFilter.map((p) =>
                      DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: _onProjectFilterChanged)),
      ]),
      const SizedBox(height: 12), // Odstęp

// V-- NOWY WIDGET: DROPDOWN DLA OBSZARU --V
      DropdownButtonFormField<Area>(
        value: _selectedFilterArea,
        hint: const Text('Wybierz obszar'),
        isExpanded: true,
        // Sprawdzamy, czy projekt jest wybrany. Jeśli nie, dropdown jest nieaktywny.
        onChanged: _selectedFilterProject == null ? null : _onAreaChanged,
        decoration: InputDecoration(
          labelText: 'Obszar',
          border: const OutlineInputBorder(),
          // Dodajemy szare tło, gdy jest nieaktywny, dla lepszego UX
          filled: _selectedFilterProject == null,
          fillColor: _selectedFilterProject == null ? Colors.grey.shade200 : null,
        ),
        items: _availableAreas.map((area) {
          // Używamy Equatable, więc to jest teraz bezpieczne!
          return DropdownMenuItem<Area>(
            value: area,
            child: Text(area.name, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
          icon: const Icon(Icons.clear_all_rounded),
          label: const Text('Wyczyść Filtry'),
          onPressed: _clearFilters,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer)),
    ]);
  }

  // NOWOŚĆ: Przebudowana lista, która dodaje poziom Pracownika
  Widget _buildHistoryList(ThemeData theme) {
    final userIds = _groupedSessionsByEmployee.keys.toList();
    // Sortujemy po nazwie użytkownika
    userIds.sort((a, b) => (_userNamesMap[a] ?? a).toLowerCase().compareTo((_userNamesMap[b] ?? b).toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: userIds.length,
      itemBuilder: (context, userIndex) {
        final userId = userIds[userIndex];
        final userName = _userNamesMap[userId] ?? 'Pracownik bez nazwy';
        final projectsForUser = _groupedSessionsByEmployee[userId]!;

        final projectIds = projectsForUser.keys.toList();
        projectIds.sort((a, b) => (_projectNamesMap[a] ?? a).toLowerCase().compareTo((_projectNamesMap[b] ?? b).toLowerCase()));

        // NOWY Poziom: ExpansionTile dla Pracownika
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            key: PageStorageKey<String>(userId),
            leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
            title: Text(userName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            children: projectIds.map((projectId) {
              final projectName = _projectNamesMap[projectId] ?? 'Projekt bez nazwy';
              final areasInProject = projectsForUser[projectId]!;
              final areaIds = areasInProject.keys.toList();
              areaIds.sort((a, b) => (_areaNamesMap[a] ?? a).toLowerCase().compareTo((_areaNamesMap[b] ?? b).toLowerCase()));

              // Istniejący poziom: ExpansionTile dla Projektu
              return ExpansionTile(
                key: PageStorageKey<String>('$userId-$projectId'),
                leading: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Icon(Icons.folder_copy_outlined, color: theme.colorScheme.secondary)
                ),
                title: Text(projectName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                children: areaIds.map((areaId) {
                  final areaName = _areaNamesMap[areaId] ?? 'Obszar bez nazwy';
                  final sessionsInArea = areasInProject[areaId]!;

                  // Istniejący poziom: ExpansionTile dla Obszaru
                  return ExpansionTile(
                    key: PageStorageKey<String>('$userId-$projectId-$areaId'),
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Icon(Icons.explore_outlined, color: theme.colorScheme.tertiary),
                    ),
                    title: Text(areaName, style: theme.textTheme.titleMedium),
                    children: sessionsInArea.map((session) => _buildCompoundSessionCard(session, theme)).toList(),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Reszta funkcji budujących UI (panele, karty, podsumowania) pozostaje w większości bez zmian,
  // ponieważ operują na tych samych strukturach (_CompoundWorkSession, itp.)
  // Poniżej wklejam je dla kompletności.

  Widget _buildDatePresetButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Wrap(
        spacing: 8.0, runSpacing: 4.0, alignment: WrapAlignment.center,
        children: [
          TextButton(onPressed: () => _setDateRangeAndFetch(_getTodayRange()), child: const Text('Dzisiaj')),
          TextButton(onPressed: () => _setDateRangeAndFetch(_getThisWeekRange()), child: const Text('Ten tydzień')),
          TextButton(onPressed: () => _setDateRangeAndFetch(_getThisMonthRange()), child: const Text('Ten miesiąc')),
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
            key: const PageStorageKey<String>('filter_panel_admin'),
            initiallyExpanded: _isFilterPanelExpanded,
            onExpansionChanged: (isExpanded) => setState(() => _isFilterPanelExpanded = isExpanded),
            title: Text("Filtry i Podsumowanie", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            leading: Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary),
            trailing: Icon(_isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more),
            children: [
              const SizedBox(height: 8.0,),
              Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
                  child: Column(children: [
                    _buildSummaryCard(theme),
                    _buildFilterSection(theme)
                  ]))
            ]));
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Podsumowanie Czasu Pracy (${_selectedUser?.displayName ?? "Wszyscy"})',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 12),
      _buildSummaryRow(theme, Icons.work_outline, 'Praca:', _formatDurationHHMMSS(_totalMainWorkDuration)),
      _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Przerwy:', _formatDurationHHMMSS(_totalBreakDuration), color: Colors.orange.shade700),
      _buildSummaryRow(theme, Icons.low_priority_rounded, 'Podzadania:', _formatDurationHHMMSS(_totalSubtaskDuration), color: Colors.teal.shade600),
      const Divider(height: 24),
    ]);
  }

  Widget _buildSummaryRow(ThemeData theme, IconData icon, String label, String value, {Color? color}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label ', style: theme.textTheme.bodyLarge),
          const Spacer(),
          Text(value,
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color ?? theme.colorScheme.primary)),
        ]));
  }

  Widget _buildCompoundSessionCard(_CompoundWorkSession session, ThemeData theme) {
    final mainTask = session.mainTask;
    final startTime = mainTask.startEntry.eventActionTimestamp.toDate();
    final endTime = mainTask.endEntry.eventActionTimestamp.toDate();
    final timeFormat = DateFormat('HH:mm:ss');
    return Card(
      elevation: 2,
      // Modyfikacja marginesu aby pasował do nowego zagnieżdżenia
      margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.work_outline, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(mainTask.startEntry.workTypeName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              Text(_formatDurationHHMMSS(mainTask.duration),
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ]),
            const Divider(height: 16),
            Padding(
                padding: const EdgeInsets.only(left: 36.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${DateFormat('d MMM yy', 'pl_PL').format(startTime)}   |   ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  if (mainTask.startEntry.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text(mainTask.startEntry.description ?? '',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _buildNestedItem(ThemeData theme, _WorkSession session, {required bool isBreak}) {
    final icon = isBreak ? Icons.free_breakfast_outlined : Icons.low_priority_rounded;
    final color = isBreak ? Colors.orange.shade700 : Colors.teal.shade600;
    final timeFormat = DateFormat('HH:mm:ss');
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
                _formatDurationHHMMSS(session.duration),
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

  // ZMIANA: Logika PDF musi być dostosowana do nowego widoku
  Future<void> _generatePdf() async {
    // ... implementacja PDF pozostaje bardzo podobna, ale musi iterować po nowej strukturze danych.
    // Dla uproszczenia, poniższa implementacja generuje raport na podstawie aktualnych filtrów
    // (albo dla wszystkich, albo dla wybranego pracownika).

    // Zmieniamy ścieżki na nowe pliki czcionek Roboto
    final regularFontData =
    await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData =
    await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttfRegular = pw.Font.ttf(regularFontData.buffer.asByteData());
    final ttfBold = pw.Font.ttf(boldFontData.buffer.asByteData());
    final pdf = pw.Document();

    final reportName = _selectedUser?.displayName ?? 'Wszyscy Pracownicy';
    final dateRange = _selectedDateRange != null
        ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
        : 'Nie wybrano zakresu';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(reportName, dateRange, ttfRegular, ttfBold),
        footer: (context) => _buildFooter(context, ttfRegular),
        build: (context) {
          final List<pw.Widget> content = [];
          content.add(_buildSummaryTable(ttfRegular, ttfBold));
          content.add(pw.SizedBox(height: 20));
          content.add(pw.Text('Szczegółowy Rejestr Pracy', style: pw.TextStyle(font: ttfBold, fontSize: 18)));
          content.add(pw.Divider(thickness: 2, color: PdfColors.black));
          content.add(pw.SizedBox(height: 10));

          // NOWOŚĆ: Iteracja po pracownikach w PDF
          _groupedSessionsByEmployee.forEach((userId, projects) {
            final userName = _userNamesMap[userId] ?? 'ID: $userId';
            content.add(pw.Header(
              level: 1,
              text: 'Pracownik: $userName',
              textStyle: pw.TextStyle(font: ttfBold, fontSize: 16, color: PdfColors.blueGrey800),
            ));

            projects.forEach((projectId, areas) {
              final projectName = _projectNamesMap[projectId] ?? 'ID: $projectId';
              content.add(pw.Header(
                level: 2,
                text: 'Projekt: $projectName',
                textStyle: pw.TextStyle(font: ttfBold, fontSize: 14),
              ));

              areas.forEach((areaId, sessions) {
                final areaName = _areaNamesMap[areaId] ?? 'ID: $areaId';
                content.add(pw.Header(
                  level: 3,
                  text: 'Obszar: $areaName',
                  textStyle: pw.TextStyle(font: ttfRegular, fontSize: 12, fontStyle: pw.FontStyle.italic),
                ));

                for (final session in sessions) {
                  content.add(_buildSessionBlock(session, ttfRegular, ttfBold));
                  content.add(pw.SizedBox(height: 10));
                }
              });
              content.add(pw.SizedBox(height: 15));
            });
          });

          return content;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'karta_pracy_${reportName.replaceAll(' ', '_')}.pdf',
    );
  }

  // Funkcje pomocnicze do PDF - bez większych zmian, tylko pobierają nazwy z map
  pw.Widget _buildHeader(String reportName, String dateRange, pw.Font regularFont, pw.Font boldFont) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 1.5))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Raport Czasu Pracy', style: pw.TextStyle(font: boldFont, fontSize: 24)),
        pw.SizedBox(height: 5),
        pw.Text('Dla: $reportName', style: pw.TextStyle(font: regularFont, fontSize: 12)),
        pw.Text('Okres: $dateRange', style: pw.TextStyle(font: regularFont, fontSize: 12)),
      ]),
    );
  }

  pw.Widget _buildSummaryTable(pw.Font regularFont, pw.Font boldFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      children: [
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Typ Czasu', style: pw.TextStyle(font: boldFont))),
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Suma', style: pw.TextStyle(font: boldFont))),
        ]),
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Praca główna', style: pw.TextStyle(font: regularFont))),
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_formatDurationHHMMSS(_totalMainWorkDuration), style: pw.TextStyle(font: regularFont))),
        ]),
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Podzadania', style: pw.TextStyle(font: regularFont))),
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_formatDurationHHMMSS(_totalSubtaskDuration), style: pw.TextStyle(font: regularFont))),
        ]),
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Przerwy', style: pw.TextStyle(font: regularFont))),
          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_formatDurationHHMMSS(_totalBreakDuration), style: pw.TextStyle(font: regularFont))),
        ]),
      ],
    );
  }

  pw.Widget _buildSessionBlock(_CompoundWorkSession session, pw.Font regularFont, pw.Font boldFont) {
    final mainTask = session.mainTask;
    final startTime = mainTask.startEntry.eventActionTimestamp.toDate();
    final endTime = mainTask.endEntry.eventActionTimestamp.toDate();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${mainTask.startEntry.workTypeName}', style: pw.TextStyle(font: boldFont, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text('${_dateFormat.format(startTime)}, ${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
                  style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.Text(_formatDurationHHMMSS(mainTask.duration),
                style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blueGrey800)),
          ]),
        ),
        if (session.subtasks.isNotEmpty || session.breaks.isNotEmpty) pw.SizedBox(height: 5),
        if (session.subtasks.isNotEmpty)
          _buildNestedTable(session.subtasks, regularFont, boldFont, 'Podzadania'),
        if (session.breaks.isNotEmpty)
          _buildNestedTable(session.breaks, regularFont, boldFont, 'Przerwy'),
      ]),
    );
  }

  pw.Widget _buildNestedTable(List<_WorkSession> sessions, pw.Font regularFont, pw.Font boldFont, String title) {
    final headers = ['Nazwa', 'Start', 'Koniec', 'Czas'];
    final data = sessions.map((s) {
      final startTime = s.startEntry.eventActionTimestamp.toDate();
      final endTime = s.endEntry.eventActionTimestamp.toDate();
      return [s.startEntry.workTypeName, DateFormat('HH:mm:ss').format(startTime), DateFormat('HH:mm:ss').format(endTime), _formatDurationHHMMSS(s.duration)];
    }).toList();
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 9)),
      pw.Table.fromTextArray(
        headers: headers,
        data: data,
        headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
        cellStyle: pw.TextStyle(font: regularFont, fontSize: 8),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {0: pw.Alignment.centerLeft},
      )
    ]
    );
  }

  pw.Widget _buildFooter(pw.Context context, pw.Font regularFont) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Strona ${context.pageNumber} z ${context.pagesCount}',
          style: pw.TextStyle(font: regularFont, color: PdfColors.grey)),
    );
  }
}