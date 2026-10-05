import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';

void main() {
  testWidgets('la barre basse bascule de page', (tester) async {
    final fakes = [
      for (var i = 0; i < 5; i++)
        MainDestination(
          label: 'D$i',
          icon: Icons.circle,
          builder: (_) => Text('PAGE$i'),
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MainScaffold(destinations: fakes)),
    );

    expect(find.text('PAGE0'), findsOneWidget);
    expect(find.text('PAGE2'), findsNothing);

    await tester.tap(find.text('D2'));
    await tester.pumpAndSettle();

    expect(find.text('PAGE2'), findsOneWidget);
    expect(find.text('PAGE0'), findsNothing);
  });

  testWidgets('mode invité : bandeau masquable et menu de compte complet',
      (tester) async {
    final userProvider = UserProvider(secureStorage: SecureStorage())
      ..enterGuestMode();
    final fakes = [
      for (var i = 0; i < 3; i++)
        MainDestination(
          label: 'D$i',
          icon: Icons.circle,
          builder: (_) => Text('PAGE$i'),
        ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: MaterialApp(home: MainScaffold(destinations: fakes)),
      ),
    );

    expect(find.textContaining('Mode invité'), findsOneWidget);
    await tester.tap(find.byTooltip('Masquer'));
    await tester.pump();
    expect(find.textContaining('Mode invité'), findsNothing);

    await tester.tap(find.byTooltip('Compte'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Changer de RU'), findsOneWidget);
    expect(find.text('Quitter le mode invité'), findsOneWidget);
  });
}
