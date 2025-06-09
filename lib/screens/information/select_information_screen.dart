// lib/features/information/presentation/screens/informations_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/information.dart';

import '../../services/information_service.dart'; // Importujemy plik z globalną instancją 'informationService'

import 'package:work_time_registration/models/information_category.dart';

import '../../services/information_category_service.dart';

class SelectInformationScreen extends StatefulWidget {
  final String projectId;
  // Opcjonalnie: można przekazać listę ID do wykluczenia
  final List<String>? excludeIds;

  const SelectInformationScreen({
    Key? key,
    required this.projectId,
    this.excludeIds,
  }) : super(key: key);

  @override
  _SelectInformationScreenState createState() => _SelectInformationScreenState();
}

class _SelectInformationScreenState extends State<SelectInformationScreen> {
  List<Information> _informations = [];
  Map<String, InformationCategory> _categoriesMap = {}; // Mapa do przechowywania kategorii
  bool _isLoading = true;
  String? _errorMessage;

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
      // 1. Pobierz wszystkie informacje dla projektu
      var fetchedInformations = await informationService.fetchAllInformationByProjectId(widget.projectId);

      // 2. Opcjonalnie, odfiltruj informacje na podstawie excludeIds
      if (widget.excludeIds != null && widget.excludeIds!.isNotEmpty) {
        fetchedInformations.removeWhere((info) => widget.excludeIds!.contains(info.informationId));
      }

      // 3. Zbierz unikalne ID kategorii z pozostałych informacji
      final categoryIds = fetchedInformations.map((info) => info.categoryId).toSet().toList();

      // 4. Pobierz obiekty kategorii, jeśli są jakieś ID do pobrania
      if (categoryIds.isNotEmpty) {
        final fetchedCategories = await informationCategoryService.getCategoriesByIds(categoryIds);
        _categoriesMap = { for (var cat in fetchedCategories) cat.categoryId : cat };
      }

      if (mounted) {
        setState(() {
          _informations = fetchedInformations;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu informacji lub kategorii: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Nie udało się załadować danych: ${e.toString()}';
        });
      }
    }
  }

  Widget _buildInformationsList(ThemeData theme) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
              const SizedBox(height: 16),
              Text(
                'Wystąpił błąd',
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Spróbuj ponownie'),
                onPressed: _loadData,
              )
            ],
          ),
        ),
      );
    }

    if (_informations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Brak dostępnych informacji do powiązania.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _informations.length,
      itemBuilder: (context, index) {
        final information = _informations[index];
        final category = _categoriesMap[information.categoryId];
        return _buildInformationItem(information, category, theme);
      },
    );
  }

  Widget _buildInformationItem(Information information, InformationCategory? category, ThemeData theme) {
    // Użyj danych z kategorii lub wartości domyślnych
    final icon = category?.iconData ?? Icons.help_outline_rounded;
    final color = category?.color ?? Colors.grey;
    final categoryName = category?.name ?? "Brak kategorii";

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: Tooltip(
          message: "$categoryName${information.requiresDecision ? '\n(Wymaga decyzji)' : ''}",
          child: Icon(icon, color: color, size: 32),
        ),
        title: Text(information.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text(
          information.content,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: information.content.length > 50,
        onTap: () => context.pop(information), // Zwróć wybrany obiekt Information
        trailing: Icon(Icons.add_link, color: theme.colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybierz Informację'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Zamknij",
          onPressed: () {
            context.pop(); // Pop bez wartości
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildInformationsList(theme)),
        ],
      ),
    );
  }
}