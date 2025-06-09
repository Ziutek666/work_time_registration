import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Dostosuj ścieżki do swoich modeli i serwisów
import '../../models/work_entry.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/user_app.dart';
import '../../models/information.dart';
import '../../models/information_category.dart';
import '../../services/work_entry_service.dart';
import '../../services/project_service.dart';
import '../../services/area_service.dart';
import '../../services/user_service.dart';
import '../../services/project_member_service.dart';
import '../../services/information_category_service.dart';
import '../../widgets/dialogs.dart';

class AdminInfoHistoryScreen extends StatefulWidget {
  const AdminInfoHistoryScreen({super.key});

  @override
  State<AdminInfoHistoryScreen> createState() => _AdminInfoHistoryScreenState();
}

class _AdminInfoHistoryScreenState extends State<AdminInfoHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  UserApp? _currentUser;
  bool _isFilterPanelExpanded = true;

  // Dane
  List<WorkEntry> _allEntriesWithInfo = [];
  Map<String, InformationCategory> _allCategories = {};
  Map<String, Map<String, Map<String, List<WorkEntry>>>> _groupedFilteredEntries = {};

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;
  UserApp? _selectedFilterUser;

  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];
  List<UserApp> _availableUsersForFilter = [];

  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};
  Map<String, String> _userNamesMap = {};

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'pl_PL');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) throw Exception("Nie można zidentyfikować administratora.");

      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

      await _loadProjectsForFilter();
      await _loadAllUsersForFilter();
      await _fetchWorkEntriesWithInfo();
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
      _projectNamesMap = {for (var p in _availableProjectsForFilter) p.projectId: p.name};
    } catch (e) {
      debugPrint("Błąd ładowania projektów administratora: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAllUsersForFilter() async {
    if (_availableProjectsForFilter.isEmpty) return;
    try {
      final projectIds = _availableProjectsForFilter.map((p) => p.projectId).toList();
      final allMembers = await projectMemberService.getMembersForAllProjects(projectIds);

      final userIds = allMembers.map<String>((m) => m.userId).toSet();

      if (userIds.isEmpty) return;

      final users = await userService.getUsersByIds(userIds.toList());
      users.sort((a, b) => (a.displayName ?? a.email ?? '').compareTo(b.displayName ?? b.email ?? ''));
      _userNamesMap = {for (var u in users) u.uid!: (u.displayName ?? u.email ?? u.uid!)};
      if (mounted) setState(() => _availableUsersForFilter = users);
    } catch (e) {
      debugPrint("Błąd ładowania wszystkich użytkowników do filtra: $e");
    }
  }

  Future<void> _fetchWorkEntriesWithInfo() async {
    if (_selectedDateRange == null || _availableProjectsForFilter.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _allEntriesWithInfo = []; });
      _applyFiltersAndGroup(); // Wywołaj, aby wyczyścić listę
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final projectIds = _availableProjectsForFilter.map((p) => p.projectId).toList();
      final allEntries = await workEntryService.getWorkEntriesForProjectsBetweenDates(
        projectIds,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day + 1),
      );

      _allEntriesWithInfo = allEntries.where((entry) => entry.relatedInformations != null && entry.relatedInformations!.isNotEmpty).toList();

      // POPRAWKA: Przekazano poprawną zmienną `_allEntriesWithInfo`
      await _ensureNamesAvailable(_allEntriesWithInfo);
      _applyFiltersAndGroup();

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd przetwarzania historii: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndGroup() {
    List<WorkEntry> tempFiltered = List.from(_allEntriesWithInfo);

    if (_selectedFilterProject != null) tempFiltered.removeWhere((e) => e.projectId != _selectedFilterProject!.projectId);
    if (_selectedFilterArea != null) tempFiltered.removeWhere((e) => e.areaId != _selectedFilterArea!.areaId);
    if (_selectedFilterUser != null) tempFiltered.removeWhere((e) => e.userId != _selectedFilterUser!.uid);

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


  Future<void> _ensureNamesAvailable(List<WorkEntry> entries) async {
    final Set<String> pIds = entries.map<String>((e) => e.projectId).toSet();
    final Set<String> aIds = entries.map<String>((e) => e.areaId).toSet();
    final Set<String> uIds = entries.map<String>((e) => e.userId).toSet();
    final Set<String> cIds = entries.expand<String>((e) => e.relatedInformations?.map((i) => i.categoryId) ?? []).toSet();

    final mPIds = pIds.where((id) => id.isNotEmpty && !_projectNamesMap.containsKey(id)).toList();
    final mAIds = aIds.where((id) => id.isNotEmpty && !_areaNamesMap.containsKey(id)).toList();
    final mUIds = uIds.where((id) => id.isNotEmpty && !_userNamesMap.containsKey(id)).toList();
    final mCIds = cIds.where((id) => id.isNotEmpty && !_allCategories.containsKey(id)).toList();

    // Równoległe pobieranie brakujących danych
    await Future.wait([
      if (mPIds.isNotEmpty)
        projectService.fetchProjectsByIds(mPIds).then((newProjects) {
          for (var p in newProjects) _projectNamesMap[p.projectId] = p.name;
        }),
      if (mAIds.isNotEmpty)
        areaService.getAreasByIds(mAIds).then((newAreas) {
          for (var a in newAreas) _areaNamesMap[a.areaId] = a.name;
        }),
      if (mUIds.isNotEmpty)
        userService.getUsersByIds(mUIds).then((newUsers) {
          for (var u in newUsers) _userNamesMap[u.uid!] = u.displayName ?? u.email ?? u.uid!;
        }),
      if (mCIds.isNotEmpty)
        informationCategoryService.getCategoriesByIds(mCIds).then((newCategories) {
          for (var c in newCategories) _allCategories[c.categoryId] = c;
        }),
    ]);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('pl', 'PL'));
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      await _fetchWorkEntriesWithInfo();
    }
  }

  Future<void> _onProjectFilterChanged(Project? project) async {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _selectedFilterUser = null;
      _availableAreasForFilter = [];
    });

    if (project != null) {
      await Future.wait([
        _loadAreasForFilter(project.projectId),
        _loadUsersForSingleProjectFilter(project.projectId),
      ]);
    } else {
      await _loadAllUsersForFilter();
    }
    _applyFiltersAndGroup();
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      final areas = await areaService.getAreasByProject(projectId);
      if (mounted) {
        setState(() {
          _availableAreasForFilter = areas..sort((a,b) => a.name.compareTo(b.name));
        });
      }
    } catch(e) {
      if (mounted) setState(() => _availableAreasForFilter = []);
      debugPrint("Błąd ładowania obszarów dla projektu $projectId: $e");
    }
  }

  Future<void> _loadUsersForSingleProjectFilter(String projectId) async {
    try {
      final members = await projectMemberService.getMembersByProjectId(projectId);
      final userIds = members.map((m) => m.userId).toSet();
      if(userIds.isEmpty) {
        if(mounted) setState(() => _availableUsersForFilter = []);
        return;
      }
      final users = await userService.getUsersByIds(userIds.toList());
      if(mounted) {
        setState(() {
          _availableUsersForFilter = users..sort((a,b) => (a.displayName ?? a.email ?? '').compareTo(b.displayName ?? b.email ?? ''));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _availableUsersForFilter = []);
      debugPrint("Błąd ładowania użytkowników dla projektu $projectId: $e");
    }
  }

  void _onAreaFilterChanged(Area? area) { setState(() => _selectedFilterArea = area); _applyFiltersAndGroup(); }
  void _onUserFilterChanged(UserApp? user) { setState(() => _selectedFilterUser = user); _applyFiltersAndGroup(); }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _selectedFilterUser = null;
      _availableAreasForFilter = [];
    });
    _loadAllUsersForFilter().then((_) {
      _fetchWorkEntriesWithInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historia Informacji (Admin)')),
      body: Column(
        children: [
          _buildCollapsibleFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _groupedFilteredEntries.isEmpty
                ? const Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Brak wpisów z informacjami dla wybranych kryteriów.', textAlign: TextAlign.center)))
                : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilterPanel(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('info_history_filter_panel'),
        initiallyExpanded: _isFilterPanelExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isFilterPanelExpanded = isExpanded),
        title: Text("Filtrowanie Historii Informacji", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        leading: Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary),
        trailing: Icon(_isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more),
        children: [ _buildFilterSection(theme) ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          OutlinedButton.icon(icon: const Icon(Icons.date_range), label: Text(_selectedDateRange != null ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}' : 'Wybierz zakres dat'), onPressed: () => _selectDateRange(context), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40))),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserApp>(decoration: const InputDecoration(labelText: 'Pracownik', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()), value: _selectedFilterUser, hint: const Text('Wszyscy pracownicy'), isExpanded: true, items: [const DropdownMenuItem<UserApp>(value: null, child: Text('Wszyscy pracownicy')), ..._availableUsersForFilter.map((u) => DropdownMenuItem<UserApp>(value: u, child: Text(u.displayName ?? u.email ?? u.uid!, overflow: TextOverflow.ellipsis)))], onChanged: _onUserFilterChanged),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: DropdownButtonFormField<Project>(decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder()), value: _selectedFilterProject, hint: const Text('Wszystkie'), isExpanded: true, items: [const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie')), ..._availableProjectsForFilter.map((p) => DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))], onChanged: _onProjectFilterChanged)),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<Area>(decoration: const InputDecoration(labelText: 'Obszar', border: OutlineInputBorder()), value: _selectedFilterArea, hint: const Text('Wszystkie'), isExpanded: true, disabledHint: _selectedFilterProject == null ? const Text('Wybierz projekt') : null, items: _selectedFilterProject == null ? [] : [const DropdownMenuItem<Area>(value: null, child: Text('Wszystkie')), ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))], onChanged: _selectedFilterProject != null ? _onAreaFilterChanged : null)),
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
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 8, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Icon(entry.isStart ? Icons.play_arrow : Icons.stop, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text("${entry.workTypeName} - ${_dateFormat.format(entry.eventActionTimestamp.toDate())}", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (entry.relatedInformations != null)
            ...entry.relatedInformations!.map((info) => _buildInformationDetailsCard(info, theme)).toList(),
        ],
      ),
    );
  }

  Widget _buildInformationDetailsCard(Information info, ThemeData theme) {
    final category = _allCategories[info.categoryId];
    final categoryIcon = category?.iconData ?? Icons.help_outline;
    final categoryColor = category?.color ?? Colors.grey;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(categoryIcon, color: categoryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(info.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
            ]),
            const Divider(height: 16),
            Text(info.content, style: theme.textTheme.bodyMedium),
            if (info.requiresDecision) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text("Podjęta decyzja: ", style: theme.textTheme.bodySmall),
                  if (info.decision == true) Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                  if (info.decision == false) Icon(Icons.cancel, color: theme.colorScheme.error, size: 18),
                  const SizedBox(width: 4),
                  Text(info.decision == true ? "Tak" : (info.decision == false ? "Nie" : "Brak"), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (info.textResponse != null && info.textResponse!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Odpowiedź: ", style: theme.textTheme.bodySmall),
                  Expanded(child: Text(info.textResponse!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}