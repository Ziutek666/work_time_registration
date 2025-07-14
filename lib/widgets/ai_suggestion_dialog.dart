// Nazwa pliku: widgets/ai_suggestion_dialog.dart

import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'dialogs.dart'; // Zakładając, że tutaj jest showErrorDialog

class AiSuggestionDialog extends StatefulWidget {
  /// Kompletny zestaw danych do analizy przez AI.
  final String dataContext;

  /// Instrukcje systemowe (prompt), które mówią AI, jak ma się zachować.
  final String systemPrompt;

  /// Pytanie, które ma zostać zadane AI.
  final String userQuestion;

  const AiSuggestionDialog({
    super.key,
    required this.dataContext,
    required this.systemPrompt,
    this.userQuestion = "Na podstawie dostarczonych danych, podaj swoje sugestie.",
  });

  @override
  State<AiSuggestionDialog> createState() => _AiSuggestionDialogState();
}

class _AiSuggestionDialogState extends State<AiSuggestionDialog> {
  bool _isLoading = true;
  String? _aiResponse;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAiSuggestion();
  }

  Future<void> _fetchAiSuggestion() async {
    try {
      final promptBuffer = StringBuffer();

      promptBuffer.writeln(widget.systemPrompt);
      promptBuffer.writeln("\n--- DANE DO ANALIZY ---");
      promptBuffer.writeln(widget.dataContext);
      promptBuffer.writeln("--- KONIEC DANYCH ---\n");
      promptBuffer.writeln("Pytanie użytkownika: ${widget.userQuestion}");

      final fullPrompt = promptBuffer.toString();
      final model = FirebaseAI.vertexAI();
      final gemini = model.generativeModel(model: 'gemini-2.0-flash-001');
      final response = await gemini.generateContent([Content.text(fullPrompt)]);

      if (mounted) {
        setState(() {
          _aiResponse = response.text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Nie udało się uzyskać sugestii: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Sugestia AI'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5, // Ustawienie szerokości
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))
              : Text(_aiResponse ?? "Brak odpowiedzi od AI."),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}