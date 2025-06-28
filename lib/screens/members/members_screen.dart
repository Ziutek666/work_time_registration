import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/area.dart';
import '../../models/member.dart';
import '../../models/project.dart';
import '../../models/user_app.dart';
import '../../services/area_service.dart';
import '../../services/members_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';
import '../../widgets/dialogs.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  // --- Dane ---
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  Map<String, UserApp> _userDetails = {};
  Map<String, Project> _projectDetails = {};
  List<Project> _ownedProjects = [];
  Map<String, String> _areaNamesMap = {}; // Mapa ID obszaru -> nazwa
  String? ownerId;

  // --- Stan UI ---
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFilterPanelExpanded = false;
  final Map<String, bool> _expandedState = {};

  // --- Stan Filtrów ---
  final TextEditingController _searchController = TextEditingController();
  Project? _selectedProjectFilter;
  Area? _selectedAreaFilter;
  List<Area> _availableAreasForFilter = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }
  // NOWA METODA: Obsługa usuwania pracownika
  Future<void> _handleDeleteMember(Member member, UserApp? user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: Text('Czy na pewno chcesz trwale usunąć pracownika "${user?.displayName ?? member.userId}"? Tej akcji nie można cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Usuń', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      showLoadingDialog(context, 'Usuwanie pracownika...');
      try {
        await membersService.deleteMembership(userId: member.userId, ownerId: member.ownerId!);
        if (mounted) {
          Navigator.of(context).pop(); // Zamknij dialog ładowania
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pomyślnie usunięto pracownika.'), backgroundColor: Colors.green),
          );
          _loadData(); // Odśwież listę
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Zamknij dialog ładowania
          showErrorDialog(context, 'Błąd', 'Nie udało się usunąć pracownika: $e');
        }
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      ownerId = await userService.uid;
      if (ownerId == null) throw Exception('Nie udało się pobrać danych właściciela');

      _ownedProjects = await projectService.getProjectsByOwner(ownerId!);
      _allMembers = await membersService.getMembersByOwner(ownerId!);

      if (_allMembers.isNotEmpty) {
        final userIds = _allMembers.map((m) => m.userId).toSet().toList();
        final projectIds = _allMembers.expand((m) => m.projects).map((p) => p.projectId).toSet().toList();
        final areaIds = _allMembers.expand((m) => m.projects).expand((p) => p.areaIds).toSet().toList();

        final users = await userService.getUsersByIds(userIds);
        final projects = await projectService.fetchProjectsByIds(projectIds);
        final areas = await areaService.getAreasByIds(areaIds);

        _userDetails = {for (var u in users) u.uid ?? '': u};
        _projectDetails = {for (var p in projects) p.projectId: p};
        _areaNamesMap = {for (var a in areas) a.areaId: a.name};
      }
      _applyFilters();
    } catch (e, stackTrace) {
      debugPrint('Błąd przy ładowaniu członków: $e\n$stackTrace');
      if (mounted) _errorMessage = 'Nie udało się załadować danych: ${e.toString()}';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Member> filtered = List.of(_allMembers);
    final searchQuery = _searchController.text.toLowerCase().trim();

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((member) {
        final user = _userDetails[member.userId];
        return (user?.displayName?.toLowerCase().contains(searchQuery) ?? false) ||
            (user?.email?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    }

    if (_selectedProjectFilter != null) {
      filtered = filtered.where((m) => m.projects.any((p) => p.projectId == _selectedProjectFilter!.projectId)).toList();
    }

    if (_selectedAreaFilter != null) {
      filtered = filtered.where((m) => m.projects.any((p) => p.areaIds.contains(_selectedAreaFilter!.areaId))).toList();
    }

    setState(() {
      _filteredMembers = filtered..sort((a, b) => (_userDetails[a.userId]?.displayName ?? '').compareTo(_userDetails[b.userId]?.displayName ?? ''));
    });
  }

  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedProjectFilter = project;
      _selectedAreaFilter = null;
      _availableAreasForFilter = [];
    });
    if (project != null) {
      _loadAreasForFilter(project.projectId);
    }
    _applyFilters();
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      final areas = await areaService.getAreasByProject(projectId);
      if (mounted) {
        setState(() => _availableAreasForFilter = areas);
      }
    } catch (e) {
      debugPrint("Błąd ładowania obszarów do filtra: $e");
    }
  }

  void _onAreaFilterChanged(Area? area) {
    setState(() => _selectedAreaFilter = area);
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedProjectFilter = null;
      _selectedAreaFilter = null;
      _availableAreasForFilter = [];
    });
    _applyFilters();
  }

  void _toggleCardExpansion(String memberId) {
    setState(() {
      _expandedState[memberId] = !(_expandedState[memberId] ?? false);
    });
  }

  Future<void> _navigateToAddMember() async {
    final result = await context.push<bool>('/create_member', extra: ownerId ?? '');
    if (result == true) _loadData();
  }

  Future<void> _handleEditMember(Member member, UserApp? user) async {
    if (user == null) {
      showErrorDialog(context, 'Błąd edycji', 'Nie udało się pobrać danych użytkownika');
      return;
    }
    final result = await context.push<bool>('/edit_member', extra: {'member': member, 'user': user});
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Pracownicy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj zmiany",
          onPressed: (){
            if (context.canPop()) {
              context.pop();
            } else {
              // Domyślnie wróć do ekranu głównego, jeśli nie ma dokąd wrócić
              context.go('/administration-menu');
            }
          }
        ),
        actions: [
          IconButton(
            icon: Icon(_isFilterPanelExpanded ? Icons.filter_list_off : Icons.filter_list),
            tooltip: 'Filtruj',
            onPressed: () => setState(() => _isFilterPanelExpanded = !_isFilterPanelExpanded),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _navigateToAddMember,
        label: const Text('Dodaj pracownika'),
        icon: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.secondary.withOpacity(0.5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildFilterPanel(theme),
            Expanded(child: _buildBodyContent(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Visibility(
        visible: _isFilterPanelExpanded,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(controller: _searchController, decoration: const InputDecoration(labelText: 'Szukaj po nazwie lub emailu', prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Project>(
                    value: _selectedProjectFilter,
                    decoration: const InputDecoration(labelText: 'Projekt', hintText: 'Wszystkie projekty'),
                    items: [
                      const DropdownMenuItem<Project>(value: null, child: Text("Wszystkie projekty")),
                      ..._ownedProjects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
                    ],
                    onChanged: _onProjectFilterChanged,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Area>(
                    value: _selectedAreaFilter,
                    decoration: InputDecoration(labelText: 'Obszar', hintText: _selectedProjectFilter == null ? 'Najpierw wybierz projekt' : 'Wszystkie obszary'),
                    items: [
                      const DropdownMenuItem<Area>(value: null, child: Text("Wszystkie obszary")),
                      ..._availableAreasForFilter.map((a) => DropdownMenuItem(value: a, child: Text(a.name))),
                    ],
                    onChanged: _selectedProjectFilter != null ? _onAreaFilterChanged : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _clearFilters, child: const Text('Wyczyść filtry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!)));
    if (_allMembers.isEmpty) return const Center(child: Text('Brak pracowników do wyświetlenia.'));
    if (_filteredMembers.isEmpty) return const Center(child: Text('Brak pracowników spełniających kryteria filtrowania.'));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 80.0),
        itemCount: _filteredMembers.length,
        itemBuilder: (context, index) {
          final member = _filteredMembers[index];
          final user = _userDetails[member.userId];
          return _buildMemberItem(member, user, theme);
        },
      ),
    );
  }

  Widget _buildMemberItem(Member member, UserApp? user, ThemeData theme) {
    final displayName = user?.displayName ?? 'Użytkownik bez nazwy';
    final email = user?.email ?? 'Brak adresu email';
    final isExpanded = _expandedState[member.userId] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _handleEditMember(member, user),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
              child: Row(
                children: [
                  CircleAvatar(child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(email, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => _toggleCardExpansion(member.userId),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: Visibility(
              visible: isExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    if (member.status != null) Align(alignment: Alignment.centerLeft, child: Chip(label: Text('Status: ${member.status!}'))),
                    const SizedBox(height: 12),
                    ...member.projects.map((access) {
                      final projectName = _projectDetails[access.projectId]?.name ?? 'Nieznany projekt';
                      return Container(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(projectName, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                            if (access.roles.isNotEmpty) _buildDetailRow(Icons.security, 'Role: ${access.roles.join(", ")}', theme),
                            if (access.areaIds.isNotEmpty) _buildDetailRow(Icons.layers_outlined, 'Obszary: ${access.areaIds.map((id) => _areaNamesMap[id] ?? 'B/D').join(", ")}', theme),
                          ],
                        ),
                      );
                    }).toList(),
                    // NOWY ELEMENT: Przycisk usuwania
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                        label: Text('Usuń pracownika', style: TextStyle(color: theme.colorScheme.error)),
                        onPressed: () => _handleDeleteMember(member, user),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}