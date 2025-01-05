import 'package:flutter/material.dart';

class CustomSnackBar extends SnackBar {
  CustomSnackBar({
    super.key,
    required String message,
    Duration? duration,
  }) : super(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
        );
}
