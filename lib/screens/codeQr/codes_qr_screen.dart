import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../exceptions/code_qr_exception.dart';
import '../../models/code-qr.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../../widgets/dialogs.dart';
import '../../services/code_qr_service.dart';
import '../../services/user_service.dart';


class CodesQrScreen extends StatefulWidget {
  final Project project;
  final License? license;

  const CodesQrScreen({
    super.key,
    required this.project,
    this.license,
  });

  @override
  State<CodesQrScreen> createState() => _CodesQrScreenState();
}

class _CodesQrScreenState extends State<CodesQrScreen> {
  List<CodeQr> _codes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _getCodes();
  }

  Future<void> _getCodes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isProcessing = true;
    });
    try {
      // Pobieramy dane jako Future, używając .first na strumieniu
      _codes = await codeQrService.getCodesByProject(widget.project.projectId).first;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu kodów QR: $e\n$stackTrace');
      if (mounted) {
        final errorMessageText = 'Nie udało się załadować kodów QR: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessageText;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _createNewCodeQr() async {
    if (widget.license != null && _codes.length >= widget.license!.qrCodes) {
    await showInfoDialog(
         context,
        'Limit Osiągnięty',
         'Osiągnięto maksymalną liczbę kodów QR dozwoloną przez Twoją licencję.',
       );
      return;
    }
    var changed = await context.push('/create-code-qr', extra: {
      'project': widget.project,
      'license': widget.license,
    }) as bool?;
    if (changed == true && mounted) {
      await _getCodes(); // Odśwież listę, jeśli coś się zmieniło
    }
  }

  // W przyszłości można zaimplementować nawigację do osobnego ekranu edycji
  Future<void> _editCodeQr(CodeQr code) async {
    var changed = await context.push('/edit-code-qr', extra: code) as bool?;
    if (changed == true && mounted) {
      await _getCodes(); // Odśwież listę, jeśli coś się zmieniło
    }
  }

  void _showQrImageDialog(CodeQr code) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(code.name, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 250, height: 250,
        child: QrImageView(data: code.getQrCode(), version: QrVersions.auto, size: 250.0),
      ),
      actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zamknij')),],
    ));
  }

  Future<void> _deleteCode(CodeQr code) async {
    final shouldDelete = await showDeleteConfirmationDialog(context, 'Potwierdź usunięcie', 'Czy na pewno chcesz trwale usunąć kod "${code.name}"?');
    if (shouldDelete == true) {
      setState(() => _isProcessing = true);
      try {
        await codeQrService.deleteCodeQr(code.codeQrId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod QR został usunięty.')));
        await _getCodes(); // Odśwież listę
      } on CodeQrException catch (e) {
        if (mounted) await showErrorDialog(context, 'Błąd Usuwania', e.message);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
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
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć do menu projektu",
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: Text(
          'Kody QR: ${widget.project.name}',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading || _isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież listę',
              onPressed: _isProcessing ? null : _getCodes,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _createNewCodeQr,
        tooltip: 'Dodaj nowy kod QR',
        icon: const Icon(Icons.qr_code_scanner_outlined),
        label: const Text('Dodaj kod'),
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.onTertiary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary.withOpacity(0.7), colorScheme.secondary.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Card(
          elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text("Ładowanie kodów QR...", style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  onPressed: _getCodes,
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_codes.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_sharp, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 20),
                Text('Brak zdefiniowanych kodów QR', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Naciśnij przycisk "+" aby dodać nowy kod dla tego projektu.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _getCodes,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _codes.length,
        itemBuilder: (context, index) {
          final code = _codes[index];
          return _buildCodeItem(code, theme);
        },
      ),
    );
  }

  Widget _buildCodeItem(CodeQr code, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _editCodeQr(code),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2_sharp, color: colorScheme.primary, size: 40),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(code.name, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (code.description.isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        code.description,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // Przyciski akcji
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.qr_code_2, color: colorScheme.secondary),
                    tooltip: 'Pokaż kod',
                    onPressed: _isProcessing ? null : () =>  _showQrImageDialog(code),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: 'Usuń kod',
                    onPressed: _isProcessing ? null : () => _deleteCode(code),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}