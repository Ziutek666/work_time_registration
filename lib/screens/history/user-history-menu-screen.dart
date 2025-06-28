import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserHistoryMenuScreen extends StatelessWidget {
  const UserHistoryMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja historia'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  leading: const Icon(Icons.work_history_outlined),
                  title: const Text('Szczegółowa histori zadań'),
                  subtitle: const Text('Przeglądaj szczegółową historię zadań'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.push('/user-history');
                  },
                ),
              ),
              // Jeśli w przyszłości dodasz tu więcej opcji (np. "Historia moich informacji"),
              // wystarczy dodać kolejny widżet Card w tym miejscu.
            ],
          ),
        ),
      ),
    );
  }
}