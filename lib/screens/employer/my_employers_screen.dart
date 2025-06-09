import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/project_member.dart';
import '../../models/user_app.dart';
import '../../models/work_entry.dart';
import '../../services/project_member_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';


class MyEmployersScreen extends StatefulWidget { // <<<--- ZMIENIONA NAZWA KLASY
  final WorkEntry? lastWorkTypeEntry;

  const MyEmployersScreen({
    this.lastWorkTypeEntry,
    super.key}); // <<<--- ZMIENIONA NAZWA KLASY

  @override
  State<MyEmployersScreen> createState() => _MyEmployersScreenState(); // <<<--- ZMIENIONA NAZWA KLASY STANU
}

class _MyEmployersScreenState extends State<MyEmployersScreen> { // <<<--- ZMIENIONA NAZWA KLASY STANU
  List<Project> _assignedProjects = [];
  Map<String, ProjectMember> _projectMemberships = {};
  UserApp? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

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
      _isProcessing = true;
      _assignedProjects.clear();
      _projectMemberships.clear();
    });

    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null || _currentUser!.uid == null || _currentUser!.uid!.isEmpty) { // Dodano sprawdzenie isEmpty
        throw Exception("Nie udało się zidentyfikować bieżącego użytkownika.");
      }

      final allMemberships = await projectMemberService.getProjectsForUser(_currentUser!.uid!);
      final employeeMemberships = allMemberships.where((member) => member.roles.contains('PRACOWNIK')).toList();

      if (employeeMemberships.isNotEmpty) {
        for (var membership in employeeMemberships) {
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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu przypisanych projektów (jako pracownik): $e\n$stackTrace');
      if (mounted) {
        final errorMessageText = 'Nie udało się załadować Twoich projektów: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessageText;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _navigateToSelectAreaForUser(Project project) {
    context.push('/select-area-for-user', extra: {
      'project': project,
      'lastWorkTypeEntry': widget.lastWorkTypeEntry,
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć",
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/');
          },
        ),
        title: Text(
          'Pracodawcy', // <<<--- ZMIENIONY TYTUŁ
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isLoading && _isProcessing)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: colorScheme.onPrimary,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież listę',
              onPressed: _isProcessing ? null : _loadCurrentUserAndAssignedProjects,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.7),
              theme.colorScheme.secondary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading && _isProcessing) {
      return Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text("Ładowanie Twoich projektów...", style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                const SizedBox(height: 16),
                Text(
                  'Wystąpił błąd',
                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary),
                  onPressed: _loadCurrentUserAndAssignedProjects,
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_assignedProjects.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.work_off_outlined, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)), // Zmieniona ikona
                const SizedBox(height: 20),
                Text(
                  'Brak Projektów Pracowniczych', // Zmieniony tekst
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nie jesteś aktualnie przypisany jako pracownik do żadnego projektu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCurrentUserAndAssignedProjects,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _assignedProjects.length,
        itemBuilder: (context, index) {
          final project = _assignedProjects[index];
          final membership = _projectMemberships[project.projectId];
          return _buildAssignedProjectItem(project, membership, theme);
        },
      ),
    );
  }

  Widget _buildAssignedProjectItem(Project project, ProjectMember? membership, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _navigateToSelectAreaForUser(project),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.business_center_outlined, color: colorScheme.primary, size: 36), // Zmieniona ikona
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      project.name,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        project.description,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (membership != null) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        'Dołączyłeś: ${_formatTimestamp(membership.dateAdded)}',
                        style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                      ),
                      // Można dodać wyświetlanie ról, jeśli to istotne w tym widoku
                      // Text(
                      //  'Twoje role: ${membership.roles.join(", ")}',
                      //  style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                      // ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.primary.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
