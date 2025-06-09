// work_types_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Dostosuj ścieżki do swoich plików
import '../../models/license.dart';
import '../../models/project.dart';
import '../../models/work_type.dart';
import '../../services/work_type_service.dart';
import '../../repositories/work_type_repository.dart'; // Założenie: ten plik istnieje
import '../../widgets/dialogs.dart'; // Dla showErrorDialog, showSuccessDialog itp.

class WorkTypesScreen extends StatefulWidget {
  final Project project;
  final License? license;

  const WorkTypesScreen({
    super.key,
    required this.project,
    this.license,
  });

  @override
  _WorkTypesScreenState createState() => _WorkTypesScreenState();
}

class _WorkTypesScreenState extends State<WorkTypesScreen> with SingleTickerProviderStateMixin { // Dodano SingleTickerProviderStateMixin
  List<WorkType> _allWorkTypes = [];
  bool _dataLoaded = false;
  String? _errorLoadingData;
  bool _isProcessing = false;

  // TabController do zarządzania zakładkami
  late TabController _tabController;

  // Filtrowane listy dla każdej zakładki
  List<WorkType> _mainWorkTypes = [];
  List<WorkType> _subTaskWorkTypes = [];
  List<WorkType> _breakWorkTypes = [];

  final WorkTypeService workTypeService = WorkTypeService(WorkTypeRepository());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection); // Nasłuchuj zmiany zakładek, jeśli potrzebne do dynamicznych akcji
    _getWorkTypes();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      // Możesz tu dodać logikę, jeśli coś ma się dziać przy zmianie zakładki,
      // np. zmiana etykiety FAB (choć w tym przypadku FAB jest spójny)
      if(mounted) setState(() {}); // Odśwież UI, jeśli np. FAB ma dynamiczną etykietę
    }
  }


  Future<void> _getWorkTypes() async {
    if (!mounted) return;
    setState(() {
      _dataLoaded = false;
      _errorLoadingData = null;
      _isProcessing = true;
    });
    try {
      if (widget.project.projectId.isEmpty) {
        throw Exception("ID projektu jest puste.");
      }
      _allWorkTypes = await workTypeService.getAllWorkTypesForProject(widget.project.projectId);
      _filterWorkTypes(); // Filtruj po pobraniu
      if (!mounted) return;
      setState(() {
        _dataLoaded = true;
      });
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu typów pracy: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _dataLoaded = true;
          _errorLoadingData = 'Nie udało się załadować typów pracy: ${e.toString()}';
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

  void _filterWorkTypes() {
    _mainWorkTypes = _allWorkTypes.where((wt) => !wt.isBreak && !wt.isSubTask).toList();
    _subTaskWorkTypes = _allWorkTypes.where((wt) => wt.isSubTask).toList();
    _breakWorkTypes = _allWorkTypes.where((wt) => wt.isBreak).toList();

    // Sortowanie każdej listy alfabetycznie
    _mainWorkTypes.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _subTaskWorkTypes.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _breakWorkTypes.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _createNewWorkType() async {
    // Ustal, jaki typ pracy tworzyć na podstawie aktywnej zakładki
    bool isCreatingBreak = false;
    bool isCreatingSubTask = false;
    String workTypeCategory = "main"; // Domyślnie

    switch (_tabController.index) {
      case 0: // Praca główna
      // isCreatingBreak = false; isCreatingSubTask = false;
        workTypeCategory = "main";
        break;
      case 1: // Podzadanie
        isCreatingSubTask = true;
        workTypeCategory = "subtask";
        break;
      case 2: // Przerwa
        isCreatingBreak = true;
        workTypeCategory = "break";
        break;
    }

    // Sprawdzenie limitu typów pracy z licencji (ogólnie, nie per kategoria)
    if (widget.license != null && _allWorkTypes.length >= widget.license!.workTypes) {
      await showInfoDialog(
        context,
        'Limit osiągnięty',
        'Osiągnięto maksymalną liczbę typów pracy (${widget.license!.workTypes}) dozwoloną przez Twoją licencję.',
      );
      return;
    }

    // Przekaż informację o typie do ekranu tworzenia
    var changed = await context.push('/create_work_type', extra: {
      'project': widget.project,
      'isBreak': isCreatingBreak,
      'isSubTask': isCreatingSubTask,
      'workTypeCategory': workTypeCategory, // Dodatkowy parametr dla jasności na ekranie tworzenia
    }) as bool?;

    if (changed == true && mounted) {
      await _getWorkTypes();
    }
  }

  Future<void> _editWorkType(WorkType workType) async {
    // Przekazujemy edytowany workType, ekran edycji powinien obsłużyć jego właściwości
    var changed = await context.push(
      '/edit_work_type',
      extra: workType,
    ) as bool?;

    if (changed == true && mounted) {
      await _getWorkTypes();
    }
  }

  Future<void> _deleteWorkType(WorkType workType) async {
    final confirm = await showDeleteConfirmationDialog(
      context,
      'Potwierdź usunięcie',
      'Czy na pewno chcesz usunąć typ pracy "${workType.name}"?',
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isProcessing = true);
      try {
        await workTypeService.deleteWorkType(workType.workTypeId);
        if (mounted) {
          await showSuccessDialog(context,'Usunięto!', 'Typ pracy "${workType.name}" został pomyślnie usunięty.');
          await _getWorkTypes();
        }
      } catch (e) {
        debugPrint('Błąd usuwania typu pracy: $e');
        if (mounted) {
          await showErrorDialog(context, 'Błąd usuwania', 'Nie udało się usunąć typu pracy: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String fabLabel = 'Dodaj Typ Pracy';

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
          'Typy Pracy: ${widget.project.name}',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isProcessing && !_dataLoaded)
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
              onPressed: _isProcessing ? null : _getWorkTypes,
            ),
        ],
        // Dodanie TabBar na dole AppBar
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: colorScheme.secondary, // Kolor wskaźnika aktywnej zakładki
          indicatorWeight: 3.0,
          tabs: const [
            Tab(icon: Icon(Icons.work_outline), text: 'Główne'),
            Tab(icon: Icon(Icons.low_priority_rounded), text: 'Podzadania'),
            Tab(icon: Icon(Icons.free_breakfast_outlined), text: 'Przerwy'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewWorkType,
        tooltip: fabLabel, // Użycie dynamicznej etykiety lub stałej
        icon: const Icon(Icons.add),
        label: Text(fabLabel), // Użycie dynamicznej etykiety lub stałej
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.onTertiary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.6), // Użycie container colors
              theme.colorScheme.secondaryContainer.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // Użycie TabBarView do wyświetlania zawartości zakładek
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWorkTypeList(_mainWorkTypes, theme, 'Główne Typy Pracy'),
            _buildWorkTypeList(_subTaskWorkTypes, theme, 'Podzadania'),
            _buildWorkTypeList(_breakWorkTypes, theme, 'Typy Przerw'),
          ],
        ),
      ),
    );
  }

  // Zmiana _buildBodyContent na _buildWorkTypeList, która przyjmuje listę i tytuł
  Widget _buildWorkTypeList(List<WorkType> workTypes, ThemeData theme, String noDataMessageSuffix) {
    if (_isProcessing && !_dataLoaded) {
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
                Text("Ładowanie...", style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorLoadingData != null) {
      return Center( /* ... (obsługa błędu jak wcześniej) ... */ );
    }

    if (workTypes.isEmpty) {
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
                Icon(Icons.work_off_outlined, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 20),
                Text(
                  'Brak zdefiniowanych typów: $noDataMessageSuffix',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Naciśnij przycisk "+" aby dodać nowy typ dla tej kategorii.',
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
      onRefresh: _getWorkTypes,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 80.0), // Padding dla FAB
        itemCount: workTypes.length,
        itemBuilder: (context, index) {
          final workType = workTypes[index];
          return _buildWorkTypeItem(workType, theme);
        },
      ),
    );
  }

  Widget _buildWorkTypeItem(WorkType workType, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    IconData leadingIconData;
    Color leadingIconColor = colorScheme.primary;

    if (workType.isBreak) {
      leadingIconData = Icons.free_breakfast_outlined;
      leadingIconColor = Colors.orange.shade700;
    } else if (workType.isSubTask) {
      leadingIconData = Icons.low_priority_rounded; // Zmieniona ikona dla podzadania
      leadingIconColor = Colors.teal.shade600;
    } else {
      leadingIconData = Icons.work_history_outlined;
    }

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6.0), // Usunięto margines poziomy
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: leadingIconColor.withOpacity(0.3)), // Ramka w kolorze ikony
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _editWorkType(workType),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: leadingIconColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                    child: Icon(leadingIconData, color: leadingIconColor, size: 32),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workType.name,
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (workType.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              workType.description,
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildInfoChip(
                    theme,
                    icon: workType.isPaid ? Icons.attach_money_outlined : Icons.money_off_outlined,
                    label: workType.isPaid ? 'Płatne' : 'Niepłatne',
                    iconColor: workType.isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    backgroundColor: (workType.isPaid ? Colors.green.shade50 : Colors.red.shade50).withOpacity(0.7),
                  ),
                  // Nie pokazujemy chipów "Przerwa" / "Podzadanie" tutaj, bo są już w osobnych zakładkach
                  if (workType.defaultDuration != null && workType.defaultDuration!.inMinutes > 0)
                    _buildInfoChip(
                      theme,
                      icon: Icons.timer_outlined,
                      label: '${workType.defaultDuration!.inMinutes} min (domyślnie)',
                      iconColor: colorScheme.secondary,
                      backgroundColor: colorScheme.secondaryContainer.withOpacity(0.3),
                    ),
                ],
              ),
              const Divider(height: 20, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.edit_outlined, size: 18, color: colorScheme.secondary),
                    label: Text('Edytuj', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                    onPressed: _isProcessing ? null : () => _editWorkType(workType),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                    label: Text('Usuń', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600)),
                    onPressed: _isProcessing ? null : () => _deleteWorkType(workType),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, {required IconData icon, required String label, Color? iconColor, Color? backgroundColor}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
      label: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: iconColor ?? theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
      backgroundColor: (backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5)).withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelPadding: const EdgeInsets.only(left: 4, right: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none // Usunięto ramkę z chipa dla czystszego wyglądu
        // side: BorderSide(color: (iconColor ?? theme.colorScheme.outline).withOpacity(0.3))
      ),
    );
  }
}