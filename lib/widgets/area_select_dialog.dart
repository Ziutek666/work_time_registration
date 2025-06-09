import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/services/project_member_service.dart'; // Dostosuj ścieżkę
import 'package:work_time_registration/widgets/work_type_selection_dialog.dart';
import '../../models/area.dart'; // Dostosuj ścieżkę
import '../../models/project.dart'; // Dostosuj ścieżkę
import '../../models/work_entry.dart'; // Dostosuj ścieżkę
import '../../models/user_app.dart'; // Dostosuj ścieżkę
import '../../services/area_service.dart'; // Dostosuj ścieżkę
import '../../services/user_service.dart';
import '../models/project_member.dart'; // Dostosuj ścieżkę
// widgets/dialogs.dart nie jest tu bezpośrednio potrzebny, chyba że ten dialog miałby pokazywać kolejne dialogi

class AreaSelectionDialog extends StatefulWidget {
  final Project project;
  final WorkEntry? lastWorkTypeEntry;

  const AreaSelectionDialog({
    super.key,
    required this.project,
    this.lastWorkTypeEntry,
  });

  @override
  State<AreaSelectionDialog> createState() => _AreaSelectionDialogState();
}

class _AreaSelectionDialogState extends State<AreaSelectionDialog> {
  List<Area> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingSelection = false;


  @override
  void initState() {
    super.initState();
    _loadAreasForProject();
  }

  Future<void> _loadAreasForProject() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _areas.clear();
    });

    try {
      UserApp? currentUser = await userService.getCurrentUser();
      if (currentUser == null || currentUser.uid == null || currentUser.uid!.isEmpty) {
        throw Exception("Nie udało się zidentyfikować bieżącego użytkownika.");
      }

      ProjectMember? projectMember = await projectMemberService.getProjectMemberByProjectAndUser(
        widget.project.projectId,
        currentUser.uid!,
      );

      if (projectMember != null && projectMember.areaIds.isNotEmpty) {
        _areas = await areaService.getAreasByIds(projectMember.areaIds);
        // Sortowanie: aktywne obszary najpierw, potem alfabetycznie
        _areas.sort((a, b) {
          if (a.active && !b.active) return -1;
          if (!a.active && b.active) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      } else {
        _areas = [];
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu obszarów dla projektu (dialog): $e\n$stackTrace');
      if (mounted) {
        _errorMessage = 'Nie udało się załadować obszarów: ${e.toString()}';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectAreaAndProceed(Area area) async {
    if (_isProcessingSelection || !mounted) return; // Nie rób nic dla nieaktywnych obszarów
    setState(() { _isProcessingSelection = true; });

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WorkTypeSelectionDialog(
          project: widget.project,
          area: area,
          lastActiveWorkEntry: widget.lastWorkTypeEntry,
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Zmniejszony padding dla contentu
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      title: Row(
        children: [
          Icon(Icons.map_outlined, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wybierz Obszar',
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
              Text("Ładowanie obszarów...", style: theme.textTheme.titleMedium),
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
              ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Spróbuj ponownie"),
                  onPressed: _loadAreasForProject,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onErrorContainer)
              )
            ],
          ),
        ),
      );
    }

    if (_areas.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_outlined, size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Brak Obszarów',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Brak dostępnych lub przypisanych obszarów dla tego projektu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessingSelection) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder( // Zmieniono na ListView.builder
              shrinkWrap: true,
              itemCount: _areas.length,
              itemBuilder: (context, index) {
                final area = _areas[index];
                return _buildAreaListItem(area, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaListItem(Area area, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isActive = area.active;
    final Color itemColor = colorScheme.primary;
    final Color textColor = colorScheme.onSurface;
    final Color subtitleColor = colorScheme.onSurfaceVariant;


    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: itemColor.withOpacity(0.5)),
      ), // Lekkie tło dla nieaktywnych
      child: ListTile(
        leading: Icon(
          Icons.location_on_rounded,
          color: itemColor,
          size: 28,
        ),
        title: Text(
          area.name,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: area.description.isNotEmpty
            ? Text(
          area.description,
          maxLines: 2, // Zwiększono maxLines dla opisu
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: subtitleColor),
        )
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: itemColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        onTap: () => _selectAreaAndProceed(area),
        isThreeLine: area.description.isNotEmpty, // Uproszczono warunek isThreeLine
      ),
    );
  }
}