// lib/features/areas/presentation/screens/areas_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/area.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../services/area_service.dart'; // Założenie: areaService jest dostępne globalnie lub przez DI
import '../../../widgets/dialogs.dart'; // Założenie, że dialogs.dart jest w lib/widgets/

// Założenie: areaService jest dostępne globalnie lub przez DI
// final AreaService areaService = AreaService();

class AreasScreen extends StatefulWidget {
  final Project project;
  final License? license; // Licencja może być opcjonalna

  const AreasScreen({
    super.key, // Dodano super.key
    required this.project,
    this.license,
  }) : super();

  @override
  _AreasScreenState createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  List<Area> _areas = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false; // Flaga dla operacji ładowania/dodawania

  @override
  void initState() {
    super.initState();
    // Usunięto WidgetsBinding.instance.addPostFrameCallback dla uproszczenia
    _getAreas();
  }

  Future<void> _getAreas() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isProcessing = true;
    });
    try {
      _areas = await areaService.getAreasByProject(widget.project.projectId);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu stref: $e\n$stackTrace');
      if (mounted) {
        final errorMessageText = 'Nie udało się załadować stref: ${e.toString()}';
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

  Future<void> _createNewArea() async {
    if (widget.license != null && _areas.length >= widget.license!.areas) {
      await showInfoDialog(
        context,
        'Limit Osiągnięty',
        'Osiągnięto maksymalną liczbę obszarów (${widget.license!.areas}) dozwoloną przez Twoją licencję.',
      );
      return;
    }
    var changed = await context.push('/create-area', extra: widget.project) as bool?;
    if (changed == true && mounted) {
      await _getAreas(); // Odśwież listę, jeśli coś się zmieniło
    }
  }

  Future<void> _editArea(Area area) async {
    // Przejście do ekranu edycji obszaru
    // Założenie: trasa '/editArea' istnieje i przyjmuje obiekt Area jako 'extra'
    var changed = await context.push('/edit-area', extra: area) as bool?;
    if (changed == true && mounted) {
      await _getAreas(); // Odśwież listę, jeśli coś się zmieniło
    }
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
          tooltip: "Wróć do menu projektu",
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Obszary: ${widget.project.name}',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewArea,
        tooltip: 'Dodaj nowy obszar',
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Dodaj obszar'),
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.onTertiary,
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
                  'Brak zdefiniowanych obszarów',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Naciśnij przycisk "+" aby dodać nowy obszar dla tego projektu.',
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
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _editArea(area),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Zwiększony padding dla lepszego wyglądu
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Wyśrodkowanie w pionie
            children: [
              Icon(Icons.place_outlined, color: colorScheme.primary, size: 36),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      area.name,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (area.description.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        area.description,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6.0),
                    Text(
                      'ID: ${area.areaId}',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
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