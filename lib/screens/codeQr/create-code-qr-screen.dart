import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

// Importy modeli
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/license.dart';
import '../../models/work_type.dart';

// Importy serwisów i widgetów
import '../../exceptions/code_qr_exception.dart';
import '../../services/area_service.dart';
import '../../services/code_qr_service.dart';
import '../../services/location_service.dart'; // Upewnij się, że ten import jest poprawny
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

  // --- Stan dla obszaru i typów pracy ---
  Area? _selectedArea;
  List<WorkType> _availableWorkTypesForArea = [];
  List<String> _selectedWorkTypesIds = [];
  bool _isLoadingWorkTypes = false;

  // --- NOWOŚĆ: Stan dla lokalizacji ---
  final _maxDistanceController = TextEditingController(text: '100'); // Domyślny dystans
  bool _checkLocation = false;
  GeoPoint? _currentLocation;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxDistanceController.dispose(); // NOWOŚĆ
    super.dispose();
  }

  Future<void> _createQrCode() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      showErrorDialog(context, 'Brak Obszaru', 'Musisz wybrać obszar, do którego chcesz przypisać ten kod QR.');
      return;
    }
    // NOWOŚĆ: Walidacja lokalizacji
    if (_checkLocation && _currentLocation == null) {
      showErrorDialog(context, 'Brak Lokalizacji', 'Jeśli weryfikacja lokalizacji jest włączona, musisz najpierw pobrać lokalizację.');
      return;
    }

    setState(() { _isSaving = true; });

    try {
      // MODYFIKACJA: Przekazanie danych o lokalizacji do serwisu
      await codeQrService.createCodeQr(
        name: _nameController.text.trim(),
        projectId: widget.project.projectId,
        areaId: _selectedArea!.areaId,
        ownerId: widget.project.ownerId,
        licenseId: widget.license?.licenseId ?? '',
        description: _descriptionController.text.trim(),
        workTypeIds: _selectedWorkTypesIds,
        // Nowe pola:
        checkLocation: _checkLocation,
        location: _checkLocation ? _currentLocation : null,
        maxDistanceInMeters: _checkLocation ? int.tryParse(_maxDistanceController.text.trim()) : null,
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

  // --- Metody do obsługi obszaru i typów pracy (bez zmian) ---
  Future<void> _selectArea() async {
    if (_isSaving) return;
    final result = await context.push<Area?>(
      '/select-area', // Upewnij się, że ta ścieżka jest poprawna w Twoim routerze
      extra: widget.project,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedArea = result;
        _availableWorkTypesForArea.clear();
        _selectedWorkTypesIds.clear();
      });
      await _loadWorkTypesForSelectedArea();
    }
  }

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

  // --- NOWOŚĆ: Metoda do pobierania lokalizacji ---
  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);

    try {
      final position = await LocationService.determinePosition();
      if (mounted) {
        setState(() {
          _currentLocation = GeoPoint(position.latitude, position.longitude);
        });
        showInfoDialog(context, 'Sukces', 'Pobrano aktualną lokalizację.');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd Lokalizacji', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
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

                          // --- NOWOŚĆ: Sekcja lokalizacji ---
                          const SizedBox(height: 24.0),
                          _buildLocationSection(theme),
                          // --- Koniec nowej sekcji ---

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

  Widget _buildWorkTypeSelectionSection(ThemeData theme) {
    if (_selectedArea == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Center(child: Text('Najpierw wybierz obszar, aby zobaczyć dostępne typy pracy.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme.textTheme, "2. Wybierz Typy Pracy dla Kodu QR"),

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

  // --- NOWOŚĆ: Widget budujący sekcję lokalizacji ---
  Widget _buildLocationSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme.textTheme, "3. Lokalizacja (Opcjonalnie)"),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Wymagaj weryfikacji lokalizacji"),
                subtitle: const Text("Skanowanie powiedzie się tylko w pobliżu"),
                value: _checkLocation,
                onChanged: (value) {
                  setState(() {
                    _checkLocation = value;
                  });
                },
                secondary: Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
              ),
              if (_checkLocation)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextFormField(
                              controller: _maxDistanceController,
                              labelText: 'Maksymalny dystans (w metrach)',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Pole jest wymagane.';
                                if (int.tryParse(v) == null) return 'Wprowadź poprawną liczbę.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_isGettingLocation)
                              const Center(child: CircularProgressIndicator())
                            else
                              OutlinedButton.icon(
                                icon: const Icon(Icons.my_location),
                                label: const Text('Pobierz aktualną lokalizację'),
                                onPressed: _getCurrentLocation,
                              ),
                            const SizedBox(height: 8),
                            if (_currentLocation != null)
                              Center(
                                child: Text(
                                  'Zapisano: ${_currentLocation!.latitude.toStringAsFixed(5)}, '
                                      '${_currentLocation!.longitude.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              )
                            else
                              Center(
                                child: Text(
                                  'Nie pobrano jeszcze lokalizacji',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}