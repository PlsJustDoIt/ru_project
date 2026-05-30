import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/theme/app_theme.dart';

void main() {
  test('buildAppTheme applique la direction A', () {
    final theme = buildAppTheme();
    expect(theme.scaffoldBackgroundColor, AppColors.surface);
    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.textTheme.bodyMedium?.color, AppColors.textPrimary);
  });
}
