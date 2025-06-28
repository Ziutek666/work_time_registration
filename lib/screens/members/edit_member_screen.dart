import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/models/app_data.dart';
import 'package:work_time_registration/models/member.dart';
import 'package:work_time_registration/models/project-access.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/user_app.dart';
import '../../services/area_service.dart';
import '../../services/members_service.dart';
import '../../services/project_service.dart';
import '../../widgets/dialogs.dart';

class EditMemberScreen extends StatefulWidget {
  final Member initialMember;
  final UserApp user;

  const EditMemberScreen({
    super.key,
    required this.initialMember,
    required this.user,
  });

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  late Member _editableMember;
  List<Project> _allOwnerProjects = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, List<Area>> _projectAvailableAreasMap = {};
  final Map<String, bool> _projectAreasLoadingMap = {};
  final Map<String, bool> _projectExpansionState = {};

  @override
  void initState() {
    super.initState();
    _editableMember = widget.initialMember.copyWith(
      projects: widget.initialMember.projects.map((p) => p.copyWith()).toList(),
    );
    for (var projectAccess in _editableMember.projects) {
      _projectExpansionState[projectAccess.projectId] = true;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _allOwnerProjects = await projectService.getProjectsByOwner(_editableMember.ownerId);
      for (var projectAccess in _editableMember.projects) {
        _loadAreasForProject(projectAccess.projectId);
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd', 'Nie udało się załadować danych początkowych.');
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
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

  void _toggleProjectAccess(String projectId) {
    setState(() {
      final isMemberOfProject = _editableMember.projects.any((p) => p.projectId == projectId);
      if (isMemberOfProject) {
        _editableMember.projects.removeWhere((p) => p.projectId == projectId);
        _projectExpansionState.remove(projectId);
      } else {
        _editableMember.projects.add(ProjectAccess(projectId: projectId));
        _projectExpansionState[projectId] = true;
        _loadAreasForProject(projectId);
      }
    });
  }

  void _toggleProjectExpansion(String projectId) {
    setState(() {
      _projectExpansionState[projectId] = !(_projectExpansionState[projectId] ?? false);
    });
  }

  void _toggleRoleForProject(String projectId, String role) {
    setState(() {
      final projectAccess = _editableMember.projects.firstWhere((p) => p.projectId == projectId);
      projectAccess.roles.contains(role) ? projectAccess.roles.remove(role) : projectAccess.roles.add(role);
    });
  }

  void _toggleAreaForProject(String projectId, String areaId) {
    setState(() {
      final projectAccess = _editableMember.projects.firstWhere((p) => p.projectId == projectId);
      projectAccess.areaIds.contains(areaId) ? projectAccess.areaIds.remove(areaId) : projectAccess.areaIds.add(areaId);
    });
  }

  void _changeStatus(String? newStatus) {
    if (newStatus == null) return;
    setState(() {
      _editableMember = _editableMember.copyWith(status: newStatus);
    });
  }

  Future<void> _saveChanges() async {
    for (var projectAccess in _editableMember.projects) {
      if (projectAccess.roles.isEmpty) {
        final projectName = _allOwnerProjects.firstWhere((p) => p.projectId == projectAccess.projectId).name;
        showErrorDialog(context, 'Brak ról', 'Pracownik musi mieć przynajmniej jedną rolę w projekcie "$projectName".');
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      await membersService.setMember(_editableMember);
      if(mounted) {
        await showSuccessDialog(context, 'Zapisano zmiany', 'Dane pracownika zostały zaktualizowane.');
        context.pop(true);
      }
    } catch (e) {
      if(mounted) await showErrorDialog(context, 'Błąd zapisu', 'Nie udało się zapisać zmian: $e');
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: Text('Edytuj Pracownika', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(false)),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))))
          else IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Zapisz zmiany', onPressed: _saveChanges),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.secondary.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : AbsorbPointer(
              absorbing: _isSaving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUserInfoCard(theme),
                        const SizedBox(height: 16),
                        _buildMainEditCard(theme),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Zapisz Zmiany'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          onPressed: _saveChanges,
                        )
                      ],
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

  Widget _buildUserInfoCard(ThemeData theme) => Card(
    elevation: 4.0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: CircleAvatar(radius: 22, child: Text(widget.user.displayName?.isNotEmpty == true ? widget.user.displayName![0].toUpperCase() : 'U')),
      title: Text(widget.user.displayName ?? 'Brak nazwy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(widget.user.email ?? 'Brak emaila'),
    ),
  );

  Widget _buildMainEditCard(ThemeData theme) => Card(
    elevation: 4.0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Status Pracownika", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: ['aktywny', 'zawieszony', 'archiwizowany'].map((status) => ChoiceChip(
              label: Text(status),
              selected: _editableMember.status == status,
              onSelected: (_) => _changeStatus(status),
            )).toList(),
          ),
          const Divider(height: 32, thickness: 1),
          Text("Dostęp do Projektów", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._allOwnerProjects.map((project) {
            final bool isSelected = _editableMember.projects.any((p) => p.projectId == project.projectId);
            final bool isExpanded = _projectExpansionState[project.projectId] ?? false;

            // POPRAWKA: Bezpiecznie pobieramy obiekt ProjectAccess
            final ProjectAccess? projectAccess = isSelected
                ? _editableMember.projects.firstWhere((p) => p.projectId == project.projectId)
                : null;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    value: isSelected,
                    onChanged: (_) => _toggleProjectAccess(project.projectId),
                    activeColor: theme.colorScheme.primary,
                    secondary: IconButton(
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                      tooltip: isExpanded ? 'Zwiń szczegóły' : 'Rozwiń szczegóły',
                      onPressed: () => _toggleProjectExpansion(project.projectId),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Visibility(
                      visible: isSelected && isExpanded,
                      // POPRAWKA: Sprawdzamy, czy projectAccess nie jest null, zanim go użyjemy
                      child: projectAccess == null ? const SizedBox.shrink() : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            ExpansionTile(
                              title: Text("Role w projekcie", style: theme.textTheme.titleSmall),
                              tilePadding: EdgeInsets.zero,
                              initiallyExpanded: true,
                              childrenPadding: const EdgeInsets.only(bottom: 8.0),
                              children: [
                                Wrap(spacing: 8.0, children: AppData().availableProjectRoles.map((role) => ChoiceChip(
                                    label: Text(role),
                                    // POPRAWKA: Używamy bezpiecznie pobranego obiektu
                                    selected: projectAccess.roles.contains(role),
                                    onSelected: (_) => _toggleRoleForProject(project.projectId, role)
                                )).toList()),
                              ],
                            ),
                            ExpansionTile(
                              title: Text("Obszary w projekcie", style: theme.textTheme.titleSmall),
                              tilePadding: EdgeInsets.zero,
                              initiallyExpanded: true,
                              // POPRAWKA: Przekazujemy bezpiecznie pobrany obiekt
                              children: [_buildAreaSelectionForProject(project.projectId, projectAccess)],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    ),
  );

  // POPRAWKA: Metoda przyjmuje teraz obiekt ProjectAccess, aby uniknąć ponownego wyszukiwania
  Widget _buildAreaSelectionForProject(String projectId, ProjectAccess projectAccess) {
    if (_projectAreasLoadingMap[projectId] ?? false) return const Center(child: CircularProgressIndicator());
    final areas = _projectAvailableAreasMap[projectId] ?? [];
    if (areas.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak obszarów do przypisania.', style: TextStyle(fontStyle: FontStyle.italic)));

    return Column(
      children: areas.map((area) => CheckboxListTile(
        title: Text(area.name),
        value: projectAccess.areaIds.contains(area.areaId),
        onChanged: (_) => _toggleAreaForProject(projectId, area.areaId),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      )).toList(),
    );
  }
}