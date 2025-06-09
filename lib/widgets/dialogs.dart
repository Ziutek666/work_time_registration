// delete_confirmation_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/information.dart';
import '../models/information_category.dart';
import '../services/information_category_service.dart';
// --- Początek definicji Dialogów (przeniesiono tutaj dla kompletności przykładu) ---
// W rzeczywistej aplikacji te funkcje powinny być w osobnym pliku, np. lib/widgets/dialogs.dart

Future<bool?> showDeleteConfirmationDialog(BuildContext context, String title, String objectName) async {
  final ThemeData theme = Theme.of(context);
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Użytkownik musi dokonać wyboru
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28), // Mniejsza ikona
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error))),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Czy na pewno chcesz usunąć "$objectName"?'),
              const SizedBox(height: 8),
              Text('Tej operacji nie można cofnąć.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Usuń'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      );
    },
  );
}

Future<void> showErrorDialog(BuildContext context, String title, String message) async {
  final ThemeData theme = Theme.of(context);
  await showDialog(
    context: context,
    barrierDismissible: true, // Pozwól zamknąć klikając obok
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error))),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showAlertDialog(BuildContext context, String title, String message) async {
  final ThemeData theme = Theme.of(context);
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.orange.shade800))),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Text('Rozumiem'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showInfoDialog(BuildContext context, String title, String message) async {
  final ThemeData theme = Theme.of(context);
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary))),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showSuccessDialog(BuildContext context,String title, String message) async {
  final ThemeData theme = Theme.of(context);
  await showDialog(
    context: context,
    barrierDismissible: false, // Sukces można zamknąć tylko przez OK
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.green.shade800))),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            child: const Text('Świetnie!'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<bool?> showQuestionDialog(BuildContext context,String title,String message) async {
  final ThemeData theme = Theme.of(context);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: theme.colorScheme.secondary, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary))),
          ],
        ),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nie'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tak'),
          ),
        ],
      );
    },
  );
}

Future<bool?> showNotificationQuestionDialog(BuildContext context) async {
  return showQuestionDialog(
    context,
    'Potwierdzenie Powiadomienia', // Zmieniony tytuł dla jasności
    'Czy na pewno chcesz wysłać powiadomienie do użytkowników?', // Bardziej szczegółowe pytanie
  );
}

Future<String?> showProjectPickerDialog(BuildContext context, List<Map<String, String>> projectsList,) async {
  final ThemeData theme = Theme.of(context);
  return await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text('Wybierz projekt', style: theme.textTheme.titleLarge),
        content: SizedBox( // Ograniczenie wysokości, aby dialog nie był za duży
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.4, // np. 40% wysokości ekranu
          child: projectsList.isEmpty
              ? Center(child: Text("Brak projektów do wyboru.", style: theme.textTheme.bodyMedium))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: projectsList.length,
            itemBuilder: (context, index) {
              final project = projectsList[index];
              return ListTile(
                leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
                title: Text(project['projectName']!, style: theme.textTheme.titleMedium),
                onTap: () {
                  Navigator.of(dialogContext).pop(project['projectId']);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Zwraca null
            },
          ),
        ],
      );
    },
  );
}

Future<String?> showUserPickerDialog(BuildContext context, List<Map<String, String>> usersList,) async {
  final ThemeData theme = Theme.of(context);
  return await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text('Wybierz użytkownika', style: theme.textTheme.titleLarge),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.4,
          child: usersList.isEmpty
              ? Center(child: Text("Brak użytkowników do wyboru.", style: theme.textTheme.bodyMedium))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: usersList.length,
            itemBuilder: (context, index) {
              final user = usersList[index];
              return ListTile(
                leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                title: Text(user['userName'] ?? 'Brak nazwy', style: theme.textTheme.titleMedium),
                subtitle: Text(user['userEmail'] ?? 'Brak emaila', style: theme.textTheme.bodySmall),
                onTap: () {
                  Navigator.of(dialogContext).pop(user['userId']);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: <Widget>[
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Zwraca null
            },
          ),
        ],
      );
    },
  );
}

Widget buildDialogPriorityIcon(BuildContext context, int priority, bool requiresDecision) {
  final ThemeData theme = Theme.of(context); // Pobierz theme dla spójności
  IconData iconData;
  Color iconColor;

  if (requiresDecision) {
    iconData = Icons.help_outline_rounded; // Bardziej pasująca ikona
    iconColor = theme.colorScheme.secondary; // Użyj koloru z theme
  } else {
    switch (priority) {
      case 0: // Informacja
        iconData = Icons.info_outline_rounded;
        iconColor = Colors.green.shade600; // Można też użyć theme.colorScheme.tertiary lub podobnego
        break;
      case 1: // Ważna Informacja
        iconData = Icons.notification_important_outlined;
        iconColor = Colors.orange.shade700;
        break;
      case 2: // Uwaga
        iconData = Icons.warning_amber_rounded;
        iconColor = theme.colorScheme.error; // Użyj koloru error z theme
        break;
      default:
        iconData = Icons.article_outlined;
        iconColor = theme.colorScheme.onSurfaceVariant; // Neutralny kolor
        break;
    }
  }
  // Zwróć samą ikonę, tooltip można dodać w miejscu użycia, jeśli potrzebny
  return Icon(iconData, color: iconColor, size: 26); // Nieco mniejsza ikona dla Dropdown
}

/// Wyświetla dialog z informacją, dynamicznie pobierając dane jej kategorii.
///
/// Zwraca:
/// - Obiekt `Information` z zaktualizowanymi polami `decision` i `textResponse`,
///   jeśli użytkownik kliknął "Dalej".
/// - `null` jeśli dialog został zamknięty przyciskiem "Anuluj" lub w inny sposób.
Future<Information?> showInformationDialog({
  required BuildContext context,
  required Information information,
  bool barrierDismissible = false,
}) async {
  // ZMIANA: Logika pobierania kategorii została przeniesiona do wnętrza funkcji.
  InformationCategory category;
  try {
    // Zakładamy, że globalna instancja `informationCategoryService` jest dostępna.
    final fetchedCategory = await informationCategoryService.getCategoryById(information.categoryId);

    // Użyj pobranej kategorii lub domyślnej, jeśli nie znaleziono.
    category = fetchedCategory ?? const InformationCategory(
      categoryId: 'default',
      name: 'Brak Kategorii',
      iconCodePoint: 1,
      iconFontFamily: 'MaterialIcons',
      color: Colors.grey,
      projectId: '',
    );
  } catch (e) {
    print("Błąd pobierania kategorii dla dialogu: $e");
    // W przypadku błędu sieciowego, użyj kategorii domyślnej.
    category = const InformationCategory(
      categoryId: 'error',
      name: 'Błąd Kategorii',
      iconCodePoint: 1,
      iconFontFamily: 'MaterialIcons',
      color: Colors.red,
      projectId: '',
    );
  }

  // --- Reszta funkcji pozostaje taka sama, używając pobranego obiektu 'category' ---

  final ThemeData theme = Theme.of(context);
  final ColorScheme colorScheme = theme.colorScheme;
  final TextTheme textTheme = theme.textTheme;

  final IconData categoryIcon = category.iconData;
  final Color categoryColor = category.color;
  final String categoryName = category.name;

  final TextEditingController textResponseController = TextEditingController(text: information.textResponse ?? '');
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool? currentSelectedDecision = information.decision;

  return showDialog<Information?>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext dialogContext) {
      bool isTextResponseVisible = information.textResponseRequiredOnDecision;

      return StatefulBuilder(
        builder: (context, stfSetState) {

          void handleSubmit() {
            bool canProceed = true;
            if (information.requiresDecision && currentSelectedDecision == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Proszę wybrać "Tak" lub "Nie".'), backgroundColor: Colors.orange),
              );
              canProceed = false;
            }

            if (canProceed && information.requiresDecision && information.textResponseRequiredOnDecision) {
              if (textResponseController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Odpowiedź tekstowa jest wymagana przy tej decyzji.'), backgroundColor: Colors.red),
                );
                canProceed = false;
              }
            }

            if (canProceed) {
              Navigator.of(dialogContext).pop(
                information.copyWith(
                  updatedAt: Timestamp.now(),
                  decision: currentSelectedDecision,
                  textResponse: textResponseController.text.trim().isEmpty
                      ? null
                      : textResponseController.text.trim(),
                ),
              );
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(categoryIcon, color: categoryColor, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: textTheme.titleMedium?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        information.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        information.content,
                        style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      if (information.requiresDecision)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wymagana decyzja:',
                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.thumb_down_alt_outlined, color: currentSelectedDecision == false ? Colors.white : colorScheme.error),
                                    label: Text('Nie', style: TextStyle(color: currentSelectedDecision == false ? Colors.white : colorScheme.error)),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: currentSelectedDecision == false ? colorScheme.error : Colors.transparent,
                                      side: BorderSide(color: colorScheme.error),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => stfSetState(() => currentSelectedDecision = false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.thumb_up_alt_outlined, color: currentSelectedDecision == true ? Colors.white : Colors.green.shade700),
                                    label: Text('Tak', style: TextStyle(color: currentSelectedDecision == true ? Colors.white : Colors.green.shade700)),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: currentSelectedDecision == true ? Colors.green.shade700 : Colors.transparent,
                                      side: BorderSide(color: Colors.green.shade700),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => stfSetState(() => currentSelectedDecision = true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      if (isTextResponseVisible)
                        TextFormField(
                          controller: textResponseController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Twoja odpowiedź / komentarz',
                            hintText: information.textResponseRequiredOnDecision && information.requiresDecision
                                ? 'Odpowiedź jest wymagana'
                                : 'Wpisz odpowiedź (opcjonalnie)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add_comment_outlined, size: 18),
                            label: const Text('Dodaj komentarz'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            ),
                            onPressed: () => stfSetState(() => isTextResponseVisible = true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                child: const Text('Anuluj'),
                style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(dialogContext).pop(null),
              ),
              ElevatedButton(
                child: const Text('Dalej'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                onPressed: handleSubmit,
              ),
            ],
          );
        },
      );
    },
  ).then((value) {
    textResponseController.dispose();
    return value;
  });
}