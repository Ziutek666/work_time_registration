import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Dla Timestamp
import 'package:work_time_registration/functions/global-functions.dart';
// import 'package:intl/intl.dart'; // Dla formatowania daty, jeśli potrzebne w tym dialogu

import '../../widgets/dialogs.dart'; // Założenie: ścieżka do dialogs.dart
import '../../exceptions/work_entry_exceptions.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/work_entry.dart';
import '../../models/work_type.dart';
import '../../services/user_auth_service.dart'; // Założenie: ścieżka do serwisu
import '../../services/work_entry_service.dart'; // Założenie: ścieżka do serwisu
import '../../services/work_type_service.dart';
import '../models/information.dart';
import '../services/information_service.dart'; // Założenie: ścieżka do serwisu

class WorkTypeSelectionDialog extends StatefulWidget {
  final Project project;
  final Area area;
  final WorkEntry? lastActiveWorkEntry;

  const WorkTypeSelectionDialog({
    super.key,
    required this.project,
    required this.area,
    this.lastActiveWorkEntry,
  });

  @override
  State<WorkTypeSelectionDialog> createState() => _WorkTypeSelectionDialogState();
}

class _WorkTypeSelectionDialogState extends State<WorkTypeSelectionDialog> {
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
      _displayableWorkTypes.clear();
    });

    try {
      List<WorkType> allAreaWorkTypes = [];
      if (widget.area.workTypesIds.isNotEmpty) {
        allAreaWorkTypes = await workTypeService.getWorkTypesByIds(widget.area.workTypesIds);
      }

      if (widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart) {
        _displayableWorkTypes = allAreaWorkTypes.where((wt) => !wt.isBreak && !wt.isSubTask).toList();
      } else {
        final activeEntry = widget.lastActiveWorkEntry!;
        if (activeEntry.workTypeIsBreak || activeEntry.workTypeIsSubTask) {
          final currentWorkType = allAreaWorkTypes.firstWhere(
                (wt) => wt.workTypeId == activeEntry.workTypeId,
            orElse: () => WorkType(
              workTypeId: activeEntry.workTypeId, name: activeEntry.workTypeName,
              description: activeEntry.workTypeDescription, projectId: activeEntry.projectId,
              isBreak: activeEntry.workTypeIsBreak, isSubTask: activeEntry.workTypeIsSubTask,
              isPaid: activeEntry.workTypeIsPaid, ownerId: '',
            ),
          );
          _displayableWorkTypes.add(currentWorkType);
        } else {
          final currentMainTaskWorkType = allAreaWorkTypes.firstWhere(
                (wt) => wt.workTypeId == activeEntry.workTypeId,
            orElse: () => WorkType(
              workTypeId: activeEntry.workTypeId, name: activeEntry.workTypeName,
              description: activeEntry.workTypeDescription, projectId: activeEntry.projectId,
              isBreak: false, isSubTask: false, isPaid: activeEntry.workTypeIsPaid, ownerId: '',
            ),
          );
          _displayableWorkTypes.add(currentMainTaskWorkType);
          _displayableWorkTypes.addAll(allAreaWorkTypes.where((wt) => wt.isBreak || wt.isSubTask));
        }
      }

      final uniqueIds = <String>{};
      _displayableWorkTypes.retainWhere((wt) => uniqueIds.add(wt.workTypeId));
      _displayableWorkTypes.sort((a, b) {
        // Sortowanie: najpierw akcja zakończenia, potem alfabetycznie
        bool aIsStop = widget.lastActiveWorkEntry != null && widget.lastActiveWorkEntry!.isStart && a.workTypeId == widget.lastActiveWorkEntry!.workTypeId;
        bool bIsStop = widget.lastActiveWorkEntry != null && widget.lastActiveWorkEntry!.isStart && b.workTypeId == widget.lastActiveWorkEntry!.workTypeId;
        if (aIsStop && !bIsStop) return -1;
        if (!aIsStop && bIsStop) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });


    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu i filtrowaniu typów pracy (dialog): $e\n$stackTrace');
      if (mounted) _errorMessage = 'Nie udało się załadować typów pracy: ${e.toString()}';
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleWorkTypeSelection(WorkType selectedWorkType) async {
    if (_isProcessingAction) return;
    if (!mounted) return;

    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      await showErrorDialog(context, "Błąd użytkownika", "Nie można zidentyfikować użytkownika.");
      return;
    }
    final userId = currentUser.uid;

    setState(() { _isProcessingAction = true; });

    String successMessage = "";
    bool actionSuccessful = false;

    try {
      final bool noActiveWork = widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart;

      if (noActiveWork) {
        if (!selectedWorkType.isBreak && !selectedWorkType.isSubTask) {
          List<Information> infoList = [];
          infoList = await informationService.getInformationByIdsShowOnStart(selectedWorkType.informationIds);
           var infoListToWrite = await processInformationListWithDialogs(context: context, informationsToProcess: infoList);
           if (infoListToWrite == null) {
             actionSuccessful = false;
           }else {
             await workEntryService.recordWorkEvent(
               userId: userId,
               projectId: widget.project.projectId,
               areaId: widget.area.areaId,
               workTypeSnapshot: selectedWorkType,
               isStartingEvent: true,
               relatedInformations: infoListToWrite,
             );
             successMessage = 'Rozpoczęto: ${selectedWorkType.name}';
             actionSuccessful = true;
           }
        } else {
          throw Exception("Nie można rozpocząć pracy od przerwy lub podzadania.");
        }
      } else {
        final activeEntry = widget.lastActiveWorkEntry!;
        if (selectedWorkType.workTypeId == activeEntry.workTypeId) {
          final workTypeSnapshotForStop = WorkType(
            workTypeId: activeEntry.workTypeId, name: activeEntry.workTypeName,
            description: activeEntry.workTypeDescription, isBreak: activeEntry.workTypeIsBreak,
            isPaid: activeEntry.workTypeIsPaid, projectId: activeEntry.projectId,
            isSubTask: activeEntry.workTypeIsSubTask, ownerId: '',
            defaultDuration: activeEntry.workTypeDefaultDurationInSeconds != null ? Duration(seconds: activeEntry.workTypeDefaultDurationInSeconds!) : null,
          );
          await workEntryService.recordWorkEvent(
            userId: userId, projectId: activeEntry.projectId, areaId: activeEntry.areaId,
            workTypeSnapshot: workTypeSnapshotForStop, isStartingEvent: false,
          );
          successMessage = 'Zakończono: ${activeEntry.workTypeName}';
          actionSuccessful = true;
        } else {
          if (!activeEntry.workTypeIsBreak && !activeEntry.workTypeIsSubTask &&
              (selectedWorkType.isBreak || selectedWorkType.isSubTask)) {
            final workTypeSnapshotForStopMain = WorkType(
              workTypeId: activeEntry.workTypeId, name: activeEntry.workTypeName, description: activeEntry.workTypeDescription,
              isBreak: activeEntry.workTypeIsBreak, isPaid: activeEntry.workTypeIsPaid,
              projectId: activeEntry.projectId, isSubTask: activeEntry.workTypeIsSubTask,
              ownerId: '',
              defaultDuration: activeEntry.workTypeDefaultDurationInSeconds != null ? Duration(seconds: activeEntry.workTypeDefaultDurationInSeconds!) : null,
            );
            await workEntryService.recordWorkEvent(
              userId: userId, projectId: activeEntry.projectId, areaId: activeEntry.areaId,
              workTypeSnapshot: workTypeSnapshotForStopMain, isStartingEvent: false,
            );
            await workEntryService.recordWorkEvent(
              userId: userId, projectId: widget.project.projectId, areaId: widget.area.areaId,
              workTypeSnapshot: selectedWorkType, isStartingEvent: true,
            );
            successMessage = 'Rozpoczęto: ${selectedWorkType.name}';
            actionSuccessful = true;
          } else {
            throw Exception('Niedozwolona operacja lub błąd logiki.');
          }
        }
      }

      if (mounted && actionSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMessage),
          backgroundColor: successMessage.startsWith("Rozpoczęto") ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }

    } on ActiveWorkEntryExistsException catch (e) {
      debugPrint("Błąd: Aktywny wpis już istnieje - $e");
      if (mounted) await showErrorDialog(context, "Operacja Niedozwolona", e.message);
    } on NoActiveWorkEntryToStopException catch (e) {
      debugPrint("Błąd: Brak aktywnego wpisu do zatrzymania - $e");
      if (mounted) await showErrorDialog(context, "Operacja Niedozwolona", e.message);
    } catch (e) {
      debugPrint("Błąd podczas obsługi wyboru typu pracy (dialog): $e");
      if (mounted) await showErrorDialog(context, "Błąd Operacji", "Wystąpił błąd: ${e.toString()}");
    } finally {
      if (mounted) setState(() { _isProcessingAction = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String dialogTitleText = 'Wybierz Akcję';
    if (widget.lastActiveWorkEntry == null || !widget.lastActiveWorkEntry!.isStart) {
      dialogTitleText = 'Rozpocznij Pracę w Obszarze';
    } else if (widget.lastActiveWorkEntry != null && widget.lastActiveWorkEntry!.isStart) {
      dialogTitleText = 'Wybierz Następną Akcję';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Zmniejszony padding dla contentu
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dialogTitleText,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40.0, top: 4.0),
            child: Text(
              'Obszar: ${widget.area.name}',
              style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite, // Aby dialog próbował zająć dostępną szerokość
        child: _buildDialogContent(theme),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Anuluj', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          onPressed: _isProcessingAction ? null : () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    if (_isLoading) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 180),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text("Ładowanie dostępnych akcji...", style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 180),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text('Wystąpił błąd', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Spróbuj ponownie"),
                  onPressed: _loadAvailableActions,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onErrorContainer)
              )
            ],
          ),
        ),
      );
    }

    if (_displayableWorkTypes.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 180),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_suggest_outlined, size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Brak Dostępnych Akcji', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Brak skonfigurowanych lub dozwolonych akcji dla obszaru "${widget.area.name}" w bieżącym stanie.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55), // Zwiększona nieco wysokość
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessingAction) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder( // Zmieniono na ListView.builder dla spójności z poprzednimi dialogami
              shrinkWrap: true,
              itemCount: _displayableWorkTypes.length,
              itemBuilder: (context, index) {
                final workType = _displayableWorkTypes[index];
                return _buildWorkTypeListItem(workType, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTypeListItem(WorkType workType, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    bool isStopAction = widget.lastActiveWorkEntry != null &&
        widget.lastActiveWorkEntry!.isStart &&
        workType.workTypeId == widget.lastActiveWorkEntry!.workTypeId;

    IconData leadingIcon;
    Color itemColor; // Kolor wiodący dla ikony, trailingu i obramowania karty
    String titleText = workType.name;

    if (isStopAction) {
      leadingIcon = Icons.stop_circle_outlined;
      itemColor = colorScheme.error;
      titleText = 'Zakończ: ${workType.name}';
    } else if (workType.isBreak) {
      leadingIcon = Icons.free_breakfast_outlined; // lub Icons.coffee_outlined
      itemColor = Colors.orange.shade700;
    } else if (workType.isSubTask) {
      leadingIcon = Icons.low_priority_rounded; // lub Icons.assignment_turned_in_outlined
      itemColor = Colors.teal.shade600;
    } else { // Główne zadanie (start)
      leadingIcon = Icons.play_circle_outline_rounded;
      itemColor = colorScheme.primary;
    }

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0), // Usunięto margines poziomy karty
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: itemColor.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(leadingIcon, color: itemColor, size: 28),
        title: Text(
          titleText,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: isStopAction ? itemColor : colorScheme.onSurface,
          ),
        ),
        subtitle: (!isStopAction && workType.description.isNotEmpty)
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              workType.description,
              maxLines: 2, // Zwiększono maxLines dla opisu
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Wrap( // Chipy informacyjne
              spacing: 6.0,
              runSpacing: 2.0,
              children: [
                Chip(
                  avatar: Icon(workType.isPaid ? Icons.attach_money_outlined : Icons.money_off_outlined, size: 14, color: workType.isPaid ? Colors.green.shade700 : Colors.red.shade700),
                  label: Text(workType.isPaid ? 'Płatne' : 'Niepłatne', style: TextStyle(fontSize: 10, color: workType.isPaid ? Colors.green.shade700 : Colors.red.shade700)),
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
            )
          ],
        )
            : null,
        trailing: Icon(
          isStopAction ? Icons.stop_rounded : Icons.arrow_forward_ios_rounded,
          size: isStopAction ? 20 : 16,
          color: itemColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Dopasowany padding
        onTap: _isProcessingAction ? null : () => _handleWorkTypeSelection(workType),
        isThreeLine: (!isStopAction && workType.description.isNotEmpty && (workType.isPaid || workType.defaultDuration != null)), // Aby zrobić miejsce na chipsy
      ),
    );
  }
}