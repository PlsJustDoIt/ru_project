import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/theme/app_theme.dart';

void main() {
  testWidgets('le thème expose une AppBar blanche', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          appBar: AppBar(title: const Text('MonCampus')),
        ),
      ),
    );
    expect(find.text('MonCampus'), findsOneWidget);
  });
}
