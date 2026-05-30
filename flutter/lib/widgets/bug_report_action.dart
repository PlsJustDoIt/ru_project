import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/services/feedback_service.dart';

/// Ouvre l'overlay de feedback (capture d'écran annotable) et envoie le rapport.
/// Centralisé ici pour être réutilisable depuis n'importe quelle AppBar.
Future<void> showBugReport(BuildContext context) async {
  final feedbackService = Provider.of<FeedbackService>(context, listen: false);
  BetterFeedback.of(context).show((UserFeedback feedback) async {
    final res = await feedbackService.sendFeedback(feedback);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res ? 'Feedback envoyé :)' : 'Echec de l\'envoi :('),
      ),
    );
  });
}

/// Bouton « Signaler un bug » à placer dans les `actions` d'une AppBar,
/// pour le rendre disponible sur toutes les pages.
class BugReportButton extends StatelessWidget {
  const BugReportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report_outlined),
      tooltip: 'Signaler un bug',
      onPressed: () => showBugReport(context),
    );
  }
}
