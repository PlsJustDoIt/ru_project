import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/widgets/more_widget.dart';

void main() {
  testWidgets('le hub Plus liste les entrées attendues', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoreWidget())),
    );
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
    // « Signaler un bug » est désormais une action globale d'AppBar, plus une
    // entrée du hub Plus.
    expect(find.text('Signaler un bug'), findsNothing);
  });
}
