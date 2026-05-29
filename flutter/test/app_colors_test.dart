import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/color.dart';

void main() {
  test('les jetons direction A ont les bonnes valeurs', () {
    expect(AppColors.accent, const Color(0xFFE01020));
    expect(AppColors.textPrimary, const Color(0xFF1A2B3C));
    expect(AppColors.textSecondary, const Color(0xFF5A6573));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceGrouped, const Color(0xFFF7F8FA));
    expect(AppColors.border, const Color(0xFFE3E6EA));
    expect(AppColors.amber, const Color(0xFFFFC107));
    expect(AppColors.success, const Color(0xFF1A7A3E));
  });
}
