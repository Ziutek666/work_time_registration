import 'package:syncfusion_flutter_calendar/calendar.dart';

class ScheduleDataSource extends CalendarDataSource {
  ScheduleDataSource(List<Appointment> source) {
    // Lista `appointments` (z klasy nadrzędnej) jest wypełniana przekazanymi danymi.
    appointments = source;
  }
}