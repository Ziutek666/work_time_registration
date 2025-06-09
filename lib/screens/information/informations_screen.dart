import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/information.dart';
import '../../models/information_category.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../services/information_service.dart';
import '../../services/information_category_service.dart';
import '../../widgets/dialogs.dart';
import 'create-category-screen.dart';


class InformationsScreen extends StatefulWidget {
  final Project project;
  final License? license;

  const InformationsScreen({
    super.key,
    required this.project,
    this.license,
  });

  @override
  _InformationsScreenState createState() => _InformationsScreenState();
}

class _InformationsScreenState extends State<InformationsScreen> {
  // Dane
  List<Information> _allInformations = [];
  List<Information> _filteredInformations = [];
  Map<String, InformationCategory> _fetchedCategories = {};

  // Stan UI
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  // Stan filtra
  InformationCategory? _selectedFilterCategory;
  List<InformationCategory> _availableCategoriesForFilter = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ZMIANA: Pobieramy informacje i kategorie w dwóch równoległych zapytaniach
      final results = await Future.wait([
        informationService.fetchAllInformationByProjectId(widget.project.projectId),
        informationCategoryService.getAllCategoriesForProject(widget.project.projectId),
      ]);

      final fetchedInformations = results[0] as List<Information>;
      final fetchedCategoriesList = results[1] as List<InformationCategory>;

      if (mounted) {
        setState(() {
          _allInformations = fetchedInformations;
          _fetchedCategories = { for (var cat in fetchedCategoriesList) cat.categoryId : cat };

          _availableCategoriesForFilter = fetchedCategoriesList
            ..sort((a, b) => a.name.compareTo(b.name));
        });
        _applyFilters();
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu informacji lub kategorii: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Nie udało się załadować informacji: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Filtruje listę informacji na podstawie wybranej kategorii.
  void _applyFilters() {
    List<Information> tempFiltered = List.from(_allInformations);

    if (_selectedFilterCategory != null) {
      tempFiltered = tempFiltered
          .where((info) => info.categoryId == _selectedFilterCategory!.categoryId)
          .toList();
    }

    if (mounted) {
      setState(() {
        _filteredInformations = tempFiltered;
      });
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final newCategory = await showDialog<InformationCategory>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateCategoryDialog(projectId: widget.project.projectId),
    );

    if (newCategory != null && mounted) {
      await _loadData();
      setState(() {
        _selectedFilterCategory = _availableCategoriesForFilter.firstWhere(
              (cat) => cat.categoryId == newCategory.categoryId,
        );
      });
      _applyFilters();
    }
  }

  Future<void> _createNewInformation() async {
    if (_selectedFilterCategory == null) {
      await showInfoDialog(context, "Brak wybranej kategorii", "Aby utworzyć nową informację, najpierw wybierz kategorię z filtra.");
      return;
    }

    final result = await context.push<bool>('/create-information', extra: {
      'project': widget.project,
      'category': _selectedFilterCategory,
    });

    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _viewOrEditInformation(Information information) async {
    final result = await context.push('/edit-information', extra: information) as bool?;
    if (result == true && mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Informacje: ${widget.project.name}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: "Wróć", onPressed: () => context.pop()),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież listę',
              onPressed: _isProcessing ? null : _loadData,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewInformation,
        tooltip: _selectedFilterCategory == null ? 'Wybierz kategorię, aby dodać informację' : 'Dodaj nową informację',
        icon: const Icon(Icons.add),
        label: const Text('Dodaj informację'),
        backgroundColor: _selectedFilterCategory == null ? Colors.grey : colorScheme.tertiary,
      ),
      body: Column(
        children: [
          _buildFilterSection(theme),
          Expanded(child: _buildBodyContent(theme)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<InformationCategory>(
                  decoration: InputDecoration(
                    labelText: 'Filtruj wg kategorii',
                    prefixIcon: _selectedFilterCategory == null ? const Icon(Icons.filter_list) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedFilterCategory,
                  hint: const Text('Wszystkie kategorie'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<InformationCategory>(value: null, child: Text('Wszystkie kategorie')),
                    ..._availableCategoriesForFilter.map((category) => DropdownMenuItem<InformationCategory>(value: category, child: Row(children: [Icon(category.iconData, color: category.color, size: 20), const SizedBox(width: 8), Text(category.name, overflow: TextOverflow.ellipsis)]))),
                  ],
                  onChanged: (category) {
                    setState(() => _selectedFilterCategory = category);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                tooltip: 'Dodaj nową kategorię',
                onPressed: _isLoading || _isProcessing ? null : _showCreateCategoryDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                const SizedBox(height: 16),
                Text('Wystąpił błąd', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                  onPressed: _loadData,
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_filteredInformations.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 20),
                Text(
                  _selectedFilterCategory == null ? 'Brak informacji' : 'Brak informacji w tej kategorii',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Naciśnij przycisk "+" aby dodać nową informację dla tego projektu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 80.0),
        itemCount: _filteredInformations.length,
        itemBuilder: (context, index) {
          final information = _filteredInformations[index];
          final category = _fetchedCategories[information.categoryId];
          return _buildInformationItem(information, category, theme);
        },
      ),
    );
  }

  Widget _buildInformationItem(Information information, InformationCategory? category, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final IconData itemIcon = category?.iconData ?? Icons.help_outline_rounded;
    final Color itemColor = category?.color ?? Colors.grey;
    final String categoryName = category?.name ?? "Brak kategorii";

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: itemColor.withOpacity(0.4)),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _viewOrEditInformation(information),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: itemColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 4.0),
                child: Tooltip(
                  message: "$categoryName${information.requiresDecision ? '\n(Wymaga decyzji)' : ''}",
                  child: Icon(itemIcon, color: itemColor, size: 32),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      information.title,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      information.content,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


