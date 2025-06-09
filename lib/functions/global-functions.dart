import 'package:flutter/material.dart';
// Załóżmy, że model Information i funkcja showInformationDialog są dostępne
// poprzez odpowiednie importy. Dostosuj ścieżki do swojej struktury projektu.
import 'package:work_time_registration/models/information.dart';
import '../widgets/dialogs.dart'; // Załóżmy, że showInformationDialog jest tutaj

Future<List<Information>?> processInformationListWithDialogs({
  required BuildContext context,
  required List<Information> informationsToProcess,
}) async {
  final List<Information> processedInformations = [];

  // Pętla przez każdą informację z oryginalnej listy
  for (Information originalInformation in informationsToProcess) {
    final Information? updatedInformation = await showInformationDialog(
      context: context,
      information: originalInformation,
    );
    if (updatedInformation != null) {
      processedInformations.add(updatedInformation);
    }else{
      return null;
    }
  }

  return processedInformations;
}