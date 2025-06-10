import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/code-qr.dart';
import '../models/work_type.dart';
import '../models/information.dart';
import '../services/user_auth_service.dart';
import '../services/work_entry_service.dart';
import '../services/information_service.dart';
import '../functions/global-functions.dart';
import 'dialogs.dart';


class QrWorkTypeSelectionDialog extends StatefulWidget {
  final CodeQr scannedCode;
  final List<WorkType> availableWorkTypes;

  const QrWorkTypeSelectionDialog({
    super.key,
    required this.scannedCode,
    required this.availableWorkTypes,
  });

  @override
  State<QrWorkTypeSelectionDialog> createState() => _QrWorkTypeSelectionDialogState();
}

class _QrWorkTypeSelectionDialogState extends State<QrWorkTypeSelectionDialog> {
  bool _isProcessingAction = false;

  /// Obsługuje wybór typu pracy i rozpoczyna nową pracę
  Future<void> _handleWorkTypeSelection(WorkType selectedWorkType) async {
    if (_isProcessingAction || !mounted) return;

    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      await showErrorDialog(context, "Błąd użytkownika", "Nie można zidentyfikować użytkownika.");
      return;
    }
    final userId = currentUser.uid;

    setState(() { _isProcessingAction = true; });

    try {
      // Logika jest uproszczona, ponieważ po skanowaniu zawsze rozpoczynamy nową pracę
      if (selectedWorkType.isBreak || selectedWorkType.isSubTask) {
        throw Exception("Nie można rozpocząć pracy od przerwy lub podzadania po zeskanowaniu kodu QR.");
      }

      List<Information> infoList = await informationService.getInformationByIdsShowOnStart(selectedWorkType.informationIds);
      var infoListToWrite = await processInformationListWithDialogs(context: context, informationsToProcess: infoList);

      if (infoList.isNotEmpty && infoListToWrite == null) {
        // Użytkownik anulował wprowadzanie informacji, przerywamy akcję
        setState(() => _isProcessingAction = false);
        return;
      }

      await workEntryService.recordWorkEvent(
        userId: userId,
        projectId: widget.scannedCode.projectId,
        areaId: widget.scannedCode.areaId, // Używamy areaId z kodu QR
        workTypeSnapshot: selectedWorkType,
        isStartingEvent: true,
        relatedInformations: infoListToWrite ?? [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rozpoczęto: ${selectedWorkType.name}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true); // Zwracamy 'true' jako sygnał sukcesu
      }

    } catch (e) {
      debugPrint("Błąd podczas obsługi wyboru typu pracy (dialog QR): $e");
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
      contentPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rozpocznij Pracę (QR)',
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40.0, top: 4.0),
            child: Text(
              'Kod: ${widget.scannedCode.name}',
              style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
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
          onPressed: _isProcessingAction ? null : () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    if (widget.availableWorkTypes.isEmpty) {
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
                'Ten kod QR nie ma przypisanych żadnych zadań, które można by teraz rozpocząć.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessingAction) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableWorkTypes.length,
              itemBuilder: (context, index) {
                final workType = widget.availableWorkTypes[index];
                // Wyświetlamy tylko zadania główne, bo tylko takie można rozpocząć po skanie
                if (workType.isBreak || workType.isSubTask) {
                  return const SizedBox.shrink();
                }
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

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(Icons.play_circle_outline_rounded, color: colorScheme.primary, size: 28),
        title: Text(workType.name, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: workType.description.isNotEmpty
            ? Text(
          workType.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        )
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        onTap: _isProcessingAction ? null : () => _handleWorkTypeSelection(workType),
      ),
    );
  }
}