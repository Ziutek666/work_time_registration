import 'dart:async'; // Import dla Timera
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Importy serwisów i modeli - upewnij się, że ścieżki są poprawne
import 'package:work_time_registration/services/area_service.dart';
import 'package:work_time_registration/services/information_service.dart';
import 'package:work_time_registration/services/project_service.dart';
import 'package:work_time_registration/services/user_auth_service.dart';
import 'package:work_time_registration/services/work_entry_service.dart';
import 'package:work_time_registration/services/work_type_service.dart';
import 'package:work_time_registration/functions/global-functions.dart';
import 'package:work_time_registration/widgets/project_selection_dialog.dart';
import 'models/information.dart';
import 'models/work_entry.dart';
import 'models/work_type.dart';

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

  // Lista dostępnych akcji (podzadań/przerw) dla aktywnego zadania głównego
  List<WorkType> _availableNextActions = [];
  bool _isLoadingNextActions = false;

  // Zmienne dla Timera odliczającego
  Timer? _countdownTimer;
  Duration? _remainingTime;
  bool _isLastMinute = false;
  AnimationController? _lastMinuteAnimationController;
  bool _showLastMinuteText = true;

  @override
  void initState() {
    super.initState();
    _lastMinuteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
        if (!mounted) return;
        if (_lastMinuteAnimationController != null) {
          final newShowText = _lastMinuteAnimationController!.value < 0.5;
          if (_showLastMinuteText != newShowText && _isLastMinute) {
            setState(() {
              _showLastMinuteText = newShowText;
            });
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

  String _formatRemainingTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        : "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startCountdownTimer(WorkEntry activeEvent) {
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
            _lastMinuteAnimationController?.isAnimating == false)
          _lastMinuteAnimationController?.repeat(reverse: true);
        else if (!isLastMinuteNow &&
            _lastMinuteAnimationController?.isAnimating == true)
          _lastMinuteAnimationController?.stop();
        if (mounted) setState(() => _remainingTime = remaining);
      });
      if (mounted)
        setState(() => _remainingTime = endTime.difference(DateTime.now()));
    }
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_lastMinuteAnimationController?.isAnimating == true)
      _lastMinuteAnimationController?.stop();
  }

  // ZMODYFIKOWANA GŁÓWNA LOGIKA ŁADOWANIA STANU
  Future<void> _loadActiveWorkEvent() async {
    print('HomeScreen: Rozpoczynanie _loadActiveWorkEvent...');
    if (!mounted) return;

    _stopCountdownTimer();
    setState(() {
      _isLoadingWorkEntry = true;
      _loadError = null;
      _activeWorkEntry = null;
      _activeProjectName = null;
      _activeAreaName = null;
      _availableNextActions = [];
      _remainingTime = null;
      _isLastMinute = false;
    });

    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      if (mounted)
        setState(() => {
              _isLoadingWorkEntry = false,
              _loadError = "Użytkownik nie jest zalogowany."
            });
      return;
    }

    try {
      WorkEntry? latestEvent =
          await workEntryService.getLatestEventForUser(currentUser.uid);

      if (latestEvent == null) {
        print(
            "HomeScreen: Brak jakichkolwiek zdarzeń. Wyświetlanie ekranu startowego.");
        if (mounted) setState(() => _isLoadingWorkEntry = false);
        return;
      }

      WorkEntry? activeEntryToShow;

      if (latestEvent.isStart) {
        // Przypadek 1: Ostatnie zdarzenie to aktywny START (zadania głównego, przerwy lub podzadania).
        print(
            "HomeScreen: Ostatnie zdarzenie to aktywny START: ${latestEvent.workTypeName}");
        activeEntryToShow = latestEvent;
      } else {
        // Przypadek 2: Ostatnie zdarzenie to STOP.
        print(
            "HomeScreen: Ostatnie zdarzenie to STOP: ${latestEvent.workTypeName}");
        if (latestEvent.workTypeIsSubTask || latestEvent.workTypeIsBreak) {
          // Jeśli był to STOP dla podzadania/przerwy, szukamy nadrzędnego zadania głównego.
          print(
              "HomeScreen: Był to STOP dla podzadania/przerwy. Szukam nadrzędnego zadania...");
          activeEntryToShow =
              await workEntryService.getLatestMainActiveEventForUserInProject(
                  currentUser.uid, latestEvent.projectId);
          if (activeEntryToShow != null) {
            print(
                "HomeScreen: Znaleziono aktywne zadanie nadrzędne: ${activeEntryToShow.workTypeName}");
          } else {
            print(
                "HomeScreen: Nie znaleziono aktywnego zadania nadrzędnego. Wyświetlanie ekranu startowego.");
          }
        } else {
          // Jeśli był to STOP dla zadania głównego, nie ma już aktywnej pracy.
          print(
              "HomeScreen: Był to STOP dla zadania głównego. Wyświetlanie ekranu startowego.");
          activeEntryToShow = null;
        }
      }

      // Teraz, jeśli mamy zadanie do wyświetlenia, pobieramy jego szczegóły.
      if (mounted && activeEntryToShow != null) {
        final projectDetails =
            await projectService.getProject(activeEntryToShow.projectId);
        final areaDetails = await areaService.getArea(activeEntryToShow.areaId);

        // Jeśli to zadanie główne, załaduj jego powiązane akcje
        if (!activeEntryToShow.workTypeIsBreak &&
            !activeEntryToShow.workTypeIsSubTask) {
          await _loadAvailableActionsForMainTask(activeEntryToShow.workTypeId);
        }

        if (mounted) {
          setState(() {
            _activeWorkEntry = activeEntryToShow;
            _activeProjectName = projectDetails?.name ?? "Nieznany projekt";
            _activeAreaName = areaDetails?.name ?? "Nieznany obszar";
            _isLoadingWorkEntry = false;
          });
          _startCountdownTimer(activeEntryToShow);
        }
      } else if (mounted) {
        // Nie ma aktywnego zadania do wyświetlenia
        setState(() {
          _isLoadingWorkEntry = false;
        });
      }
    } catch (e, s) {
      print("Błąd w _loadActiveWorkEvent: $e\n$s");
      if (mounted)
        setState(() => {
              _isLoadingWorkEntry = false,
              _loadError = "Błąd ładowania statusu."
            });
    }
  }

  // Ładuje akcje powiązane z zadaniem głównym
  Future<void> _loadAvailableActionsForMainTask(String mainWorkTypeId) async {
    if (!mounted) return;
    setState(() => _isLoadingNextActions = true);
    try {
      final mainWorkType = await workTypeService.getWorkType(mainWorkTypeId);
      if (mainWorkType != null && mainWorkType.subTaskIds.isNotEmpty) {
        final linkedActions =
            await workTypeService.getWorkTypesByIds(mainWorkType.subTaskIds);
        if (mounted) {
          setState(() {
            _availableNextActions = linkedActions;
            _availableNextActions.sort((a, b) => a.name.compareTo(b.name));
          });
        }
      } else {
        // Jeśli nie ma powiązanych akcji, upewnij się, że lista jest pusta
        if (mounted) setState(() => _availableNextActions = []);
      }
    } catch (e) {
      print("Błąd ładowania dostępnych akcji dla zadania głównego: $e");
    } finally {
      if (mounted) setState(() => _isLoadingNextActions = false);
    }
  }

  // Logika kończenia pracy i rozpoczynania podzadań (pozostaje bez zmian)
  Future<void> _stopCurrentWork(Timestamp customEventTimestamp) async {
    if (_activeWorkEntry == null) return;
    final workEntryToStop = _activeWorkEntry!;
    _stopCountdownTimer();
    setState(() => _isLoadingWorkEntry = true);
    final currentUser = userAuthService.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      setState(() => _isLoadingWorkEntry = false);
      return;
    }
    try {
      List<Information> infoList = [];
      if (workEntryToStop.workTypeInformationIds.isNotEmpty)
        infoList = await informationService.getInformationByIdsShowOnStop(
            workEntryToStop.workTypeInformationIds);
      List<Information>? infoListToWrite =
          await processInformationListWithDialogs(
              context: context, informationsToProcess: infoList);
      if (infoList.isNotEmpty && infoListToWrite == null) {
        setState(() => _isLoadingWorkEntry = false);
        return;
      }
      final workTypeSnapshotForStop = WorkType(
          workTypeId: workEntryToStop.workTypeId,
          name: workEntryToStop.workTypeName,
          description: workEntryToStop.workTypeDescription,
          isPaid: workEntryToStop.workTypeIsPaid,
          projectId: workEntryToStop.projectId,
          isSubTask: workEntryToStop.workTypeIsSubTask,
          ownerId: '',
          isBreak: workEntryToStop.workTypeIsBreak,
          defaultDuration: workEntryToStop.workTypeDefaultDurationInSeconds !=
                  null
              ? Duration(
                  seconds: workEntryToStop.workTypeDefaultDurationInSeconds!)
              : null,
          informationIds: workEntryToStop.workTypeInformationIds,
          subTaskIds: const []);
      await workEntryService.recordWorkEvent(
          userId: currentUser.uid,
          customEventTimestamp: customEventTimestamp,
          projectId: workEntryToStop.projectId,
          areaId: workEntryToStop.areaId,
          workTypeSnapshot: workTypeSnapshotForStop,
          isStartingEvent: false,
          relatedInformations: infoListToWrite ?? []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Zadanie "${workEntryToStop.workTypeName}" zostało zakończone.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        await _loadActiveWorkEvent();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWorkEntry = false);
    }
  }

  Future<void> _startBreakOrSubTask(WorkType selectedNextWorkType,Timestamp customEventTimestamp) async {
    if (_activeWorkEntry == null || !mounted) return;
    final currentUser = userAuthService.currentUser;
    if (currentUser == null) {
      return;
    }
    setState(() => _isLoadingWorkEntry = true);
    try {
      List<Information> infoList = [];
      if (selectedNextWorkType.informationIds.isNotEmpty)
        infoList = await informationService.getInformationByIdsShowOnStart(
            selectedNextWorkType.informationIds);
      List<Information>? infoListToWrite =
          await processInformationListWithDialogs(
              context: context, informationsToProcess: infoList);
      if (infoList.isNotEmpty && infoListToWrite == null) {
        setState(() => _isLoadingWorkEntry = false);
        return;
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
          relatedInformations: infoListToWrite ?? []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Rozpoczęto: ${selectedNextWorkType.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        await _loadActiveWorkEvent();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWorkEntry = false);
    }
  }

  String _formatEventTime(Timestamp timestamp) =>
      DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
          title: Row(children: [
            SizedBox(
                height: 36,
                width: 36,
                child: Image.asset('icons/Icon-192.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Icon(
                        Icons.business_center_outlined,
                        size: 30,
                        color: colorScheme.onPrimary))),
            const SizedBox(width: 12),
            Text('Rejestracja Czasu Pracy',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary, fontWeight: FontWeight.bold))
          ]),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 4.0,
          actions: <Widget>[
            IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer())
          ]),
      endDrawer: Drawer(
          child: ListView(padding: EdgeInsets.zero, children: <Widget>[
        DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      height: 60,
                      width: 60,
                      child: Image.asset('icons/Icon-192.png',
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Icon(
                              Icons.business_center_rounded,
                              size: 50,
                              color: colorScheme.onPrimary))),
                  const SizedBox(height: 8),
                  Text('Menu Główne',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: colorScheme.onPrimary)),
                  if (userAuthService.currentUser?.email != null)
                    Text(userAuthService.currentUser!.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimary.withOpacity(0.8)))
                ])),
        ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Konto użytkownika'),
            onTap: () {
              Navigator.pop(context);
              context.push('/edit-user');
            }),
        ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Historia'),
            onTap: () {
              Navigator.pop(context);
              context.push('/user-history-menu');
            }),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.folder_special_outlined),
            title: const Text('Moje projekty (Admin)'),
            onTap: () {
              Navigator.pop(context);
              context.push('/my-projects');
            }),
            ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Historia (Admin)'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin-history-menu');
                }),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('O aplikacji'),
            onTap: () {
              Navigator.pop(context);
              context.push('/about');
            }),
        ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title:
                Text('Wyloguj się', style: TextStyle(color: colorScheme.error)),
            onTap: () async {
              Navigator.pop(context);
              await userAuthService.signOut();
              if (mounted &&
                  GoRouter.of(context)
                          .routerDelegate
                          .navigatorKey
                          .currentContext !=
                      null) {
                context.go('/auth');
              }
            })
      ])),
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          theme.colorScheme.primaryContainer.withOpacity(0.3),
          theme.colorScheme.surfaceVariant.withOpacity(0.3)
        ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoadingWorkEntry
                ? Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(color: colorScheme.primary),
                          const SizedBox(height: 16),
                          Text("Sprawdzanie statusu pracy...",
                              style: theme.textTheme.titleMedium)
                        ])))
                : _loadError != null
                    ? Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: theme.colorScheme.onErrorContainer,
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
                                      onPressed: _loadActiveWorkEvent,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.error,
                                          foregroundColor: theme
                                              .colorScheme.onErrorContainer))
                                ])))
                    : _activeWorkEntry != null
                        ? _buildActiveWorkUI(theme, _activeWorkEntry!)
                        : _buildStartWorkCard(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildStartWorkCard(ThemeData theme) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill_outlined,
                size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Rejestracja Czasu Pracy',
                style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
                'Witaj, ${userAuthService.currentUser?.displayName ?? userAuthService.currentUser?.email ?? "Użytkowniku"}!',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.secondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Nie masz aktualnie rozpoczętej żadnej pracy.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              label: const Text('Rozpocznij pracę'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0)),
                  elevation: 4.0),
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return ProjectSelectionDialog(
                      lastWorkTypeEntry: _activeWorkEntry,
                    );
                  },
                );
                if (result == true && mounted) {
                  await _loadActiveWorkEvent();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWorkUI(ThemeData theme, WorkEntry activeEvent) {
    final bool isMainTaskActive =
        !activeEvent.workTypeIsBreak && !activeEvent.workTypeIsSubTask;
    final bool isTimedEvent =
        activeEvent.workTypeDefaultDurationInSeconds != null &&
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
            mainAxisSize: MainAxisSize.min,
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              style: countdownTextStyle)),
                    ],
                  ),
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
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0))),
                  onPressed: (){
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
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                                "Brak zdefiniowanych podzadań lub przerw dla tego zadania.",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    IconData icon = workType.isBreak
        ? Icons.free_breakfast_outlined
        : Icons.low_priority_rounded;
    Color color =
        workType.isBreak ? Colors.orange.shade700 : Colors.teal.shade600;
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: color.withOpacity(0.5))),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(workType.name,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: workType.description.isNotEmpty
            ? Text(workType.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall)
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
        onTap: () {
          _startBreakOrSubTask(workType,Timestamp.now());
          },
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
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
