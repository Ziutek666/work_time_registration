// lib/features/schedule_templates/presentation/combined_schedule_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../models/schedule_template.dart';

class CombinedScheduleCalendarScreen extends StatefulWidget {
  final List<ScheduleTemplate> templates;

  const CombinedScheduleCalendarScreen({
    required this.templates,
    super.key,
  });

  @override
  State<CombinedScheduleCalendarScreen> createState() =>
      _CombinedScheduleCalendarScreenState();
}

class _CombinedScheduleCalendarScreenState
    extends State<CombinedScheduleCalendarScreen> {
  late final _ScheduleDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = _prepareDataSource();
  }

  _ScheduleDataSource _prepareDataSource() {
    final List<Appointment> appointments = [];
    // Pętla w pętli: przechodzimy przez każdy szablon, a potem przez każdy jego blok
    for (final template in widget.templates) {
      for (final block in template.scheduleBlocks) {
        appointments.add(Appointment(
          startTime: block.startTime,
          endTime: block.endTime,
          // Dodajemy nazwę szablonu do nazwy bloku dla lepszej czytelności
          subject: '${template.name}: ${block.name}',
          color: block.color,
          recurrenceRule: block.recurrenceRule,
        ));
      }
    }
    return _ScheduleDataSource(appointments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Połączony harmonogram'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SfCalendar(
        view: CalendarView.week,
        dataSource: _dataSource,
        firstDayOfWeek: 1,
        timeSlotViewSettings: const TimeSlotViewSettings(
          startHour: 6,
          endHour: 22,
          timeIntervalHeight: 60,
        ),
        monthViewSettings: const MonthViewSettings(
          showAgenda: true,
          agendaViewHeight: 150,
        ),
        appointmentTimeTextFormat: 'HH:mm',
      ),
    );
  }
}

// Ta klasa jest identyczna jak w schedule_calendar_screen.dart - można ją reużyć
class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) => appointments![index].startTime;
  @override
  DateTime getEndTime(int index) => appointments![index].endTime;
  @override
  String getSubject(int index) => appointments![index].subject;
  @override
  Color getColor(int index) => appointments![index].color;
  @override
  bool isAllDay(int index) => appointments![index].isAllDay;
  @override
  String? getRecurrenceRule(int index) => appointments![index].recurrenceRule;
}