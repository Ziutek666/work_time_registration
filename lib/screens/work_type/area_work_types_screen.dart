// lib/features/work_types/presentation/screens/area_work_types_screen.dart
// (Dostosuj ścieżkę do swojej struktury projektu)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Dla Timestamp
import 'package:intl/intl.dart'; // Dla formatowania daty

import '../../../widgets/dialogs.dart';
import '../../exceptions/work_entry_exceptions.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/work_entry.dart';
import '../../models/work_type.dart';
import '../../services/user_auth_service.dart';
import '../../services/work_entry_service.dart';
import '../../services/work_type_service.dart';


class AreaWorkTypesScreen extends StatefulWidget {
  final Project project;
  final Area area;
  final WorkEntry? lastActiveWorkEntry; // Ostatni *aktywny* wpis (gdzie isStart = true i nie ma jeszcze stopu)

  const AreaWorkTypesScreen({
    super.key,
    required this.project,
    required this.area,
    this.lastActiveWorkEntry,
  });

  @override
  State<AreaWorkTypesScreen> createState() => _AreaWorkTypesScreenState();
}

class _AreaWorkTypesScreenState extends State<AreaWorkTypesScreen> {
  List<WorkType> _displayableWorkTypes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableActions();
  }

  Future<void> _loadAvailableActions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isProcessingAction = true;
      _displayableWorkTypes.clear();
    });

    try {
      List<WorkType> allAreaWorkTypes = [];
      if (widget.area.workTypesIds.isNotEmpty) {
        allAreaWorkTypes = await workTypeService.getWorkTypesByIds(widget.area.workTypesIds);
      }

      if (widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart) {
        // Przypadek 1: Użytkownik nie ma aktywnej pracy LUB ostatnie zdarzenie było ZAKOŃCZENIEM.
        // Może rozpocząć tylko zadanie główne (nie przerwę, nie podzadanie).
        _displayableWorkTypes = allAreaWorkTypes.where((wt) => !wt.isBreak && !wt.isSubTask).toList();
        print('Logika: Brak aktywnej pracy lub ostatni był stop. Dostępne główne zadania: ${_displayableWorkTypes.map((e)=>e.name).join(', ')}');
      } else {
        // Przypadek 2: Użytkownik MA aktywny wpis pracy (lastActiveWorkEntry.isStart == true)
        final activeEntry = widget.lastActiveWorkEntry!;

        if (activeEntry.workTypeIsBreak || activeEntry.workTypeIsSubTask) {
          // Podprzypadek 2.A: Aktywna jest przerwa lub podzadanie.
          // Użytkownik może tylko zakończyć bieżącą przerwę/podzadanie.
          final currentWorkType = allAreaWorkTypes.firstWhere(
                  (wt) => wt.workTypeId == activeEntry.workTypeId,
              orElse: () {
                // Fallback: utwórz WorkType na podstawie snapshotu z WorkEntry, jeśli nie ma go w allAreaWorkTypes
                // To nie powinno się zdarzyć, jeśli workTypesIds w Area jest spójne z WorkEntry
                print("OSTRZEŻENIE: Nie znaleziono WorkType dla aktywnej przerwy/podzadania w allAreaWorkTypes. Używam danych ze snapshotu.");
                return WorkType(
                  workTypeId: activeEntry.workTypeId,
                  name: activeEntry.workTypeName,
                  description: activeEntry.workTypeDescription,
                  projectId: activeEntry.projectId,
                  isBreak: activeEntry.workTypeIsBreak,
                  isSubTask: activeEntry.workTypeIsSubTask,
                  isPaid: activeEntry.workTypeIsPaid, ownerId: '',
                );
              }
          );
          _displayableWorkTypes.add(currentWorkType);
          print('Logika: Aktywna przerwa/podzadanie (${activeEntry.workTypeName}). Dostępne: Zakończ ${_displayableWorkTypes.map((e)=>e.name).join(', ')}');
        } else {
          // Podprzypadek 2.B: Aktywne jest zadanie główne.
          // Użytkownik może zakończyć bieżące zadanie główne LUB rozpocząć przerwę LUB rozpocząć podzadanie.
          final currentMainTaskWorkType = allAreaWorkTypes.firstWhere(
                  (wt) => wt.workTypeId == activeEntry.workTypeId,
              orElse: () {
                print("OSTRZEŻENIE: Nie znaleziono WorkType dla aktywnego zadania głównego w allAreaWorkTypes. Używam danych ze snapshotu.");
                return WorkType(
                    workTypeId: activeEntry.workTypeId,
                    name: activeEntry.workTypeName,
                    description: activeEntry.workTypeDescription,
                    projectId: activeEntry.projectId,
                    isBreak: false, isSubTask: false,
                    isPaid: activeEntry.workTypeIsPaid, ownerId: '',
                );
              }
          );
          _displayableWorkTypes.add(currentMainTaskWorkType); // Opcja zakończenia

          // Dodaj wszystkie przerwy i podzadania z obszaru
          _displayableWorkTypes.addAll(allAreaWorkTypes.where((wt) => wt.isBreak || wt.isSubTask));
          print('Logika: Aktywne zadanie główne (${activeEntry.workTypeName}). Dostępne: Zakończ, Przerwy, Podzadania: ${_displayableWorkTypes.map((e)=>e.name).join(', ')}');
        }
      }

      final uniqueIds = <String>{};
      _displayableWorkTypes.retainWhere((wt) => uniqueIds.add(wt.workTypeId));

      _displayableWorkTypes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu i filtrowaniu typów pracy: $e\n$stackTrace');
      if (mounted) {
        final errorMessageText = 'Nie udało się załadować typów pracy: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessageText;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _handleWorkTypeSelection(WorkType selectedWorkType,Timestamp customEventTimestamp) async {
    if (_isProcessingAction) return;
    if (!mounted) return;

    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      await showErrorDialog(context, "Błąd użytkownika", "Nie można zidentyfikować użytkownika.");
      return;
    }
    final userId = currentUser.uid;

    setState(() { _isProcessingAction = true; });

    WorkEntry? resultToPop;
    String successMessage = "";
    bool isActuallyStartingNewEvent;

    try {
      final bool noActiveWork = widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart;

      if (noActiveWork) {
        // SCENARIUSZ 1: Rozpoczynamy nowe zadanie główne
        if (!selectedWorkType.isBreak && !selectedWorkType.isSubTask) {
          isActuallyStartingNewEvent = true;
          resultToPop = await workEntryService.recordWorkEvent(
            userId: userId,
            customEventTimestamp: customEventTimestamp,
            projectId: widget.project.projectId,
            areaId: widget.area.areaId,
            workTypeSnapshot: selectedWorkType,
            isStartingEvent: true,
          );
          successMessage = 'Rozpoczęto: ${selectedWorkType.name}';
        } else {
          throw Exception("Nie można rozpocząć pracy od przerwy lub podzadania, gdy nie ma aktywnego zadania głównego.");
        }
      } else {
        // SCENARIUSZ 2: Użytkownik ma aktywny wpis (widget.lastActiveWorkEntry.isStart == true)
        final activeEntry = widget.lastActiveWorkEntry!;

        if (selectedWorkType.workTypeId == activeEntry.workTypeId) {
          // Użytkownik wybrał zakończenie bieżącego zadania/przerwy/podzadania
          isActuallyStartingNewEvent = false;
          final workTypeSnapshotForStop = WorkType( // Tworzymy snapshot na podstawie aktywnego WorkEntry
            workTypeId: activeEntry.workTypeId,
            name: activeEntry.workTypeName,
            description: activeEntry.workTypeDescription, // Dla szablonu WorkType, to zdarzenie nie jest "inicjujące"
            isBreak: activeEntry.workTypeIsBreak,
            isPaid: activeEntry.workTypeIsPaid,
            projectId: activeEntry.projectId,
            isSubTask: activeEntry.workTypeIsSubTask,
            ownerId: '',
          );
          await workEntryService.recordWorkEvent(
            userId: userId,
            customEventTimestamp: customEventTimestamp,
            projectId: activeEntry.projectId,
            areaId: activeEntry.areaId,
            workTypeSnapshot: workTypeSnapshotForStop,
            isStartingEvent: false,
          );
          successMessage = 'Zakończono: ${activeEntry.workTypeName}';
          resultToPop = null;
        } else {
          // Użytkownik wybrał rozpoczęcie przerwy lub podzadania (gdy zadanie główne było aktywne)
          if (!activeEntry.workTypeIsBreak && !activeEntry.workTypeIsSubTask &&
              (selectedWorkType.isBreak || selectedWorkType.isSubTask)) {

            // 1. Zakończ bieżące zadanie główne
            final workTypeSnapshotForStopMain = WorkType(
              workTypeId: activeEntry.workTypeId, name: activeEntry.workTypeName, description: activeEntry.workTypeDescription,
              isBreak: activeEntry.workTypeIsBreak, isPaid: activeEntry.workTypeIsPaid,
              projectId: activeEntry.projectId, isSubTask: activeEntry.workTypeIsSubTask,
              ownerId: '',
            );
            await workEntryService.recordWorkEvent(
              userId: userId,
              customEventTimestamp: customEventTimestamp,
              projectId: activeEntry.projectId, areaId: activeEntry.areaId,
              workTypeSnapshot: workTypeSnapshotForStopMain, isStartingEvent: false,
            );

            // 2. Rozpocznij nową przerwę/podzadanie
            isActuallyStartingNewEvent = true;
            resultToPop = await workEntryService.recordWorkEvent(
              userId: userId,
              customEventTimestamp: customEventTimestamp,
              projectId: widget.project.projectId, areaId: widget.area.areaId,
              workTypeSnapshot: selectedWorkType, isStartingEvent: true,
            );
            successMessage = 'Rozpoczęto: ${selectedWorkType.name}';
          } else {
            throw Exception('Niedozwolona operacja lub błąd logiki filtrowania.');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMessage),
          backgroundColor: successMessage.startsWith("Rozpoczęto") ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        context.go('/');
      }

    } on ActiveWorkEntryExistsException catch (e) {
      debugPrint("Błąd: Aktywny wpis już istnieje - $e");
      if (mounted) await showErrorDialog(context, "Operacja Niedozwolona", e.message);
    } on NoActiveWorkEntryToStopException catch (e) {
      debugPrint("Błąd: Brak aktywnego wpisu do zatrzymania - $e");
      if (mounted) await showErrorDialog(context, "Operacja Niedozwolona", e.message);
    } catch (e) {
      debugPrint("Błąd podczas obsługi wyboru typu pracy: $e");
      if (mounted) await showErrorDialog(context, "Błąd Operacji", "Wystąpił błąd: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() { _isProcessingAction = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String appBarTitleText = 'Wybierz Akcję';
    if (widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart) {
      appBarTitleText = 'Rozpocznij Pracę';
    } else if (widget.lastActiveWorkEntry != null && widget.lastActiveWorkEntry!.isStart) {
      appBarTitleText = 'Wybierz Następną Akcję';
    }


    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj",
          onPressed: _isProcessingAction ? null : () {
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appBarTitleText,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Obszar: ${widget.area.name}',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isLoading || (_isProcessingAction && !_isLoading))
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
              tooltip: 'Odśwież listę akcji',
              onPressed: _isProcessingAction ? null : _loadAvailableActions,
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
    if (_isLoading) {
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
                Text("Ładowanie dostępnych akcji...", style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center( /* ... (obsługa błędu bez zmian) ... */ );
    }

    if (_displayableWorkTypes.isEmpty) {
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
                Icon(Icons.settings_suggest_outlined, size: 60, color: theme.colorScheme.error),
                const SizedBox(height: 20),
                Text(
                  'Błąd Konfiguracji',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Wystąpił błąd konfiguracji zadań dla obszaru "${widget.area.name}".\nBrak dostępnych akcji do wykonania.\n\nSkontaktuj się z administratorem systemu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  label: const Text('Wróć'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_isProcessingAction && !_isLoading)
          LinearProgressIndicator(
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
            color: theme.colorScheme.tertiary,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAvailableActions,
            color: theme.colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _displayableWorkTypes.length,
              itemBuilder: (context, index) {
                final workType = _displayableWorkTypes[index];
                return _buildWorkTypeItem(workType, theme);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkTypeItem(WorkType workType, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    bool isStopActionForCurrent = widget.lastActiveWorkEntry != null &&
        widget.lastActiveWorkEntry!.isStart &&
        workType.workTypeId == widget.lastActiveWorkEntry!.workTypeId;

    IconData leadingIconData;
    Color leadingIconColor = colorScheme.primary;
    String actionButtonText;
    Color actionButtonColor;
    IconData actionButtonIcon;

    if (isStopActionForCurrent) {
      leadingIconData = Icons.stop_circle_outlined;
      leadingIconColor = colorScheme.error;
      actionButtonText = 'Zakończ: ${workType.name}';
      actionButtonColor = colorScheme.error;
      actionButtonIcon = Icons.stop_rounded;
    } else {
      actionButtonText = 'Rozpocznij';
      actionButtonIcon = Icons.play_arrow_rounded;
      actionButtonColor = colorScheme.primary;

      if (workType.isBreak) {
        leadingIconData = Icons.free_breakfast_outlined;
        leadingIconColor = Colors.orange.shade700;
        actionButtonText = 'Rozpocznij przerwę';
        actionButtonColor = Colors.orange.shade700;
        actionButtonIcon = Icons.coffee_outlined;
      } else if (workType.isSubTask) {
        leadingIconData = Icons.assignment_turned_in_outlined;
        leadingIconColor = Colors.teal.shade600;
        actionButtonText = 'Rozpocznij podzadanie';
        actionButtonColor = Colors.teal.shade600;
        actionButtonIcon = Icons.low_priority_rounded;
      } else {
        leadingIconData = Icons.work_history_outlined;
      }
    }

    return Card(
        elevation: 3.0,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(leadingIconData, color: leadingIconColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      workType.name,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (!isStopActionForCurrent && workType.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  workType.description,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              if (!isStopActionForCurrent)
                Wrap(
                  spacing: 6.0,
                  runSpacing: 2.0,
                  children: [
                    Chip(
                      avatar: Icon(workType.isPaid ? Icons.attach_money_outlined : Icons.money_off_outlined, size: 14, color: workType.isPaid ? Colors.green.shade800 : Colors.red.shade800),
                      label: Text(workType.isPaid ? 'Płatne' : 'Niepłatne', style: TextStyle(fontSize: 10, color: workType.isPaid ? Colors.green.shade800 : Colors.red.shade800)),
                      backgroundColor: workType.isPaid ? Colors.green.shade50.withOpacity(0.7) : Colors.red.shade50.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                    if (workType.defaultDuration != null && workType.defaultDuration!.inMinutes > 0)
                      Chip(
                        avatar: Icon(Icons.timer_outlined, size: 14, color: colorScheme.secondary),
                        label: Text('${workType.defaultDuration!.inMinutes} min', style: TextStyle(fontSize: 10, color: colorScheme.secondary)),
                        backgroundColor: colorScheme.secondaryContainer.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: Icon(actionButtonIcon, size: 18),
                  label: Text(actionButtonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _isProcessingAction ? null : () => _handleWorkTypeSelection(workType, Timestamp.now()),
                ),
              ),
            ],
          ),
        )
    );
  }
}
