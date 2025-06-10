import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Importy modeli
import '../../models/area.dart'; // <-- Dodany import
import '../../models/project.dart';
import '../../models/license.dart';
import '../../models/work_type.dart';

// Importy serwisów i widgetów
import '../../exceptions/code_qr_exception.dart';
import '../../services/area_service.dart'; // <-- Dodany import
import '../../services/code_qr_service.dart';
import '../../services/work_type_service.dart';
import '../../../widgets/dialogs.dart';

class CreateCodeQrScreen extends StatefulWidget {
  final Project project;
  final License? license;

  const CreateCodeQrScreen({
    super.key,
    required this.project,
    this.license,
  });

  @override
  State<CreateCodeQrScreen> createState() => _CreateCodeQrScreenState();
}

class _CreateCodeQrScreenState extends State<CreateCodeQrScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;

  // --- NOWY STAN DLA OBSZARU I TYPÓW PRACY ---
  Area? _selectedArea;

  // Lista typów pracy dostępnych dla wybranego obszaru
  List<WorkType> _availableWorkTypesForArea = [];
  // Lista ID typów pracy zaznaczonych przez użytkownika
  List<String> _selectedWorkTypesIds = [];

  bool _isLoadingWorkTypes = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createQrCode() async {
    if (_isSaving) return;
    // Walidacja formularza i wybranego obszaru
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      showErrorDialog(context, 'Brak Obszaru', 'Musisz wybrać obszar, do którego chcesz przypisać ten kod QR.');
      return;
    }

    setState(() { _isSaving = true; });

    try {
      await codeQrService.createCodeQr(
        name: _nameController.text.trim(),
        projectId: widget.project.projectId,
        areaId: _selectedArea!.areaId, // <-- Przekazanie ID obszaru
        ownerId: widget.project.ownerId,
        licenseId: widget.license?.licenseId ?? '',
        description: _descriptionController.text.trim(),
        workTypeIds: _selectedWorkTypesIds, // <-- Przekazanie zaznaczonych typów pracy
      );

      if (!mounted) return;
      await showSuccessDialog(context, 'Utworzono!', 'Nowy kod QR "${_nameController.text.trim()}" został pomyślnie utworzony.');
      if (!mounted) return;
      context.pop(true);
    } on CodeQrException catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd Tworzenia Kodu QR', e.message);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd', 'Wystąpił nieoczekiwany błąd: $e');
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  /// Otwiera ekran wyboru obszaru.
  Future<void> _selectArea() async {
    if (_isSaving) return;
    final result = await context.push<Area?>(
      '/select-area',
      extra: widget.project,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedArea = result;
        // Resetujemy poprzednie wybory po zmianie obszaru
        _availableWorkTypesForArea.clear();
        _selectedWorkTypesIds.clear();
      });
      // Ładujemy typy pracy dla nowo wybranego obszaru
      await _loadWorkTypesForSelectedArea();
    }
  }

  /// Ładuje typy pracy na podstawie ID powiązanych z wybranym obszarem.
  Future<void> _loadWorkTypesForSelectedArea() async {
    if (_selectedArea == null || _selectedArea!.workTypesIds.isEmpty) {
      setState(() => _availableWorkTypesForArea = []);
      return;
    }

    setState(() => _isLoadingWorkTypes = true);
    try {
      final workTypes = await workTypeService.getWorkTypesByIds(_selectedArea!.workTypesIds);
      if (mounted) {
        setState(() {
          _availableWorkTypesForArea = workTypes..sort((a,b) => a.name.compareTo(b.name));
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd', 'Nie udało się załadować typów pracy dla obszaru: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkTypes = false);
      }
    }
  }

  /// Obsługuje zaznaczenie/odznaczenie checkboxa dla typu pracy.
  void _onWorkTypeSelected(bool? isSelected, String workTypeId) {
    setState(() {
      if (isSelected == true) {
        if (!_selectedWorkTypesIds.contains(workTypeId)) {
          _selectedWorkTypesIds.add(workTypeId);
        }
      } else {
        _selectedWorkTypesIds.remove(workTypeId);
      }
    });
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
        title: const Text('Nowy Kod QR'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Kod QR',
              onPressed: _createQrCode,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary.withOpacity(0.7), colorScheme.secondary.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Definiowanie Nowego Kodu QR',
                            style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24.0),

                          _buildSectionTitle(textTheme, "Informacje Ogólne"),
                          _buildTextFormField(
                            controller: _nameController,
                            labelText: "Nazwa Kodu QR *",
                            validator: (v) => (v==null||v.trim().isEmpty)?'Nazwa jest wymagana.':null,
                          ),
                          const SizedBox(height: 16.0),
                          _buildTextFormField(
                            controller: _descriptionController,
                            labelText: "Opis (opcjonalnie)",
                            maxLines: 3,
                          ),

                          const SizedBox(height: 24.0),
                          _buildAreaSelectionSection(theme),

                          const SizedBox(height: 16.0),
                          _buildWorkTypeSelectionSection(theme),

                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Utwórz Kod QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            onPressed: _isSaving ? null : _createQrCode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Metody budujące UI ---

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      maxLines: maxLines,
      validator: validator,
      enabled: !_isSaving,
    );
  }

  /// Buduje sekcję wyboru obszaru.
  Widget _buildAreaSelectionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme.textTheme, "1. Wybierz Obszar *"),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: Icon(Icons.place_outlined, color: theme.colorScheme.primary),
            title: Text(_selectedArea?.name ?? 'Nie wybrano obszaru'),
            subtitle: Text(_selectedArea != null ? 'Kliknij, aby zmienić' : 'Kliknij, aby wybrać'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _isSaving ? null : _selectArea,
          ),
        ),
      ],
    );
  }

  /// Buduje sekcję wyboru typów pracy, widoczną po wybraniu obszaru.
  Widget _buildWorkTypeSelectionSection(ThemeData theme) {
    // Sekcja jest ukryta, dopóki nie wybierzemy obszaru
    if (_selectedArea == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme.textTheme, "2. Wybierz Typy Pracy dla Kodu QR"),
        Text(
          'Zaznacz zadania, które będą dostępne do rozpoczęcia po zeskanowaniu tego kodu QR.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12.0),

        if (_isLoadingWorkTypes)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else if (_availableWorkTypesForArea.isEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Center(child: Text('Wybrany obszar nie ma przypisanych żadnych typów pracy.')),
          )
        else
        // Lista Checkboxów do wyboru
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableWorkTypesForArea.length,
              itemBuilder: (context, index) {
                final workType = _availableWorkTypesForArea[index];
                return CheckboxListTile(
                  title: Text(workType.name),
                  subtitle: Text(
                    workType.description.isNotEmpty ? workType.description : 'Brak opisu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: _selectedWorkTypesIds.contains(workType.workTypeId),
                  onChanged: (bool? value) {
                    if (!_isSaving) {
                      _onWorkTypeSelected(value, workType.workTypeId);
                    }
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
          ),
      ],
    );
  }
}