import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:work_time_registration/models/app_data.dart';
import 'package:work_time_registration/models/member.dart';
import 'package:work_time_registration/models/project-access.dart';
import '../../../widgets/dialogs.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/user_app.dart';
import '../../services/area_service.dart';
import '../../services/members_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';

class CreateMemberScreen extends StatefulWidget {
  final String ownerId;
  const CreateMemberScreen({super.key, required this.ownerId});

  @override
  State<CreateMemberScreen> createState() => _CreateMemberScreenState();
}

class _CreateMemberScreenState extends State<CreateMemberScreen> {
  // Krok 1: Wyszukiwanie usera
  final TextEditingController _emailController = TextEditingController();
  UserApp? _searchedUser;
  bool _isSearchingUser = false;
  String? _searchError;

  // Krok 2: Wybór projektów
  List<Project> _availableProjects = [];
  final Set<String> _selectedProjectIds = {};
  bool _isLoadingProjects = true;

  // Krok 3: Konfiguracja dostępu (role i obszary per projekt)
  final Map<String, Set<String>> _projectRolesMap = {};
  final Map<String, Set<String>> _projectSelectedAreasMap = {};
  final Map<String, List<Area>> _projectAvailableAreasMap = {};
  final Map<String, bool> _projectAreasLoadingMap = {};
  final Map<String, bool> _projectExpansionState = {}; // Stan rozwinięcia dla kart projektów

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableProjects();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableProjects() async {
    setState(() => _isLoadingProjects = true);
    try {
      _availableProjects = await projectService.getProjectsByOwner(widget.ownerId);
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd', 'Nie udało się załadować listy projektów.');
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _findUserByEmail() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() { _isSearchingUser = true; _searchedUser = null; _searchError = null; });
    try {
      final user = await userService.getUserByExactEmail(_emailController.text.trim());
      if (user != null) {
        // ZMIANA: Sprawdź, czy użytkownik nie jest już pracownikiem w TEJ firmie.
        final existingMember = await membersService.getMembership(
          userId: user.uid!,
          ownerId: widget.ownerId,
        );

        if (existingMember != null) {
          setState(() {
            _searchError = "Ten użytkownik jest już pracownikiem w tej firmie.";
          });
        } else {
          setState(() {
            _searchedUser = user;
          });
        }
      } else {
        setState(() => _searchError = "Nie znaleziono użytkownika o podanym adresie email.");
      }
    } catch (e) {
      setState(() => _searchError = "Wystąpił błąd: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isSearchingUser = false);
    }
  }

  void _clearSearchedUser() {
    setState(() {
      _searchedUser = null;
      _emailController.clear();
      _searchError = null;
    });
  }

  void _toggleProjectSelection(String projectId) {
    setState(() {
      if (_selectedProjectIds.contains(projectId)) {
        _selectedProjectIds.remove(projectId);
        _projectRolesMap.remove(projectId);
        _projectSelectedAreasMap.remove(projectId);
        _projectExpansionState.remove(projectId);
      } else {
        _selectedProjectIds.add(projectId);
        _projectRolesMap[projectId] = {}; // Inicjalizuj pusty zbiór ról
        _projectSelectedAreasMap[projectId] = {}; // Inicjalizuj pusty zbiór obszarów
        _projectExpansionState[projectId] = true; // Domyślnie rozwiń nowy projekt
        _loadAreasForProject(projectId);
      }
    });
  }

  void _toggleProjectExpansion(String projectId) {
    setState(() {
      _projectExpansionState[projectId] = !(_projectExpansionState[projectId] ?? false);
    });
  }

  Future<void> _loadAreasForProject(String projectId) async {
    if (_projectAvailableAreasMap.containsKey(projectId)) return;
    setState(() => _projectAreasLoadingMap[projectId] = true);
    try {
      final areas = await areaService.getAreasByProject(projectId);
      if(mounted) setState(() => _projectAvailableAreasMap[projectId] = areas);
    } finally {
      if(mounted) setState(() => _projectAreasLoadingMap[projectId] = false);
    }
  }

  void _toggleRoleForProject(String projectId, String role) => setState(() {
    _projectRolesMap[projectId]!.contains(role) ? _projectRolesMap[projectId]!.remove(role) : _projectRolesMap[projectId]!.add(role);
  });

  void _toggleAreaForProject(String projectId, String areaId) => setState(() {
    _projectSelectedAreasMap[projectId]!.contains(areaId) ? _projectSelectedAreasMap[projectId]!.remove(areaId) : _projectSelectedAreasMap[projectId]!.add(areaId);
  });

  Future<void> _createMember() async {
    if (_searchedUser == null || _selectedProjectIds.isEmpty) return;

    // Walidacja, czy dla każdego wybranego projektu przypisano rolę
    for (var projectId in _selectedProjectIds) {
      if (_projectRolesMap[projectId] == null || _projectRolesMap[projectId]!.isEmpty) {
        final projectName = _availableProjects.firstWhere((p) => p.projectId == projectId).name;
        showErrorDialog(context, 'Brak ról', 'Wybierz przynajmniej jedną rolę dla projektu "$projectName".');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final projectAccessList = _selectedProjectIds.map((projectId) => ProjectAccess(
        projectId: projectId,
        roles: _projectRolesMap[projectId]!,
        areaIds: _projectSelectedAreasMap[projectId]!,
      )).toList();

      // ZMIANA: Utwórz obiekt Member z wymaganym polem `memberId`.
      final newMember = Member(
        memberId: '${_searchedUser!.uid!}_${widget.ownerId}', // Unikalne ID dokumentu
        userId: _searchedUser!.uid!,
        ownerId: widget.ownerId,
        projects: projectAccessList,
        dateAdded: Timestamp.now(),
        status: 'aktywny',
      );

      // Wywołanie jest poprawne, jeśli `membersService.addMember` używa
      // nowej logiki repozytorium (sprawdzanie unikalności).
      await membersService.addMember(newMember);

      if (mounted) {
        await showSuccessDialog(context, 'Utworzono pracownika!', 'Pomyślnie dodano ${_searchedUser!.displayName ?? _searchedUser!.email}.');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd zapisu', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reszta kodu UI (build, _buildSectionTitle, itd.) pozostaje bez zmian.
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowy Pracownik'),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Zapisz', onPressed: (_isSaving || _searchedUser == null || _selectedProjectIds.isEmpty) ? null : _createMember),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.secondary.withOpacity(0.5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: AbsorbPointer(
              absorbing: _isSaving,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Card(
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionTitle(theme, "Krok 1: Znajdź użytkownika"),
                            _buildUserEmailSearchField(theme),
                            if (_isSearchingUser) const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: CircularProgressIndicator()))
                            else if (_searchError != null) Padding(padding: const EdgeInsets.only(top: 12.0), child: Text(_searchError!, style: TextStyle(color: theme.colorScheme.error)))
                            else if (_searchedUser != null) _buildSelectedUserInfo(theme, _searchedUser!),

                            if (_searchedUser != null) ...[
                              const Divider(height: 40, thickness: 1),
                              _buildSectionTitle(theme, "Krok 2: Przypisz do projektów"),
                              _buildProjectsSection(theme),
                            ],

                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Utwórz Pracownika'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              onPressed: (_isSaving || _searchedUser == null || _selectedProjectIds.isEmpty) ? null : _createMember,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
  );

  Widget _buildUserEmailSearchField(ThemeData theme) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: TextFormField(controller: _emailController, decoration: InputDecoration(labelText: "Adres email użytkownika", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0))), onFieldSubmitted: (_) => _findUserByEmail(), enabled: _searchedUser == null)),
      const SizedBox(width: 8),
      ElevatedButton(child: const Text("Szukaj"), onPressed: _searchedUser != null ? null : _findUserByEmail),
    ],
  );

  Widget _buildSelectedUserInfo(ThemeData theme, UserApp user) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3))),
    child: ListTile(
      leading: CircleAvatar(child: Text(user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : 'U')),
      title: Text(user.displayName ?? 'Brak nazwy', style: theme.textTheme.titleMedium),
      subtitle: Text(user.email ?? 'Brak emaila'),
      trailing: IconButton(icon: Icon(Icons.close, color: theme.colorScheme.error), onPressed: _clearSearchedUser),
    ),
  );

  Widget _buildProjectsSection(ThemeData theme) {
    if (_isLoadingProjects) return const Center(child: CircularProgressIndicator());
    return Column(
      children: _availableProjects.map((project) {
        final isSelected = _selectedProjectIds.contains(project.projectId);
        final isExpanded = _projectExpansionState[project.projectId] ?? false;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                value: isSelected,
                onChanged: (_) => _toggleProjectSelection(project.projectId),
                activeColor: theme.colorScheme.primary,
                secondary: IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: 'Rozwiń/Zwiń szczegóły',
                  onPressed: () => _toggleProjectExpansion(project.projectId),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Visibility(
                  visible: isSelected && isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text("Role w projekcie", style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8.0, children: AppData().availableProjectRoles.map((role) => ChoiceChip(label: Text(role), selected: (_projectRolesMap[project.projectId] ?? {}).contains(role), onSelected: (_) => _toggleRoleForProject(project.projectId, role))).toList()),
                        const SizedBox(height: 16),
                        Text("Obszary w projekcie", style: theme.textTheme.titleSmall),
                        _buildAreaSelectionForProject(project.projectId),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAreaSelectionForProject(String projectId) {
    if (_projectAreasLoadingMap[projectId] ?? false) return const Center(child: CircularProgressIndicator());
    final areas = _projectAvailableAreasMap[projectId] ?? [];
    if (areas.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak obszarów do przypisania.', style: TextStyle(fontStyle: FontStyle.italic)));

    return Column(
      children: areas.map((area) => CheckboxListTile(
        title: Text(area.name),
        value: (_projectSelectedAreasMap[projectId] ?? {}).contains(area.areaId),
        onChanged: (_) => _toggleAreaForProject(projectId, area.areaId),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      )).toList(),
    );
  }
}