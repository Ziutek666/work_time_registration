import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
// Importy dla PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// Importy dla Excela
import 'package:excel/excel.dart' as excel_plugin;
import 'package:file_saver/file_saver.dart';

// Dostosuj ścieżki do swoich modeli i serwisów
import '../../models/work_entry.dart';
import '../../models/project.dart';
import '../../models/area.dart';
import '../../models/user_app.dart';
import '../../models/information.dart';
import '../../services/work_entry_service.dart';
import '../../services/project_service.dart';
import '../../services/area_service.dart';
import '../../services/user_service.dart';
import '../../services/information_category_service.dart';
import '../../models/information_category.dart';
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


class UserHistoryScreen extends StatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFilterPanelExpanded = true;
  UserApp? _currentUser;

  // Struktura danych
  Map<String, Map<String, List<WorkSession>>> _groupedSessions = {};
  List<WorkEntry> _allWorkEntries = [];
  Map<String, InformationCategory> _allCategories = {};

  // Filtry
  DateTimeRange? _selectedDateRange;
  Project? _selectedFilterProject;
  Area? _selectedFilterArea;

  // Stan dla podsumowania czasów
  Duration _totalMainWorkDuration = Duration.zero;
  Duration _totalBreakDuration = Duration.zero;
  Duration _totalSubtaskDuration = Duration.zero;

  // Mapy nazw i dostępne obiekty do filtrów
  List<Project> _availableProjectsForFilter = [];
  List<Area> _availableAreasForFilter = [];
  Map<String, String> _projectNamesMap = {};
  Map<String, String> _areaNamesMap = {};

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss', 'pl_PL');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _currentUser = await userService.getCurrentUser();
      if (_currentUser == null) throw Exception(
          "Brak zalogowanego użytkownika.");
      final now = DateTime.now();
      _selectedDateRange =
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      await _fetchAndProcessEntries();
    } catch (e) {
      if (mounted) setState(() =>
      _errorMessage = "Błąd inicjalizacji: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndProcessEntries() async {
    if (_selectedDateRange == null || _currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _allWorkEntries =
      await workEntryService.getWorkEntriesForUserBetweenDates(
        _currentUser!.uid!,
        _selectedDateRange!.start,
        DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month,
            _selectedDateRange!.end.day + 1),
      );
      await _ensureProjectAndAreaNamesAvailable(_allWorkEntries);
      _applyFiltersAndGroup();
    } catch (e) {
      if (mounted) setState(() =>
      _errorMessage = "Błąd przetwarzania historii: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndGroup() {
    List<WorkEntry> tempFiltered = List.from(_allWorkEntries);
    if (_selectedFilterProject != null) tempFiltered =
        tempFiltered.where((e) => e.projectId ==
            _selectedFilterProject!.projectId).toList();
    if (_selectedFilterArea != null) tempFiltered =
        tempFiltered.where((e) => e.areaId == _selectedFilterArea!.areaId)
            .toList();
    _calculateSummaryDurations(tempFiltered);
    tempFiltered.sort((a, b) =>
        a.eventActionTimestamp.compareTo(b.eventActionTimestamp));
    _groupedSessions.clear();
    final groupedByProject = groupBy(tempFiltered, (entry) => entry.projectId);
    groupedByProject.forEach((projectId, entriesInProject) {
      final groupedByArea = groupBy(entriesInProject, (entry) => entry.areaId);
      final areaMap = <String, List<WorkSession>>{};
      groupedByArea.forEach((areaId, entriesInArea) {
        areaMap[areaId] = _pairEntriesIntoSessions(entriesInArea);
      });
      _groupedSessions[projectId] = areaMap;
    });
    final projectIdsInView = _groupedSessions.keys.toSet();
    if (projectIdsInView.isNotEmpty) _loadProjectsForFilter(
        projectIdsInView.toList());
    if (mounted) setState(() {});
  }

  List<WorkSession> _pairEntriesIntoSessions(List<WorkEntry> entries) {
    final List<WorkSession> sessions = [];
    WorkEntry? activeMainTaskStart;
    List<WorkEntry> eventsForCurrentSession = [];

    for (final entry in entries) {
      if (entry.workTypeIsCheckPoint) {
        if (activeMainTaskStart == null) {
          sessions.add(
              WorkSession(startEntry: entry, allEventsInSession: [entry]));
        } else {
          eventsForCurrentSession.add(entry);
        }
        continue;
      }

      if (activeMainTaskStart == null) {
        if (entry.isStart && entry.workTypeIsMain) {
          activeMainTaskStart = entry;
          eventsForCurrentSession.add(entry);
        }
      } else {
        eventsForCurrentSession.add(entry);
        if (!entry.isStart && entry.workTypeIsMain &&
            entry.workTypeId == activeMainTaskStart.workTypeId) {
          sessions.add(WorkSession(startEntry: activeMainTaskStart,
              endEntry: entry,
              allEventsInSession: List.from(eventsForCurrentSession)));
          activeMainTaskStart = null;
          eventsForCurrentSession.clear();
        }
      }
    }

    if (activeMainTaskStart != null) {
      sessions.add(WorkSession(startEntry: activeMainTaskStart,
          allEventsInSession: List.from(eventsForCurrentSession)));
    }

    sessions.sort((a, b) => b.startEntry.eventActionTimestamp.compareTo(
        a.startEntry.eventActionTimestamp));
    return sessions;
  }

  void _calculateSummaryDurations(List<WorkEntry> entries) {
    Map<String, WorkEntry> openSessions = {};
    List<MapEntry<WorkEntry, WorkEntry>> pairedSessions = [];
    final sortedEntries = List<WorkEntry>.from(entries)
      ..sort((a, b) =>
          a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

    for (var entry in sortedEntries) {
      if (entry.workTypeIsCheckPoint) continue;
      String sessionKey = '${entry.userId}_${entry.projectId}_${entry
          .areaId}_${entry.workTypeId}';
      if (entry.isStart) {
        openSessions[sessionKey] = entry;
      } else {
        if (openSessions.containsKey(sessionKey)) {
          pairedSessions.add(MapEntry(openSessions.remove(sessionKey)!, entry));
        }
      }
    }

    Duration mainWork = Duration.zero,
        breakTime = Duration.zero,
        subtaskTime = Duration.zero;
    for (var session in pairedSessions) {
      final duration = session.value.eventActionTimestamp.toDate().difference(
          session.key.eventActionTimestamp.toDate());
      if (session.key.workTypeIsBreak)
        breakTime += duration;
      else if (session.key.workTypeIsSubTask)
        subtaskTime += duration;
      else
        mainWork += duration;
    }

    if (mounted) setState(() {
      _totalMainWorkDuration = mainWork;
      _totalBreakDuration = breakTime;
      _totalSubtaskDuration = subtaskTime;
    });
  }

  String _formatDurationHHMMSS(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _ensureProjectAndAreaNamesAvailable(
      List<WorkEntry> entries) async {
    final projectIds = entries.map((e) => e.projectId).toSet();
    final areaIds = entries.map((e) => e.areaId).toSet();
    final missingProjectIds = projectIds.where((id) =>
    id.isNotEmpty && !_projectNamesMap.containsKey(id)).toList();
    final missingAreaIds = areaIds.where((id) =>
    id.isNotEmpty && !_areaNamesMap.containsKey(id)).toList();

    if (missingProjectIds.isNotEmpty) {
      final newProjects = await projectService.fetchProjectsByIds(
          missingProjectIds);
      for (var p in newProjects)
        _projectNamesMap[p.projectId] = p.name;
    }
    if (missingAreaIds.isNotEmpty) {
      final newAreas = await areaService.getAreasByIds(missingAreaIds);
      for (var a in newAreas)
        _areaNamesMap[a.areaId] = a.name;
    }
  }

  Future<void> _loadProjectsForFilter(List<String> projectIds) async {
    try {
      _availableProjectsForFilter =
      await projectService.fetchProjectsByIds(projectIds);
      _availableProjectsForFilter.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint("Błąd ładowania projektów do filtra: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAreasForFilter(String projectId) async {
    try {
      final allAreas = await areaService.getAreasByProject(projectId);
      if (mounted) setState(() => _availableAreasForFilter = allAreas
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    } catch (e) {
      debugPrint("Błąd ładowania obszarów dla projektu $projectId: $e");
      if (mounted) setState(() => _availableAreasForFilter = []);
    }
  }

  void _onProjectFilterChanged(Project? project) {
    setState(() {
      _selectedFilterProject = project;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    if (project != null) _loadAreasForFilter(project.projectId);
    _applyFiltersAndGroup();
  }

  void _onAreaFilterChanged(Area? area) {
    setState(() => _selectedFilterArea = area);
    _applyFiltersAndGroup();
  }

  void _setDateRangeAndFetch(DateTimeRange newRange) {
    setState(() => _selectedDateRange = newRange);
    _fetchAndProcessEntries();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(context: context,
        initialDateRange: _selectedDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('pl', 'PL'));
    if (picked != null && picked != _selectedDateRange) _setDateRangeAndFetch(
        picked);
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange =
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      _selectedFilterProject = null;
      _selectedFilterArea = null;
      _availableAreasForFilter = [];
    });
    _fetchAndProcessEntries();
  }

  DateTimeRange _getTodayRange() => DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 1)),
      end: DateTime.now());

  DateTimeRange _getThisWeekRange() =>
      DateTimeRange(start: DateTime.now().subtract(Duration(days: DateTime
          .now()
          .weekday - 1)), end: DateTime.now());

  DateTimeRange _getThisMonthRange() =>
      DateTimeRange(start: DateTime(DateTime
          .now()
          .year, DateTime
          .now()
          .month, 1), end: DateTime.now());

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      var excel = excel_plugin.Excel.createExcel();
      excel.delete('Sheet1');
      excel_plugin.Sheet sheetObject = excel['Historia Pracy'];

      excel_plugin.CellStyle headerStyle = excel_plugin.CellStyle(bold: true,
          backgroundColorHex: "#FFDDDDDD".excelColor,
          verticalAlign: excel_plugin.VerticalAlign.Center,
          horizontalAlign: excel_plugin.HorizontalAlign.Center,
          textWrapping: excel_plugin.TextWrapping.WrapText);

      List<excel_plugin.TextCellValue> headers = [
        excel_plugin.TextCellValue('Data i Godzina'),
        excel_plugin.TextCellValue('Zdarzenie (Start/Stop)'),
        excel_plugin.TextCellValue('Projekt'),
        excel_plugin.TextCellValue('Obszar'),
        excel_plugin.TextCellValue('Nazwa Zadania'),
        excel_plugin.TextCellValue('Opis'),
      ];

      sheetObject.appendRow(headers);
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(excel_plugin.CellIndex.indexByColumnRow(
            columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      List<WorkEntry> tempFiltered = List.from(_allWorkEntries);
      if (_selectedFilterProject != null) tempFiltered.removeWhere((e) =>
      e.projectId != _selectedFilterProject!.projectId);
      if (_selectedFilterArea != null) tempFiltered.removeWhere((e) =>
      e.areaId != _selectedFilterArea!.areaId);

      tempFiltered.sort((a, b) =>
          a.eventActionTimestamp.compareTo(b.eventActionTimestamp));

      for (final entry in tempFiltered) {
        final eventDateTime = _dateFormat.format(
            entry.eventActionTimestamp.toDate());
        final eventType = entry.isStart ? 'Start' : 'Stop';
        final projectName = _projectNamesMap[entry.projectId] ??
            entry.projectId;
        final areaName = _areaNamesMap[entry.areaId] ?? entry.areaId;

        List<excel_plugin.CellValue> row = [
          excel_plugin.TextCellValue(eventDateTime),
          excel_plugin.TextCellValue(eventType),
          excel_plugin.TextCellValue(projectName),
          excel_plugin.TextCellValue(areaName),
          excel_plugin.TextCellValue(entry.workTypeName),
          excel_plugin.TextCellValue(entry.description ?? ''),
        ];
        sheetObject.appendRow(row);
      }

      for (var i = 0; i < headers.length; i++) {
        //sheetObject.setColAutoFit(i);
      }
      String fileName = "moja_historia_pracy_${DateFormat('yyyyMMdd_HHmm')
          .format(DateTime.now())}.xlsx";
      var fileBytes = excel.save(fileName: fileName);

    } catch (e) {
      if (mounted) await showErrorDialog(context, "Błąd Eksportu",
          "Nie udało się wygenerować pliku Excel: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData.buffer.asByteData());
  }

  Future<void> _generatePdfForSession(WorkSession session) async {
    final ttfRegular = await _loadFont("assets/fonts/Roboto-Regular.ttf");
    final ttfBold = await _loadFont("assets/fonts/Roboto-Bold.ttf");
    final pdfTheme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);
    final pdf = pw.Document(theme: pdfTheme);

    final userName = _currentUser?.displayName ?? 'Brak nazwy użytkownika';
    final projectName = _projectNamesMap[session.startEntry.projectId] ??
        'Nie przypisano projektu';
    final areaName = _areaNamesMap[session.startEntry.areaId] ??
        'Nie przypisano obszaru';
    final sessionDate = DateFormat('dd.MM.yyyy').format(
        session.startEntry.eventActionTimestamp.toDate());
    final totalTime = _formatDurationHHMMSS(session.duration);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Karta Pracy', style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfInfoRow('Pracownik:', userName),
                        _buildPdfInfoRow('Projekt:', projectName),
                        _buildPdfInfoRow('Obszar:', areaName),
                      ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfInfoRow('Data:', sessionDate),
                        _buildPdfInfoRow(
                            'Łączny czas pracy:', totalTime, isBold: true),
                      ]),
                ]),
            pw.Divider(height: 30, thickness: 1.5),
            _buildPdfSessionBlock(session),
            pw.Spacer(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
              pw.Column(children: [
                pw.Container(width: 150, child: pw.Divider()),
                pw.SizedBox(height: 4),
                pw.Text('Podpis pracownika')
              ]),
              pw.Column(children: [
                pw.Container(width: 150, child: pw.Divider()),
                pw.SizedBox(height: 4),
                pw.Text('Podpis przełożonego')
              ])
            ]),
            pw.SizedBox(height: 20),
          ]),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(),
        name: 'karta_pracy_${session.workTypeName.replaceAll(' ', '_')}.pdf');
  }

  pw.Widget _buildPdfInfoRow(String label, String value,
      {bool isBold = false}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: isBold
              ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle()),
        ]));
  }

  pw.Widget _buildPdfHeader(String userName, String dateRange) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Raport Akcji i Informacji',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
      pw.SizedBox(height: 5),
      pw.Text('Dla: $userName'),
      pw.Text('Okres: $dateRange'),
      pw.Divider(height: 20, thickness: 1.5)
    ]);
  }

  pw.Widget _buildPdfFooter(pw.Context context) =>
      pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Strona ${context.pageNumber} z ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)));

  pw.Widget _buildPdfSummaryTable() {
    return pw.Table.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headers: ['Typ Czasu', 'Suma'],
        data: [
          ['Praca główna', _formatDurationHHMMSS(_totalMainWorkDuration)],
          ['Podzadania', _formatDurationHHMMSS(_totalSubtaskDuration)],
          ['Przerwy', _formatDurationHHMMSS(_totalBreakDuration)],
        ]);
  }

  pw.Widget _buildPdfSessionBlock(WorkSession session) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(session.workTypeName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 5),
        if (!session.isCheckPointEvent)
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Czas trwania: ${_formatDurationHHMMSS(session.duration)}'),
            pw.Text(session.isFinished ? 'Zakończona' : 'W toku',
                style: pw.TextStyle(
                    color: session.isFinished ? PdfColors.green700 : PdfColors
                        .orange700)),
          ]),
        pw.SizedBox(height: 5),
        pw.Text('Zdarzenie: ${_dateFormat.format(
            session.startEntry.eventActionTimestamp.toDate())} ${_timeFormat
            .format(session.startEntry.eventActionTimestamp.toDate())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        if (session.isFinished)
          pw.Text('Koniec:    ${_dateFormat.format(
              session.endEntry!.eventActionTimestamp.toDate())} ${_timeFormat
              .format(session.endEntry!.eventActionTimestamp.toDate())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Divider(height: 10, color: PdfColors.grey400),
        pw.SizedBox(height: 5),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: session.allEventsInSession.map((entry) =>
                _buildPdfWorkEntryRow(entry)).toList()),
      ]),
    );
  }

  pw.Widget _buildPdfWorkEntryRow(WorkEntry entry) {
    String actionText;
    if (entry.workTypeIsCheckPoint) {
      actionText = entry.workTypeName;
    } else {
      actionText = '${entry.isStart ? "START" : "STOP"}: ${entry.workTypeName}';
    }
    final infos = entry.relatedInformations ?? [];
    return pw.Container(
        padding: const pw.EdgeInsets.only(left: 10, bottom: 5, top: 5),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(actionText, style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text(
                '${_timeFormat.format(entry.eventActionTimestamp.toDate())}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ]),
          if (infos.isNotEmpty)
            ...infos.map((info) {
              final List<pw.Widget> infoWidgets = [
                pw.Text(info.content, style: const pw.TextStyle(fontSize: 8))
              ];
              if (info.decision != null) infoWidgets.add(pw.Text(
                  info.decision! ? "Odp: TAK" : "Odp: NIE", style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: info.decision! ? PdfColors.green700 : PdfColors
                      .red700)));
              if (info.textResponse != null) infoWidgets.add(pw.Text(
                  'Opis: ${info.textResponse}',
                  style: const pw.TextStyle(fontSize: 8)));
              return pw.Container(
                  padding: const pw.EdgeInsets.only(left: 8, top: 2),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: infoWidgets));
            }).toList()
        ]));
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          title: const Text('Moja Historia Akcji'),
          actions: [
            IconButton(icon: const Icon(Icons.download_for_offline_outlined),
                onPressed: _isLoading || _groupedSessions.isEmpty
                    ? null
                    : _exportToExcel)
          ]),
      body: Column(children: [
        _buildCollapsibleFilterPanel(theme),
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : _buildHistoryList(theme)),
      ]),
    );
  }

  Widget _buildCollapsibleFilterPanel(ThemeData theme) =>
      Card(
          margin: const EdgeInsets.all(8),
          child: ExpansionTile(
              initiallyExpanded: _isFilterPanelExpanded,
              onExpansionChanged: (e) =>
                  setState(() => _isFilterPanelExpanded = e),
              title: const Text("Filtry i Podsumowanie"),
              children: [
                Padding(padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _buildSummaryCard(theme),
                      _buildFilterSection(theme)
                    ]))
              ]));

  Widget _buildSummaryCard(ThemeData theme) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Twoje Podsumowanie Czasu',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        _buildSummaryRow(theme, Icons.work_outline, 'Praca:',
            _formatDurationHHMMSS(_totalMainWorkDuration)),
        _buildSummaryRow(theme, Icons.free_breakfast_outlined, 'Przerwy:',
            _formatDurationHHMMSS(_totalBreakDuration),
            color: Colors.orange.shade700),
        _buildSummaryRow(theme, Icons.low_priority_rounded, 'Podzadania:',
            _formatDurationHHMMSS(_totalSubtaskDuration),
            color: Colors.teal.shade600),
        const Divider(height: 24)
      ]);

  Widget _buildSummaryRow(ThemeData theme, IconData icon, String label,
      String value, {Color? color}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text('$label '),
            const Spacer(),
            Text(value, style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? theme.colorScheme.primary))
          ]));

  Widget _buildFilterSection(ThemeData theme) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildDatePresetButtons(theme),
        OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(
                _selectedDateRange != null ? '${DateFormat('dd.MM.yyyy').format(
                    _selectedDateRange!.start)} - ${DateFormat('dd.MM.yyyy')
                    .format(_selectedDateRange!.end)}' : 'Wybierz zakres dat'),
            onPressed: () => _selectDateRange(context)),
        const SizedBox(height: 12),
        DropdownButtonFormField<Project>(
            decoration: const InputDecoration(
                labelText: 'Projekt', border: OutlineInputBorder()),
            value: _selectedFilterProject,
            hint: const Text('Wszystkie'),
            items: [
              const DropdownMenuItem<Project>(
                  value: null, child: Text('Wszystkie projekty')),
              ..._availableProjectsForFilter.map((p) =>
                  DropdownMenuItem<Project>(value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis)))
            ],
            onChanged: _onProjectFilterChanged),
        const SizedBox(height: 12),
        DropdownButtonFormField<Area>(
            decoration: InputDecoration(labelText: 'Obszar',
                border: const OutlineInputBorder(),
                filled: _selectedFilterProject == null),
            value: _selectedFilterArea,
            hint: const Text('Wszystkie'),
            onChanged: _selectedFilterProject == null
                ? null
                : _onAreaFilterChanged,
            items: [
              const DropdownMenuItem<Area>(
                  value: null, child: Text('Wszystkie obszary')),
              ..._availableAreasForFilter.map((a) => DropdownMenuItem<Area>(
                  value: a,
                  child: Text(a.name, overflow: TextOverflow.ellipsis)))
            ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Wyczyść Filtry'),
            onPressed: _clearFilters)
      ]);

  Widget _buildDatePresetButtons(ThemeData theme) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(spacing: 8.0, alignment: WrapAlignment.center, children: [
            TextButton(onPressed: () => _setDateRangeAndFetch(_getTodayRange()),
                child: const Text('Dzisiaj')),
            TextButton(
                onPressed: () => _setDateRangeAndFetch(_getThisWeekRange()),
                child: const Text('Ten tydzień')),
            TextButton(
                onPressed: () => _setDateRangeAndFetch(_getThisMonthRange()),
                child: const Text('Ten miesiąc'))
          ]));

  Widget _buildHistoryList(ThemeData theme) {
    if (_groupedSessions.isEmpty && !_isLoading)
      return const Center(child: Text('Brak sesji pracy do wyświetlenia.'));
    final projectIds = _groupedSessions.keys.toList()
      ..sort((a, b) =>
          (_projectNamesMap[a] ?? a).compareTo(_projectNamesMap[b] ?? ''));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: projectIds.length,
      itemBuilder: (context, projectIndex) {
        final projectId = projectIds[projectIndex];
        final projectName = _projectNamesMap[projectId] ?? 'Projekt bez nazwy';
        final areasInProject = _groupedSessions[projectId]!;
        final areaIds = areasInProject.keys.toList()
          ..sort((a, b) =>
              (_areaNamesMap[a] ?? a).compareTo(_areaNamesMap[b] ?? ''));
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ExpansionTile(
            key: PageStorageKey<String>(projectId),
            leading: Icon(
                Icons.folder_copy_outlined, color: theme.colorScheme.primary),
            title: Text(projectName,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            children: areaIds.map((areaId) {
              final areaName = _areaNamesMap[areaId] ?? 'Obszar bez nazwy';
              final sessionsInArea = areasInProject[areaId]!;
              return _buildAreaSessionsList(areaName, sessionsInArea, theme);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAreaSessionsList(String areaName, List<WorkSession> sessions,
      ThemeData theme) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 16, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text("Obszar: $areaName",
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold))),
          ...sessions.map((session) => _buildSessionCard(session, theme)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(WorkSession session, ThemeData theme) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (session.isCheckPointEvent)
            Text(session.workTypeName,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic, color: Colors.blue.shade700))
          else
            Text(session.workTypeName,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(children: [
            if (!session.isCheckPointEvent) ...[
              Icon(Icons.timer_outlined, size: 16,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(_formatDurationHHMMSS(session.duration),
                  style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
            ],
            const Spacer(),
            if (!session.isFinished && !session.isCheckPointEvent) const Chip(
                label: Text('W TOKU'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white, fontSize: 10)),
            if (!session.isCheckPointEvent) IconButton(
                icon: const Icon(Icons.print_outlined),
                iconSize: 20.0,
                color: theme.colorScheme.secondary,
                tooltip: 'Drukuj raport dla tej sesji',
                onPressed: () => _generatePdfForSession(session))
          ]),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
              'Zdarzenie: ${_dateFormat.format(
                  session.startEntry.eventActionTimestamp
                      .toDate())} ${_timeFormat.format(
                  session.startEntry.eventActionTimestamp.toDate())}'
                  '${session.isFinished ? "\nKoniec:      ${_dateFormat.format(
                  session.endEntry!.eventActionTimestamp
                      .toDate())} ${_timeFormat.format(
                  session.endEntry!.eventActionTimestamp.toDate())}" : ""}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline)),
        ),
        children: [
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...session.allEventsInSession.map((event) =>
                        _buildWorkEntryRowWithInfo(event, theme))
                  ])),
        ],
      ),
    );
  }

  Widget _buildWorkEntryRowWithInfo(WorkEntry entry, ThemeData theme) {
    IconData icon;
    Color color;
    String actionText;

    if (entry.workTypeIsCheckPoint) {
      actionText = entry.workTypeName;
      icon = Icons.flag_outlined;
      color = Colors.blue.shade700;
    } else {
      actionText =
      '${entry.isStart ? "Rozpoczęcie" : "Zakończenie"}: ${entry.workTypeName}';
      if (entry.workTypeIsBreak) {
        icon = entry.isStart ? Icons.free_breakfast_outlined : Icons
            .check_circle_outline;
        color = Colors.orange.shade700;
      } else if (entry.workTypeIsSubTask) {
        icon =
        entry.isStart ? Icons.low_priority_rounded : Icons.check_circle_outline;
        color = Colors.teal.shade600;
      } else {
        icon =
        entry.isStart ? Icons.play_circle_outline : Icons.stop_circle_outlined;
        color = theme.colorScheme.primary;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(actionText, style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600)),
            Text('${_dateFormat.format(
                entry.eventActionTimestamp.toDate())}  ${_timeFormat.format(
                entry.eventActionTimestamp.toDate())}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline)),
          ])),
        ]),
        if (entry.relatedInformations != null &&
            entry.relatedInformations!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 8.0, right: 4.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(border: Border(
                  left: BorderSide(color: theme.dividerColor, width: 2.0))),
              child: _buildInfoList(entry.relatedInformations!, theme),
            ),
          ),
      ]),
    );
  }

  Widget _buildInfoList(List<Information> infos, ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: infos.map((info) =>
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 8.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                if (info.decision != null)
                  info.decision!
                      ? Text("Odp: TAK",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold))
                      : Text("Odp: NIE",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold)),
                if (info.textResponse != null) Text(
                    'Opis: ${info.textResponse!}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline)),
                Text(_formatUpdateTime(info.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline, fontSize: 10)),
              ]),
            )).toList());
  }

  String _formatUpdateTime(Timestamp? timestamp) =>
      timestamp == null ? 'Brak daty' : 'Aktualizacja: ${_dateFormat.format(
          timestamp.toDate())} ${_timeFormat.format(timestamp.toDate())}';
}