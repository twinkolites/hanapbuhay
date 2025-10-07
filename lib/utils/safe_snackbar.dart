import 'package:flutter/material.dart';

/// Utility class for safely showing SnackBars
/// Prevents animation errors when widgets are disposed
class SafeSnackBar {
  /// Safely show a SnackBar with mounted check
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    // Check if the widget is still mounted
    if (!context.mounted) return;
    
    try {
      // Additional check for ScaffoldMessenger availability
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger == null) return;
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: action,
        ),
      );
    } catch (e) {
      // Silently handle any errors
      debugPrint('Error showing SnackBar: $e');
    }
  }

  /// Show success SnackBar
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.green,
      duration: duration,
    );
  }

  /// Show error SnackBar
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.red,
      duration: duration,
    );
  }

  /// Show info SnackBar
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.blue,
      duration: duration,
    );
  }

  /// Show warning SnackBar
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.orange,
      duration: duration,
    );
  }
}
