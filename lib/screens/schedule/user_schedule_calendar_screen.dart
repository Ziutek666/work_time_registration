import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:work_time_registration/models/user_availability.dart';
import 'package:work_time_registration/services/availability_service.dart';
import '../../../models/area.dart';
import '../../../models/project.dart';
import '../../../models/schedule_assignments.dart';
import '../../../models/schedule_template.dart';
import '../../../screens/schedule/schedule_data_source.dart';
import '../../../services/area_service.dart';
import '../../../services/schedule_assignment_service.dart';
import '../../../services/schedule_template_service.dart';
import '../../../services/user_service.dart';
import '../../../services/members_service.dart';
import '../../../widgets/dialogs.dart';
import '../../widgets/availability_wizard.dart';

enum ScheduleDisplayMode {
  myAssignments,
  allTemplates,
  availability,
}

class UserScheduleAppointmentItem extends Appointment {
  final ScheduleAssignment? assignment;
  final String templateName;
  final String projectName;
  final String areaName;

  UserScheduleAppointmentItem({
    this.assignment,
    required this.templateName,
    required this.projectName,
    required this.areaName,
    required DateTime startTime,
    required DateTime endTime,
    required String subject,
    required Color color,
    super.resourceIds,
  }) : super(
    startTime: startTime,
    endTime: endTime,
    subject: subject,
    color: color,
  );
}

class AvailabilityAppointmentItem extends Appointment {
  final UserAvailability availability;
  final String documentId;

  AvailabilityAppointmentItem({
    required this.availability,
    required this.documentId,
    required DateTime startTime,
    required DateTime endTime,
    required String subject,
    required Color color,
  }) : super(
    startTime: startTime,
    endTime: endTime,
    subject: subject,
    color: color,
  );
}

class UserScheduleCalendarScreen extends StatefulWidget {
  const UserScheduleCalendarScreen({super.key});

  @override
  State<UserScheduleCalendarScreen> createState() => _UserScheduleCalendarScreenState();
}

class _UserScheduleCalendarScreenState extends State<UserScheduleCalendarScreen> {
  final CalendarController _calendarController = CalendarController();
  bool _isLoading = true;
  Key _calendarKey = UniqueKey();
  CalendarView _currentView = CalendarView.week;
  ScheduleDisplayMode _displayMode = ScheduleDisplayMode.myAssignments;
  ViewChangedDetails? _lastViewDetails;

  List<ScheduleAssignment> _myAssignments = [];
  List<ScheduleTemplate> _allUserTemplates = [];
  Map<String, ScheduleTemplate> _templateCache = {};
  Map<String, Project> _projectCache = {};
  Map<String, Area> _areaCache = {};
  ScheduleDataSource? _dataSource;

  Map<String, UserAvailability> _myAvailabilities = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (forceRefresh || _isLoading == false) {
      setState(() { _isLoading = true; });
    }
    try {
      final userId = userService.uid;
      if (userId == null) throw Exception('Użytkownik niezalogowany.');

      if (_projectCache.isEmpty || forceRefresh) {
        final myProjects = await membersService.getAllProjectsForUserAcrossCompanies(userId);
        _projectCache = {for (var p in myProjects) p.projectId: p};
      }

      if (_templateCache.isEmpty || forceRefresh) {
        _allUserTemplates.clear();
        for (final project in _projectCache.values) {
          final templates = await scheduleTemplateService.getTemplatesForProject(project.projectId);
          // UWAGA: Upewnij się, że 'ScheduleTargetType.user' jest poprawnie zdefiniowane w Twoim projekcie
          _allUserTemplates.addAll(templates.where((t) => t.targetType == ScheduleTargetType.user));
        }
        _templateCache = {for (var t in _allUserTemplates) t.templateId: t};
      }

      final assignmentsFuture = scheduleAssignmentService.getAssignmentsForUser(userId);
      final availabilitiesFuture = availabilityService.getAvailabilitiesForUserWithDocId(userId);

      final results = await Future.wait([assignmentsFuture, availabilitiesFuture]);

      _myAssignments = results[0] as List<ScheduleAssignment>;
      _myAvailabilities = results[1] as Map<String, UserAvailability>;

      final areaIds = _myAssignments.map((a) => a.areaId).where((id) => id.isNotEmpty).toSet();
      if (areaIds.isNotEmpty) {
        final areas = await areaService.getAreasByIds(areaIds.toList());
        _areaCache = {for (var area in areas) area.areaId: area};
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd ładowania', 'Nie udało się pobrać danych: $e');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
        _refreshCalendarView();
      }
    }
  }

  void _refreshCalendarView() {
    switch (_displayMode) {
      case ScheduleDisplayMode.myAssignments:
        _buildMyAssignmentsOnly();
        break;
      case ScheduleDisplayMode.allTemplates:
        if (_lastViewDetails != null) {
          _buildAllTemplatesView(_lastViewDetails!);
        } else {
          setState(() { _dataSource = ScheduleDataSource([]); });
        }
        break;
      case ScheduleDisplayMode.availability:
        _buildAvailabilityView();
        break;
    }
  }

  void _buildAppointmentsForVisibleDates(ViewChangedDetails details) {
    _lastViewDetails = details;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayMode == ScheduleDisplayMode.allTemplates) {
        _buildAllTemplatesView(details);
      }
    });
  }

  void _buildMyAssignmentsOnly() {
    final appointments = <UserScheduleAppointmentItem>[];
    for (final assignment in _myAssignments) {
      final template = _templateCache[assignment.scheduleTemplateId];
      if (template == null || template.scheduleBlocks.length <= assignment.blockIndex) continue;
      final block = template.scheduleBlocks[assignment.blockIndex];
      final projectName = _projectCache[template.projectId]?.name ?? 'Brak projektu';
      final areaName = _areaCache[assignment.areaId]?.name ?? '';

      appointments.add(UserScheduleAppointmentItem(
        assignment: assignment, templateName: template.name, projectName: projectName, areaName: areaName,
        startTime: assignment.startDate, endTime: assignment.endDate ?? DateTime.now(),
        subject: block.name, color: block.color,
      ));
    }
    setState(() { _dataSource = ScheduleDataSource(appointments); });
  }

  void _buildAllTemplatesView(ViewChangedDetails details) {
    final appointments = <UserScheduleAppointmentItem>[];
    final assignedSlotsMap = { for (var a in _myAssignments) '${a.startDate}-${a.blockIndex}-${a.scheduleTemplateId}': a };
    for (final date in details.visibleDates) {
      for (final template in _allUserTemplates) {
        for (int i = 0; i < template.scheduleBlocks.length; i++) {
          final block = template.scheduleBlocks[i];
          final occurrences = SfCalendar.getRecurrenceDateTimeCollection(
              block.recurrenceRule, block.startTime, specificStartDate: date, specificEndDate: date);

          if (occurrences.isNotEmpty) {
            final appointmentStartTime = DateTime(date.year, date.month, date.day, block.startTime.hour, block.startTime.minute);
            final appointmentEndTime = appointmentStartTime.add(block.endTime.difference(block.startTime));
            final projectName = _projectCache[template.projectId]?.name ?? 'Brak projektu';
            final slotKey = '$appointmentStartTime-$i-${template.templateId}';
            final assignment = assignedSlotsMap[slotKey];
            final areaName = assignment != null ? (_areaCache[assignment.areaId]?.name ?? '') : '';

            appointments.add(UserScheduleAppointmentItem(
              assignment: assignment, templateName: template.name, projectName: projectName, areaName: areaName,
              startTime: appointmentStartTime, endTime: appointmentEndTime,
              subject: block.name, color: block.color,
            ));
          }
        }
      }
    }
    setState(() { _dataSource = ScheduleDataSource(appointments); });
  }

  void _buildAvailabilityView() {
    final appointments = <AvailabilityAppointmentItem>[];
    _myAvailabilities.forEach((docId, availability) {
      final template = _templateCache[availability.scheduleTemplateId];
      if (template == null || template.scheduleBlocks.length <= availability.blockIndex) return;
      final block = template.scheduleBlocks[availability.blockIndex];

      final startTime = DateTime(availability.date.year, availability.date.month, availability.date.day, block.startTime.hour, block.startTime.minute);
      final endTime = startTime.add(block.endTime.difference(block.startTime));

      final subject = availability.isAvailable ? 'Dostępny: ${block.name}' : 'Niedostępny: ${block.name}';
      final color = availability.isAvailable ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.6);

      appointments.add(AvailabilityAppointmentItem(
        availability: availability, documentId: docId,
        startTime: startTime, endTime: endTime, subject: subject, color: color,
      ));
    });
    setState(() { _dataSource = ScheduleDataSource(appointments); });
  }

  // ZMIANA: Usunięto skomplikowaną funkcję _handleAvailabilitySave.
  // Logika jest teraz prosta: jeśli kreator zwróci 'true', odśwież dane.

  void _onAppointmentTapped(CalendarTapDetails details) async {
    if (details.targetElement != CalendarElement.appointment || details.appointments?.isEmpty == true) return;

    final appointment = details.appointments!.first;
    if (appointment is AvailabilityAppointmentItem) {
      final projectId = appointment.availability.projectId;
      // ZMIANA: Zamiast List.from, używamy .toList(), co jest bardziej standardowe i tworzy modyfikowalną listę.
      final allAvailabilitiesForProject = _myAvailabilities.values.where((a) => a.projectId == projectId).toList();

      // ZMIANA: Oczekujemy na wartość bool, a nie na listę.
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AvailabilityWizard(
          userId: userService.uid!,
          projects: _projectCache.values.toList(),
          templates: _allUserTemplates,
          initialDate: appointment.availability.date,
          allAvailabilitiesForProject: allAvailabilitiesForProject,
        ),
      );

      // ZMIANA: Sprawdzamy, czy kreator zwrócił 'true' i odświeżamy dane.
      if (result == true) {
        await _loadInitialData(forceRefresh: true);
      }
    }
  }

  void _showAvailabilityWizard() async {
    final String? userId = userService.uid;
    if (userId == null) return;

    // ZMIANA: Oczekujemy na wartość bool.
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AvailabilityWizard(
        userId: userId,
        projects: _projectCache.values.toList(),
        templates: _allUserTemplates,
        initialDate: _calendarController.displayDate ?? DateTime.now(),
        // W trybie dodawania przekazujemy pustą, modyfikowalną listę.
        allAvailabilitiesForProject: [],
      ),
    );

    // ZMIANA: Sprawdzamy, czy kreator zwrócił 'true' i odświeżamy dane.
    if (result == true) {
      await _loadInitialData(forceRefresh: true);
    }
  }

  String _getAppBarTitle() {
    switch (_displayMode) {
      case ScheduleDisplayMode.myAssignments: return 'Mój Grafik';
      case ScheduleDisplayMode.allTemplates: return 'Harmonogramy Firm';
      case ScheduleDisplayMode.availability: return 'Moja Dyspozycyjność';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text(_getAppBarTitle()),
        actions: [
          if (_displayMode == ScheduleDisplayMode.availability)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colorScheme.onPrimary),
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: const Text('Zadeklaruj'),
              onPressed: _showAvailabilityWizard,
            ),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _calendarController.backward!()),
          IconButton(icon: const Icon(Icons.today, size: 20), onPressed: () {
            _calendarController.displayDate = DateTime.now();
            if (_displayMode == ScheduleDisplayMode.allTemplates) {
              _buildAllTemplatesView(ViewChangedDetails([DateTime.now()]));
            }
          }),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _calendarController.forward!()),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SegmentedButton<ScheduleDisplayMode>(
              segments: const <ButtonSegment<ScheduleDisplayMode>>[
                ButtonSegment<ScheduleDisplayMode>(value: ScheduleDisplayMode.myAssignments, label: Text('Mój Grafik'), icon: Icon(Icons.person, color: Colors.white)),
                ButtonSegment<ScheduleDisplayMode>(value: ScheduleDisplayMode.allTemplates, label: Text('Harmonogramy'), icon: Icon(Icons.apps, color: Colors.white)),
                ButtonSegment<ScheduleDisplayMode>(value: ScheduleDisplayMode.availability, label: Text('Dyspozycyjność'), icon: Icon(Icons.event_available, color: Colors.white)),
              ],
              selected: {_displayMode},
              onSelectionChanged: (newSelection) => setState(() {
                _displayMode = newSelection.first;
                _refreshCalendarView();
              }),
              style: SegmentedButton.styleFrom(
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                foregroundColor: colorScheme.onPrimary,
                selectedForegroundColor: colorScheme.primary,
                selectedBackgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
        key: _calendarKey,
        controller: _calendarController,
        view: _currentView,
        dataSource: _dataSource,
        firstDayOfWeek: 1,
        onViewChanged: _buildAppointmentsForVisibleDates,
        onTap: _onAppointmentTapped,
        timeSlotViewSettings: const TimeSlotViewSettings(timeIntervalHeight: 24, timeFormat: 'HH:mm'),
        appointmentBuilder: (context, details) {
          final appointment = details.appointments.first;
          if (appointment is UserScheduleAppointmentItem) {
            final isAssigned = appointment.assignment != null;
            final blockColor = isAssigned ? appointment.color : appointment.color.withOpacity(0.35);
            final border = isAssigned ? null : Border.all(color: appointment.color, width: 1);
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(4), border: border),
              child: Text(appointment.subject, style: const TextStyle(color: Colors.white, fontSize: 10)),
            );
          }
          if (appointment is AvailabilityAppointmentItem) {
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: appointment.color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black26)),
              child: Text(appointment.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
            );
          }
          return Container();
        },
      ),
    );
  }
}