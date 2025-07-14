import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../../../models/area.dart';
import '../../../models/user_app.dart';
import '../../../models/schedule_assignments.dart';
import '../../../models/schedule_template.dart';
import '../../../models/user_availability.dart';
import '../../../screens/schedule/schedule_data_source.dart';
import '../../../services/area_service.dart';
import '../../../services/availability_service.dart';
import '../../../services/members_service.dart';
import '../../../services/project_service.dart';
import '../../../services/schedule_assignment_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/availability_assignment_dialog.dart';
import '../../../widgets/dialogs.dart';
import '../../models/project-access.dart';

// Zunifikowany model dla terminu w kalendarzu
class UnifiedAppointmentItem extends Appointment {
  final int blockIndex;
  final List<ScheduleAssignment> assignments;
  final List<UserAvailability> availabilities;
  final List<UserApp> allUsersInProject;

  UnifiedAppointmentItem({
    required this.blockIndex,
    required this.assignments,
    required this.availabilities,
    required this.allUsersInProject,
    required DateTime startTime,
    required DateTime endTime,
    required String subject,
    required Color color,
  }) : super(startTime: startTime, endTime: endTime, subject: subject, color: color);
}

class AdminScheduleCalendarScreen extends StatefulWidget {
  final ScheduleTemplate template;
  const AdminScheduleCalendarScreen({required this.template, super.key});

  @override
  State<AdminScheduleCalendarScreen> createState() => _AdminScheduleCalendarScreenState();
}

class _AdminScheduleCalendarScreenState extends State<AdminScheduleCalendarScreen> {
  final CalendarController _calendarController = CalendarController();
  CalendarView _currentView = CalendarView.week;
  bool _isLoading = true;
  ScheduleDataSource? _dataSource;
  ViewChangedDetails? _lastViewDetails;

  // Zunifikowane źródła danych
  List<ScheduleAssignment> _allAssignments = [];
  List<UserAvailability> _allAvailabilities = [];
  Map<String, UserApp> _userMap = {};

  // ZMIANA: Przechowujemy tylko jeden, główny obszar szablonu
  Area? _templateArea;

  // Logika szybkiego przypisywania
  bool _isQuickAssignMode = false;
  final Set<UserApp> _quickAssignUsers = {};
  final Map<String, UnifiedAppointmentItem> _quickAssignSlots = {};

  // Stan i kontrolery dla Asystenta AI
  final TextEditingController _aiQueryController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isAiLoading = false;
  final ScrollController _aiChatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _aiQueryController.dispose();
    _aiChatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    if (forceRefresh || !_isLoading) {
      setState(() { _isLoading = true; });
    }
    try {
      // ZMIANA: Uproszczone ładowanie obszaru - tylko jeden dla szablonu
      if (_templateArea == null || forceRefresh) {
        _templateArea = await areaService.getArea(widget.template.areaId);
      }

      if (_userMap.isEmpty || forceRefresh) {
        final project = await projectService.getProject(widget.template.projectId);
        if (project == null) throw Exception('Nie znaleziono projektu.');
        final members = await membersService.getMembersByOwner(project.ownerId);
        final allUserIds = members.map((m) => m.userId).where((id) => id != null).cast<String>().toSet().toList();
        if (allUserIds.isNotEmpty) {
          final users = await userService.getUsersByIds(allUserIds);
          _userMap = {for (var user in users) user.uid!: user};
          _allAvailabilities = await availabilityService.getAvailabilitiesForUsers(allUserIds);
        }
      }

      final assignments = await scheduleAssignmentService.getAssignmentsForTemplate(widget.template.templateId);
      _allAssignments = assignments.where((a) => a.targetType == widget.template.targetType).toList();

    } catch (e) {
      if(mounted) showErrorDialog(context, 'Błąd ładowania', 'Nie udało się pobrać danych: $e');
    }
    if (mounted) {
      setState(() { _isLoading = false; });
      if (_lastViewDetails != null) {
        _buildUnifiedAppointments(_lastViewDetails!);
      }
    }
  }

  void _buildUnifiedAppointments(ViewChangedDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appointments = <UnifiedAppointmentItem>[];

      for (final date in details.visibleDates) {
        for (int i = 0; i < widget.template.scheduleBlocks.length; i++) {
          final block = widget.template.scheduleBlocks[i];
          final occurrences = SfCalendar.getRecurrenceDateTimeCollection(
              block.recurrenceRule, block.startTime, specificStartDate: date, specificEndDate: date);
          if (occurrences.isEmpty) continue;

          final assignmentsForBlock = _allAssignments.where((a) => DateUtils.isSameDay(a.startDate, date) && a.blockIndex == i).toList();
          final availabilitiesForBlock = _allAvailabilities.where((a) => DateUtils.isSameDay(a.date, date) && a.blockIndex == i).toList();

          final appointmentStartTime = DateTime(date.year, date.month, date.day, block.startTime.hour, block.startTime.minute);
          final appointmentEndTime = appointmentStartTime.add(block.endTime.difference(block.startTime));

          appointments.add(UnifiedAppointmentItem(
            blockIndex: i,
            startTime: appointmentStartTime,
            endTime: appointmentEndTime,
            subject: block.name,
            color: block.color,
            assignments: assignmentsForBlock,
            availabilities: availabilitiesForBlock,
            allUsersInProject: _userMap.values.toList(),
          ));
        }
      }
      setState(() { _dataSource = ScheduleDataSource(appointments); });
    });
  }

  void _onCalendarTapped(CalendarTapDetails details) async {
    if (details.targetElement != CalendarElement.appointment || details.appointments == null || details.appointments!.isEmpty) return;

    final appointment = details.appointments!.first as UnifiedAppointmentItem;

    if (_isQuickAssignMode) {
      _handleSlotSelection(appointment);
    } else {
      final allVisibleAppointments = _dataSource?.appointments
          ?.whereType<UnifiedAppointmentItem>()
          .sorted((a, b) => a.startTime.compareTo(b.startTime))
          .toList() ?? [];
      final currentIndex = allVisibleAppointments.indexOf(appointment);
      if (currentIndex == -1) return;

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AvailabilityAssignmentDialog(
          allAppointments: allVisibleAppointments,
          initialIndex: currentIndex,
          userMap: _userMap,
          // ZMIANA: Przekazujemy tylko jeden obszar w mapie
          areaCache: _templateArea != null ? {_templateArea!.areaId: _templateArea!} : {},
          allAssignments: _allAssignments,
          template: widget.template,
        ),
      );

      if (result == true) {
        await _loadInitialData(forceRefresh: true);
      }
    }
  }

  String _getSlotKey(UnifiedAppointmentItem item) => '${DateFormat('yyyy-MM-dd').format(item.startTime)}-${item.blockIndex}';

  void _handleSlotSelection(UnifiedAppointmentItem appointment) {
    final key = _getSlotKey(appointment);
    setState(() {
      if (_quickAssignSlots.containsKey(key)) {
        _quickAssignSlots.remove(key);
      } else {
        _quickAssignSlots[key] = appointment;
      }
    });
  }

  // ZMIANA: Uproszczona logika trybu szybkiego przypisywania
  Future<void> _toggleQuickAssignMode({bool forceOff = false}) async {
    if (_isQuickAssignMode || forceOff) {
      setState(() {
        _isQuickAssignMode = false;
        _quickAssignUsers.clear();
        _quickAssignSlots.clear();
      });
      return;
    }
    try {
      // Krok 1: Pobierz wszystkich użytkowników z dostępem do obszaru szablonu
      final allMembers = await membersService.getMembershipsForProject(widget.template.projectId, _userMap.keys.toList());
      final usersWithAccess = allMembers
          .where((member) => member.projects.any((p) => p.projectId == widget.template.projectId && p.areaIds.contains(widget.template.areaId)))
          .map((member) => _userMap[member.userId])
          .whereNotNull()
          .toList();

      if (usersWithAccess.isEmpty) {
        showInfoDialog(context, 'Brak pracowników', 'Żaden pracownik w tym projekcie nie ma dostępu do obszaru "${_templateArea?.name ?? 'N/A'}".');
        return;
      }

      // Krok 2: Pokaż dialog wyboru użytkowników (tylko tych z dostępem)
      final selectedUsers = await showDialog<Set<UserApp>>(
        context: context,
        builder: (ctx) => _UserSelectionDialog(allUsers: usersWithAccess),
      );
      if (selectedUsers == null || selectedUsers.isEmpty) return;

      // Krok 3: Ustaw tryb - nie ma potrzeby wybierania obszaru
      setState(() {
        _isQuickAssignMode = true;
        _quickAssignUsers.addAll(selectedUsers);
      });
    } catch (e) {
      if(mounted) showErrorDialog(context, 'Błąd', 'Wystąpił nieoczekiwany błąd: $e');
    }
  }

  Future<void> _performQuickAssignment() async {
    if (_quickAssignUsers.isEmpty || _quickAssignSlots.isEmpty) {
      showInfoDialog(context, 'Brak zaznaczenia', 'Wybierz pracowników i co najmniej jeden blok.');
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final proposedAssignments = <ScheduleAssignment>[];
      for (final slot in _quickAssignSlots.values) {
        for (final user in _quickAssignUsers) {
          if (slot.assignments.any((existingAssignment) => existingAssignment.targetId == user.uid)) continue;
          proposedAssignments.add(ScheduleAssignment(
            scheduleTemplateId: widget.template.templateId,
            targetId: user.uid!,
            targetType: widget.template.targetType,
            startDate: slot.startTime,
            endDate: slot.endTime,
            blockIndex: slot.blockIndex,
            areaId: widget.template.areaId, // ZMIANA: Użyj areaId z szablonu
          ));
        }
      }
      for (final user in _quickAssignUsers) {
        final userProposedAssignments = proposedAssignments.where((a) => a.targetId == user.uid).toList();
        await scheduleAssignmentService.validateOverlappingAssignments(userProposedAssignments, user.uid!);
      }
      if (proposedAssignments.isEmpty) {
        showInfoDialog(context, 'Brak zmian', 'Wybrani pracownicy są już przypisani do zaznaczonych bloków.');
      } else {
        await scheduleAssignmentService.createMultipleAssignments(proposedAssignments);
      }
      await _toggleQuickAssignMode(forceOff: true);
      await _loadInitialData(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano przypisania.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) showErrorDialog(context, 'Błąd zapisu', e.toString());
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  Widget _buildSummaryRow({required IconData icon, required String text, required bool isCompact, Color? color = Colors.white}) {
    if (isCompact) {
      return Text(text, style: TextStyle(color: color?.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color?.withOpacity(0.7), size: 14),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // #region Logika Asystenta AI (bez zmian)
  String _generateStringForAi() {
    final buffer = StringBuffer();
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm', 'pl_PL');
    final dateFormat = DateFormat('yyyy-MM-dd', 'pl_PL');
    final visibleStartDate = _lastViewDetails?.visibleDates.first ?? DateTime.now();
    final visibleEndDate = _lastViewDetails?.visibleDates.last ?? DateTime.now();

    buffer.writeln("--- KONTEKST ANALIZY ---");
    buffer.writeln("Analiza dotyczy szablonu: '${widget.template.name}' w obszarze '${_templateArea?.name ?? 'N/A'}' (ID: ${widget.template.templateId})");
    buffer.writeln("Analizowany zakres dat w kalendarzu: ${dateFormat.format(visibleStartDate)} - ${dateFormat.format(visibleEndDate)}");

    buffer.writeln("\n--- PRZYPISANE HARMONOGRAMY (RZECZYWISTY GRAFIK) ---");
    if (_allAssignments.isEmpty) {
      buffer.writeln("Brak przypisanych harmonogramów w tym szablonie.");
    } else {
      for (final assignment in _allAssignments) {
        final userName = _userMap[assignment.targetId]?.displayName ?? 'Nieznany';
        buffer.writeln(
            "Pracownik: $userName (ID: ${assignment.targetId}); "
                "Start grafiku: ${dateTimeFormat.format(assignment.startDate)}; "
                "Koniec grafiku: ${dateTimeFormat.format(assignment.endDate)}; "
                "ID szablonu: ${assignment.scheduleTemplateId}; Blok: ${assignment.blockIndex};"
        );
      }
    }

    buffer.writeln("\n--- DEKLARACJE DYSPOZYCYJNOŚCI (CHĘCI PRACOWNIKÓW) ---");
    if (_allAvailabilities.isEmpty) {
      buffer.writeln("Brak deklaracji dyspozycyjności od pracowników.");
    } else {
      for (final availability in _allAvailabilities) {
        final userName = _userMap[availability.userId]?.displayName ?? 'Nieznany';
        final status = availability.isAvailable ? 'Dostępny' : 'Niedostępny';
        final template = widget.template;
        String startTimeStr = "Nieznany czas", endTimeStr = "Nieznany czas";
        if (availability.blockIndex >= 0 && availability.blockIndex < template.scheduleBlocks.length) {
          final timeBlock = template.scheduleBlocks[availability.blockIndex];
          final fullStartTime = DateTime(availability.date.year, availability.date.month, availability.date.day, timeBlock.startTime.hour, timeBlock.startTime.minute);
          final fullEndTime = DateTime(availability.date.year, availability.date.month, availability.date.day, timeBlock.endTime.hour, timeBlock.endTime.minute);
          startTimeStr = dateTimeFormat.format(fullStartTime);
          endTimeStr = dateTimeFormat.format(fullEndTime);
        }
        buffer.writeln(
            "Pracownik: $userName (ID: ${availability.userId}); "
                "Status deklaracji: $status; "
                "Początek bloku: $startTimeStr; "
                "Koniec bloku: $endTimeStr; "
                "ID szablonu: ${availability.scheduleTemplateId}; Blok: ${availability.blockIndex};"
        );
      }
    }

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiChatScrollController.hasClients && _aiChatScrollController.position.maxScrollExtent > 0) {
        _aiChatScrollController.animateTo(_aiChatScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showAiAssistantPanel() {
    _chatHistory.clear();
    _aiQueryController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {

            void sendQuery() async {
              if (_aiQueryController.text.trim().isEmpty) return;
              final userQuery = _aiQueryController.text;
              FocusScope.of(context).unfocus();

              modalState(() {
                _isAiLoading = true;
                _chatHistory.add({'role': 'user', 'content': userQuery});
                _aiQueryController.clear();
              });
              _scrollToBottom();

              try {
                final dataString = _generateStringForAi();
                final promptBuffer = StringBuffer();

                promptBuffer.writeln("Jesteś ekspertem w analizie planowania grafików i dostępności pracowników. Twoim zadaniem jest odpowiadanie na pytania użytkownika, analizując dostarczone dane. Odpowiadaj po polsku, profesjonalnie i zwięźle.");
                promptBuffer.writeln("Twoje zadania analityczne opierają się na następujących regułach:");
                promptBuffer.writeln("1. **Pytania o Grafik**: Gdy użytkownik pyta 'kto jest w pracy?' lub 'jaki jest grafik?', podsumuj informacje z sekcji 'PRZYPISANE HARMONOGRAMY'.");
                promptBuffer.writeln("2. **Pytania o Dostępność**: Gdy użytkownik pyta o dostępność, użyj sekcji 'DEKLARACJE DYSPOZYCYJNOŚCI'.");
                promptBuffer.writeln("3. **NAJWAŻNIEJSZE - WYKRYWANIE KONFLIKTÓW**: Konflikt występuje, gdy pracownik ma wpis w 'PRZYPISANE HARMONOGRAMY' (musi pracować), ale dla tego samego dnia i bloku czasowego istnieje jego wpis w 'DEKLARACJE DYSPOZYCYJNOŚCI' ze statusem 'Niedostępny'. Twoim priorytetem jest proaktywne wyszukiwanie i jasne wskazywanie takich sytuacji.");
                promptBuffer.writeln("4. **NAJWAŻNIEJSZE - ZNAJDOWANIE POTENCJAŁU**: Potencjał (luka w grafiku) występuje, gdy pracownik ma wpis 'Dostępny' w 'DEKLARACJE DYSPOZYCYJNOŚCI', ale nie ma dla niego odpowiadającego wpisu w 'PRZYPISANE HARMONOGRAMY'. Zasugeruj obsadzenie go na wolnej zmianie.");
                promptBuffer.writeln("Zawsze podawaj imiona i nazwiska pracowników, daty i godziny, aby Twoje odpowiedzi były precyzyjne i użyteczne dla planisty.");

                promptBuffer.writeln("\n--- DANE DO ANALIZY ---");
                promptBuffer.writeln(dataString);
                promptBuffer.writeln("--- KONIEC DANYCH ---\n");

                final fullPrompt = promptBuffer.toString();
                final model = FirebaseAI.vertexAI();
                final gemini = model.generativeModel(model: 'gemini-2.0-flash-001');
                final response = await gemini.generateContent([Content.text(fullPrompt)]);

                if (mounted) {
                  modalState(() {
                    _chatHistory.add({'role': 'ai', 'content': response.text ?? "Brak odpowiedzi."});
                  });
                }
              } catch (e) {
                if (mounted) {
                  modalState(() {
                    _chatHistory.add({'role': 'ai', 'content': 'Wystąpił błąd: ${e.toString()}', 'isError': true});
                  });
                }
              } finally {
                if (mounted) {
                  modalState(() {
                    _isAiLoading = false;
                  });
                  _scrollToBottom();
                }
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Material(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  elevation: 8,
                  child: Column(
                    children: [
                      AppBar(
                        title: const Text('Asystent Planowania AI'),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        automaticallyImplyLeading: false,
                        centerTitle: true,
                        actions: [
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop())
                        ],
                      ),
                      Expanded(
                        child: _chatHistory.isEmpty && !_isAiLoading
                            ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text('Zadaj pytanie, np. "Kto jest dostępny w piątek rano?" lub "Znajdź konflikty w grafiku".', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                          ),
                        )
                            : ListView.builder(
                          controller: _aiChatScrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _chatHistory.length + (_isAiLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isAiLoading && index == _chatHistory.length) {
                              return const AiBubble(isLoading: true);
                            }
                            final message = _chatHistory[index];
                            return message['role'] == 'user'
                                ? UserBubble(text: message['content'])
                                : AiBubble(text: message['content'], isError: message['isError'] ?? false);
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0,-2))]
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiQueryController,
                                decoration: const InputDecoration(hintText: 'Zadaj pytanie AI...', border: InputBorder.none),
                                onSubmitted: (_) => sendQuery(),
                                enabled: !_isAiLoading,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_rounded),
                              onPressed: _isAiLoading ? null : sendQuery,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        // ZMIANA: Bardziej informacyjny tytuł
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isQuickAssignMode ? 'Szybkie przypisanie' : 'Grafik: ${widget.template.name}',
              overflow: TextOverflow.ellipsis,
            ),
            if (_templateArea != null)
              Text(
                'Obszar: ${_templateArea!.name}',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
              )
          ],
        ),
        actions: [
          if (_isQuickAssignMode) ...[
            IconButton(icon: const Icon(Icons.close), tooltip: 'Anuluj', onPressed: () => _toggleQuickAssignMode(forceOff: true)),
            IconButton(icon: const Icon(Icons.save), tooltip: 'Zapisz', onPressed: _performQuickAssignment),
          ] else ...[
            if (widget.template.targetType == ScheduleTargetType.user)
              IconButton(icon: const Icon(Icons.add_task), tooltip: 'Szybkie przypisywanie', onPressed: _toggleQuickAssignMode),
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _calendarController.backward!()),
            IconButton(icon: const Icon(Icons.today, size: 20), onPressed: () => _calendarController.displayDate = DateTime.now()),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _calendarController.forward!()),
          ]
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAiAssistantPanel,
        tooltip: 'Asystent Planowania AI',
        child: const Icon(Icons.auto_awesome),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
        key: ValueKey(_dataSource),
        controller: _calendarController,
        view: _currentView,
        dataSource: _dataSource,
        firstDayOfWeek: 1,
        onViewChanged: (details) {
          if (_lastViewDetails != null &&
              _lastViewDetails!.visibleDates.length == details.visibleDates.length &&
              _lastViewDetails!.visibleDates.first == details.visibleDates.first) {
            return;
          }
          _lastViewDetails = details;
          _buildUnifiedAppointments(details);
        },
        onTap: _onCalendarTapped,
        timeSlotViewSettings: const TimeSlotViewSettings(timeIntervalHeight: 20, timeFormat: 'HH:mm'),
        appointmentBuilder: (context, details) {
          final appointment = details.appointments.first as UnifiedAppointmentItem;
          final isSelected = _quickAssignSlots.containsKey(_getSlotKey(appointment));
          final assignedCount = appointment.assignments.length;
          final availableCount = appointment.availabilities.where((a) => a.isAvailable).length;
          final unavailableCount = appointment.availabilities.where((a) => !a.isAvailable).length;
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: appointment.color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
              border: isSelected ? Border.all(color: theme.primaryColor, width: 3) : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 65;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.subject,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (assignedCount > 0)
                            _buildSummaryRow(icon: Icons.person, text: assignedCount.toString(), isCompact: isCompact),
                          if (availableCount > 0 || unavailableCount > 0)
                            _buildSummaryRow(icon: Icons.event_available, text: '$availableCount / $unavailableCount', isCompact: isCompact, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _UserSelectionDialog extends StatefulWidget {
  final List<UserApp> allUsers;
  const _UserSelectionDialog({required this.allUsers});
  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}
class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  final Set<UserApp> _selectedUsers = {};
  void _toggleSelectAll() {
    setState(() {
      if (_selectedUsers.length == widget.allUsers.length) {
        _selectedUsers.clear();
      } else {
        _selectedUsers.addAll(widget.allUsers);
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final bool areAllSelected = _selectedUsers.isNotEmpty && _selectedUsers.length == widget.allUsers.length;
    return AlertDialog(
      title: const Text('Wybierz pracowników'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.allUsers.isEmpty
            ? const Center(child: Text('Brak dostępnych pracowników.'))
            : ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allUsers.length,
          itemBuilder: (context, index) {
            final user = widget.allUsers[index];
            return CheckboxListTile(
              title: Text(user.displayName ?? 'Brak nazwy'),
              value: _selectedUsers.contains(user),
              onChanged: (isSelected) {
                setState(() {
                  if (isSelected == true) {
                    _selectedUsers.add(user);
                  } else {
                    _selectedUsers.remove(user);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        if (widget.allUsers.isNotEmpty) TextButton(onPressed: _toggleSelectAll, child: Text(areAllSelected ? 'Odznacz wszystkich' : 'Zaznacz wszystkich')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(onPressed: _selectedUsers.isNotEmpty ? () => Navigator.of(context).pop(_selectedUsers) : null, child: const Text('Dodaj zaznaczonych')),
      ],
    );
  }
}

class _AreaSelectionDialog extends StatefulWidget {
  final List<Area> availableAreas;
  const _AreaSelectionDialog({required this.availableAreas});
  @override
  State<_AreaSelectionDialog> createState() => _AreaSelectionDialogState();
}
class _AreaSelectionDialogState extends State<_AreaSelectionDialog> {
  Area? _selectedArea;
  @override
  void initState() {
    super.initState();
    if (widget.availableAreas.length == 1) {
      _selectedArea = widget.availableAreas.first;
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wybierz strefę'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.availableAreas.length,
          itemBuilder: (context, index) {
            final area = widget.availableAreas[index];
            return RadioListTile<Area>(
              title: Text(area.name),
              value: area,
              groupValue: _selectedArea,
              onChanged: (Area? value) { setState(() { _selectedArea = value; }); },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(onPressed: _selectedArea != null ? () => Navigator.of(context).pop(_selectedArea) : null, child: const Text('Wybierz')),
      ],
    );
  }
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
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
          borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20), topLeft: Radius.circular(20)),
        ),
        child: isLoading
            ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3))
            : SelectableText(text ?? '', style: TextStyle(color: isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}