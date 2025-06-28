import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/widgets/dialogs.dart';
import '../../models/area.dart';
import '../../services/area_service.dart';

class AreaSelectionDialog extends StatefulWidget {
  // ZMIANA: Dialog przyjmuje listę ID obszarów
  final List<String> areaIds;

  const AreaSelectionDialog({
    super.key,
    required this.areaIds,
  });

  @override
  State<AreaSelectionDialog> createState() => _AreaSelectionDialogState();
}

class _AreaSelectionDialogState extends State<AreaSelectionDialog> {
  List<Area> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  // ZMIANA: Logika pobiera obszary na podstawie przekazanej listy ID
  Future<void> _loadAreas() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.areaIds.isEmpty) {
        _areas = [];
      } else {
        // Używamy metody pobierającej obszary po liście ID
        _areas = await areaService.getAreasByIds(widget.areaIds);

        // Sortowanie: aktywne obszary najpierw, potem alfabetycznie
        _areas.sort((a, b) {
          if (a.active && !b.active) return -1;
          if (!a.active && b.active) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu obszarów (dialog): $e\n$stackTrace');
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

  Future<void> _selectAreaAndReturn(Area area) async {
    if(area.active == false){
      print('Wybrano obszar: ${area.active}');
      await showAlertDialog(context, 'Wybór lokalizacji', 'Obecnie ta lokalizacja nie jest aktywna');
      return;
    }
    context.pop(area);
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
          onPressed: () => context.pop(),
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
              Text('Wystąpił błąd', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Spróbuj ponownie"),
                onPressed: _loadAreas,
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
              Text('Brak Obszarów', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              // ZMIANA: Bardziej generyczny komunikat
              Text('Brak dostępnych obszarów do wyświetlenia.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _areas.length,
        itemBuilder: (context, index) {
          final area = _areas[index];
          return _buildAreaListItem(area, theme);
        },
      ),
    );
  }

  Widget _buildAreaListItem(Area area, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isActive = area.active;
    final Color itemColor = isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4);
    final Color? textColor = isActive ? null : colorScheme.onSurface.withOpacity(0.6);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: itemColor.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(Icons.location_on_outlined, color: itemColor, size: 28),
        title: Text(
          area.name,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: textColor,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: area.description.isNotEmpty
            ? Text(
          area.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: textColor?.withOpacity(0.8)),
        )
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: itemColor),
        onTap: () => _selectAreaAndReturn(area),
        isThreeLine: area.description.isNotEmpty,
      ),
    );
  }
}