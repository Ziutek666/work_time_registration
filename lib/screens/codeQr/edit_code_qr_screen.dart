import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

// Importy modeli - upewnij się, że ścieżki są poprawne dla Twojego projektu
import '../../models/area.dart';
import '../../models/code-qr.dart';
import '../../models/work_type.dart';

// Importy serwisów i widgetów - upewnij się, że ścieżki są poprawne
import '../../exceptions/code_qr_exception.dart';
import '../../services/area_service.dart';
import '../../services/code_qr_service.dart';// Serwis do obsługi lokalizacji
import '../../services/location_service.dart';
import '../../services/work_type_service.dart';
import '../../../widgets/dialogs.dart';

class EditCodeQrScreen extends StatefulWidget {
  final CodeQr codeQr;

  const EditCodeQrScreen({
    super.key,
    required this.codeQr,
  });

  @override
  State<EditCodeQrScreen> createState() => _EditCodeQrScreenState();
}

class _EditCodeQrScreenState extends State<EditCodeQrScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _isSaving = false;
  bool _isInitializing = true;

  // --- Stan dla obszaru i typów pracy ---
  Area? _selectedArea;
  late List<String> _selectedWorkTypesIds;
  List<WorkType> _availableWorkTypesForArea = [];
  bool _isLoadingWorkTypes = false;

  // --- Stan dla lokalizacji ---
  bool _isGettingLocation = false;
  late bool _checkLocation;
  late final TextEditingController _maxDistanceController;
  GeoPoint? _currentLocation;

  @override
  void initState() {
    super.initState();
    // Inicjalizacja kontrolerów
    _nameController = TextEditingController(text: widget.codeQr.name);
    _descriptionController = TextEditingController(text: widget.codeQr.description);
    _selectedWorkTypesIds = List.from(widget.codeQr.workTypeIds);

    // Inicjalizacja stanu lokalizacji
    _checkLocation = widget.codeQr.checkLocation ?? false;
    _maxDistanceController = TextEditingController(
      text: widget.codeQr.maxDistanceInMeters?.toString() ?? '100', // Domyślna wartość
    );
    _currentLocation = widget.codeQr.location;

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxDistanceController.dispose();
    super.dispose();
  }

  /// Ładuje dane początkowe (obszar i jego typy pracy)
  Future<void> _loadInitialData() async {
    try {
      if (widget.codeQr.areaId.isNotEmpty) {
        final area = await areaService.getArea(widget.codeQr.areaId);
        if (mounted) {
          setState(() {
            _selectedArea = area;
          });
          if (area != null) {
            await _loadWorkTypesForSelectedArea();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Błąd ładowania danych', 'Nie udało się załadować danych początkowych: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  /// Aktualizuje kod QR
  Future<void> _updateQrCode() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      showErrorDialog(context, 'Brak Obszaru', 'Musisz wybrać obszar, do którego chcesz przypisać ten kod QR.');
      return;
    }
    // Walidacja lokalizacji
    if (_checkLocation && _currentLocation == null) {
      showErrorDialog(context, 'Brak Lokalizacji', 'Jeśli weryfikacja lokalizacji jest włączona, musisz pobrać i zapisać lokalizację.');
      return;
    }

    setState(() { _isSaving = true; });

    final updatedCode = CodeQr(
      codeQrId: widget.codeQr.codeQrId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      projectId: widget.codeQr.projectId,
      areaId: _selectedArea!.areaId,
      ownerId: widget.codeQr.ownerId,
      licenseId: widget.codeQr.licenseId,
      workTypeIds: _selectedWorkTypesIds,
      // Pola lokalizacji
      checkLocation: _checkLocation,
      location: _checkLocation ? _currentLocation : null,
      maxDistanceInMeters: _checkLocation
          ? (int.tryParse(_maxDistanceController.text.trim()) ?? 100)
          : null,
    );

    try {
      await codeQrService.updateCodeQr(updatedCode);
      if (!mounted) return;
      await showSuccessDialog(context, 'Zaktualizowano!', 'Zmiany w kodzie QR zostały zapisane.');
      if (!mounted) return;
      context.pop(true);
    } on CodeQrException catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Błąd Aktualizacji', e.message);
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  /// Metoda do pobierania aktualnej lokalizacji urządzenia
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

  // --- Metody do wyboru obszaru i typów pracy (bez zmian) ---
  Future<void> _selectArea() async {
    if (_isSaving) return;
    final result = await context.push<Area?>(
      '/select_area',
      extra: widget.codeQr.projectId,
    );

    if (result != null && mounted && result.areaId != _selectedArea?.areaId) {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text('Edytuj Kod QR'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Zmiany',
              onPressed: _updateQrCode,
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
          child: _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : Center(
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
                            'Edycja Kodu QR',
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

                          const SizedBox(height: 24.0),
                          _buildLocationSection(theme),

                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Zapisz Zmiany'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            onPressed: _isSaving ? null : _updateQrCode,
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

  // Metody pomocnicze do budowania UI
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
        _buildSectionTitle(theme.textTheme, "1. Powiązany Obszar *"),
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