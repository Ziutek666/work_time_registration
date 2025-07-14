import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/code-qr.dart';
import '../models/work_type.dart';
import '../models/information.dart';
import '../screens/codeQr/scaner.dart';
import '../services/code_qr_service.dart';
import '../services/location_service.dart';
import '../services/user_auth_service.dart';
import '../services/work_entry_service.dart';
import '../services/information_service.dart';
import '../services/work_type_service.dart';
import '../functions/global-functions.dart';
import 'dialogs.dart';

class SelectWorkTypeToStartDialog extends StatefulWidget {
  final String projectId;
  final String areaId;
  final List<String> workTypesIds;

  const SelectWorkTypeToStartDialog({
    super.key,
    required this.projectId,
    required this.areaId,
    required this.workTypesIds,
  });

  @override
  State<SelectWorkTypeToStartDialog> createState() => _SelectWorkTypeToStartDialogState();
}

class _SelectWorkTypeToStartDialogState extends State<SelectWorkTypeToStartDialog> {
  List<WorkType> _availableWorkTypes = [];
  bool _isLoading = true;
  bool _isProcessingAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableWorkTypes();
  }

  Future<void> _loadAvailableWorkTypes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (widget.workTypesIds.isEmpty) {
        _availableWorkTypes = [];
      } else {
        _availableWorkTypes = await workTypeService.getWorkTypesByIds(widget.workTypesIds);
      }
    } catch (e) {
      if (mounted) _errorMessage = "Błąd ładowania czynności: ${e.toString()}";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWorkTypeSelection(WorkType selectedWorkType) async {
    if (_isProcessingAction || !mounted) return;
    final currentUser = userAuthService.currentUser;
    if (currentUser == null) {
      await showErrorDialog(context, "Błąd użytkownika", "Nie można zidentyfikować użytkownika.");
      return;
    }
    setState(() { _isProcessingAction = true; });

    try {
      if (selectedWorkType.requiresQrScan == true) {
        if (!mounted) return;
        final rawValue = await Navigator.push<String>(context, MaterialPageRoute(fullscreenDialog: true, builder: (context) => const QrScannerScreen()));

        if (rawValue == null) {
          throw Exception("Skanowanie kodu QR zostało anulowane.");
        }

        final Map<String, dynamic> decodedData = jsonDecode(rawValue);
        final String? codeId = decodedData['i'];
        if (codeId == null) throw Exception("Nieprawidłowy format kodu QR.");

        final code = await codeQrService.getCodeQrById(codeId);
        if (code == null) throw Exception("Kod QR nie został znaleziony w systemie.");

        if ((code.projectId != selectedWorkType.projectId) || (!code.workTypeIds.contains(selectedWorkType.workTypeId))) {
          throw Exception("Zeskanowany kod QR pochodzi z innego projektu lub innego zadania.");
        }

        if (code.checkLocation == true) {
          // ZMIANA: Przekazujemy BuildContext do funkcji i sprawdzamy jej wynik
          final bool isLocationValid = await _checkLocation(context, code);
          // POPRAWKA: Jeśli lokalizacja jest nieprawidłowa, resetujemy stan i kończymy działanie
          if (!isLocationValid) {
            setState(() { _isProcessingAction = false; });
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod QR zweryfikowany.'), backgroundColor: Colors.green));
        }
      }

      // Uproszczona logika - używamy gettera isMain
      if (!selectedWorkType.isMain) {
        throw Exception("Tylko zadania główne mogą być rozpoczynane w ten sposób.");
      }

      List<Information> infoList = await informationService.getInformationByIdsShowOnStart(selectedWorkType.informationIds);
      var infoListToWrite = await processInformationListWithDialogs(context: context, informationsToProcess: infoList);

      if (infoList.isNotEmpty && infoListToWrite == null) {
        setState(() => _isProcessingAction = false);
        return;
      }

      await workEntryService.recordWorkEvent(
        userId: currentUser.uid,
        projectId: widget.projectId,
        areaId: widget.areaId,
        workTypeSnapshot: selectedWorkType,
        isStartingEvent: true,
        relatedInformations: infoListToWrite ?? [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rozpoczęto: ${selectedWorkType.name}'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint("Błąd podczas wyboru typu pracy: $e");
      if (mounted) await showErrorDialog(context, "Błąd Operacji", e.toString());
      // POPRAWKA: Upewniamy się, że stan jest resetowany również w przypadku ogólnego błędu
      setState(() { _isProcessingAction = false; });
    } finally {
      // Ten blok `finally` jest teraz "na wszelki wypadek", główne ścieżki błędów resetują stan wcześniej.
      if (mounted && _isProcessingAction) {
        setState(() { _isProcessingAction = false; });
      }
    }
  }

  // ZMIANA: Funkcja zwraca Future<bool> i sama pokazuje błędy.
  Future<bool> _checkLocation(BuildContext dialogContext, CodeQr scannedCode) async {
    try {
      if (scannedCode.location == null || scannedCode.maxDistanceInMeters == null) {
        await showErrorDialog(dialogContext, "Błąd Konfiguracji", "Kod QR wymaga weryfikacji lokalizacji, ale nie ma zapisanych współrzędnych.");
        return false;
      }

      final currentPosition = await LocationService.determinePosition();
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        scannedCode.location!.latitude,
        scannedCode.location!.longitude,
      );

      if (distance > scannedCode.maxDistanceInMeters!) {
        await showErrorDialog(dialogContext, "Nieprawidłowa Lokalizacja", "Jesteś zbyt daleko od punktu. Odległość: ${distance.round()} m, dozwolona: ${scannedCode.maxDistanceInMeters} m.");
        return false;
      }

      // Jeśli wszystko jest w porządku
      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
        content: Text('Lokalizacja zweryfikowana pomyślnie.'),
        backgroundColor: Colors.green,
      ));
      return true;

    } catch (e) {
      // Obsługa błędów z Geolocator itp.
      await showErrorDialog(dialogContext, "Błąd Lokalizacji", "Nie udało się zweryfikować lokalizacji: ${e.toString()}");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Row(
        children: [
          Icon(Icons.playlist_play_rounded, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Rozpocznij Pracę', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildDialogContent(theme),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Anuluj'),
          onPressed: _isProcessingAction ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)));

    final mainWorkTypes = _availableWorkTypes.where((wt) => wt.isMain).toList();

    if (mainWorkTypes.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.work_off_outlined, size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Brak Dostępnych Czynności', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Brak zdefiniowanych zadań głównych do rozpoczęcia dla tego obszaru.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
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
              itemCount: mainWorkTypes.length,
              itemBuilder: (context, index) {
                final workType = mainWorkTypes[index];
                return _buildWorkTypeListItem(workType, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTypeListItem(WorkType workType, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        leading: Icon(Icons.play_circle_outline_rounded, color: theme.colorScheme.primary),
        title: Text(workType.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: workType.description.isNotEmpty
            ? Text(workType.description, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.arrow_forward_ios_rounded),
        onTap: _isProcessingAction ? null : () => _handleWorkTypeSelection(workType),
      ),
    );
  }
}