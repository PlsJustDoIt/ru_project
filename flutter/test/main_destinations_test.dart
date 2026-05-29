import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';

void main() {
  test('5 destinations dans le bon ordre', () {
    expect(kMainDestinations.map((d) => d.label).toList(),
        ['Carte', 'Menu', 'Messages', 'Amis', 'Plus']);
  });
}
