import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../models/work_type.dart';
import '../../services/work_type_service.dart';
import '../../repositories/work_type_repository.dart';
import '../../widgets/dialogs.dart';

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

class _WorkTypesScreenState extends State<WorkTypesScreen> with SingleTickerProviderStateMixin {
  List<WorkType> _allWorkTypes = [];
  bool _dataLoaded = false;
  String? _errorLoadingData;
  bool _isProcessing = false;

  late TabController _tabController;

  List<WorkType> _mainWorkTypes = [];
  List<WorkType> _checkPointWorkTypes = [];
  List<WorkType> _subTaskWorkTypes = [];
  List<WorkType> _breakWorkTypes = [];

  final WorkTypeService workTypeService = WorkTypeService(WorkTypeRepository());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {})); // Prostszy listener do odświeżania UI
    _getWorkTypes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getWorkTypes() async {
    if (!mounted) return;
    setState(() { _dataLoaded = false; _errorLoadingData = null; _isProcessing = true; });
    try {
      _allWorkTypes = await workTypeService.getAllWorkTypesForProject(widget.project.projectId);
      _filterWorkTypes();
    } catch (e) {
      if (mounted) _errorLoadingData = 'Nie udało się załadować typów pracy: ${e.toString()}';
    } finally {
      if (mounted) setState(() { _dataLoaded = true; _isProcessing = false; });
    }
  }

  void _filterWorkTypes() {
    _mainWorkTypes = _allWorkTypes.where((wt) => wt.isMain).toList();
    _checkPointWorkTypes = _allWorkTypes.where((wt) => wt.isCheckPoint).toList();
    _subTaskWorkTypes = _allWorkTypes.where((wt) => wt.isSubTask && !wt.isCheckPoint).toList();
    _breakWorkTypes = _allWorkTypes.where((wt) => wt.isBreak).toList();

    // Sortowanie list
    for (var list in [_mainWorkTypes, _checkPointWorkTypes, _subTaskWorkTypes, _breakWorkTypes]) {
      list.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  // ZMIANA: Uproszczona logika przekazywania parametrów
  Future<void> _createNewWorkType() async {
    if (widget.license != null && _allWorkTypes.length >= widget.license!.workTypes) {
      await showInfoDialog(context, 'Limit osiągnięty', 'Osiągnięto maksymalną liczbę typów pracy (${widget.license!.workTypes}) dozwoloną przez Twoją licencję.');
      return;
    }

    String workTypeIs = 'main'; // Domyślna wartość
    switch (_tabController.index) {
      case 0: workTypeIs = "main"; break;
      case 1: workTypeIs = "subtask"; break;
      case 2: workTypeIs = "break"; break;
      case 3: workTypeIs = "checkpoint"; break;
    }

    var changed = await context.push('/create_work_type', extra: {
      'project': widget.project,
      'workTypeIs': workTypeIs, // Przekazujemy jeden, czytelny parametr
    }) as bool?;

    if (changed == true && mounted) {
      await _getWorkTypes();
    }
  }

  Future<void> _editWorkType(WorkType workType) async {
    var changed = await context.push('/edit_work_type', extra: workType) as bool?;
    if (changed == true && mounted) await _getWorkTypes();
  }

  Future<void> _deleteWorkType(WorkType workType) async {
    final confirm = await showDeleteConfirmationDialog(context, 'Potwierdź usunięcie', 'Czy na pewno chcesz usunąć typ pracy "${workType.name}"?');
    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      await workTypeService.deleteWorkType(workType.workTypeId);
      if (mounted) {
        await showSuccessDialog(context,'Usunięto!', 'Typ pracy "${workType.name}" został pomyślnie usunięty.');
        await _getWorkTypes();
      }
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Błąd usuwania', 'Nie udało się usunąć typu pracy: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
        title: Text('Typy Pracy: ${widget.project.name}', overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); }),
        actions: [
          if (_isProcessing && !_dataLoaded)
            const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))))
          else
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Odśwież listę', onPressed: _isProcessing ? null : _getWorkTypes),
        ],
        bottom: TabBar(
          // --- DODAJ TE WŁAŚCIWOŚCI ---
          labelColor: Colors.white, // Kolor tekstu aktywnej zakładki
          unselectedLabelColor: Colors.white.withOpacity(0.75), // Kolor tekstu nieaktywnych zakładek (lekko przezroczysty)
          indicatorColor: Colors.white,
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.work_outline,color: Colors.white,), text: 'Główne'),
            Tab(icon: Icon(Icons.low_priority_rounded, color: Colors.white), text: 'Podzadania'),
            Tab(icon: Icon(Icons.free_breakfast_outlined, color: Colors.white), text: 'Przerwy'),
            Tab(icon: Icon(Icons.flag_outlined, color: Colors.white), text: 'Pkt. kontrolne'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewWorkType,
        label: const Text('Dodaj Typ Pracy'),
        icon: const Icon(Icons.add),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ theme.colorScheme.primaryContainer.withOpacity(0.6), theme.colorScheme.secondaryContainer.withOpacity(0.4) ],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWorkTypeList(_mainWorkTypes, theme, 'Główne'),
            _buildWorkTypeList(_subTaskWorkTypes, theme, 'Podzadania'),
            _buildWorkTypeList(_breakWorkTypes, theme, 'Przerwy'),
            _buildWorkTypeList(_checkPointWorkTypes, theme, 'Punkty Kontrolne'),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTypeList(List<WorkType> workTypes, ThemeData theme, String noDataMessageSuffix) {
    if (_isProcessing && !_dataLoaded) return const Center(child: CircularProgressIndicator());
    if (_errorLoadingData != null) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorLoadingData!)));
    if (workTypes.isEmpty) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined, size: 60, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text('Brak zdefiniowanych typów: $noDataMessageSuffix', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Naciśnij przycisk "+" aby dodać nowy typ dla tej kategorii.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
    return RefreshIndicator(
      onRefresh: _getWorkTypes,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 96.0),
        itemCount: workTypes.length,
        itemBuilder: (context, index) => _buildWorkTypeItem(workTypes[index], theme),
      ),
    );
  }

  Widget _buildWorkTypeItem(WorkType workType, ThemeData theme) {
    IconData leadingIconData;
    Color leadingIconColor = theme.colorScheme.primary;

    if (workType.isCheckPoint) {
      leadingIconData = Icons.flag_outlined;
      leadingIconColor = Colors.blue.shade700;
    } else if (workType.isBreak) {
      leadingIconData = Icons.free_breakfast_outlined;
      leadingIconColor = Colors.orange.shade700;
    } else if (workType.isSubTask) {
      leadingIconData = Icons.low_priority_rounded;
      leadingIconColor = Colors.teal.shade600;
    } else { // isMain
      leadingIconData = Icons.work_history_outlined;
    }

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: leadingIconColor.withOpacity(0.3))),
      child: InkWell(
        onTap: _isProcessing ? null : () => _editWorkType(workType),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2.0, right: 12.0), child: Icon(leadingIconData, color: leadingIconColor, size: 32)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workType.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (workType.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(workType.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                  _buildInfoChip(theme, icon: workType.isPaid ? Icons.attach_money_outlined : Icons.money_off_outlined, label: workType.isPaid ? 'Płatne' : 'Niepłatne', iconColor: workType.isPaid ? Colors.green.shade700 : Colors.red.shade700),
                  if (workType.isRequired)
                    _buildInfoChip(theme, icon: Icons.rule_folder_outlined, label: 'Wymagane', iconColor: theme.colorScheme.error),
                  if (workType.defaultDuration != null && workType.defaultDuration!.inMinutes > 0)
                    _buildInfoChip(theme, icon: Icons.timer_outlined, label: '${workType.defaultDuration!.inMinutes} min', iconColor: theme.colorScheme.secondary),
                ],
              ),
              const Divider(height: 20, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edytuj'), onPressed: _isProcessing ? null : () => _editWorkType(workType)),
                  const SizedBox(width: 8),
                  TextButton.icon(icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error), label: Text('Usuń', style: TextStyle(color: theme.colorScheme.error)), onPressed: _isProcessing ? null : () => _deleteWorkType(workType)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, {required IconData icon, required String label, Color? iconColor}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: iconColor),
      label: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: iconColor)),
      visualDensity: VisualDensity.compact,
    );
  }
}