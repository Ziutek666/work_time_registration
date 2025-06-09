import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart'; // Załóżmy, że ścieżki są poprawne
import '../../models/project_member.dart';
import '../../models/user_app.dart';
import '../../models/work_entry.dart';
import '../../services/project_member_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';
import 'area_select_dialog.dart';

class ProjectSelectionDialog extends StatefulWidget {
  final WorkEntry? lastWorkTypeEntry;

  const ProjectSelectionDialog({
    this.lastWorkTypeEntry,
    super.key,
  });

  @override
  State<ProjectSelectionDialog> createState() => _ProjectSelectionDialogState();
}

class _ProjectSelectionDialogState extends State<ProjectSelectionDialog> {
  List<Project> _assignedProjects = [];
  Map<String, ProjectMember> _projectMemberships = {}; // Zachowujemy, jeśli potrzebne do wyświetlania np. daty dołączenia
  UserApp? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingSelection = false;


  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndAssignedProjects();
  }

  Future<void> _loadCurrentUserAndAssignedProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _assignedProjects.clear();
      _projectMemberships.clear();
    });

    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null || _currentUser!.uid == null || _currentUser!.uid!.isEmpty) {
        throw Exception("Nie udało się zidentyfikować bieżącego użytkownika.");
      }

      final allMemberships = await projectMemberService.getProjectsForUser(_currentUser!.uid!);
      final employeeMemberships = allMemberships.where((member) => member.roles.contains('PRACOWNIK')).toList();

      if (employeeMemberships.isNotEmpty) {
        for (var membership in employeeMemberships) {
          // Przechowujemy całe obiekty ProjectMember, aby mieć dostęp do daty dołączenia itp.
          _projectMemberships[membership.projectId] = membership;
        }
        final projectIds = employeeMemberships.map((member) => member.projectId).toList();
        if (projectIds.isNotEmpty) {
          _assignedProjects = await projectService.fetchProjectsByIds(projectIds);
          _assignedProjects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }
      } else {
        _assignedProjects = [];
      }

    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu przypisanych projektów (dialog): $e\n$stackTrace');
      if (mounted) {
        _errorMessage = 'Nie udało się załadować projektów: ${e.toString()}';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectProjectAndProceed(Project project) async {
    if (_isProcessingSelection || !mounted) return;
    setState(() { _isProcessingSelection = true; });

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AreaSelectionDialog(
          project: project,
          lastWorkTypeEntry: widget.lastWorkTypeEntry,
        );
      },
    );

    if (mounted) {
      setState(() { _isProcessingSelection = false; });
      if (result == true) {
        Navigator.of(context).pop(true);
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.all(20.0),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Zmniejszony padding dla contentu
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      title: Row(
        children: [
          Icon(Icons.business_center_outlined, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wybierz Projekt',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildDialogContent(theme),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Anuluj', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          onPressed: _isProcessingSelection ? null : () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    if (_isLoading) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text("Ładowanie projektów...", style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(
                'Wystąpił błąd',
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon( // Przycisk odświeżania przy błędzie
                  icon: const Icon(Icons.refresh),
                  label: const Text("Spróbuj ponownie"),
                  onPressed: _loadCurrentUserAndAssignedProjects,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onErrorContainer)
              )
            ],
          ),
        ),
      );
    }

    if (_assignedProjects.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.work_off_outlined, size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Brak Projektów',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Nie jesteś przypisany jako pracownik do żadnego projektu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessingSelection) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder( // Zmieniono na ListView.builder
              shrinkWrap: true,
              itemCount: _assignedProjects.length,
              itemBuilder: (context, index) {
                final project = _assignedProjects[index];
                final membership = _projectMemberships[project.projectId]; // Pobieramy członkostwo
                return _buildProjectListItem(project, membership, theme); // Przekazujemy członkostwo
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectListItem(Project project, ProjectMember? membership, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color itemColor = colorScheme.primary; // Domyślny kolor dla projektów

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: itemColor.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(Icons.folder_shared_outlined, color: itemColor, size: 28),
        title: Text(
          project.name,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.description.isNotEmpty)
              Text(
                project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            if (membership != null) ...[ // Wyświetlanie daty dołączenia, jeśli dostępna
              SizedBox(height: project.description.isNotEmpty ? 4.0 : 0),
              Text(
                'Dołączono: ${_formatTimestamp(membership.dateAdded)}',
                style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: itemColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        onTap: _isProcessingSelection ? null : () => _selectProjectAndProceed(project),
        isThreeLine: project.description.isNotEmpty && membership != null, // Dostosowanie isThreeLine
      ),
    );
  }
}