import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
