import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// NOWE IMPORTY DLA EKSPORTU DO PDF
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/area.dart';
import '../../models/information_category.dart';
import '../../models/project.dart';
import '../../models/schedule_assignments.dart';
import '../../models/schedule_template.dart';
import '../../models/user_app.dart';
import '../../models/user_availability.dart';
import '../../models/work_entry.dart';
import '../../services/area_service.dart';
import '../../services/availability_service.dart';
import '../../services/members_service.dart';
import '../../services/project_service.dart';
import '../../services/schedule_assignment_service.dart';
import '../../services/schedule_template_service.dart';
import '../../services/user_service.dart';
import '../../services/work_entry_service.dart';
import '../../widgets/dialogs.dart';
import 'package:collection/collection.dart';
/// Reprezentuje pojedynczą sesję pracy lub zdarzenie typu CheckPoint.
class WorkSession {
  final WorkEntry startEntry;
  final WorkEntry? endEntry;
  final List<WorkEntry> allEventsInSession;

  WorkSession({
    required this.startEntry,
    this.endEntry,
    required this.allEventsInSession,
  });

  bool get isFinished => endEntry != null;
  bool get isCheckPointEvent => startEntry.workTypeIsCheckPoint;

  Duration get duration {
    if (isCheckPointEvent) return Duration.zero;
    if (!isFinished) {
      return DateTime.now().difference(startEntry.eventActionTimestamp.toDate());
    }
    return endEntry!.eventActionTimestamp
        .toDate()
        .difference(startEntry.eventActionTimestamp.toDate());
  }

  String get workTypeName => startEntry.workTypeName;
}

/// --- GŁÓWNY WIDŻET EKRANU ---
class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  // --- Stan UI ---
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFilterPanelVisible = true;
  final ScrollController _scrollController = ScrollController();

  // --- Stan danych ---
  UserApp? _currentUser;
  List<WorkEntry> _allWorkEntries = [];
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;
  UserApp? _selectedUser;
  List<UserApp> _availableUsers = [];
  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];
  Map<String, String> _userNamesMap = {};
  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};
  List<UserAvailability> _userAvailabilities = [];
  List<ScheduleAssignment> _scheduleAssignments = [];
  Map<String, ScheduleTemplate> _scheduleTemplatesMap = {}; // Do mapowania ID szablonu na jego dane

  // --- Stan AI ---
  final TextEditingController _aiQueryController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = []; // Lista do przechowywania pytań i odpowiedzi
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _aiQueryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // #region Logika ładowania i przetwarzania danych
  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      await _loadUsersAndInitialData();
      await _fetchAndProcessEntries();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsersAndInitialData() async {
    _currentUser = await userService.getCurrentUser();
    if (_currentUser?.uid == null) {
      throw Exception("Brak uwierzytelnionego administratora.");
    }
    final ownerId = _currentUser!.uid!;
    final allProjects = await projectService.getProjectsByOwner(ownerId);
    if (allProjects.isEmpty) {
      if (mounted) setState(() => _availableUsers = []);
      return;
    }
    final allMembers = await membersService.getMembersByOwner(ownerId);
    final uniqueUserIds = allMembers.map((m) => m.userId).where((uid) => uid != null).cast<String>().toSet().toList();

    if (uniqueUserIds.isNotEmpty) {
      _availableUsers = await userService.getUsersByIds(uniqueUserIds);
      _availableUsers.sort((a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));
      _userNamesMap = {for (var user in _availableUsers) user.uid!: user.displayName ?? 'Użytkownik bez nazwy'};
    }
  }

  Future<void> _fetchAndProcessEntries() async {
    if (_selectedDateRange == null || _availableUsers.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final userIds = _availableUsers.map((user) => user.uid!).toList();

      // 1. Przygotuj wszystkie asynchroniczne operacje pobierania danych
      // Pobierz wpisy o pracy i od razu spłaszcz listę list w jedną listę
      final Future<List<WorkEntry>> allWorkEntriesFuture = Future.wait(
          userIds.map((id) => workEntryService.getWorkEntriesForUserBetweenDates(
              id, _selectedDateRange!.start, _selectedDateRange!.end.add(const Duration(days: 1))
          ))
      ).then((listOfLists) => listOfLists.expand((list) => list).toList());

      // Pobierz deklaracje dyspozycyjności
      final Future<List<UserAvailability>> availabilitiesFuture =
      availabilityService.getAvailabilitiesForUsers(userIds);

      // Pobierz przypisane harmonogramy
      final Future<List<ScheduleAssignment>> assignmentsFuture =
      scheduleAssignmentService.getAllAssignmentsForUsers(userIds);

      // 2. Uruchom wszystkie operacje pobierania równocześnie
      final results = await Future.wait([
        allWorkEntriesFuture,
        availabilitiesFuture,
        assignmentsFuture,
      ]);

      // 3. Przypisz wyniki do stanu (upewniając się, że widżet nadal istnieje)
      if (!mounted) return;

      // Używamy `setState` tylko raz na końcu, aby zaktualizować UI
      setState(() {
        _allWorkEntries = results[0] as List<WorkEntry>;
        _userAvailabilities = results[1] as List<UserAvailability>;
        _scheduleAssignments = results[2] as List<ScheduleAssignment>;
      });

      // 4. Pobierz dane zależne i zaktualizuj filtry
      await _fetchScheduleTemplateDetails(_scheduleAssignments);
      await _ensureProjectAndAreaNamesAvailable(_allWorkEntries);
      _updateAvailableFilters();

    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Błąd przetwarzania historii: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
// Dodaj nową funkcję pomocniczą do pobierania szablonów
  Future<void> _fetchScheduleTemplateDetails(List<ScheduleAssignment> assignments) async {
    final templateIds = assignments.map((a) => a.scheduleTemplateId).toSet();
    if (templateIds.isEmpty) return;

    for (final templateId in templateIds) {
      if (!_scheduleTemplatesMap.containsKey(templateId)) {
        try {
          final template = await scheduleTemplateService.getTemplate(templateId);
          _scheduleTemplatesMap[templateId] = template;
        } catch(e) {
          print("Nie udało się pobrać szablonu $templateId: $e");
        }
      }
    }
  }
  void _updateAvailableFilters() {
    final projectIdsInView = _allWorkEntries.map((e) => e.projectId).toSet();
    _loadProjectsForFilter(projectIdsInView.toList());
  }

  Future<void> _ensureProjectAndAreaNamesAvailable(List<WorkEntry> entries) async {
    final projectIds = entries.map((e) => e.projectId).toSet();
    final areaIds = entries.map((e) => e.areaId).toSet();

    if (projectIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(projectIds.toList());
      for (var p in newProjects) { _projectNamesMap[p.projectId] = p.name; }
    }
    if (areaIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(areaIds.toList());
      for (var a in newAreas) { _areaNamesMap[a.areaId] = a.name; }
    }
  }

  Future<void> _loadProjectsForFilter(List<String> projectIds) async {
    try {
      _availableProjectsForFilter = await projectService.fetchProjectsByIds(projectIds);
      _availableProjectsForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint("Błąd ładowania projektów do filtra: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      final allAreas = await areaService.getAreasByProject(projectId);
      if (mounted) {
        setState(() {
          _availableAreasForFilter = allAreas;
          _availableAreasForFilter.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _availableAreasForFilter = []);
    }
  }

  void _onFilterChanged() {
    setState(() {});
  }

  void _setDateRangeAndFetch(DateTimeRange newRange) {
    setState(() => _selectedDateRange = newRange);
    _fetchAndProcessEntries();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl', 'PL'),
    );
    if (picked != null && picked != _selectedDateRange) {
      _setDateRangeAndFetch(picked);
    }
  }

  DateTimeRange _getTodayRange() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
  }

  DateTimeRange _getThisWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day), end: now);
  }

  DateTimeRange _getThisMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
      _selectedUser = null;
      _aiQueryController.clear();
      _chatHistory.clear();
    });
    _fetchAndProcessEntries();
  }

  String _generateStringForAi() {
    final buffer = StringBuffer();
    final DateFormat dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm', 'pl_PL');
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd', 'pl_PL');

    // --- SEKCJA 1: GŁÓWNY KONTEKST ANALIZY ---
    // ... (bez zmian)
    buffer.writeln("--- KONTEKST ANALIZY ---");
    buffer.writeln("Data dzisiejsza: ${dateFormat.format(DateTime.now())}");
    buffer.writeln("Analizowany zakres dat: ${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}");
    if (_selectedUser != null) {
      buffer.writeln("Filtrowanie po pracowniku: ${_selectedUser!.displayName ?? _selectedUser!.uid} (ID: ${_selectedUser!.uid})");
    }
    if (_selectedFilterProject != null) {
      buffer.writeln("Filtrowanie po projekcie: ${_selectedFilterProject!.name} (ID: ${_selectedFilterProject!.projectId})");
    }
    if (_selectedFilterArea != null) {
      buffer.writeln("Filtrowanie po obszarze: ${_selectedFilterArea!.name} (ID: ${_selectedFilterArea!.areaId})");
    }


    // --- SEKCJA 2: PRZYPISANE HARMONOGRAMY ---
    // ... (bez zmian)
    buffer.writeln("\n--- PRZYPISANE HARMONOGRAMY W ZAKRESIE ---");
    final relevantAssignments = _scheduleAssignments.where((assignment) {
      bool userMatch = _selectedUser == null || assignment.targetId == _selectedUser!.uid;
      bool dateMatch = assignment.startDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
          assignment.startDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      bool projectMatch = _selectedFilterProject == null || (_scheduleTemplatesMap[assignment.scheduleTemplateId]?.projectId == _selectedFilterProject!.projectId);
      return userMatch && dateMatch && projectMatch;
    }).toList();

    if (relevantAssignments.isEmpty) {
      buffer.writeln("Brak przypisanych harmonogramów spełniających kryteria.");
    } else {
      for (final assignment in relevantAssignments) {
        final userName = _userNamesMap[assignment.targetId] ?? 'Nieznany Użytkownik';
        final template = _scheduleTemplatesMap[assignment.scheduleTemplateId];
        final projectName = _projectNamesMap[template?.projectId] ?? 'Nieznany Projekt';

        buffer.writeln(
            "Pracownik: $userName (ID: ${assignment.targetId}); "
                "Data i godzina startu pracy wg harmonogramu: ${dateTimeFormat.format(assignment.startDate)}; "
                "Data i godzina końca pracy wg harmonogramu: ${dateTimeFormat.format(assignment.endDate)}; "
                "Projekt: $projectName (ID: ${template?.projectId ?? 'brak'}); "
                "Nazwa szablonu: ${template?.name ?? 'Nieznany szablon'}; "
                "ID szablonu: ${assignment.scheduleTemplateId};");
      }
    }


    // --- SEKCJA 3: DEKLARACJE DYSPOZYCYJNOŚCI (FINALNA WERSJA) ---
    buffer.writeln("\n--- DEKLARACJE DYSPOZYCYJNOŚCI ---");
    final relevantAvailabilities = _userAvailabilities.where((availability) {
      bool userMatch = _selectedUser == null || availability.userId == _selectedUser!.uid;
      bool projectMatch = _selectedFilterProject == null || availability.projectId == _selectedFilterProject!.projectId;
      return userMatch && projectMatch;
    }).toList();

    if(relevantAvailabilities.isEmpty) {
      buffer.writeln("Brak deklaracji dyspozycyjności spełniających kryteria.");
    } else {
      for (final availability in relevantAvailabilities) {
        final userName = _userNamesMap[availability.userId] ?? 'Nieznany Użytkownik';
        final projectName = _projectNamesMap[availability.projectId] ?? 'Nieznany Projekt';
        final status = availability.isAvailable ? 'Dostępny' : 'Niedostępny';

        // NOWA LOGIKA: Znajdź szablon i pobierz z niego godziny startu i końca
        final template = _scheduleTemplatesMap[availability.scheduleTemplateId];
        String startTimeStr = "Nieznany czas";
        String endTimeStr = "Nieznany czas";

        if (template != null && availability.blockIndex < template.scheduleBlocks.length) {
          final timeBlock = template.scheduleBlocks[availability.blockIndex];

          // Łączymy datę z `UserAvailability` z godziną i minutą z `TimeBlock`
          final fullStartTime = DateTime(
            availability.date.year,
            availability.date.month,
            availability.date.day,
            timeBlock.startTime.hour,
            timeBlock.startTime.minute,
          );
          final fullEndTime = DateTime(
            availability.date.year,
            availability.date.month,
            availability.date.day,
            timeBlock.endTime.hour,
            timeBlock.endTime.minute,
          );

          startTimeStr = dateTimeFormat.format(fullStartTime);
          endTimeStr = dateTimeFormat.format(fullEndTime);
        }

        buffer.writeln(
            "Pracownik: $userName (ID: ${availability.userId}); "
                "Status: $status; "
                "Projekt: $projectName (ID: ${availability.projectId}); "
                "Początek bloku dostępności: $startTimeStr; "
                "Koniec bloku dostępności: $endTimeStr; "
                "Dotyczy szablonu: ${template?.name ?? 'nieznany'} (ID: ${availability.scheduleTemplateId}, Blok: ${availability.blockIndex})"
        );
      }
    }

    // --- SEKCJA 4: SZCZEGÓŁOWE ZDARZENIA (CZAS PRACY) ---
    // ... (bez zmian)
    buffer.writeln("\n--- SZCZEGÓŁOWE ZDARZENIA (CZAS PRACY) ---");
    List<WorkEntry> tempFilteredEntries = _allWorkEntries.where((entry) {
      if (_selectedUser != null && entry.userId != _selectedUser!.uid) return false;
      if (_selectedFilterProject != null && entry.projectId != _selectedFilterProject!.projectId) return false;
      if (_selectedFilterArea != null && entry.areaId != _selectedFilterArea!.areaId) return false;
      return true;
    }).toList();

    tempFilteredEntries.sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

    if (tempFilteredEntries.isEmpty) {
      buffer.writeln("Brak zarejestrowanych zdarzeń pracy spełniających kryteria.");
    } else {
      for (final entry in tempFilteredEntries) {
        final userName = _userNamesMap[entry.userId] ?? 'Nieznany Użytkownik';
        final eventDateTime = dateTimeFormat.format(entry.eventActionTimestamp.toDate());
        final eventType = entry.isStart ? 'Start Pracy' : 'Stop Pracy';
        final projectName = _projectNamesMap[entry.projectId] ?? 'Nieznany Projekt';
        final areaName = _areaNamesMap[entry.areaId] ?? 'Nieznany Obszar';

        buffer.write(
            "Pracownik: $userName (ID: ${entry.userId}); "
                "Czas zdarzenia: $eventDateTime; "
                "Typ: $eventType; "
                "Zadanie: ${entry.workTypeName}; "
                "Projekt: $projectName (ID: ${entry.projectId}); "
                "Obszar: $areaName (ID: ${entry.areaId}); "
                "Opis: ${entry.description ?? 'brak'}");

        if (entry.relatedInformations != null && entry.relatedInformations!.isNotEmpty) {
          final infoString = entry.relatedInformations!.map((info) => info.toAiString()).join(", ");
          buffer.write("; Dodatkowe informacje: $infoString");
        }
        buffer.writeln();
      }
    }


    print(buffer.toString());
    return buffer.toString();
  }

  Future<void> _sendQueryToAi() async {
    if (_aiQueryController.text.trim().isEmpty) return;

    final userQuery = _aiQueryController.text;
    FocusScope.of(context).unfocus();
    _aiQueryController.clear();

    setState(() {
      _isAiLoading = true;
      // Natychmiast dodaj nową wiadomość użytkownika do historii
      _chatHistory.add({'role': 'user', 'content': userQuery});
    });
    _scrollToBottom();

    try {
      // Krok 1: Przygotuj statyczny kontekst danych
      final dataString = _generateStringForAi();

      // Krok 2: Zbuduj pełny prompt zawierający instrukcje, dane i całą historię rozmowy
      final promptBuffer = StringBuffer();

      promptBuffer.writeln("Jesteś ekspertem w analizie danych o czasie pracy. Twoim zadaniem jest odpowiadanie na pytania użytkownika poprzez samodzielne analizowanie i korelowanie danych z dostarczonych sekcji. Odpowiadaj po polsku, profesjonalnie i zwięźle.");
      promptBuffer.writeln("Twoje zadania analityczne opierają się na następujących regułach:");
      promptBuffer.writeln("1.  **Analiza Nieobecności**: Aby stwierdzić nieobecność, musisz znaleźć pracownika, który ma wpis w sekcji 'PRZYPISANE HARMONOGRAMY' na konkretny dzień, ale w sekcji 'SZCZEGÓŁOWE ZDARZENIA' nie ma dla niego ŻADNYCH zdarzeń w tym samym dniu. Jeśli te dwa warunki są spełnione, pracownik był nieobecny.");
      promptBuffer.writeln("2.  **Analiza Spóźnień**: Aby stwierdzić spóźnienie, musisz znaleźć pracownika, który ma harmonogram na dany dzień. Następnie znajdź jego NAJWCZEŚNIEJSZE zdarzenie typu 'Start Pracy' w tym dniu. Porównaj godzinę tego zdarzenia z 'godziną startu pracy wg harmonogramu'. Jeśli faktyczny start jest późniejszy, pracownik się spóźnił. Podaj o ile.");
      promptBuffer.writeln("3.  **Obliczanie Czasu Pracy**: Czas pracy dla zadania głównego ('main') to różnica między czasem zdarzenia 'Stop Pracy' a 'Start Pracy' dla tego samego zadania.");
      promptBuffer.writeln("4.  **Obliczanie Czasu Przerwy**: Czas przerwy ('break') to różnica między jej końcem ('Stop Pracy') a początkiem ('Start Pracy'). Przerwy należy rozpatrywać w kontekście dnia pracy.");
      promptBuffer.writeln("5.  **Analiza Dostępności /  dyspozycyjności**: Sekcja 'DEKLARACJE DYSPOZYCYJNOŚCI' informuje, kiedy pracownik zadeklarował, że może (status 'Dostępny') lub nie może (status 'Niedostępny') pracować. Jest to jedynie deklaracja pracownika, a nie faktyczny grafik. Gdy użytkownik pyta o dostępność, odpowiedz na podstawie tej sekcji.");
      promptBuffer.writeln("Zawsze dokładnie analizuj daty i godziny, aby poprawnie połączyć harmonogramy ze zdarzeniami. Wyciągaj wnioski tylko na podstawie dostarczonych danych.");

      // Kontekst danych z wpisów pracy
      promptBuffer.writeln("--- DANE DO ANALIZY ---");
      promptBuffer.writeln(dataString);
      promptBuffer.writeln("--- KONIEC DANYCH ---");
      promptBuffer.writeln();

      // Historia konwersacji
      promptBuffer.writeln("--- HISTORIA KONWERSACJI ---");
      if (_chatHistory.isEmpty) {
        promptBuffer.writeln("(Brak wcześniejszej historii. To jest pierwsza wiadomość.)");
      } else {
        // Przejdź przez całą historię czatu, budując dialog
        for (final message in _chatHistory) {
          if (message['role'] == 'user') {
            promptBuffer.writeln("Użytkownik: ${message['content']}");
          } else if (message['role'] == 'ai') {
            // Nie dołączaj komunikatów o błędach do kontekstu dla AI
            if (message['isError'] != true) {
              promptBuffer.writeln("Asystent: ${message['content']}");
            }
          }
        }
      }
      promptBuffer.writeln("--- KONIEC HISTORII ---");
      promptBuffer.writeln();
      promptBuffer.writeln("Odpowiedz na OSTATNIE pytanie od użytkownika, biorąc pod uwagę powyższe dane i całą historię konwersacji.");

      final fullPrompt = promptBuffer.toString();

      // Krok 3: Wyślij zapytanie do AI
      var model = FirebaseAI.vertexAI();
      //var model = FirebaseAI.googleAI();
      final gemini = model.generativeModel(model: 'gemini-2.0-flash-001');
      final response = await gemini.generateContent([Content.text(fullPrompt)]);
      if (response.usageMetadata != null) {
        final usage = response.usageMetadata!;
        print('--- Użycie Tokenów ---');
        print('Liczba tokenów promptu: ${usage.promptTokenCount}');
        print('Liczba tokenów wygenerowanej odpowiedzi: ${usage.candidatesTokenCount}');
        print('Całkowita liczba tokenów: ${usage.totalTokenCount}');
        print('----------------------');
      }
      if(mounted && response.text != null){
        setState(() {
          // Dodaj odpowiedź AI do historii
          _chatHistory.add({'role': 'ai', 'content': response.text!});
        });
      } else if (mounted) {
        // Obsłuż przypadek, gdy odpowiedź jest pusta
        throw Exception("Otrzymano pustą odpowiedź od serwera AI.");
      }

    } catch(e) {
      if(mounted){
        setState(() {
          // Dodaj błąd do historii czatu, aby użytkownik go widział
          _chatHistory.add({'role': 'ai', 'content': 'Wystąpił błąd: ${e.toString()}', 'isError': true});
        });
      }
    } finally {
      if(mounted) {
        setState(() => _isAiLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  // #endregion

  // #region Logika eksportu do PDF
  Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData.buffer.asByteData());
  }

  Future<void> _exportConversationToPdf() async {
    if (_chatHistory.isEmpty) {
      await showErrorDialog(context, "Brak Danych", "Historia konwersacji jest pusta i nie można jej wyeksportować.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ttfRegular = await _loadFont("assets/fonts/Roboto-Regular.ttf");
      final ttfBold = await _loadFont("assets/fonts/Roboto-Bold.ttf");
      final pdfTheme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);
      final pdf = pw.Document(theme: pdfTheme);

      final String dateRangeStr = _selectedDateRange != null
          ? '${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.end)}'
          : 'Nieokreślony zakres';
      final String filtersStr = [
        if (_selectedUser != null) 'Pracownik: ${_userNamesMap[_selectedUser!.uid]}',
        if (_selectedFilterProject != null) 'Projekt: ${_selectedFilterProject!.name}',
        if (_selectedFilterArea != null) 'Obszar: ${_selectedFilterArea!.name}',
      ].where((s) => s.isNotEmpty).join(', ');

      final List<pw.Widget> chatWidgets = _chatHistory.map((message) {
        final role = message['role'];
        final content = message['content'] as String;
        final isError = message['isError'] ?? false;
        if (role == 'user') {
          return _buildUserMessagePdf(content);
        } else {
          return _buildAiMessagePdf(content, isError: isError);
        }
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => _buildPdfHeader('Raport z konwersacji AI', dateRangeStr, filtersStr),
          footer: (context) => _buildPdfFooter(context),
          build: (context) => [pw.ListView(children: chatWidgets, spacing: 5)],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Raport_AI_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );

    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, "Błąd Eksportu PDF", "Nie udało się wygenerować pliku PDF: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  pw.Widget _buildPdfHeader(String title, String dateRange, String filters) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
          pw.SizedBox(height: 10),
          pw.Text('Dane źródłowe z okresu: $dateRange'),
          if (filters.isNotEmpty) pw.Text('Zastosowane filtry: $filters'),
          pw.Divider(height: 20, thickness: 1.5),
        ]);
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Strona ${context.pageNumber} z ${context.pagesCount}',
          style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)),
    );
  }

  pw.Widget _buildUserMessagePdf(String text) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        constraints: const pw.BoxConstraints(maxWidth: 400),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex("#1976D2"), // Kolor Primary z motywu
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(15),
            bottomLeft: pw.Radius.circular(15),
            topRight: pw.Radius.circular(15),
          ),
        ),
        child: pw.Text(text, style: const pw.TextStyle(color: PdfColors.white)),
      ),
    );
  }

  pw.Widget _buildAiMessagePdf(String text, {bool isError = false}) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        constraints: const pw.BoxConstraints(maxWidth: 400),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: isError ? PdfColor.fromHex("#B00020") : PdfColor.fromHex("#E0E0E0"), // Kolor Error / Grey
          borderRadius: const pw.BorderRadius.only(
            topRight: pw.Radius.circular(15),
            bottomRight: pw.Radius.circular(15),
            topLeft: pw.Radius.circular(15),
          ),
        ),
        child: pw.Text(text, style: pw.TextStyle(color: isError ? PdfColors.white : PdfColors.black)),
      ),
    );
  }

  // #endregion

  // #region Budowa UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiza AI'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // NOWY PRZYCISK EKSPORTU DO PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Eksportuj konwersację do PDF',
            onPressed: _chatHistory.isEmpty || _isLoading ? null : _exportConversationToPdf,
          ),
          IconButton(
            icon: Icon(_isFilterPanelVisible ? Icons.filter_list_off_outlined : Icons.filter_list_outlined),
            tooltip: _isFilterPanelVisible ? 'Ukryj filtry' : 'Pokaż filtry',
            onPressed: () => setState(() => _isFilterPanelVisible = !_isFilterPanelVisible),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAnimatedFilterPanel(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _buildChatView(theme),
          ),
          _buildAiInputPanel(theme),
        ],
      ),
    );
  }

  Widget _buildAnimatedFilterPanel(ThemeData theme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Visibility(
        visible: _isFilterPanelVisible,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: _buildFilterSection(theme),
        ),
      ),
    );
  }

  // ZMODYFIKOWANA SEKCJA FILTRÓW
  Widget _buildFilterSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _buildDatePresetButtons(theme), // NOWY WIDGET
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDateRange != null
                          ? '${DateFormat('dd.MM.yy').format(_selectedDateRange!.start)} - ${DateFormat('dd.MM.yy').format(_selectedDateRange!.end)}'
                          : 'Wybierz zakres',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 38.0), // Dopasowanie do wysokości przycisków
                child: ElevatedButton(
                  onPressed: _clearFilters,
                  child: const Icon(Icons.clear_all_rounded),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<UserApp>(
                decoration: const InputDecoration(labelText: 'Pracownik', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                value: _selectedUser,
                hint: const Text('Wszyscy'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<UserApp>(value: null, child: Text('Wszyscy')),
                  ..._availableUsers.map((u) => DropdownMenuItem<UserApp>(value: u, child: Text(u.displayName ?? u.uid!, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (val) => setState(() { _selectedUser = val; _onFilterChanged(); }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<Project>(
                decoration: const InputDecoration(labelText: 'Projekt', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                value: _selectedFilterProject,
                hint: const Text('Wszystkie'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<Project>(value: null, child: Text('Wszystkie')),
                  ..._availableProjectsForFilter.map((p) => DropdownMenuItem<Project>(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedFilterProject = val;
                    _selectedFilterArea = null;
                    _availableAreasForFilter = [];
                  });
                  if (val != null) _loadAreasForFilter(val.projectId);
                  _onFilterChanged();
                },
              ),
            ),
          ],
        ),
        if(_selectedFilterProject != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Area>(
            decoration: const InputDecoration(labelText: 'Obszar', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            value: _selectedFilterArea,
            hint: const Text('Wszystkie'),
            isExpanded: true,
            items: [
              const DropdownMenuItem<Area>(value: null, child: Text('Wszystkie')),
              ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)))
            ],
            onChanged: (val) => setState(() { _selectedFilterArea = val; _onFilterChanged(); }),
          ),
        ],
      ],
    );
  }

  // NOWY WIDGET PRZYCISKÓW DATY
  Widget _buildDatePresetButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.start,
        children: [
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getTodayRange()),
              child: const Text('Dzisiaj')),
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getThisWeekRange()),
              child: const Text('Ten tydzień')),
          TextButton(
              onPressed: () => _setDateRangeAndFetch(_getThisMonthRange()),
              child: const Text('Ten miesiąc')),
        ],
      ),
    );
  }

  Widget _buildChatView(ThemeData theme) {
    if (_chatHistory.isEmpty && !_isAiLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Zadaj pytanie dotyczące danych z wybranego okresu i filtrów.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: _chatHistory.length + (_isAiLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isAiLoading && index == _chatHistory.length) {
          return const AiBubble(isLoading: true);
        }
        final message = _chatHistory[index];
        return message['role'] == 'user'
            ? UserBubble(text: message['content'])
            : AiBubble(
            text: message['content'],
            isError: message['isError'] ?? false
        );
      },
    );
  }

  Widget _buildAiInputPanel(ThemeData theme) {
    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _aiQueryController,
                decoration: const InputDecoration(
                  hintText: 'Zadaj pytanie AI...',
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendQueryToAi(),
                enabled: !_isAiLoading,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _isAiLoading ? null : _sendQueryToAi,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
// #endregion
}

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Text(text, style: TextStyle(color: theme.colorScheme.onPrimary)),
      ),
    );
  }
}

class AiBubble extends StatelessWidget {
  final String? text;
  final bool isLoading;
  final bool isError;
  const AiBubble({super.key, this.text, this.isLoading = false, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            topLeft: Radius.circular(20),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 25,
          height: 25,
          child: CircularProgressIndicator(strokeWidth: 3),
        )
            : SelectableText(text ?? '', style: TextStyle(
            color: isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurfaceVariant
        ),
        ),
      ),
    );
  }
}