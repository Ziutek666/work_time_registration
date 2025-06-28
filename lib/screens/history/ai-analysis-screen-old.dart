import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/area.dart';
import '../../models/information_category.dart';
import '../../models/project.dart';
import '../../models/user_app.dart';
import '../../models/work_entry.dart';
import '../../services/members_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';
import '../../services/work_entry_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:collection/collection.dart';
import 'package:printing/printing.dart';


import '../../services/area_service.dart';
import '../../widgets/dialogs.dart';

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
      final futures = _availableUsers.map((user) =>
          workEntryService.getWorkEntriesForUserBetweenDates(
              user.uid!, _selectedDateRange!.start, _selectedDateRange!.end.add(const Duration(days: 1))
          )
      ).toList();
      final results = await Future.wait(futures);
      _allWorkEntries = results.expand((list) => list).toList();
      await _ensureProjectAndAreaNamesAvailable(_allWorkEntries);
      _updateAvailableFilters();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Błąd przetwarzania historii: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    // Ta funkcja jest wywoływana po każdej zmianie filtra.
    // Nie ma potrzeby ponownego pobierania danych, tylko przefiltrowania tego co mamy.
    // Tutaj można dodać logikę, jeśli analiza ma się dziać na żywo po zmianie filtrów.
    // Na razie pozostawiam to puste, bo analiza jest wyzwalana przyciskiem "Zapytaj AI"
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

  // #endregion
  // #region Logika AI
  /// ZMODYFIKOWANA FUNKCJA
  String _generateStringForAi() {
    final buffer = StringBuffer();
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'pl_PL');

    buffer.writeln("--- KONTEKST ANALIZY ---");
    buffer.writeln("Zakres dat: ${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}");
    if (_selectedUser != null) buffer.writeln("Pracownik: ${_selectedUser!.displayName ?? _selectedUser!.uid}");
    if (_selectedFilterProject != null) buffer.writeln("Projekt: ${_selectedFilterProject!.name}");
    if (_selectedFilterArea != null) buffer.writeln("Obszar: ${_selectedFilterArea!.name}");
    buffer.writeln("\n--- SZCZEGÓŁOWE ZDARZENIA ---");

    List<WorkEntry> tempFiltered = _allWorkEntries.where((e) {
      if (_selectedUser != null && e.userId != _selectedUser!.uid) return false;
      if (_selectedFilterProject != null && e.projectId != _selectedFilterProject!.projectId) return false;
      if (_selectedFilterArea != null && e.areaId != _selectedFilterArea!.areaId) return false;
      return true;
    }).toList();

    tempFiltered.sort((a, b) => a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

    if (tempFiltered.isEmpty) {
      buffer.writeln("Brak zdarzeń spełniających kryteria filtrowania.");
      return buffer.toString();
    }

    for (final entry in tempFiltered) {
      final userName = _userNamesMap[entry.userId] ?? entry.userId;
      final eventDateTime = dateFormat.format(entry.eventActionTimestamp.toDate());
      final eventType = entry.isStart ? 'Start' : 'Stop';
      final projectName = _projectNamesMap[entry.projectId] ?? 'Nieznany projekt';
      final areaName = _areaNamesMap[entry.areaId] ?? 'Nieznany obszar';

      buffer.write(
          "Pracownik: $userName; Data: $eventDateTime; Typ: $eventType; Zadanie: ${entry.workTypeName}; Projekt: $projectName; Obszar: $areaName; Opis: ${entry.description ?? 'brak'}");

      // --- POCZĄTEK MODYFIKACJI ---
      // Sprawdzanie i dołączanie powiązanych informacji bezpośrednio z obiektu
      String informations = '';
      if (entry.relatedInformations != null && entry.relatedInformations!.isNotEmpty) {
        for (final info in entry.relatedInformations!) {
          informations += info.toAiString();
        }
        buffer.write("; Informacje: $informations");
      }
      // --- KONIEC MODYFIKACJI ---

      buffer.writeln(); // Zakończ linię dla danego wpisu
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
      _chatHistory.add({'role': 'user', 'content': userQuery});
    });
    _scrollToBottom();

    try {
      final dataString = _generateStringForAi();
      final prompt = """
        Jesteś ekspertem w analizie danych o czasie pracy. Odpowiedz na pytanie użytkownika na podstawie dostarczonych danych. Odpowiadaj po polsku, profesjonalnie i zwięźle.

        --- DANE DO ANALIZY ---
        $dataString
        --- KONIEC DANYCH ---

        Pytanie użytkownika: "$userQuery"
      """;

      var model = FirebaseAI.vertexAI();
      final gemini = model.generativeModel(model: 'gemini-2.0-flash-001'); // Użyj nowego modelu
      final response = await gemini.generateContent([Content.text(prompt)]);
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
          _chatHistory.add({'role': 'ai', 'content': response.text!});
        });
      }

    } catch(e) {
      if(mounted){
        setState(() {
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
          // Przycisk do pokazywania/chowania filtrów
          IconButton(
            icon: Icon(_isFilterPanelVisible ? Icons.filter_list_off_outlined : Icons.filter_list_outlined),
            tooltip: _isFilterPanelVisible ? 'Ukryj filtry' : 'Pokaż filtry',
            onPressed: () => setState(() => _isFilterPanelVisible = !_isFilterPanelVisible),
          ),
        ],
      ),
      body: Column(
        children: [
          // Animowany panel filtrów
          _buildAnimatedFilterPanel(theme),

          // Główna zawartość - czat lub ładowanie
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))
                : _buildChatView(theme),
          ),

          // Dolny panel do wpisywania wiadomości
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
            color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: _buildFilterSection(theme),
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _selectedDateRange != null
                      ? '${DateFormat('dd.MM.yy').format(_selectedDateRange!.start)} - ${DateFormat('dd.MM.yy').format(_selectedDateRange!.end)}'
                      : 'Wybierz zakres',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _selectDateRange(context),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Icon(Icons.clear_all_rounded),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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

// --- WIDŻETY POMOCNICZE DO CZATU ---

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
