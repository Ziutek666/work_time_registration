import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/area.dart';
import '../../../models/project.dart';
import '../../../models/schedule_template.dart';
import '../../../services/area_service.dart';
import '../../../widgets/dialogs.dart';
import '../../exceptions/schedule_template_exceptions.dart';
import '../../models/license.dart';
import '../../services/schedule_template_service.dart';


class ScheduleTemplatesScreen extends StatefulWidget {
  final Project project;
  final License? license;
  const ScheduleTemplatesScreen({
    required this.project,
    this.license,
    super.key
  });

  @override
  _ScheduleTemplatesScreenState createState() => _ScheduleTemplatesScreenState();
}

class _ScheduleTemplatesScreenState extends State<ScheduleTemplatesScreen> {
  List<ScheduleTemplate> _templates = [];
  bool _dataLoaded = false;
  bool _isDeleting = false;

  // ZMIANA: Dodano cache dla nazw obszarów
  Map<String, String> _areaNamesCache = {};

  final Map<ScheduleTargetType, String> _targetTypeLabels = {
    ScheduleTargetType.user: 'Pracownik',
    ScheduleTargetType.workType: 'Rodzaj pracy',
    ScheduleTargetType.area: 'Obszar',
    ScheduleTargetType.qrCode: 'Kod QR',
  };

  final Map<ScheduleTargetType, IconData> _targetTypeIcons = {
    ScheduleTargetType.user: Icons.group_outlined,
    ScheduleTargetType.workType: Icons.build_outlined,
    ScheduleTargetType.area: Icons.public_outlined,
    ScheduleTargetType.qrCode: Icons.qr_code_scanner_rounded,
  };


  @override
  void initState() {
    super.initState();
    _getTemplates();
  }

  Future<void> _getTemplates() async {
    if (!mounted) return;
    setState(() {
      _dataLoaded = false;
    });

    try {
      final templates = await scheduleTemplateService.getTemplatesForProject(widget.project.projectId);
      if (mounted) {
        setState(() {
          _templates = templates;
        });
        // ZMIANA: Po pobraniu szablonów, pobierz nazwy ich obszarów
        if (_templates.isNotEmpty) {
          await _fetchAreaDetailsForTemplates();
        }
        setState(() {
          _dataLoaded = true;
        });
      }
    } on ScheduleTemplateException catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd szablonów', e.message);
        setState(() => _dataLoaded = true);
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd krytyczny', 'Wystąpił nieoczekiwany błąd: ${e.toString()}');
        setState(() => _dataLoaded = true);
      }
    }
  }

  // NOWA FUNKCJA: Pobiera szczegóły obszarów i zapisuje je w cache
  Future<void> _fetchAreaDetailsForTemplates() async {
    final areaIds = _templates.map((t) => t.areaId).where((id) => id.isNotEmpty).toSet();
    if (areaIds.isEmpty) return;

    try {
      final areas = await areaService.getAreasByIds(areaIds.toList());
      if (mounted) {
        setState(() {
          _areaNamesCache = {for (var area in areas) area.areaId: area.name};
        });
      }
    } catch (e) {
      print("Nie udało się pobrać szczegółów obszarów: $e");
    }
  }

  Future<void> _deleteTemplate(BuildContext context, ScheduleTemplate template) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: const Text('Potwierdź usunięcie'),
          content: Text('Czy na pewno chcesz usunąć szablon harmonogramu "${template.name}"? Tej operacji nie można cofnąć.'),
          actions: <Widget>[
            TextButton(child: const Text('Anuluj'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
              child: const Text('Usuń'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isDeleting = true);

      try {
        await scheduleTemplateService.deleteTemplate(template.templateId);
        if (mounted) {
          await showSuccessDialog(context, 'Sukces', 'Szablon "${template.name}" został pomyślnie usunięty.');
          await _getTemplates();
        }
      } catch (e) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd usuwania', 'Nie udało się usunąć szablonu: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  Future<void> _goToCreateScreen() async {
    final result = await context.push('/create_schedule_template', extra: {
      'project': widget.project,
      'license': widget.license,
    }) as bool?;
    if (result == true && mounted) {
      _getTemplates();
    }
  }

  void _goToCombinedCalendar() {
    if (_templates.isEmpty) {
      showInfoDialog(context, 'Brak szablonów', 'Nie ma żadnych szablonów do wyświetlenia na połączonym kalendarzu.');
      return;
    }
    context.push('/combined-schedule-calendar', extra: _templates);
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć do menu projektu",
          onPressed: () => context.pop(),
        ),
        title: Text('Szablony harmonogramów', style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: "Pokaż połączony kalendarz",
            onPressed: _goToCombinedCalendar,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Utwórz nowy szablon",
            onPressed: _goToCreateScreen,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.secondary.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _dataLoaded ? _templatesList(theme) : _loadingIndicator(theme),
          ),
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Usuwanie szablonu...")],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingIndicator(ThemeData theme) {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text("Ładowanie szablonów...", style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templatesList(ThemeData theme) {
    if (_templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_view_month_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.8)),
                  const SizedBox(height: 20),
                  Text('Brak szablonów w tym projekcie.', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text('Kliknij ikonę "+" w prawym górnym rogu, aby dodać nowy.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _getTemplates,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return _buildTemplateItem(context, template, theme);
        },
      ),
    );
  }

  Widget _buildTemplateItem(BuildContext context, ScheduleTemplate template, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    // ZMIANA: Pobierz nazwę obszaru z cache
    final areaName = _areaNamesCache[template.areaId] ?? '...';

    return InkWell(
      onTap: () => context.push('/schedule-calendar', extra: {
        'project': widget.project,
        'template': template,
      }),
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        elevation: 5.0,
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: colorScheme.outline.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(_targetTypeIcons[template.targetType] ?? Icons.schema_outlined, color: colorScheme.primary, size: 38),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (template.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(template.description, style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildBlocksInfo(template, theme),
                  _buildTargetTypeInfo(template, theme),
                  // ZMIANA: Dodano wyświetlanie nazwy obszaru
                  _buildAreaInfo(areaName, theme),
                ],
              ),
              const Divider(height: 24.0, thickness: 0.8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.secondary, size: 20),
                    label: Text('Edytuj', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final result = await context.push('/edit_schedule_template', extra: {
                        'project': widget.project,
                        'template': template,
                      }) as bool?;
                      if (result == true && mounted) {
                        _getTemplates();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                    label: Text('Usuń', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600)),
                    onPressed: () => _deleteTemplate(context, template),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlocksInfo(ScheduleTemplate template, ThemeData theme) {
    final count = template.scheduleBlocks.length;
    final String text;
    if (count == 1) {
      text = 'zdefiniowany blok';
    } else if (count > 1 && count < 5) {
      text = 'zdefiniowane bloki';
    } else {
      text = 'zdefiniowanych bloków';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, color: theme.colorScheme.secondary, size: 16),
          const SizedBox(width: 6),
          Text('$count $text', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTargetTypeInfo(ScheduleTemplate template, ThemeData theme) {
    final icon = _targetTypeIcons[template.targetType] ?? Icons.help_outline;
    final label = _targetTypeLabels[template.targetType] ?? 'Nieznany';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 16),
          const SizedBox(width: 6),
          Text('Typ: $label', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // NOWA METODA: Buduje etykietę z nazwą obszaru
  Widget _buildAreaInfo(String areaName, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, color: Colors.teal, size: 16),
          const SizedBox(width: 6),
          Text(areaName, style: theme.textTheme.bodySmall?.copyWith(color: Colors.teal, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}