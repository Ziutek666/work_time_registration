import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/project_service.dart';

class ProjectSelectionDialog extends StatefulWidget {
  // ZMIANA: Dialog przyjmuje listę ID projektów
  final List<String> projectIds;

  const ProjectSelectionDialog({
    super.key,
    required this.projectIds,
  });

  @override
  State<ProjectSelectionDialog> createState() => _ProjectSelectionDialogState();
}

class _ProjectSelectionDialogState extends State<ProjectSelectionDialog> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  // ZMIANA: Logika pobiera projekty na podstawie przekazanej listy ID
  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.projectIds.isEmpty) {
        _projects = [];
      } else {
        // Używamy metody pobierającej projekty po liście ID
        _projects = await projectService.fetchProjectsByIds(widget.projectIds);
        _projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu projektów (dialog): $e\n$stackTrace');
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

  void _selectProjectAndReturn(Project project) {
    print('Wybrano projekt: ${project.toMap()}');
    Navigator.of(context).pop(project);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.all(20.0),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      title: Row(
        children: [
          Icon(Icons.folder_copy_outlined, color: colorScheme.primary, size: 28),
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
          onPressed: () => Navigator.of(context).pop(),
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
                  Text('Wystąpił błąd', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
                  const SizedBox(height: 8),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Spróbuj ponownie"),
                    onPressed: _loadProjects,
                  )
                ]),
          ));
    }

    if (_projects.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.work_off_outlined, size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Brak Projektów', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              // ZMIANA: Bardziej generyczny komunikat
              Text('Brak projektów do wyświetlenia.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          return _buildProjectListItem(project, theme);
        },
      ),
    );
  }

  Widget _buildProjectListItem(Project project, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(Icons.folder_shared_outlined, color: colorScheme.primary, size: 28),
        title: Text(
          project.name,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: project.description.isNotEmpty
            ? Text(
          project.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        )
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.primary),
        onTap: () => _selectProjectAndReturn(project),
        isThreeLine: project.description.isNotEmpty,
      ),
    );
  }
}