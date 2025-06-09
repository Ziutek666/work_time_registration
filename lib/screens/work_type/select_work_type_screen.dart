// select_work_type_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Dostosuj ścieżki do swoich plików
import '../../models/work_type.dart';
import '../../services/work_type_service.dart';
import '../../repositories/work_type_repository.dart'; // Potrzebne do uproszczonej inicjalizacji serwisu
import '../../widgets/dialogs.dart'; // Załóżmy, że ten plik istnieje

class SelectWorkTypeScreen extends StatefulWidget {
  final String projectId;
  final String? filterType; // np. 'subtask_or_break', 'main'
  final List<String>? excludeIds; // NOWY PARAMETR: Lista ID do wykluczenia

  const SelectWorkTypeScreen({
    Key? key,
    required this.projectId,
    this.filterType,
    this.excludeIds, // Dodano do konstruktora
  }) : super(key: key);

  @override
  _SelectWorkTypeScreenState createState() => _SelectWorkTypeScreenState();
}

class _SelectWorkTypeScreenState extends State<SelectWorkTypeScreen> {
  List<WorkType> _displayedWorkTypes = []; // Zmieniono nazwę dla jasności
  bool _isLoading = true; // Zmieniono nazwę flagi
  String? _errorMessage; // Zmieniono nazwę flagi


  @override
  void initState() {
    super.initState();
    // Nie ma potrzeby używania addPostFrameCallback, jeśli _getWorkTypes obsługuje setState i mounted check.
    _getWorkTypes();
  }

  Future<void> _getWorkTypes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _displayedWorkTypes.clear();
    });
    try {
      List<WorkType> fetchedWorkTypes = [];
      if (widget.filterType == 'subtask_or_break') {
        fetchedWorkTypes = await workTypeService.getSubOrBreakWorkTypesForProject(widget.projectId);
      } else if (widget.filterType == 'main') {
        fetchedWorkTypes = await workTypeService.getMainWorkTypesForProject(widget.projectId);
      } else {
        fetchedWorkTypes = await workTypeService.getAllWorkTypesForProject(widget.projectId);
      }

      // Filtrowanie po stronie klienta na podstawie excludeIds
      if (widget.excludeIds != null && widget.excludeIds!.isNotEmpty) {
        fetchedWorkTypes.removeWhere((wt) => widget.excludeIds!.contains(wt.workTypeId));
      }

      // Sortowanie
      fetchedWorkTypes.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _displayedWorkTypes = fetchedWorkTypes;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Błąd przy pobieraniu typów pracy: $e');
      print(stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Błąd podczas pobierania typów pracy: ${e.toString()}';
        });
      }
    }
  }

  Widget _buildWorkTypesList(ThemeData theme) {
    if (_errorMessage != null) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16.0, color: theme.colorScheme.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                  onPressed: _getWorkTypes,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_displayedWorkTypes.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding( // Dodano Padding dla lepszego wyglądu
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'Brak dostępnych typów pracy spełniających kryteria.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          itemCount: _displayedWorkTypes.length,
          itemBuilder: (context, index) {
            final workType = _displayedWorkTypes[index];
            return _buildWorkTypeItem(workType, theme); // Przekazanie theme
          },
        ),
      );
    }
  }

  Widget _buildWorkTypeItem(WorkType workType, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    IconData leadingIconData;
    Color leadingIconColor = colorScheme.primary; // Domyślny kolor

    if (workType.isBreak) {
      leadingIconData = Icons.free_breakfast_outlined;
      leadingIconColor = Colors.orange.shade700;
    } else if (workType.isSubTask) {
      leadingIconData = Icons.low_priority_rounded;
      leadingIconColor = Colors.teal.shade600;
    } else {
      leadingIconData = Icons.work_history_outlined; // Ikona dla zadania głównego
    }

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: leadingIconColor.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: Icon(leadingIconData, color: leadingIconColor, size: 30),
        title: Text(
          workType.name,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (workType.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3.0, bottom: 5.0),
                child: Text(
                  workType.description,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Wrap( // Użycie Wrap dla lepszego układu chipów
              spacing: 6.0,
              runSpacing: 4.0,
              children: [
                Chip(
                  avatar: Icon(workType.isPaid ? Icons.attach_money : Icons.money_off, size: 14, color: workType.isPaid ? Colors.green.shade800 : Colors.red.shade800),
                  label: Text(workType.isPaid ? 'Płatne' : 'Niepłatne', style: TextStyle(fontSize: 11, color: workType.isPaid ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w500)),
                  backgroundColor: (workType.isPaid ? Colors.green.shade50 : Colors.red.shade50).withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
                if(workType.defaultDuration != null && workType.defaultDuration!.inMinutes > 0)
                  Chip(
                    avatar: Icon(Icons.timer_outlined, size: 14, color: colorScheme.secondary),
                    label: Text('${workType.defaultDuration!.inMinutes} min', style: TextStyle(fontSize: 11, color: colorScheme.secondary, fontWeight: FontWeight.w500)),
                    backgroundColor: colorScheme.secondaryContainer.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: leadingIconColor),
        isThreeLine: workType.description.isNotEmpty, // Uproszczenie warunku
        onTap: () {
          context.pop(workType);
        },
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); // Pobranie theme
    return Scaffold(
      appBar: AppBar(
        title: Text('Wybierz Typ Pracy${widget.filterType == "subtask_or_break" ? " (Akcję)" : (widget.filterType == "main" ? " (Główne)" : "")}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Zamknij",
          onPressed: () {
            context.pop();
          },
        ),
        // Można dodać akcję odświeżania, jeśli potrzebne
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _isLoading ? null : _getWorkTypes,
          ),
        ],
      ),
      body: Padding( // Dodano Padding wokół Column dla estetyki
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Wyśrodkowanie zawartości, jeśli lista jest krótka
          children: [
            // Można usunąć _topPanel(), jeśli AppBar jest wystarczający
            // _topPanel(),
            if (_isLoading) // Zmieniono z !dataLoaded na _isLoading
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildWorkTypesList(theme), // Przekazanie theme
          ],
        ),
      ),
    );
  }
}