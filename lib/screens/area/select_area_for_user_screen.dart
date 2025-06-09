// lib/features/areas/presentation/screens/select_area_screen.dart
// (Dostosuj ścieżkę do swojej struktury projektu)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/services/project_member_service.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/work_entry.dart';
import '../../services/area_service.dart'; // Założenie: areaService jest dostępne globalnie lub przez DI
import '../../../widgets/dialogs.dart';
import '../../services/user_service.dart'; // Założenie, że dialogs.dart jest w lib/widgets/

class SelectAreaForUserScreen extends StatefulWidget { // <<<--- ZMIENIONA NAZWA KLASY
  final Project project;
  final WorkEntry? lastWorkTypeEntry;

  const SelectAreaForUserScreen({ // <<<--- ZMIENIONA NAZWA KLASY
    super.key,
    required this.project,
    this.lastWorkTypeEntry,
  });

  @override
  _SelectAreaForUserScreenState createState() => _SelectAreaForUserScreenState(); // <<<--- ZMIENIONA NAZWA KLASY STANU
}

class _SelectAreaForUserScreenState extends State<SelectAreaForUserScreen> { // <<<--- ZMIENIONA NAZWA KLASY STANU
  List<Area> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false; // Flaga dla operacji ładowania/dodawania

  // Założenie: areaService jest dostępne globalnie lub przez DI
  final AreaService areaService = AreaService();


  @override
  void initState() {
    super.initState();
    _getAreas();
  }

  Future<void> _getAreas() async {
    var user = await userService.getCurrentUser();
    var projectMember = await projectMemberService.getProjectMemberByProjectAndUser(widget.project.projectId, user?.uid??'');
    if (projectMember != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isProcessing = true;
      });
      try {
        _areas = await areaService.getAreasByIds(projectMember.areaIds);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e, stackTrace) {
        debugPrint('Błąd przy pobieraniu obszarów: $e\n$stackTrace');
        if (mounted) {
          final errorMessageText = 'Nie udało się załadować obszarów: ${e
              .toString()}';
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
  }


  void _selectAreaAndPop(Area area) {
    context.push('/area-work-types', extra: {
      'project': widget.project,
      'area': area,
      'lastWorkTypeEntry': widget.lastWorkTypeEntry,
    });
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
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Wybierz Obszar z: ${widget.project.name}',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
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
              onPressed: _isProcessing ? null : _getAreas,
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
                Text("Ładowanie obszarów...", style: theme.textTheme.titleMedium),
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
                  onPressed: _getAreas,
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_areas.isEmpty) {
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
                Icon(Icons.map_outlined, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 20),
                Text(
                  'Brak dostępu do stref w tym projekcie',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _getAreas,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _areas.length,
        itemBuilder: (context, index) {
          final area = _areas[index];
          return _buildAreaItem(area, theme);
        },
      ),
    );
  }

  Widget _buildAreaItem(Area area, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: area.active ? colorScheme.primary.withOpacity(0.5) : colorScheme.outline.withOpacity(0.2)),
      ),
      color: area.active ? colorScheme.primaryContainer.withOpacity(0.15) : null,
      child: ListTile(
        leading: Icon(
          area.active ? Icons.location_on_rounded : Icons.location_off_outlined,
          color: area.active ? colorScheme.primary : colorScheme.onSurfaceVariant,
          size: 36,
        ),
        title: Text(
          area.name,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (area.description.isNotEmpty)
              Text(
                area.description,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right_rounded, size: 24, color: colorScheme.primary),
        onTap: _isProcessing ? null : () => _selectAreaAndPop(area),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        isThreeLine: area.description.length > 40,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }
}