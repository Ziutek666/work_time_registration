import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminHistoryMenuScreen extends StatelessWidget {
  const AdminHistoryMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia - Panel Admina'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        // Przycisk powrotu - dostosuj nawigację, jeśli ten ekran jest częścią głębszego stosu
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć",
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Domyślnie wróć do ekranu głównego, jeśli nie ma dokąd wrócić
              context.go('/');
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: const Icon(Icons.work_history),
                  title: const Text('Historia pracy użytkowników'),
                  subtitle: const Text('Przeglądaj wpisy o pracy wszystkich użytkowników'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Używamy push, aby umożliwić łatwy powrót przyciskiem "wstecz"
                    context.push('/admin-history/work');
                  },
                ),
              ),
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Historia informacji'),
                  subtitle: const Text('Zobacz historię odczytanych informacji'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Używamy push, aby umożliwić łatwy powrót przyciskiem "wstecz"
                    context.push('/admin-history/info');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}