// Nazwa pliku: widgets/availability_assignment_dialog.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/area.dart';
import '../models/member.dart';
import '../models/schedule_assignments.dart';
import '../models/schedule_template.dart';
import '../models/user_app.dart';
import '../models/user_availability.dart';
import '../screens/schedule/admin_schedule_calendar_screen.dart';
import '../services/area_service.dart';
import '../services/members_service.dart';
import '../services/schedule_assignment_service.dart';
import 'ai_suggestion_dialog.dart';
import 'dialogs.dart';

class AvailabilityAssignmentDialog extends StatefulWidget {
  final List<UnifiedAppointmentItem> allAppointments;
  final int initialIndex;
  final Map<String, UserApp> userMap;
  final Map<String, Area> areaCache;
  final List<ScheduleAssignment> allAssignments;
  final ScheduleTemplate template;

  const AvailabilityAssignmentDialog({
    super.key,
    required this.allAppointments,
    required this.initialIndex,
    required this.userMap,
    required this.areaCache,
    required this.allAssignments,
    required this.template,
  });

  @override
  State<AvailabilityAssignmentDialog> createState() => _AvailabilityAssignmentDialogState();
}

class _AvailabilityAssignmentDialogState extends State<AvailabilityAssignmentDialog> {
  late PageController _pageController;
  late UnifiedAppointmentItem _currentAppointment;
  late int _currentPage;

  // Stan formularza
  UserApp? _selectedUser;
  bool _isSaving = false;
  bool _hasMadeChanges = false;

  // Stan dla sugestii AI
  bool _isAiSuggesting = false;

  // ZMIANA: Lista użytkowników z dostępem do obszaru szablonu
  List<UserApp> _usersWithAccessToTemplateArea = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: _currentPage);
    _currentAppointment = widget.allAppointments[_currentPage];
    _filterUsersForTemplateArea();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// NOWA FUNKCJA: Filtruje użytkowników, którzy mają dostęp do obszaru tego szablonu.
  Future<void> _filterUsersForTemplateArea() async {
    try {
      final allMembers = await membersService.getMembershipsForProject(widget.template.projectId, widget.userMap.keys.toList());

      final usersWithAccess = allMembers
          .where((member) => member.projects.any((p) => p.projectId == widget.template.projectId && p.areaIds.contains(widget.template.areaId)))
          .map((member) => widget.userMap[member.userId])
          .whereNotNull()
          .toList();

      if (mounted) {
        setState(() {
          _usersWithAccessToTemplateArea = usersWithAccess;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd', 'Nie udało się wczytać listy pracowników z dostępem do tego obszaru: $e');
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  /// Dodaje nowe przypisanie i odświeża dialog.
  Future<void> _addAssignment() async {
    // ZMIANA: Usunięto walidację _selectedArea
    if (_selectedUser == null) {
      showInfoDialog(context, 'Brak danych', 'Wybierz pracownika.');
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final newAssignment = ScheduleAssignment(
        scheduleTemplateId: widget.template.templateId,
        blockIndex: _currentAppointment.blockIndex,
        targetId: _selectedUser!.uid!,
        targetType: widget.template.targetType,
        startDate: _currentAppointment.startTime,
        endDate: _currentAppointment.endTime,
        areaId: widget.template.areaId, // ZMIANA: Użyj areaId z szablonu
      );
      await scheduleAssignmentService.validateOverlappingAssignments([newAssignment], _selectedUser!.uid!);
      final newAssignmentId = await scheduleAssignmentService.createAssignment(newAssignment);

      if (mounted) {
        setState(() {
          final createdAssignment = newAssignment.copyWith(assignmentId: newAssignmentId);
          widget.allAssignments.add(createdAssignment);
          _currentAppointment.assignments.add(createdAssignment);
          _selectedUser = null; // Resetuj tylko użytkownika
          _isSaving = false;
          _hasMadeChanges = true;
        });
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Błąd zapisu', e.toString());
    } finally {
      if (mounted && _isSaving) {
        setState(() { _isSaving = false; });
      }
    }
  }

  /// Usuwa przypisanie i odświeża dialog.
  Future<void> _deleteAssignment(String assignmentId) async {
    await showConfirmationDialog(
      context,
      'Potwierdź usunięcie',
      'Czy na pewno chcesz usunąć to przypisanie z grafiku?',
      onConfirm: () async {
        setState(() { _isSaving = true; });
        try {
          await scheduleAssignmentService.deleteAssignment(assignmentId);
          if (mounted) {
            setState(() {
              widget.allAssignments.removeWhere((a) => a.assignmentId == assignmentId);
              _currentAppointment.assignments.removeWhere((a) => a.assignmentId == assignmentId);
              _hasMadeChanges = true;
            });
          }
        } catch (e) {
          if (mounted) showErrorDialog(context, 'Błąd usuwania', e.toString());
        } finally {
          if (mounted) {
            setState(() { _isSaving = false; });
          }
        }
      },
    );
  }

  /// Przygotowuje dane i pokazuje dialog z sugestią AI.
  Future<void> _getAiSuggestion() async {
    setState(() => _isAiSuggesting = true);

    final dataContext = _generateStringForAiForCurrentSlot();
    const systemPrompt = "Jesteś asystentem planowania.Twoim zadaniem jest przeanalizowanie danych dla KONKRETNEGO bloku czasowego i zasugerowanie najlepszych kandydatów do jego obsadzenia. Twoja odpowiedź powinna być listą punktowaną. Dla każdego sugerowanego (dostępnego) pracownika podaj krótkie uzasadnienie, dlaczego jest dobrym kandydatem. Na końcu podsumuj, dlaczego inni są niedostępni. Odpowiadaj zwięźle i po polsku."
        "Jeżeli nie ma informacji o dostępie do strefy to oznacza że ten pracownik nie ma dostępu";
    const userQuestion = "Kogo najlepiej przypisać do tej zmiany? Podaj sugestie.";

    await showDialog(
      context: context,
      builder: (ctx) => AiSuggestionDialog(
        dataContext: dataContext,
        systemPrompt: systemPrompt,
        userQuestion: userQuestion,
      ),
    );

    if (mounted) {
      setState(() => _isAiSuggesting = false);
    }
  }

  /// Generuje string z danymi dla AI tylko dla bieżącego terminu.
  String _generateStringForAiForCurrentSlot() {
    final buffer = StringBuffer();
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm', 'pl_PL');

    buffer.writeln("Analizowany termin: ${_currentAppointment.subject} dnia ${dateTimeFormat.format(_currentAppointment.startTime)} w obszarze '${widget.areaCache[widget.template.areaId]?.name ?? 'N/A'}'.");

    final availableUsers = _currentAppointment.availabilities.where((a) => a.isAvailable).map((a) => widget.userMap[a.userId]).whereNotNull().toList();
    final unavailableUsers = _currentAppointment.availabilities.where((a) => !a.isAvailable).map((a) => widget.userMap[a.userId]).whereNotNull().toList();
    final assignedUsers = _currentAppointment.assignments.map((a) => widget.userMap[a.targetId]).whereNotNull().toList();

    buffer.writeln("\n--- WSZYSCY PRACOWNICY Z DOSTĘPEM DO TEGO OBSZARU (${_usersWithAccessToTemplateArea.length}) ---");
    for (var user in _usersWithAccessToTemplateArea) { buffer.writeln("- ${user.displayName ?? user.uid} (ID: ${user.uid})"); }

    buffer.writeln("\n--- PRACOWNICY JUŻ PRZYPISANI DO TEGO TERMINU (${assignedUsers.length}) ---");
    if (assignedUsers.isEmpty) buffer.writeln("Nikt nie jest jeszcze przypisany.");
    for (var user in assignedUsers) { buffer.writeln("- ${user.displayName ?? user.uid}"); }

    buffer.writeln("\n--- PRACOWNICY, KTÓRZY ZADEKLAROWALI DOSTĘPNOŚĆ W TYM TERMINIE (${availableUsers.length}) ---");
    if (availableUsers.isEmpty) buffer.writeln("Nikt nie zadeklarował dostępności.");
    for (var user in availableUsers) { buffer.writeln("- ${user.displayName ?? user.uid}"); }

    buffer.writeln("\n--- PRACOWNICY, KTÓRZY ZADEKLAROWALI BRAK DOSTĘPNOŚCI W TYM TERMINIE (${unavailableUsers.length}) ---");
    if (unavailableUsers.isEmpty) buffer.writeln("Nikt nie zadeklarował braku dostępności.");
    for (var user in unavailableUsers) { buffer.writeln("- ${user.displayName ?? user.uid}"); }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    bool canGoBack = _currentPage > 0;
    bool canGoForward = _currentPage < widget.allAppointments.length - 1;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: canGoBack ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null),
          Expanded(child: Text('Zarządzaj terminem', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center)),
          IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: canGoForward ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.allAppointments.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
              _currentAppointment = widget.allAppointments[index];
              _selectedUser = null;
            });
          },
          itemBuilder: (context, index) => _buildAppointmentDetails(widget.allAppointments[index]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(_hasMadeChanges), child: const Text('Zamknij')),
      ],
    );
  }

  Widget _buildAppointmentDetails(UnifiedAppointmentItem appointment) {
    final availableUsers = appointment.availabilities.where((a) => a.isAvailable).map((a) => widget.userMap[a.userId]).whereNotNull().toList();
    final unavailableUsers = appointment.availabilities.where((a) => !a.isAvailable).map((a) => widget.userMap[a.userId]).whereNotNull().toList();
    final assignedUsers = appointment.assignments.map((a) => widget.userMap[a.targetId]).whereNotNull().toList();

    // ZMIANA: Lista użytkowników do wyboru jest teraz filtrowana na starcie
    final assignableUsers = _usersWithAccessToTemplateArea.where((user) => !assignedUsers.any((assigned) => assigned.uid == user.uid)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appointment.subject, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: appointment.color)),
          Text(DateFormat('EEEE, d MMMM yyyy, HH:mm', 'pl_PL').format(appointment.startTime)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dodaj nowe przypisanie', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: _isAiSuggesting ? null : _getAiSuggestion,
                icon: _isAiSuggesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Sugestia AI'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingUsers)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<UserApp>(
              value: _selectedUser,
              hint: const Text('Wybierz pracownika z dostępem...'),
              isExpanded: true,
              items: assignableUsers.map((user) => DropdownMenuItem(value: user, child: Text(user.displayName ?? 'Brak nazwy'))).toList(),
              onChanged: (value) => setState(() => _selectedUser = value),
            ),

          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              // ZMIANA: Uproszczona walidacja
              onPressed: (_selectedUser == null || _isSaving) ? null : _addAssignment,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ),
          const Divider(height: 24),
          _buildAssignedUserList('Przypisani (${appointment.assignments.length})', appointment.assignments),
          _buildUserList('Dostępni (${availableUsers.length})', availableUsers, icon: Icons.check_circle_outline, color: Colors.green.shade700),
          _buildUserList('Niedostępni (${unavailableUsers.length})', unavailableUsers, icon: Icons.highlight_off, color: Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _buildAssignedUserList(String title, List<ScheduleAssignment> assignments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (assignments.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: assignments.map((assignment) {
              final user = widget.userMap[assignment.targetId];
              // ZMIANA: Używamy nazwy obszaru z szablonu
              final areaName = widget.areaCache[widget.template.areaId]?.name ?? 'N/A';
              return Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text('${user?.displayName ?? 'Brak nazwy'} ($areaName)'),
                onDeleted: () => _deleteAssignment(assignment.assignmentId),
                deleteIcon: const Icon(Icons.delete_forever, size: 18),
                deleteIconColor: Colors.red.shade700,
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUserList(String title, List<UserApp> users, {IconData? icon, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (users.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: users.map((user) {
              return Chip(
                avatar: icon != null ? Icon(icon, color: color, size: 16) : null,
                label: Text(user.displayName ?? 'Brak nazwy'),
                labelStyle: TextStyle(color: color),
                backgroundColor: color?.withOpacity(0.1),
                side: BorderSide(color: color?.withOpacity(0.4) ?? Colors.grey),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}