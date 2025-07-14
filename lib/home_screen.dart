import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:work_time_registration/services/location_service.dart';
import 'package:work_time_registration/services/members_service.dart';
import 'package:work_time_registration/widgets/area_select_dialog.dart';
import 'package:work_time_registration/widgets/project_selection_dialog.dart';
import 'package:work_time_registration/widgets/qr_work_type_selection_dialog.dart';
import 'package:work_time_registration/widgets/select_work_type_to_start_dialog.dart';
import 'models/area.dart';
import 'models/code-qr.dart';
import 'models/information.dart';
import 'models/project.dart';
import 'models/work_entry.dart';
import 'models/work_type.dart';
import 'services/area_service.dart';
import 'services/information_service.dart';
import 'services/project_service.dart';
import 'services/user_auth_service.dart';
import 'services/user_service.dart';
import 'services/work_entry_service.dart';
import 'services/work_type_service.dart';
import 'services/code_qr_service.dart';
import 'functions/global-functions.dart';
import 'widgets/dialogs.dart';
import 'screens/codeQr/scaner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  WorkEntry? _activeWorkEntry;
  String? _activeProjectName;
  String? _activeAreaName;
  bool _isLoadingWorkEntry = true;
  String? _loadError;

  List<WorkType> _availableNextActions = [];
  bool _isLoadingNextActions = false;
  Set<String> _completedSubTaskIds = {};

  Timer? _countdownTimer;
  Duration? _remainingTime;
  bool _isLastMinute = false;
  AnimationController? _lastMinuteAnimationController;
  bool _showLastMinuteText = true;

  @override
  void initState() {
    super.initState();
    _lastMinuteAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..addListener(() {
        if (!mounted) return;
        if (_lastMinuteAnimationController != null) {
          final newShowText = _lastMinuteAnimationController!.value < 0.5;
          if (_showLastMinuteText != newShowText && _isLastMinute) {
            setState(() => _showLastMinuteText = newShowText);
          }
        }
      });
    _loadActiveWorkEvent();
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    _lastMinuteAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadActiveWorkEvent() async {
    // ... bez zmian
    if (!mounted) return;
    _stopCountdownTimer();
    setState(() {
      _isLoadingWorkEntry = true;
      _loadError = null;
      _activeWorkEntry = null;
      _activeProjectName = null;
      _activeAreaName = null;
      _availableNextActions = [];
      _completedSubTaskIds = {};
    });

    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingWorkEntry = false;
          _loadError = "Użytkownik nie jest zalogowany.";
        });
      }
      return;
    }

    try {
      WorkEntry? latestEvent =
      await workEntryService.getLatestEventForUser(currentUser.uid);
      WorkEntry? activeEntryToShow;

      if (latestEvent == null) {
        if (mounted) setState(() => _isLoadingWorkEntry = false);
        return;
      }

      bool isLastEventMain = !latestEvent.workTypeIsBreak &&
          !latestEvent.workTypeIsSubTask &&
          !latestEvent.workTypeIsCheckPoint;

      if (latestEvent.isStart) {
        activeEntryToShow = latestEvent;
      } else {
        if (!isLastEventMain) {
          activeEntryToShow =
          await workEntryService.getLatestMainActiveEventForUserInProject(
              currentUser.uid, latestEvent.projectId);
        }
      }

      if (mounted && activeEntryToShow != null) {
        final projectDetailsFuture =
        projectService.getProject(activeEntryToShow.projectId);
        final areaDetailsFuture = areaService.getArea(activeEntryToShow.areaId);

        final results =
        await Future.wait([projectDetailsFuture, areaDetailsFuture]);
        final projectDetails = results[0] as Project?;
        final areaDetails = results[1] as Area?;

        bool isActiveEntryMain = !activeEntryToShow.workTypeIsBreak &&
            !activeEntryToShow.workTypeIsSubTask &&
            !activeEntryToShow.workTypeIsCheckPoint;
        if (isActiveEntryMain) {
          await Future.wait([
            _loadAvailableActionsForMainTask(activeEntryToShow.workTypeId),
            _loadCompletedSubTasks(activeEntryToShow.entryId),
          ]);
        }

        if (mounted) {
          setState(() {
            _activeWorkEntry = activeEntryToShow;
            _activeProjectName = projectDetails?.name ?? "Nieznany projekt";
            _activeAreaName = areaDetails?.name ?? "Nieznany obszar";
          });
          _startCountdownTimer(activeEntryToShow);
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingWorkEntry = false);
        }
      }
    } catch (e, s) {
      debugPrint("Błąd w _loadActiveWorkEvent: $e\n$s");
      if (mounted) {
        setState(() => _loadError = "Błąd ładowania statusu.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkEntry = false);
      }
    }
  }

  Future<void> _loadCompletedSubTasks(String parentEntryId) async {
    // ... bez zmian
    if (!mounted) return;
    try {
      final completedEntries =
      await workEntryService.getCompletedSubEntriesFor(parentEntryId);
      if (mounted) {
        setState(() {
          _completedSubTaskIds =
              completedEntries.map((e) => e.workTypeId).toSet();
        });
      }
    } catch (e) {
      debugPrint("Błąd ładowania wykonanych podzadań: $e");
    }
  }

  Future<void> _loadAvailableActionsForMainTask(String mainWorkTypeId) async {
    // ... bez zmian
    if (!mounted) return;
    setState(() => _isLoadingNextActions = true);
    try {
      final mainWorkType = await workTypeService.getWorkType(mainWorkTypeId);
      if (mainWorkType != null && mainWorkType.subTaskIds.isNotEmpty) {
        _availableNextActions =
        await workTypeService.getWorkTypesByIds(mainWorkType.subTaskIds)
          ..sort((a, b) => a.name.compareTo(b.name));
      } else {
        _availableNextActions = [];
      }
    } catch (e) {
      debugPrint("Błąd ładowania dostępnych akcji: $e");
    } finally {
      if (mounted) setState(() => _isLoadingNextActions = false);
    }
  }

  Future<void> _stopCurrentWork(Timestamp customEventTimestamp) async {
    if (_activeWorkEntry == null || !mounted) return;

    final workEntryToStop = _activeWorkEntry!;

    // NOWOŚĆ: Sprawdzenie, czy zadanie wymaga skanowania QR przy zakończeniu
    try {
      final workTypeDetails = await workTypeService.getWorkType(workEntryToStop.workTypeId);

      // WAŻNE: Poniższa linijka zakłada, że do modelu WorkType DODANO pole `requiresQrScanOnStop`
      if (workTypeDetails?.requiresQrScan == true) {
        if (!mounted) return;

        final rawValue = await Navigator.push<String>(
            context,
            MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => const QrScannerScreen()));
        if (rawValue == null) return;

        final Map<String, dynamic> decodedData = jsonDecode(rawValue);
        final String? codeId = decodedData['i'];
        if (codeId == null) throw Exception("Nieprawidłowy format kodu QR.");

        final code = await codeQrService.getCodeQrById(codeId);
        if (code == null) throw Exception("Kod QR nie został znaleziony w systemie.");

        if ((code.projectId != _activeWorkEntry!.projectId)||(!code.workTypeIds.contains(_activeWorkEntry!.workTypeId))) {
          throw Exception("Zeskanowany kod QR pochodzi z innego projektu lub innego zadania. Akcja została anulowana.");
        }

        if (code.checkLocation == true) {
          await _checkLocation(code);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kod QR zweryfikowany.'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd Walidacji Kodu QR', e.toString());
      return; // Przerwij zakańczanie pracy w przypadku błędu
    }
    // Koniec nowej logiki

    bool isMainTask = !workEntryToStop.workTypeIsBreak &&
        !workEntryToStop.workTypeIsSubTask &&
        !workEntryToStop.workTypeIsCheckPoint;

    if (isMainTask) {
      final requiredActions =
      _availableNextActions.where((wt) => wt.isRequired).toList();
      final allRequiredCompleted = requiredActions
          .every((action) => _completedSubTaskIds.contains(action.workTypeId));
      if (!allRequiredCompleted) {
        if (mounted) {
          await showErrorDialog(context, 'Wymagane akcje',
              'Nie można zakończyć zadania, ponieważ nie wszystkie wymagane punkty kontrolne lub podzadania zostały wykonane.');
        }
        return;
      }
    }

    _stopCountdownTimer();
    setState(() => _isLoadingWorkEntry = true);

    final currentUser = userAuthService.currentUser;
    if (currentUser == null) {
      setState(() => _isLoadingWorkEntry = false);
      return;
    }

    try {
      List<Information> infoList =
      await informationService.getInformationByIdsShowOnStop(
          workEntryToStop.workTypeInformationIds);
      List<Information>? infoListToWrite;
      if (infoList.isNotEmpty && mounted) {
        infoListToWrite = await processInformationListWithDialogs(
            context: context, informationsToProcess: infoList);
        if (infoListToWrite == null) {
          setState(() => _isLoadingWorkEntry = false);
          return;
        }
      }

      final workTypeSnapshotForStop = WorkType(
        workTypeId: workEntryToStop.workTypeId,
        name: workEntryToStop.workTypeName,
        description: workEntryToStop.workTypeDescription,
        isPaid: workEntryToStop.workTypeIsPaid,
        projectId: workEntryToStop.projectId,
        ownerId: '',
        isBreak: workEntryToStop.workTypeIsBreak,
        isSubTask: workEntryToStop.workTypeIsSubTask,
        isCheckPoint: workEntryToStop.workTypeIsCheckPoint,
        isRequired: workEntryToStop.workTypeIsRequired,
        isMain: workEntryToStop.workTypeIsMain,
        defaultDuration:
        workEntryToStop.workTypeDefaultDurationInSeconds != null
            ? Duration(
            seconds: workEntryToStop.workTypeDefaultDurationInSeconds!)
            : null,
        informationIds: workEntryToStop.workTypeInformationIds,
      );

      await workEntryService.recordWorkEvent(
        userId: currentUser.uid,
        customEventTimestamp: customEventTimestamp,
        projectId: workEntryToStop.projectId,
        areaId: workEntryToStop.areaId,
        workTypeSnapshot: workTypeSnapshotForStop,
        isStartingEvent: false,
        relatedInformations: infoListToWrite ?? [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Zadanie "${workEntryToStop.workTypeName}" zostało zakończone.'),
          backgroundColor: Colors.green,
        ));
        await _loadActiveWorkEvent();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd', 'Nie udało się zakończyć pracy: $e');
        setState(() => _isLoadingWorkEntry = false);
      }
    }
  }

  Future<void> _startBreakOrSubTask(
      WorkType selectedNextWorkType, Timestamp customEventTimestamp) async {
    if (_activeWorkEntry == null || !mounted) return;
    final currentUser = userAuthService.currentUser;
    if (currentUser == null) return;
    if (selectedNextWorkType.requiresQrScan == true) {
      if (!mounted) return;

      final rawValue = await Navigator.push<String>(
          context,
          MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => const QrScannerScreen()));

      if (rawValue == null) return;

      try {
        final Map<String, dynamic> decodedData = jsonDecode(rawValue);
        final String? codeId = decodedData['i'];
        if (codeId == null) throw Exception("Nieprawidłowy format kodu.");

        final code = await codeQrService.getCodeQrById(codeId);
        if (code == null) throw Exception("Kod QR nie został znaleziony w systemie.");

        if ((code.projectId != _activeWorkEntry!.projectId)||(!code.workTypeIds.contains(_activeWorkEntry!.workTypeId))) {
          throw Exception("Zeskanowany kod QR pochodzi z innego projektu lub innego zadania. Akcja została anulowana.");
        }

        if (code.checkLocation == true) {
          await _checkLocation(code);
        }


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kod QR zweryfikowany pomyślnie.'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) showErrorDialog(context, 'Błąd Walidacji Kodu QR', e.toString());
        return;
      }
    }

    setState(() => _isLoadingWorkEntry = true);
    try {
      List<Information> infoList = await informationService
          .getInformationByIdsShowOnStart(selectedNextWorkType.informationIds);
      List<Information>? infoListToWrite;

      if (infoList.isNotEmpty && mounted) {
        infoListToWrite = await processInformationListWithDialogs(
            context: context, informationsToProcess: infoList);
        if (infoListToWrite == null) {
          setState(() => _isLoadingWorkEntry = false);
          return;
        }
      }

      await workEntryService.recordWorkEvent(
        userId: currentUser.uid,
        customEventTimestamp: customEventTimestamp,
        projectId: selectedNextWorkType.projectId.isNotEmpty
            ? selectedNextWorkType.projectId
            : _activeWorkEntry!.projectId,
        areaId: _activeWorkEntry!.areaId,
        workTypeSnapshot: selectedNextWorkType,
        isStartingEvent: true,
        parentWorkEntryId: _activeWorkEntry!.entryId,
        relatedInformations: infoListToWrite ?? [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Rozpoczęto: ${selectedNextWorkType.name}')));
        await _loadActiveWorkEvent();
      }
    } catch (e) {
      debugPrint("Błąd podczas rozpoczynania podzadania: $e");
      if (mounted) {
        setState(() => _isLoadingWorkEntry = false);
      }
    }
  }

  void _startCountdownTimer(WorkEntry activeEvent) {
    // ... bez zmian
    _stopCountdownTimer();
    if (activeEvent.workTypeDefaultDurationInSeconds != null &&
        activeEvent.workTypeDefaultDurationInSeconds! > 0) {
      final startTime = activeEvent.eventActionTimestamp.toDate();
      final totalDuration =
      Duration(seconds: activeEvent.workTypeDefaultDurationInSeconds!);
      final endTime = startTime.add(totalDuration);

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final remaining = endTime.difference(DateTime.now());
        if (remaining.isNegative) {
          _stopCountdownTimer();
          if (mounted) setState(() => _remainingTime = Duration.zero);
          return;
        }
        final isLastMinuteNow =
            remaining.inSeconds <= 60 && remaining.inSeconds > 0;
        if (_isLastMinute != isLastMinuteNow) {
          if (mounted) setState(() => _isLastMinute = isLastMinuteNow);
        }
        if (isLastMinuteNow &&
            _lastMinuteAnimationController?.isAnimating == false) {
          _lastMinuteAnimationController?.repeat(reverse: true);
        } else if (!isLastMinuteNow &&
            _lastMinuteAnimationController?.isAnimating == true) {
          _lastMinuteAnimationController?.stop();
        }
        if (mounted) setState(() => _remainingTime = remaining);
      });
      if (mounted)
        setState(() => _remainingTime = endTime.difference(DateTime.now()));
    }
  }

  void _stopCountdownTimer() {
    // ... bez zmian
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_lastMinuteAnimationController?.isAnimating == true) {
      _lastMinuteAnimationController?.stop();
    }
  }

  String _formatRemainingTime(Duration duration) {
    // ... bez zmian
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatEventTime(Timestamp timestamp) =>
      // ... bez zmian
  DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());

  Future<void> _navigateToScannerScreen() async {
    // ... bez zmian
    if (!mounted) return;
    final rawValue = await Navigator.push<String>(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const QrScannerScreen()));
    if (rawValue != null) {
      await _handleScannedQrCode(rawValue);
    }
  }

  Future<void> _handleScannedQrCode(String rawValue) async {
    setState(() => _isLoadingWorkEntry = true);
    try {
      final Map<String, dynamic> decodedData = jsonDecode(rawValue);
      final String? codeId = decodedData['i'];
      if (codeId == null) throw Exception("Nieprawidłowy format kodu QR.");

      final scannedCode = await codeQrService.getCodeQrById(codeId);
      if (scannedCode == null) {
        throw Exception("Kod QR nie został znaleziony w systemie.");
      }

      if (scannedCode.checkLocation == true) {
        await _checkLocation(scannedCode);
      }

      final userId = userService.uid;
      if (userId == null) throw Exception("Brak zalogowanego użytkownika.");

      final hasAccess = await membersService.hasAccessToArea(
          ownerId: scannedCode.ownerId,
          userId: userId,
          projectId: scannedCode.projectId,
          areaId: scannedCode.areaId);
      if (!hasAccess) throw Exception("Brak dostępu do projektu lub obszaru.");

      final workTypes =
      await workTypeService.getWorkTypesByIds(scannedCode.workTypeIds);
      if (workTypes.isEmpty) {
        throw Exception("Ten kod QR nie ma przypisanych zadań do rozpoczęcia.");
      }

      if (!mounted) return;

      final bool? result = await showDialog<bool>(
          context: context,
          builder: (context) => QrWorkTypeSelectionDialog(
              scannedCode: scannedCode, availableWorkTypes: workTypes));

      if (result == true) {
        await _loadActiveWorkEvent();
      } else {
        setState(() => _isLoadingWorkEntry = false);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd Walidacji Kodu QR', e.toString());
        setState(() => _isLoadingWorkEntry = false);
      }
    }
  }

  Future<void> _checkLocation(CodeQr scannedCode) async {
    if (scannedCode.location == null || scannedCode.maxDistanceInMeters == null) {
      throw Exception("Kod QR wymaga weryfikacji lokalizacji, ale nie ma zapisanych współrzędnych.");
    }

    final currentPosition = await LocationService.determinePosition();

    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      scannedCode.location!.latitude,
      scannedCode.location!.longitude,
    );

    if (distance > scannedCode.maxDistanceInMeters!) {
      throw Exception("Jesteś zbyt daleko od lokalizacji przypisanej do tego kodu QR. Odległość: ${distance.round()} m, dozwolona: ${scannedCode.maxDistanceInMeters} m.");
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lokalizacja zweryfikowana pomyślnie.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _startWork() async {
    // ... bez zmian
    final userId = userService.uid;
    if (userId == null) {
      if (mounted)
        await showAlertDialog(
            context, 'Błąd', 'Użytkownik nie jest zalogowany.');
      return;
    }
    final projects = await membersService.getAllProjectsForUserAcrossCompanies(userId);
    if (projects.isEmpty) {
      if (mounted)
        await showAlertDialog(context, 'Brak projektów',
            'Nie jesteś przypisany jako pracownik do żadnego projektu.');
      return;
    }
    if (!mounted) return;
    final projectIds = projects.map((p) => p.projectId).toList();
    final selectedProject = await showDialog<Project>(
        context: context,
        builder: (ctx) => ProjectSelectionDialog(projectIds: projectIds));
    if (selectedProject == null || !mounted) return;
    final areaIds = await membersService.getAreaIdsForUserInProject(
        ownerId: selectedProject.ownerId,
        userId: userId,
        projectId: selectedProject.projectId);
    if (areaIds.isEmpty) {
      if (mounted)
        await showAlertDialog(context, 'Brak obszarów',
            'Brak dostępnych obszarów w tym projekcie.');
      return;
    }

    if (!mounted) return;
    final selectedArea = await showDialog<Area>(
        context: context,
        builder: (ctx) => AreaSelectionDialog(areaIds: areaIds));
    if (selectedArea == null || !mounted) return;

    final workTypes =
    await workTypeService.getWorkTypesByIds(selectedArea.workTypesIds);
    final startableWorkTypes =
    workTypes.where((wt) => wt.isMain).map((wt) => wt.workTypeId).toList();
    if (startableWorkTypes.isEmpty) {
      if (mounted)
        await showAlertDialog(context, 'Brak zadań',
            'Brak zdefiniowanych zadań głównych dla tego obszaru.');
      return;
    }

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => SelectWorkTypeToStartDialog(
        projectId: selectedProject.projectId,
        areaId: selectedArea.areaId,
        workTypesIds: startableWorkTypes,
      ),
    );
    if (result == true) await _loadActiveWorkEvent();
  }

  @override
  Widget build(BuildContext context) {
    // Cała metoda `build` i jej metody pomocnicze pozostają bez zmian
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(children: [
          Container(
              color: Colors.white,
              child: SizedBox(
                  height: 36,
                  width: 36,
                  child: Image.asset('icons/Icon-192.png',
                      errorBuilder: (c, e, s) =>
                      const Icon(Icons.business_center_outlined)))),
          const SizedBox(width: 12),
          Text('Rejestracja Czasu Pracy',
              style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold))
        ]),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer())
        ],
      ),
      endDrawer: Drawer(
          child: ListView(padding: EdgeInsets.zero, children: <Widget>[
            DrawerHeader(
                decoration: BoxDecoration(color: theme.colorScheme.primary),
                child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    color: Colors.white,
                    child: SizedBox(
                        height: 60,
                        width: 60,
                        child: Image.asset('icons/Icon-192.png',
                            errorBuilder: (c, e, s) => Icon(
                                Icons.business_center_rounded,
                                size: 50,
                                color: theme.colorScheme.onPrimary))),
                  ),
                  const SizedBox(height: 8),
                  Text('Menu Główne',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: theme.colorScheme.onPrimary)),
                  if (userAuthService.currentUser?.email != null)
                    Text(userAuthService.currentUser!.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimary.withOpacity(0.8)))
                ])),
            ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Konto użytkownika'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/edit-user');
                }),
            ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Historia'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/user-history-menu');
                }),
            ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Grafiki'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/user-schedule-calendar');
                }),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text('Administracja'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/administration-menu');
                }),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('O aplikacji'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/about');
                }),
            ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text('Wyloguj się',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await userAuthService.signOut();
                  if (mounted) context.go('/auth');
                })
          ])),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.3),
                  theme.colorScheme.surfaceVariant.withOpacity(0.3)
                ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingWorkEntry
                  ? Card(
                  elevation: 4,
                  child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child:
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(
                            color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text("Sprawdzanie statusu pracy...",
                            style: theme.textTheme.titleMedium)
                      ])))
                  : _loadError != null
                  ? Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color:
                                theme.colorScheme.onErrorContainer,
                                size: 40),
                            const SizedBox(height: 12),
                            Text("Wystąpił błąd",
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                    color: theme.colorScheme
                                        .onErrorContainer)),
                            const SizedBox(height: 8),
                            Text(_loadError!,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                    color: theme.colorScheme
                                        .onErrorContainer),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text("Spróbuj ponownie"),
                                onPressed: _loadActiveWorkEvent)
                          ])))
                  : _activeWorkEntry != null
                  ? _buildActiveWorkUI(theme, _activeWorkEntry!)
                  : _buildStartWorkCard(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartWorkCard(ThemeData theme) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_circle_fill_outlined,
              size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Rejestracja Czasu Pracy',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
              'Witaj, ${userAuthService.currentUser?.displayName ?? userAuthService.currentUser?.email ?? "Użytkowniku"}!',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.secondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Nie masz aktualnie rozpoczętej żadnej pracy.',
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Rozpocznij pracę'),
              style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              onPressed: _startWork),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Zeskanuj kod QR'),
              style: OutlinedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: _navigateToScannerScreen),
        ]),
      ),
    );
  }

  Widget _buildActiveWorkUI(ThemeData theme, WorkEntry activeEvent) {
    final isMainTaskActive = !activeEvent.workTypeIsBreak &&
        !activeEvent.workTypeIsSubTask &&
        !activeEvent.workTypeIsCheckPoint;
    final isTimedEvent = activeEvent.workTypeDefaultDurationInSeconds != null &&
        activeEvent.workTypeDefaultDurationInSeconds! > 0;
    TextStyle? countdownTextStyle = theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: _isLastMinute
            ? (_showLastMinuteText
            ? theme.colorScheme.error
            : theme.colorScheme.error.withOpacity(0.3))
            : theme.colorScheme.secondary);
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.timer_outlined,
                    size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text("Aktualnie w pracy",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary))
              ]),
              const SizedBox(height: 20),
              _buildInfoRow(theme, Icons.business_outlined, "Projekt:",
                  _activeProjectName ?? activeEvent.projectId),
              _buildInfoRow(theme, Icons.place_outlined, "Obszar:",
                  _activeAreaName ?? activeEvent.areaId),
              _buildInfoRow(theme, Icons.label_important_outline, "Zadanie:",
                  activeEvent.workTypeName),
              _buildInfoRow(theme, Icons.play_circle_outline, "Rozpoczęto:",
                  _formatEventTime(activeEvent.eventActionTimestamp)),
              if (isTimedEvent)
                _buildInfoRow(
                    theme,
                    Icons.hourglass_bottom_outlined,
                    "Planowany czas:",
                    "${Duration(seconds: activeEvent.workTypeDefaultDurationInSeconds!).inMinutes} min"),
              if (isTimedEvent && _remainingTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(children: [
                    Icon(Icons.update_rounded,
                        size: 20,
                        color: _isLastMinute
                            ? theme.colorScheme.error
                            : theme.colorScheme.secondary),
                    const SizedBox(width: 10),
                    Text('Pozostało: ',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Expanded(
                        child: Text(_formatRemainingTime(_remainingTime!),
                            style: countdownTextStyle))
                  ]),
                ),
              if (activeEvent.description != null &&
                  activeEvent.description!.isNotEmpty)
                _buildInfoRow(theme, Icons.description_outlined, "Opis:",
                    activeEvent.description!),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text('Zakończ: ${activeEvent.workTypeName}'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      minimumSize: const Size(double.infinity, 48)),
                  onPressed: () {
                    _stopCurrentWork(Timestamp.now());
                  }),
              const SizedBox(height: 16),
              if (isMainTaskActive) ...[
                _buildSectionTitle(theme.textTheme, "Dostępne Następne Akcje:"),
                _isLoadingNextActions
                    ? const Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: CircularProgressIndicator()))
                    : _availableNextActions.isEmpty
                    ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                        "Brak zdefiniowanych podzadań lub przerw dla tego zadania.",
                        textAlign: TextAlign.center))
                    : Column(
                    children: _availableNextActions
                        .map((workType) =>
                        _buildNextActionCard(theme, workType))
                        .toList()),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextActionCard(ThemeData theme, WorkType workType) {
    final isCompleted = _completedSubTaskIds.contains(workType.workTypeId);
    IconData icon = workType.isBreak
        ? Icons.free_breakfast_outlined
        : workType.isSubTask
        ? Icons.low_priority_rounded
        : Icons.flag_outlined;
    Color color = workType.isBreak
        ? Colors.orange.shade700
        : workType.isSubTask
        ? Colors.teal.shade600
        : Colors.blue.shade600;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: color.withOpacity(0.5))),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(workType.name,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: workType.description.isNotEmpty
            ? Text(workType.description,
            maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: isCompleted
            ? Icon(Icons.check_circle_rounded,
            color: Colors.green.shade600, semanticLabel: 'Wykonano')
            : workType.isRequired
            ? Icon(Icons.warning_amber_rounded,
            color: theme.colorScheme.error, semanticLabel: 'Wymagane')
            : Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
        onTap: isCompleted
            ? null
            : () {
          _startBreakOrSubTask(workType, Timestamp.now());
        },
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text('$label ',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(
            child: Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                softWrap: true)),
      ]),
    );
  }

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
      child: Text(title,
          style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9)),
          textAlign: TextAlign.center),
    );
  }
}